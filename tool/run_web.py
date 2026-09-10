#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Multi-port launcher for the 5 accounting systems.

Serves the built Flutter web app on:
  http://localhost:8080  -> admin
  http://localhost:8081  -> branch1
  http://localhost:8082  -> branch2
  http://localhost:8083  -> branch3
  http://localhost:8084  -> branch4

Also acts as a local relay (mailbox) so branch reports reach the admin
across different origins/ports:
  POST /api/report   <- branches submit their end-of-day report JSON
  GET  /api/reports  <- admin polls to auto-receive reports instantly
"""

import json
import os
import socketserver
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer, SimpleHTTPRequestHandler

WEB_ROOT = os.path.abspath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir, "build", "web")
)
RELAY_DIR = os.path.join(tempfile.gettempdir(), "accounting_relay")
PORTS = [8080, 8081, 8082, 8083, 8084]

os.makedirs(RELAY_DIR, exist_ok=True)
for f in os.listdir(RELAY_DIR):
    if f.endswith(".json"):
        try:
            os.remove(os.path.join(RELAY_DIR, f))
        except OSError:
            pass


class ThreadingHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads = True


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_ROOT, **kwargs)

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/api/reports"):
            reports = []
            try:
                for fn in sorted(os.listdir(RELAY_DIR)):
                    if not fn.endswith(".json"):
                        continue
                    with open(os.path.join(RELAY_DIR, fn), encoding="utf-8") as f:
                        reports.append(json.load(f))
            except Exception:
                pass
            body = json.dumps(reports, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/report"):
            length = int(self.headers.get("Content-Length", 0) or 0)
            raw = self.rfile.read(length).decode("utf-8")
            data = {}
            try:
                data = json.loads(raw)
            except Exception:
                pass
            code = str(data.get("branch_code") or "BR??")
            date = str(data.get("report_date") or "unknown").replace("/", "-")
            safe = "".join(c for c in f"{code}_{date}" if c.isalnum() or c in "-_")
            with open(
                os.path.join(RELAY_DIR, f"{safe}.json"), "w", encoding="utf-8"
            ) as f:
                json.dump(data, f, ensure_ascii=False)
            body = b'{"ok":true}'
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self._cors()
            self.send_header("Content-Length", "0")
            self.end_headers()

    def log_message(self, fmt, *args):
        try:
            print("[%s] %s" % (self.server.server_address[1], fmt % args), flush=True)
        except Exception:
            pass


def serve(port):
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print("Serving system on http://localhost:%d (root: %s)" % (port, WEB_ROOT), flush=True)
    server.serve_forever()


def main():
    threads = [threading.Thread(target=serve, args=(p,), daemon=True) for p in PORTS]
    for t in threads:
        t.start()
    for t in threads:
        t.join()


if __name__ == "__main__":
    main()