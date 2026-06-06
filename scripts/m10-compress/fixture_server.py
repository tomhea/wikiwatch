#!/usr/bin/env python3
"""Tiny static file server for the M10.6 install-check sim harness.

The CIQ simulator's makeWebRequest requires HTTPS (rc=-1001
SECURE_CONNECTION_REQUIRED over plain http), so this serves TLS, HTTP/1.1, with
explicit Content-Length + application/json, threaded so the install's concurrent
chunk fetches don't serialize. The cert is self-signed (the simulator does not
strictly validate it, unlike a real device).

Usage:  python fixture_server.py <port> <directory> [<certfile> <keyfile>]
"""
import functools
import http.server
import socketserver
import ssl
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    port = int(sys.argv[1])
    directory = sys.argv[2]
    handler = functools.partial(Handler, directory=directory)
    httpd = ThreadingHTTPServer(("127.0.0.1", port), handler)
    scheme = "http"
    if len(sys.argv) >= 5:
        certfile, keyfile = sys.argv[3], sys.argv[4]
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(certfile, keyfile)
        httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
        scheme = "https"
    sys.stderr.write("fixture_server: %s HTTP/1.1 on 127.0.0.1:%d serving %s\n"
                     % (scheme.upper(), port, directory))
    httpd.serve_forever()


if __name__ == "__main__":
    main()
