import http.server
import socketserver
import os
import sys

web_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "app", "build", "web"))
os.chdir(web_dir)

class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000

try:
    with ThreadingHTTPServer(('0.0.0.0', port), Handler) as httpd:
        print(f"Flutter Web App serving on http://localhost:{port}")
        httpd.serve_forever()
except Exception as e:
    print(f"Error serving on port {port}: {e}")
