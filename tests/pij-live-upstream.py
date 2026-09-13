#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    record: Path

    def log_message(self, format: str, *args: object) -> None:
        del format, args

    def do_POST(self) -> None:
        length = int(self.headers["Content-Length"])
        body = self.rfile.read(length)
        record: dict[str, Any] = {
            "path": self.path,
            "headers": {name.lower(): value for name, value in self.headers.items()},
            "body": body.decode("utf-8"),
        }
        with self.record.open("a", encoding="utf-8") as output:
            output.write(json.dumps(record) + "\n")
        payload = b'data: {"type":"response.completed","response":{"status":"completed"}}\n\n'
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ready", type=Path, required=True)
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    Handler.record = args.record
    server = HTTPServer(("127.0.0.1", 0), Handler)
    args.ready.write_text(str(server.server_address[1]), encoding="ascii")
    server.handle_request()
    server.handle_request()
    server.server_close()


if __name__ == "__main__":
    main()
