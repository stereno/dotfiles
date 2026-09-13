#!/usr/bin/env python3
"""SSE-only OpenAI Codex credential bridge for pij."""

from __future__ import annotations

import argparse
import base64
import hmac
import http.client
import json
import os
import socket
import socketserver
import stat
import subprocess
import sys
import threading
import urllib.parse
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any, NoReturn, cast

AUTH_CLAIM = "https://api.openai.com/auth"
CODEX_PATH = "/codex/responses"
DEFAULT_UPSTREAM_URL = "https://chatgpt.com/backend-api/codex/responses"
MAX_REQUEST_BYTES = 64 * 1024 * 1024
MAX_RESPONSE_BYTES = 128 * 1024 * 1024
MAX_CONCURRENT_CONNECTIONS = 8
CLIENT_TIMEOUT_SECONDS = 10.0


class BridgeError(Exception):
    pass


def fail(message: str) -> NoReturn:
    raise BridgeError(message)


def require_private_directory(path: Path) -> None:
    try:
        info = path.lstat()
    except OSError:
        fail("cannot inspect the dedicated OpenAI auth directory")
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        fail("the dedicated OpenAI auth directory must be owned by the invoking user")
    if stat.S_IMODE(info.st_mode) & 0o077:
        fail("the dedicated OpenAI auth directory must be private")


def require_private_auth_file(path: Path) -> None:
    try:
        info = path.lstat()
    except OSError:
        fail("cannot inspect the dedicated OpenAI auth file")
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        fail("the dedicated OpenAI auth file must be regular and owned by the invoking user")
    if stat.S_IMODE(info.st_mode) & 0o077:
        fail("the dedicated OpenAI auth file must be private")


def decode_account_id(token: str) -> str:
    parts = token.split(".")
    if len(parts) != 3:
        fail("OpenAI bearer token is not a JWT")
    try:
        payload_bytes = base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4))
        payload = cast(object, json.loads(payload_bytes))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
        fail("OpenAI bearer token has an invalid JWT payload")
    if not isinstance(payload, dict):
        fail("OpenAI bearer token has an invalid JWT payload")
    auth = payload.get(AUTH_CLAIM)
    account_id = auth.get("chatgpt_account_id") if isinstance(auth, dict) else None
    if not isinstance(account_id, str) or not account_id or len(account_id) > 512:
        fail("OpenAI bearer token is missing the ChatGPT account ID")
    if any(ord(character) < 0x20 or ord(character) == 0x7F for character in account_id):
        fail("OpenAI bearer token has an invalid ChatGPT account ID")
    return account_id


def validate_upstream_url(raw: str) -> urllib.parse.SplitResult:
    parsed = urllib.parse.urlsplit(raw)
    if parsed.username is not None or parsed.password is not None or parsed.query or parsed.fragment:
        fail("upstream URL is invalid")
    if raw == DEFAULT_UPSTREAM_URL:
        return parsed
    if (
        parsed.scheme == "http"
        and parsed.hostname in {"127.0.0.1", "::1", "localhost"}
        and parsed.path == "/backend-api/codex/responses"
    ):
        return parsed
    fail("upstream URL must be the fixed OpenAI Codex endpoint or a loopback test endpoint")


def read_chunked_body(handler: BaseHTTPRequestHandler) -> bytes:
    chunks: list[bytes] = []
    total = 0
    while True:
        line = handler.rfile.readline(128)
        if not line or len(line) >= 128 or not line.endswith(b"\r\n"):
            fail("invalid chunked request body")
        size_text = line[:-2].split(b";", 1)[0]
        try:
            size = int(size_text, 16)
        except ValueError:
            fail("invalid chunked request body")
        if size < 0 or total + size > MAX_REQUEST_BYTES:
            fail("request body exceeds the bridge limit")
        if size == 0:
            while True:
                trailer = handler.rfile.readline(8192)
                if trailer == b"\r\n":
                    return b"".join(chunks)
                if not trailer or len(trailer) >= 8192:
                    fail("invalid chunked request trailer")
        chunk = handler.rfile.read(size)
        if len(chunk) != size or handler.rfile.read(2) != b"\r\n":
            fail("truncated chunked request body")
        chunks.append(chunk)
        total += size


