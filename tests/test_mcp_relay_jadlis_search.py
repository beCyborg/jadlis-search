"""mcp-relay: replies come back as lines, and a daemon restart (stale session -> 404) is recovered."""
import json
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RELAY = Path(__file__).resolve().parent.parent / "scripts" / "mcp-relay.py"


class FakeDaemon(BaseHTTPRequestHandler):
    generation = 1  # bump to simulate a restart: older session ids become unknown
    seen_auth = []

    def log_message(self, *a):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        FakeDaemon.seen_auth.append(self.headers.get("Authorization"))
        sid = self.headers.get("Mcp-Session-Id")
        current = "s%d" % FakeDaemon.generation
        if body.get("method") == "initialize":
            self._reply({"jsonrpc": "2.0", "id": body["id"], "result": {"protocolVersion": "2025-06-18"}}, sid=current)
            return
        if sid != current:
            self.send_response(404)
            self.end_headers()
            return
        if "id" not in body:
            self.send_response(202)
            self.end_headers()
            return
        # answer tools/call as SSE to cover that path
        payload = json.dumps({"jsonrpc": "2.0", "id": body["id"], "result": {"gen": FakeDaemon.generation}})
        data = ("event: message\ndata: %s\n\n" % payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _reply(self, obj, sid):
        data = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Mcp-Session-Id", sid)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def _read_line(proc, timeout=10):
    box = []
    t = threading.Thread(target=lambda: box.append(proc.stdout.readline()))
    t.start()
    t.join(timeout)
    assert box, "relay produced no line"
    return json.loads(box[0])


def test_relay_roundtrip_and_restart_recovery():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), FakeDaemon)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    env = dict(os.environ, JADLIS_MCP_URL="http://127.0.0.1:%d/mcp" % srv.server_port, JADLIS_MCP_BEARER="tok")
    proc = subprocess.Popen(["python3", str(RELAY)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
    try:
        def send(obj):
            proc.stdin.write(json.dumps(obj) + "\n")
            proc.stdin.flush()

        send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        assert _read_line(proc)["id"] == 1
        send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {}})
        assert _read_line(proc)["result"] == {"gen": 1}

        FakeDaemon.generation = 2  # daemon restarted: s1 is gone
        time.sleep(0.1)
        send({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {}})
        reply = _read_line(proc)
        assert reply["id"] == 3 and reply["result"] == {"gen": 2}
        assert set(FakeDaemon.seen_auth) == {"Bearer tok"}
    finally:
        proc.kill()
        srv.shutdown()
