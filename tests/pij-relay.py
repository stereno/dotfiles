#!/usr/bin/env python3
from __future__ import annotations

import base64
import hashlib
import http.client
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

BRIDGE = Path(os.environ.get("RELAY", "packages/pij/model-relay.py"))
PYTHON = os.environ.get("PYTHON", sys.executable)
AUTH_CLAIM = "https://api.openai.com/auth"


def fake_jwt(account_id: str) -> str:
    payload = base64.urlsafe_b64encode(
        json.dumps({AUTH_CLAIM: {"chatgpt_account_id": account_id}}).encode()
    ).decode().rstrip("=")
    return f"header.{payload}.signature"


class FakeUpstreamHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    records: list[dict[str, Any]] = []

    def log_message(self, format: str, *args: object) -> None:
        del format, args
        return

    def do_POST(self) -> None:
        length = int(self.headers["Content-Length"])
        body = self.rfile.read(length)
        self.records.append(
            {
                "path": self.path,
                "headers": {name.lower(): value for name, value in self.headers.items()},
                "body": body,
            }
        )
        if body == b"retry-me":
            payload = b'{"error":"busy"}'
            self.send_response(429)
            self.send_header("Content-Type", "application/json")
            self.send_header("Retry-After", "7")
            self.send_header("retry-after-ms", "125")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        first = b'data: {"type":"response.output_text.delta","delta":"o"}\n\n'
        second = b'data: {"type":"response.completed","response":{"status":"completed"}}\n\n'
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(first)
        self.wfile.flush()
        time.sleep(0.5)
        self.wfile.write(second)


class BridgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="pij-openai-bridge-test-")
        self.root = Path(self.temp.name)
        self.agent_dir = self.root / "openai-agent"
        self.agent_dir.mkdir(mode=0o700)
        (self.agent_dir / "auth.json").write_text("{}\n", encoding="utf-8")
        os.chmod(self.agent_dir / "auth.json", 0o600)

        self.real_token = fake_jwt("real-account")
        self.guest_token = fake_jwt("placeholder-account")
        self.helper_record = self.root / "helper-record.jsonl"
        self.outside_marker = self.root / "outside-marker"
        self.outside_marker.write_text("unchanged\n", encoding="utf-8")
        self.pi_bin = self.root / "pi"
        self.pi_bin.write_text(
            "#!/bin/sh\n"
            f"printf '%s\\n' \"$PWD|$PI_CODING_AGENT_DIR|$*\" >>{self.helper_record!s}\n"
            "printf '{\"refreshed-by-helper\":true}\\n' >\"$PI_CODING_AGENT_DIR/auth.json\"\n"
            f"printf '%s\\n' {self.real_token}\n",
            encoding="utf-8",
        )
        os.chmod(self.pi_bin, 0o700)

        FakeUpstreamHandler.records = []
        self.upstream = ThreadingHTTPServer(("127.0.0.1", 0), FakeUpstreamHandler)
        self.upstream_thread = threading.Thread(target=self.upstream.serve_forever, daemon=True)
        self.upstream_thread.start()
        upstream_port = self.upstream.server_address[1]

        self.bridge_port = self.free_tcp_port()
        self.ready = self.root / "ready"
        self.bridge = subprocess.Popen(
            [
                PYTHON,
                str(BRIDGE),
                "serve",
                "--pi-bin",
                str(self.pi_bin),
                "--agent-dir",
                str(self.agent_dir),
                "--guest-token",
                self.guest_token,
                "--upstream-url",
                f"http://127.0.0.1:{upstream_port}/backend-api/codex/responses",
                "--ready",
                str(self.ready),
                "--test-tcp-port",
                str(self.bridge_port),
                "--test-client-timeout",
                "0.2",
            ],
            env={"PATH": os.environ.get("PATH", "")},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        for _ in range(100):
            if self.ready.exists():
                break
            if self.bridge.poll() is not None:
                stderr = self.bridge.stderr.read() if self.bridge.stderr is not None else ""
                self.fail(f"bridge exited early: {stderr}")
            time.sleep(0.02)
        self.assertTrue(self.ready.exists(), "bridge did not become ready")

    def tearDown(self) -> None:
        if hasattr(self, "bridge"):
            self.bridge.terminate()
            try:
                _, stderr = self.bridge.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                self.bridge.kill()
                _, stderr = self.bridge.communicate(timeout=5)
            self.assertNotIn(self.real_token, stderr)
            self.assertNotIn("opaque-private-prompt", stderr)
            self.assertNotIn(str(self.agent_dir), stderr)
        self.upstream.shutdown()
        self.upstream.server_close()
        self.temp.cleanup()

    @staticmethod
    def free_tcp_port() -> int:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            return int(sock.getsockname()[1])

    def fixture_manifest(self) -> dict[str, tuple[str, int, str]]:
        manifest: dict[str, tuple[str, int, str]] = {}
        for path in sorted(self.root.rglob("*")):
            relative = str(path.relative_to(self.root))
            info = path.lstat()
            if path.is_symlink():
                manifest[relative] = ("symlink", info.st_mode, os.readlink(path))
            elif path.is_file():
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                manifest[relative] = ("file", info.st_mode, digest)
            elif path.is_dir():
                manifest[relative] = ("directory", info.st_mode, "")
        return manifest

    def request(
        self,
        body: bytes,
        *,
        token: str | None = None,
        path: str = "/codex/responses",
        encode_chunked: bool = False,
    ) -> tuple[http.client.HTTPResponse, http.client.HTTPConnection]:
        connection = http.client.HTTPConnection("127.0.0.1", self.bridge_port, timeout=5)
        headers = {
            "Authorization": f"Bearer {self.guest_token if token is None else token}",
            "chatgpt-account-id": "guest-spoofed-account",
            "Proxy-Authorization": "Bearer guest-proxy-secret",
            "Forwarded": "for=192.0.2.1",
            "X-Forwarded-For": "192.0.2.2",
            "Host": "attacker.invalid",
            "Content-Type": "application/json",
            "Content-Encoding": "zstd",
            "OpenAI-Beta": "guest-value",
            "originator": "guest-value",
            "session-id": "session-123",
            "x-client-request-id": "request-123",
        }
        if encode_chunked:
            connection.request("POST", path, [body[:3], body[3:]], headers, encode_chunked=True)
        else:
            connection.request("POST", path, body, headers)
        return connection.getresponse(), connection

    def test_forwards_opaque_codex_request_with_fresh_host_identity(self) -> None:
        body = b"\x28\xb5\x2f\xfdopaque-private-prompt"
        response, connection = self.request(body)
        response.read()
        connection.close()

        self.assertEqual(response.status, 200)
        self.assertEqual(len(FakeUpstreamHandler.records), 1)
        upstream = FakeUpstreamHandler.records[0]
        self.assertEqual(upstream["path"], "/backend-api/codex/responses")
        self.assertEqual(upstream["body"], body)
        headers = upstream["headers"]
        self.assertEqual(headers["authorization"], f"Bearer {self.real_token}")
        self.assertEqual(headers["chatgpt-account-id"], "real-account")
        self.assertEqual(headers["content-encoding"], "zstd")
        self.assertEqual(headers["accept"], "text/event-stream")
        self.assertEqual(headers["content-type"], "application/json")
        self.assertEqual(headers["openai-beta"], "responses=experimental")
        self.assertEqual(headers["originator"], "pi")
        self.assertEqual(headers["session-id"], "session-123")
        self.assertEqual(headers["x-client-request-id"], "request-123")
        self.assertNotIn("proxy-authorization", headers)
        self.assertNotIn("forwarded", headers)
        self.assertNotIn("x-forwarded-for", headers)
        helper_cwd, helper_agent_dir, helper_args = self.helper_record.read_text().strip().split("|", 2)
        self.assertEqual(helper_cwd, str(self.agent_dir))
        self.assertEqual(helper_agent_dir, str(self.agent_dir))
        self.assertEqual(helper_args,
                         "auth print-bearer-token --provider openai-codex --min-expiry 30m")
        token_headers = [name for name, value in headers.items() if self.real_token in value]
        self.assertEqual(token_headers, ["authorization"])
        self.assertNotIn(self.real_token.encode(), upstream["body"])
        self.assertNotIn(self.real_token.encode(), Path(f"/proc/{self.bridge.pid}/cmdline").read_bytes())
        self.assertNotIn(self.real_token.encode(), Path(f"/proc/{self.bridge.pid}/environ").read_bytes())

    def test_refresh_helper_mutates_only_the_dedicated_auth_store(self) -> None:
        before = self.fixture_manifest()
        response, connection = self.request(b"refresh-scope")
        response.read()
        connection.close()
        self.assertEqual(response.status, 200)
        self.assertEqual(
            (self.agent_dir / "auth.json").read_text(encoding="utf-8"),
            '{"refreshed-by-helper":true}\n',
        )
        self.assertEqual(self.outside_marker.read_text(encoding="utf-8"), "unchanged\n")
        after = self.fixture_manifest()
        changed = {
            path
            for path in before.keys() | after.keys()
            if before.get(path) != after.get(path)
        }
        self.assertEqual(changed, {"helper-record.jsonl", "openai-agent/auth.json"})

    def test_revalidates_auth_file_permissions_before_refresh(self) -> None:
        os.chmod(self.agent_dir / "auth.json", 0o644)
        response, connection = self.request(b"must-not-refresh")
        response.read()
        connection.close()
        self.assertEqual(response.status, 400)
        self.assertFalse(self.helper_record.exists())
        self.assertEqual(FakeUpstreamHandler.records, [])

    def test_accepts_chunked_guest_body_but_sends_a_sized_upstream_body(self) -> None:
        body = b"chunked-opaque-body"
        response, connection = self.request(body, encode_chunked=True)
        response.read()
        connection.close()
        upstream = FakeUpstreamHandler.records[0]
        self.assertEqual(response.status, 200)
        self.assertEqual(upstream["body"], body)
        self.assertEqual(upstream["headers"]["content-length"], str(len(body)))
        self.assertNotIn("transfer-encoding", upstream["headers"])

    def test_streams_first_sse_event_without_waiting_for_upstream_eof(self) -> None:
        response, connection = self.request(b"stream-me")
        started = time.monotonic()
        first = response.read(1)
        elapsed = time.monotonic() - started
        response.read()
        connection.close()
        self.assertEqual(response.status, 200)
        self.assertEqual(first, b"d")
        self.assertLess(elapsed, 0.3)

    def test_preserves_retry_response_status_headers_and_body(self) -> None:
        response, connection = self.request(b"retry-me")
        body = response.read()
        connection.close()
        self.assertEqual(response.status, 429)
        self.assertEqual(response.getheader("Retry-After"), "7")
        self.assertEqual(response.getheader("retry-after-ms"), "125")
        self.assertEqual(body, b'{"error":"busy"}')

    def test_rejects_wrong_token_route_and_method_without_contacting_upstream(self) -> None:
        response, connection = self.request(b"nope", token="wrong")
        response.read()
        connection.close()
        self.assertEqual(response.status, 401)

        response, connection = self.request(b"nope", path="/anything")
        response.read()
        connection.close()
        self.assertEqual(response.status, 404)

        connection = http.client.HTTPConnection("127.0.0.1", self.bridge_port, timeout=5)
        connection.request("GET", "/codex/responses")
        response = connection.getresponse()
        response.read()
        connection.close()
        self.assertEqual(response.status, 405)
        self.assertEqual(FakeUpstreamHandler.records, [])

    def test_times_out_a_partial_http_request(self) -> None:
        with socket.create_connection(("127.0.0.1", self.bridge_port), timeout=1) as connection:
            connection.sendall(b"POST /codex/responses HTTP/1.1\r\nHost: bridge\r\n")
            connection.settimeout(1)
            self.assertEqual(connection.recv(1), b"")

    def test_bounds_threads_under_many_partial_connections(self) -> None:
        baseline_threads = len(list(Path(f"/proc/{self.bridge.pid}/task").iterdir()))
        connections: list[socket.socket] = []
        try:
            for _ in range(32):
                connection = socket.create_connection(("127.0.0.1", self.bridge_port), timeout=1)
                connection.sendall(b"POST /codex/responses HTTP/1.1\r\n")
                connections.append(connection)
            time.sleep(0.1)
            active_threads = len(list(Path(f"/proc/{self.bridge.pid}/task").iterdir()))
            self.assertLessEqual(active_threads, baseline_threads + 8)
        finally:
            for connection in connections:
                connection.close()

    def test_rejects_a_symlinked_auth_file_before_starting(self) -> None:
        bad_agent_dir = self.root / "symlinked-openai-agent"
        bad_agent_dir.mkdir(mode=0o700)
        outside = self.root / "outside-auth.json"
        outside.write_text("outside-marker\n", encoding="utf-8")
        (bad_agent_dir / "auth.json").symlink_to(outside)
        ready = self.root / "symlinked-ready"
        process = subprocess.Popen(
            [
                PYTHON,
                str(BRIDGE),
                "serve",
                "--pi-bin",
                str(self.pi_bin),
                "--agent-dir",
                str(bad_agent_dir),
                "--guest-token",
                self.guest_token,
                "--upstream-url",
                "http://127.0.0.1:1/backend-api/codex/responses",
                "--ready",
                str(ready),
                "--test-tcp-port",
                str(self.free_tcp_port()),
            ],
            env={"PATH": os.environ.get("PATH", "")},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            for _ in range(50):
                if process.poll() is not None or ready.exists():
                    break
                time.sleep(0.02)
            self.assertIsNotNone(process.poll(), "bridge accepted a symlinked auth file")
            self.assertFalse(ready.exists())
            self.assertEqual(outside.read_text(encoding="utf-8"), "outside-marker\n")
        finally:
            if process.poll() is None:
                process.terminate()
            process.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main(verbosity=2)