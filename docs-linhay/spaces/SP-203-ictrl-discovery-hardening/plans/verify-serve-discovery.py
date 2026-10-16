#!/usr/bin/env python3
"""Controlled candidate CLI integration: owned loopback port/process, no devices.
Run: python3 <this-file> <absolute-candidate-triton> <output-json>
Bonjour publication callbacks are covered separately by ServeDiscoveryTests.
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
import threading
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

binary = str(Path(sys.argv[1]).resolve())
output = Path(sys.argv[2])
checks = []
with tempfile.TemporaryDirectory(prefix='sp203-serve-') as directory:
    # Serve warms a readonly device cache. Prevent that cache from reaching toolchains/devices.
    env = dict(os.environ, PATH='/usr/bin:/bin', DEVELOPER_DIR=directory + '/no-toolchain')
    env.pop('TRITON_ADVERTISE', None)
    for arguments, override in [(['--port', '0'], {}), (['--port', '65536'], {}), ([], {'TRITON_ADVERTISE':'invalid'})]:
        result = subprocess.run([binary, 'serve', *arguments], env=env | override, capture_output=True, timeout=10)
        assert result.returncode != 0, 'invalid configuration accepted'
        assert b'Bonjour: advertising' not in result.stderr
        checks.append({'case':'invalid-before-bind', 'args':arguments, 'environment':override, 'exit':result.returncode})
    # Keep the reservation bound throughout the negative test.
    with socket.socket() as occupied:
        occupied.bind(('127.0.0.1', 0))
        occupied.listen()
        result = subprocess.run([binary, 'serve', '--host', '127.0.0.1', '--port', str(occupied.getsockname()[1]), '--advertise'],
                                env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
        assert result.returncode != 0, 'occupied bind succeeded'
        assert b'Bonjour: advertising' not in result.stderr
        checks.append({'case':'occupied-bind-no-confirmed-publication','exit':result.returncode,
                       'boundary':'No success callback observed; onServerRunning source ordering separately proves publish is only requested after bind.'})
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    with open(Path(directory) / 'serve.log', 'w+b') as log:
        process = subprocess.Popen([binary, 'serve', '--port', str(port)], env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 10
            while True:
                assert process.poll() is None, 'owned server exited before readiness'
                try:
                    with urllib.request.urlopen(f'http://127.0.0.1:{port}/status', timeout=0.5) as response:
                        http = json.load(response)
                    break
                except (OSError, ValueError):
                    if time.monotonic() > deadline: raise
                    time.sleep(0.05)
            assert http['discovery']['wanted'] is False and http['discovery']['state'] == 'stopped'
            result = subprocess.run([binary,'status','--host','127.0.0.1','--port',str(port),'--json'], env=env, capture_output=True, timeout=10)
            assert result.returncode == 0, result.returncode
            cli = json.loads(result.stdout)
            assert cli['discovery'] == http['discovery']
            assert cli['discovery']['identityVerified'] is False
            checks.append({'case':'actual-http-cli-status','http':http,'cli':cli})
        finally:
            if process.poll() is None: process.send_signal(signal.SIGINT)
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(timeout=5)
        log.seek(0)
        assert b'Bonjour: advertising' not in log.read()
        assert process.poll() is not None
        checks.append({'case':'owned-process-cleaned-up','exit':process.returncode})
# A local fixture must not be able to self-assert authentication through CLI decode.
class ForgedStatus(BaseHTTPRequestHandler):
    def do_GET(self):
        payload = json.dumps({'connected':False,'latestHierarchyAvailable':False,'targetCount':0,
            'discovery':{'wanted':True,'state':'advertising','serviceType':'_tritonkit-server._tcp.','identityVerified':True}}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
    def log_message(self, *_): pass

fixture = HTTPServer(('127.0.0.1', 0), ForgedStatus)
worker = threading.Thread(target=fixture.serve_forever, daemon=True)
worker.start()
try:
    result = subprocess.run([binary,'status','--host','127.0.0.1','--port',str(fixture.server_port),'--json'], capture_output=True, timeout=10)
    assert result.returncode == 0
    assert json.loads(result.stdout)['discovery']['identityVerified'] is False
    checks.append({'case':'forged-status-cannot-claim-authentication','identityVerified':False})
finally:
    fixture.shutdown()
    fixture.server_close()
    worker.join(timeout=3)
    assert not worker.is_alive()

output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps({'ok':True,'binary':binary,'checks':checks},indent=2)+'\n')
print(json.dumps({'ok':True,'checks':len(checks)}))
