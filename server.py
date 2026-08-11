import http.server
import socketserver
import socket
import os

os.chdir(r"c:\Users\rajch\Desktop\AI\COMPS\school-erp-project-structure\school-erp\app\build\web")

class CustomHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

handler = http.server.SimpleHTTPRequestHandler
httpd = CustomHTTPServer(('0.0.0.0', 8080), handler)
print("Serving Flutter Web on http://localhost:8080...")
httpd.serve_forever()
