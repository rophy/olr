#!/usr/bin/env python3
"""HTTP receiver for Debezium Server HTTP sink.

Receives CDC events from two Debezium Server instances (LogMiner and OLR adapters)
and writes them to separate JSONL files. Provides status endpoint for polling
completion via sentinel table detection.

Endpoints:
  POST /logminer  — append event(s) to logminer.jsonl
  POST /olr       — append event(s) to olr.jsonl
  GET  /status    — return event counts and sentinel detection status
  POST /reset     — clear all state for next scenario
"""

import json
import os
import sys
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '/app/output')
SENTINEL_TABLE = 'DEBEZIUM_SENTINEL'

# Shared state protected by lock
lock = threading.Lock()
state = {
    'logminer_count': 0,
    'olr_count': 0,
    'logminer_sentinel': False,
    'olr_sentinel': False,
}
logminer_file = None
olr_file = None


def open_files():
    global logminer_file, olr_file
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    logminer_file = open(os.path.join(OUTPUT_DIR, 'logminer.jsonl'), 'a')
    olr_file = open(os.path.join(OUTPUT_DIR, 'olr.jsonl'), 'a')


def reset_state():
    global logminer_file, olr_file
    with lock:
        state['logminer_count'] = 0
        state['olr_count'] = 0
        state['logminer_sentinel'] = False
        state['olr_sentinel'] = False

        if logminer_file:
            logminer_file.close()
        if olr_file:
            olr_file.close()

        # Truncate files
        for name in ('logminer.jsonl', 'olr.jsonl'):
            path = os.path.join(OUTPUT_DIR, name)
            with open(path, 'w'):
                pass

        open_files()


def is_sentinel(event):
    """Check if event is a sentinel table insert."""
    if not isinstance(event, dict):
        return False
    # Debezium envelope: source.table
    source = event.get('source', {})
    table = source.get('table', '')
    op = event.get('op', '')
    return table == SENTINEL_TABLE and op == 'c'


def process_events(body, channel):
    """Parse and store events from HTTP POST body."""
    # Debezium HTTP sink may send single event or array
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return 0

    events = data if isinstance(data, list) else [data]

    with lock:
        f = logminer_file if channel == 'logminer' else olr_file
        count_key = f'{channel}_count'
        sentinel_key = f'{channel}_sentinel'

        for event in events:
            if not isinstance(event, dict):
                continue
            f.write(json.dumps(event) + '\n')
            f.flush()
            state[count_key] += 1

            if is_sentinel(event):
                state[sentinel_key] = True

    return len(events)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length else ''

        if self.path == '/logminer':
            n = process_events(body, 'logminer')
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f'{{"accepted":{n}}}'.encode())

        elif self.path == '/olr':
            n = process_events(body, 'olr')
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f'{{"accepted":{n}}}'.encode())

        elif self.path == '/reset':
            reset_state()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"reset":true}')

        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == '/status':
            with lock:
                body = json.dumps(state)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(body.encode())

        elif self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')

        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Log requests for debugging
        sys.stderr.write("%s - - [%s] %s\n" %
                         (self.client_address[0],
                          self.log_date_time_string(),
                          format%args))
        sys.stderr.flush()


def main():
    open_files()
    port = int(os.environ.get('PORT', 8080))
    server = HTTPServer(('0.0.0.0', port), Handler)
    print(f'Debezium receiver listening on :{port}', flush=True)
    print(f'Output dir: {OUTPUT_DIR}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        if logminer_file:
            logminer_file.close()
        if olr_file:
            olr_file.close()


if __name__ == '__main__':
    main()
