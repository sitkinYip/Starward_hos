"""Private, unmodified player DTO snapshots from this disposable HTTPS backend."""
import json
import os
import re
import ssl
import urllib.request

from native_device_ui import ROOT, SafeFailure

AUTH = '/api/collections/game_players/auth-with-password'
ME = '/api/questions/v1/me'
LIST = '/api/questions/v1/assignments'
PRIVATE = ROOT / 'artifacts/private/https-isolation'


def private_json(name, value):
    if not re.fullmatch(r'[A-Za-z0-9_-]+\.json', name):
        raise SafeFailure('Snapshot filename is not allowed')
    target = PRIVATE / name
    descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(value, output, ensure_ascii=False, indent=2)
        output.write('\n')
    target.chmod(0o600)


class ReadonlySnapshot:
    """Only authentication and fixed, generated test assignment IDs are allowed."""
    def __init__(self, state):
        self.state = state
        self.assignment_ids = frozenset([state['assignmentId']] + [
            entry['assignmentId'] for entry in state.get('assignments', {}).values()])
        if not self.assignment_ids or any(not isinstance(value, str) or not re.fullmatch(r'[a-z0-9]{15}', value)
                                          for value in self.assignment_ids):
            raise SafeFailure('Snapshot assignment IDs are not generated test IDs')
        if not re.fullmatch(r'https://127\.0\.0\.1:[0-9]+', state['tls']['hostBase']):
            raise SafeFailure('Snapshot TLS origin must be this loopback gateway')
        self.allowed_paths = frozenset((AUTH, ME, LIST)) | frozenset(LIST + '/' + value for value in self.assignment_ids)
        self.context = ssl.create_default_context(cafile=state['tls']['caPath'])
        self.token = ''

    def request(self, path, body=None):
        if path not in self.allowed_paths or (body is not None and path != AUTH):
            raise SafeFailure('Snapshot endpoint or method is not allowed')
        headers = {'Accept': 'application/json'}
        if self.token:
            headers['Authorization'] = self.token
        if body is not None:
            headers['Content-Type'] = 'application/json'
        request = urllib.request.Request(self.state['tls']['hostBase'] + path,
                                         data=json.dumps(body).encode() if body is not None else None,
                                         headers=headers, method='POST' if body is not None else 'GET')
        try:
            with urllib.request.urlopen(request, context=self.context, timeout=25) as response:
                return json.load(response)
        except Exception:
            raise SafeFailure('Verified HTTPS snapshot read failed: ' + path) from None

    def login(self, password):
        auth = self.request(AUTH, {'identity': self.state['account'], 'password': password})
        self.token = auth.get('token', '')
        if not self.token:
            raise SafeFailure('Snapshot authentication returned no token')

    def capture(self, assignment_id=None):
        selected = assignment_id or self.state['assignmentId']
        if selected not in self.assignment_ids:
            raise SafeFailure('Snapshot assignment is outside this generated test set')
        return {'player': self.request(ME), 'assignment': self.request(LIST + '/' + selected),
                'assignments': self.request(LIST)}