def read_request_body(handler: BaseHTTPRequestHandler) -> bytes:
    transfer_encoding = handler.headers.get("Transfer-Encoding")
    content_length = handler.headers.get("Content-Length")
    if transfer_encoding is not None:
        if transfer_encoding.lower().strip() != "chunked" or content_length is not None:
            fail("unsupported request framing")
        return read_chunked_body(handler)
    if content_length is None or not content_length.isdecimal():
        fail("a decimal Content-Length is required")
    size = int(content_length)
    if size > MAX_REQUEST_BYTES:
        fail("request body exceeds the bridge limit")
    body = handler.rfile.read(size)
    if len(body) != size:
        fail("truncated request body")
    return body


def optional_request_header(handler: BaseHTTPRequestHandler, name: str) -> str | None:
    value = handler.headers.get(name)
    if value is None:
        return None
    if not value or len(value) > 512 or any(ord(character) < 0x20 for character in value):
        fail(f"invalid {name} header")
    return value


@dataclass(frozen=True)
class BridgeConfig:
    pi_bin: Path
    agent_dir: Path
    guest_token: str
    upstream: urllib.parse.SplitResult

    def current_identity(self) -> tuple[str, str]:
        require_private_auth_file(self.agent_dir / "auth.json")
        environment = {
            "HOME": str(self.agent_dir.parent),
            "PI_CODING_AGENT_DIR": str(self.agent_dir),
            "PI_TELEMETRY": "0",
            "PI_SKIP_VERSION_CHECK": "1",
        }
        try:
            result = subprocess.run(
                [
                    str(self.pi_bin),
                    "auth",
                    "print-bearer-token",
                    "--provider",
                    "openai-codex",
                    "--min-expiry",
                    "30m",
                ],
                check=False,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                env=environment,
                cwd=self.agent_dir,
                text=True,
                timeout=60,
            )
        except (OSError, subprocess.TimeoutExpired):
            fail("failed to obtain an OpenAI bearer token")
        token = result.stdout.strip()
        if result.returncode != 0 or not token or "\n" in token or "\r" in token:
            fail("failed to obtain an OpenAI bearer token")
        return token, decode_account_id(token)


class BridgeHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "pij-openai-bridge/1"
    config: BridgeConfig

    def log_message(self, format: str, *args: object) -> None:
        del format, args
        return

    def send_empty_error(self, status: int) -> None:
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True

    def do_GET(self) -> None:
        self.send_empty_error(405)

    def do_HEAD(self) -> None:
        self.send_empty_error(405)

    def do_CONNECT(self) -> None:
        self.send_empty_error(405)

    def do_POST(self) -> None:
        upstream_connection: http.client.HTTPConnection | None = None
        response_started = False
        try:
            if self.path != CODEX_PATH:
                self.send_empty_error(404)
                return
            expected = f"Bearer {self.config.guest_token}"
            authorization = self.headers.get("Authorization", "")
            if not hmac.compare_digest(authorization, expected):
                self.send_empty_error(401)
                return
            content_type = self.headers.get("Content-Type", "")
            if content_type.split(";", 1)[0].strip().lower() != "application/json":
                fail("unsupported content type")
            content_encoding = self.headers.get("Content-Encoding")
            if content_encoding is not None and content_encoding.lower().strip() != "zstd":
                fail("unsupported content encoding")
            session_id = optional_request_header(self, "session-id")
            client_request_id = optional_request_header(self, "x-client-request-id")
            body = read_request_body(self)
            token, account_id = self.config.current_identity()

            upstream = self.config.upstream
            if upstream.hostname is None:
                fail("upstream URL is invalid")
            connection_type = http.client.HTTPSConnection if upstream.scheme == "https" else http.client.HTTPConnection
            upstream_connection = connection_type(upstream.hostname, upstream.port, timeout=180)
            headers = {
                "Authorization": f"Bearer {token}",
                "chatgpt-account-id": account_id,
                "Accept": "text/event-stream",
                "Content-Type": "application/json",
                "OpenAI-Beta": "responses=experimental",
                "originator": "pi",
                "User-Agent": "pij-openai-bridge/1",
            }
            if content_encoding is not None:
                headers["Content-Encoding"] = "zstd"
            if session_id is not None:
                headers["session-id"] = session_id
            if client_request_id is not None:
                headers["x-client-request-id"] = client_request_id
            upstream_connection.request("POST", upstream.path, body=body, headers=headers)
            upstream_response = upstream_connection.getresponse()

            self.send_response(upstream_response.status)
            for name in ("Content-Type", "Content-Encoding", "Cache-Control", "Retry-After", "retry-after-ms"):
                value = upstream_response.getheader(name)
                if value is not None:
                    self.send_header(name, value)
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            self.end_headers()
            response_started = True

            total = 0
            while True:
                chunk = upstream_response.read1(65536)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_RESPONSE_BYTES:
                    fail("upstream response exceeds the bridge limit")
                self.wfile.write(f"{len(chunk):X}\r\n".encode("ascii"))
                self.wfile.write(chunk)
                self.wfile.write(b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
            self.close_connection = True
        except BridgeError:
            if not response_started:
                try:
                    self.send_empty_error(400)
                except (BrokenPipeError, ConnectionError, OSError):
                    pass
            else:
                self.close_connection = True
        except (BrokenPipeError, ConnectionError, OSError, http.client.HTTPException):
            if not response_started:
                try:
                    self.send_empty_error(502)
                except (BrokenPipeError, ConnectionError, OSError):
                    pass
            self.close_connection = True
        finally:
            if upstream_connection is not None:
                upstream_connection.close()


class LimitedThreadingMixIn(socketserver.ThreadingMixIn):
    daemon_threads = True

    def __init__(self, *args: object, client_timeout: float, **kwargs: object) -> None:
        self.client_timeout = client_timeout
        self.connection_slots = threading.BoundedSemaphore(MAX_CONCURRENT_CONNECTIONS)
        super().__init__(*args, **kwargs)

    def process_request(self, request: Any, client_address: Any) -> None:
        if not self.connection_slots.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.connection_slots.release()
            raise

    def process_request_thread(self, request: Any, client_address: Any) -> None:
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.connection_slots.release()

    def handle_error(self, request: object, client_address: object) -> None:
        del request, client_address


class ThreadingUnixServer(LimitedThreadingMixIn, socketserver.UnixStreamServer):
    allow_reuse_address = False
    request_queue_size = 64

    def get_request(self) -> tuple[socket.socket, object]:
        request, client_address = super().get_request()
        request.settimeout(self.client_timeout)
        return request, client_address


class ThreadingTcpServer(LimitedThreadingMixIn, socketserver.TCPServer):
    address_family = socket.AF_INET
    allow_reuse_address = False
    request_queue_size = 64

    def get_request(self) -> tuple[socket.socket, object]:
        request, client_address = super().get_request()
        request.settimeout(self.client_timeout)
        return request, client_address


def serve(args: argparse.Namespace) -> None:
    pi_bin = Path(args.pi_bin)
    agent_dir = Path(args.agent_dir)
    if not pi_bin.is_absolute() or not pi_bin.is_file() or not os.access(pi_bin, os.X_OK):
        fail("Pi executable is invalid")
    require_private_directory(agent_dir)
    require_private_auth_file(agent_dir / "auth.json")
    config = BridgeConfig(pi_bin, agent_dir, args.guest_token, validate_upstream_url(args.upstream_url))
    decode_account_id(config.guest_token)
    BridgeHandler.config = config
    client_timeout = args.test_client_timeout or CLIENT_TIMEOUT_SECONDS

    if args.test_tcp_port is None:
        if args.socket is None:
            fail("--socket is required outside tests")
        socket_path = Path(args.socket)
        server: socketserver.BaseServer = ThreadingUnixServer(
            str(socket_path), BridgeHandler, client_timeout=client_timeout
        )
        os.chmod(socket_path, 0o600)
    else:
        server = ThreadingTcpServer(
            ("127.0.0.1", args.test_tcp_port), BridgeHandler, client_timeout=client_timeout
        )
    with server:
        ready = Path(args.ready)
        ready.write_text("ready\n", encoding="ascii")
        os.chmod(ready, 0o600)
        server.serve_forever(poll_interval=0.2)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    serve_parser = subparsers.add_parser("serve")
    serve_parser.add_argument("--pi-bin", required=True)
    serve_parser.add_argument("--agent-dir", required=True)
    serve_parser.add_argument("--guest-token", required=True)
    serve_parser.add_argument("--upstream-url", default=DEFAULT_UPSTREAM_URL)
    serve_parser.add_argument("--ready", required=True)
    serve_parser.add_argument("--socket")
    serve_parser.add_argument("--test-tcp-port", type=int, help=argparse.SUPPRESS)
    serve_parser.add_argument("--test-client-timeout", type=float, help=argparse.SUPPRESS)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        serve(args)
    except BridgeError as error:
        print(f"pij-openai-bridge: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))