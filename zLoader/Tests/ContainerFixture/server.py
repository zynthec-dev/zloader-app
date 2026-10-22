"""Local OAuth-scheme collision fixture. Contains only synthetic test values."""
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'<html><body><a href="fixturecallback://oauth?state=acceptance&amp;code=synthetic">Finish fixture login</a></body></html>'
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


if __name__ == '__main__':
    HTTPServer(('127.0.0.1', 18769), Handler).serve_forever()
