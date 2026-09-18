#!/usr/bin/env python3
"""Static file server for the prompter, plus an endpoint that accepts a take.

`python3 -m http.server` can only serve. Getting a take off the phone meant
going through iOS share -> Photos, which is also where takes were arriving
re-encoded and at the wrong frame rate. This adds one POST route so the phone
can hand the original file straight to the Mac, untouched, over the same
tailnet URL the app is already served from.

    ./server.py [port]        # default 8080, bound to 127.0.0.1
"""
import re
import sys
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
TAKES = HERE / "takes"
MAX_BYTES = 4 * 1024 * 1024 * 1024        # a long 4K take is still well under this
SAFE = re.compile(r"[^A-Za-z0-9._-]+")


def safe_name(raw):
    """Never let a posted name escape the takes folder or overwrite anything."""
    name = SAFE.sub("-", Path(raw or "take").name).strip("-.") or "take"
    stem, dot, ext = name.rpartition(".")
    if not dot:
        stem, ext = name, "mp4"
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    candidate = TAKES / f"{stem}-{stamp}.{ext}"
    n = 2
    while candidate.exists():
        candidate = TAKES / f"{stem}-{stamp}-{n}.{ext}"
        n += 1
    return candidate


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(HERE), **kw)

    def _json(self, code, body):
        payload = repr(body).replace("'", '"').encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self):
        if self.path.split("?")[0] != "/upload":
            self._json(404, {"error": "no such endpoint"})
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length <= 0:
            self._json(400, {"error": "empty body"})
            return
        if length > MAX_BYTES:
            self._json(413, {"error": "too large"})
            return

        TAKES.mkdir(parents=True, exist_ok=True)
        dest = safe_name(self.headers.get("X-Take-Name"))
        # Stream to disk: a take is far too big to hold in memory twice.
        remaining = length
        try:
            with open(dest, "wb") as f:
                while remaining > 0:
                    chunk = self.rfile.read(min(1 << 20, remaining))
                    if not chunk:
                        break
                    f.write(chunk)
                    remaining -= len(chunk)
        except OSError as e:
            self._json(500, {"error": str(e)})
            return
        if remaining:                      # client vanished mid-upload
            dest.unlink(missing_ok=True)
            self._json(400, {"error": "incomplete upload"})
            return
        print(f"saved {dest.name} ({dest.stat().st_size / 1e6:.1f} MB)", flush=True)
        self._json(200, {"saved": dest.name})

    def log_message(self, fmt, *args):     # quieter than the default one-line-per-asset
        if self.command != "GET":
            super().log_message(fmt, *args)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    TAKES.mkdir(parents=True, exist_ok=True)
    print(f"Prompter on http://127.0.0.1:{port}  ·  takes land in {TAKES}")
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
