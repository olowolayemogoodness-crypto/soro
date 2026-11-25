#!/usr/bin/env python3
"""Local stand-in for POST /tutor/turn (issue #39), stdlib only.

    python3 tools/mock_tutor.py [port]     # default 8000

Returns a valid reply for guide and solve mode so the app can be tested
without the real API. Not the real brain: replies are canned.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


def reply(req):
    sid = req.get("session_id", "s1")
    problem = req.get("problem") or "x^2 + 2x = 1"
    if req.get("mode") == "solve":
        return {
            "session_id": sid,
            "step_id": "s-done",
            "say": "Here is the full working. Now try a similar one.",
            "board": [
                {"op": "write", "text": problem},
                {"op": "write", "text": "x^2 + 2x + 1 = 1 + 1"},
                {"op": "write", "text": "(x + 1)^2 = 2"},
                {"op": "write", "text": "x + 1 = ±√2"},
                {"op": "write", "text": "x = -1 ± √2"},
                {"op": "mark", "kind": "tick", "target": "last"},
                {"op": "blank", "text": "x^2 + 4x = 1  =>  (x + [ ])^2 = [ ]"},
            ],
            "analogy": "",
            "done": False,
            "source": "script",
        }
    return {
        "session_id": sid,
        "step_id": "s2",
        "say": "What number do we add to both sides to make the left a perfect square?",
        "board": [
            {"op": "write", "text": problem},
            {"op": "blank", "text": "x^2 + 2x + [ ] = 1 + [ ]"},
        ],
        "analogy": "Like adding the missing tile to finish a square floor.",
        "done": False,
        "source": "script",
    }


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body=b""):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send(204)

    def do_POST(self):
        if self.path != "/tutor/turn":
            return self._send(404, b"{}")
        length = int(self.headers.get("Content-Length", 0))
        try:
            req = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            return self._send(400, b"{}")
        print("turn:", req, flush=True)
        self._send(200, json.dumps(reply(req), ensure_ascii=False).encode())


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
