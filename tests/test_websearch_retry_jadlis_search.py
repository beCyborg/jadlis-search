"""websearch.http_json retries HTTP 429 (max 2 extra attempts) and does not retry other errors."""
import importlib.util
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = importlib.util.spec_from_file_location("websearch_retry_mod", os.path.join(HERE, "..", "scripts", "websearch.py"))
ws = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ws)


def serve(codes):
    """Start a server that answers each request with the next status from `codes`."""
    seq = list(codes)
    hits = []

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            code = seq.pop(0) if seq else 200
            hits.append(code)
            body = json.dumps({"code": code}).encode()
            self.send_response(code)
            if code == 429:
                self.send_header("Retry-After", "0")
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    srv = HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, hits


def call(srv):
    return ws.http_json("GET", "http://127.0.0.1:%d/x" % srv.server_port, {}, None, 5)


def test_429_then_200_retries(monkeypatch):
    monkeypatch.setattr(ws.time, "sleep", lambda s: None)
    srv, hits = serve([429, 200])
    status, parsed, _ = call(srv)
    srv.shutdown()
    assert status == 200 and parsed == {"code": 200}
    assert hits == [429, 200]


def test_429_gives_up_after_two_retries(monkeypatch):
    monkeypatch.setattr(ws.time, "sleep", lambda s: None)
    srv, hits = serve([429, 429, 429, 200])
    status, _, _ = call(srv)
    srv.shutdown()
    assert status == 429
    assert hits == [429, 429, 429]


def test_402_is_not_retried(monkeypatch):
    monkeypatch.setattr(ws.time, "sleep", lambda s: None)
    srv, hits = serve([402, 200])
    status, _, _ = call(srv)
    srv.shutdown()
    assert status == 402
    assert hits == [402]
