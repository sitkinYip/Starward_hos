#!/usr/bin/env python3
"""Export the authorized admin content API projection into a fresh private folder.

Default help does no credential, private-file or network IO. `self-test` uses only
in-memory fake responses. `run` performs one real game_admins authentication and
allowlisted GETs; it never changes business records or retries authentication.
"""
import argparse
import copy
import datetime
import getpass
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import ssl
import stat
import sys
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
PRIVATE_ROOT = ROOT / 'artifacts/private'
OUTPUT_ROOT = PRIVATE_ROOT / 'ui-reference'
ORIGIN = 'https://api.sitkin.top'
AUTH = '/api/collections/game_admins/auth-with-password'
ME = '/api/questions/v1/admin/me'
CATALOG = '/api/questions/v1/admin/catalog'
MAX_RESPONSE = 32 * 1024 * 1024
MAX_RECORDS = 10000
SECTIONS = ('questions', 'sessions', 'narratives', 'ranks', 'rewards')
CREDENTIAL_KEYS = {'password', 'passwordconfirm', 'oldpassword', 'newpassword',
                   'token', 'controltoken', 'authorization', 'players', 'authstore'}
BACKEND_SCHEMA_COMMIT = 'c28f488d6b682ae213713ccdd2d992595a941ae3'


class ExportFailure(Exception):
    """Only fixed non-sensitive descriptions may enter this exception."""


def require(value, message='An export boundary or required API field is invalid'):
    if not value:
        raise ExportFailure(message)


def origin(value):
    require(value == ORIGIN, 'Only the explicitly reviewed HTTPS API origin is allowed')
    return value


def text(value):
    return isinstance(value, str)


def record_id(value):
    return text(value) and re.fullmatch(r'[a-z0-9]{15}', value) is not None


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def array(value):
    return isinstance(value, list) and len(value) <= MAX_RECORDS


def string_array(value):
    return array(value) and all(text(item) for item in value)


def fields(row, rules):
    require(isinstance(row, dict) and all(key in row and check(row[key]) for key, check in rules.items()))


def optional(row, key, check):
    require(key not in row or check(row[key]))


def picked(row, names):
    return {name: copy.deepcopy(row[name]) for name in names if name in row}


def versioned(row):
    fields(row, {'id': record_id, 'seriesKey': text, 'revision': lambda n: integer(n, 1),
                 'status': lambda s: s in ('draft', 'published', 'archived'), 'title': text})


def presentation(row):
    require(isinstance(row, dict))
    for key in ('bgmUrl', 'backgroundUrl'):
        optional(row, key, text)
    optional(row, 'hideTitle', lambda v: type(v) is bool)
    optional(row, 'backgroundMode', lambda v: v in ('inherit', 'custom', 'none'))
    optional(row, 'bgmMode', lambda v: v in ('inherit', 'custom', 'silent'))
    optional(row, 'completionStyle', lambda v: v in ('normal', 'finale'))


def validate_question(row):
    versioned(row)
    fields(row, {'kind': lambda v: v in ('text', 'choice'), 'placeholder': text, 'content': array,
                 'options': array, 'acceptedAnswers': string_array, 'fuzzyMatch': lambda v: type(v) is bool,
                 'groupName': text, 'commonClueCount': integer})
    for block in row['content']:
        fields(block, {'text': text, 'hint': text, 'imageUrl': text, 'imageUrls': string_array, 'videoUrl': text})
    for item in row['options']:
        fields(item, {'key': text, 'text': text, 'imageUrl': text, 'videoUrl': text})
    return picked(row, ('id', 'seriesKey', 'revision', 'status', 'kind', 'title', 'placeholder', 'content',
                        'options', 'acceptedAnswers', 'fuzzyMatch', 'groupName', 'commonClueCount', 'usage'))


def clue_content(row):
    fields(row, {'title': text, 'text': text, 'url': text, 'imageUrls': string_array, 'buttonText': text})
    optional(row, 'description', text)
    optional(row, 'tips', text)


def validate_session(row):
    versioned(row)
    fields(row, {'description': text, 'minLevel': lambda v: v == '' or record_id(v),
                 'maxLevel': lambda v: v == '' or record_id(v), 'presentation': lambda v: isinstance(v, dict),
                 'completionTarget': lambda v: v is None or isinstance(v, dict), 'levels': array,
                 'clues': array, 'rewardRules': array, 'liveSettingsVersion': text})
    presentation(row['presentation'])
    for step in row['levels']:
        fields(step, {'id': record_id, 'question': record_id, 'position': lambda v: integer(v, 1),
                      'xp': integer, 'autoNext': lambda v: type(v) is bool, 'penaltyPolicy': array,
                      'presentationOverride': lambda v: isinstance(v, dict)})
        presentation(step['presentationOverride'])
        for penalty in step['penaltyPolicy']:
            fields(penalty, {'type': lambda v: v in ('cooldown', 'lock')})
            if penalty['type'] == 'cooldown':
                fields(penalty, {'seconds': integer})
    for clue in row['clues']:
        fields(clue, {'id': record_id, 'sessionLevel': lambda v: v == '' or record_id(v),
                      'trigger': lambda v: v in ('start', 'level_completed', 'session_completed', 'manual'),
                      'position': integer, 'kind': lambda v: v in ('text', 'image', 'video', 'link', 'letter', 'bless'),
                      'narrative': lambda v: v == '' or record_id(v), 'autoPlay': lambda v: type(v) is bool,
                      'content': lambda v: isinstance(v, dict)})
        clue_content(clue['content'])
    for rule in row['rewardRules']:
        fields(rule, {'id': record_id, 'sessionLevel': lambda v: v == '' or record_id(v),
                      'trigger': lambda v: v in ('level_completed', 'session_completed'),
                      'reward': record_id, 'quantity': lambda v: integer(v, 1)})
    return picked(row, ('id', 'seriesKey', 'revision', 'status', 'title', 'description', 'minLevel', 'maxLevel',
                        'presentation', 'completionTarget', 'levels', 'clues', 'rewardRules', 'liveSettingsVersion'))


def validate_catalog(raw):
    require(isinstance(raw, dict) and 'players' in raw and array(raw['players']))
    # The unneeded player domain is discarded before any output is constructed.
    raw.pop('players')
    for key in SECTIONS:
        require(key in raw and array(raw[key]))
        require(all(isinstance(row, dict) and record_id(row.get('id')) for row in raw[key]))
        require(len({row['id'] for row in raw[key]}) == len(raw[key]))
    out = {'questions': [validate_question(row) for row in raw['questions']],
           'sessions': [validate_session(row) for row in raw['sessions']]}
    for row in raw['narratives']:
        versioned(row)
        fields(row, {'kind': lambda v: v in ('letter', 'bless'), 'payload': lambda v: isinstance(v, dict)})
    out['narratives'] = [picked(row, ('id', 'seriesKey', 'revision', 'status', 'kind', 'title', 'payload')) for row in raw['narratives']]
    for row in raw['ranks']:
        fields(row, {'id': record_id, 'order': lambda v: integer(v, 1), 'name': text, 'minTotalXp': integer,
                     'visualConfig': lambda v: True})
    out['ranks'] = [picked(row, ('id', 'order', 'name', 'minTotalXp', 'visualConfig', 'defaultName', 'customTitle')) for row in raw['ranks']]
    for row in raw['rewards']:
        fields(row, {'id': record_id, 'name': text, 'image': text, 'description': text,
                     'claimMethod': lambda v: v in ('staff', 'location', 'locker'), 'publicInstructions': text,
                     'active': lambda v: type(v) is bool})
    out['rewards'] = [picked(row, ('id', 'name', 'image', 'description', 'claimMethod', 'publicInstructions', 'active')) for row in raw['rewards']]
    if 'capabilities' in raw:
        fields(raw['capabilities'], {'playerTitles': lambda v: type(v) is bool, 'extraConfig': lambda v: type(v) is bool})
        out['capabilities'] = picked(raw['capabilities'], ('playerTitles', 'extraConfig'))
    return out


def validate_clues(value, question_id):
    fields(value, {'items': array, 'version': lambda v: text(v) and re.fullmatch(r'[a-f0-9]{64}', v) is not None})
    require(len({item.get('id') for item in value['items'] if isinstance(item, dict)}) == len(value['items']))
    for clue in value['items']:
        fields(clue, {'id': record_id, 'question': lambda v: v == question_id,
                      'position': integer, 'kind': lambda v: v in ('text', 'image', 'video', 'link'),
                      'content': lambda v: isinstance(v, dict), 'autoPlay': lambda v: type(v) is bool,
                      'status': lambda v: v == 'active', 'updated': text})
        clue_content(clue['content'])
    return {'items': [picked(item, ('id', 'question', 'position', 'kind', 'content', 'autoPlay', 'status', 'updated'))
                      for item in value['items']], 'version': value['version']}


def no_credentials(value, secrets=()):
    if isinstance(value, dict):
        require(not any(key.lower() in CREDENTIAL_KEYS for key in value), 'A credential or player domain would enter the export')
        for item in value.values():
            no_credentials(item, secrets)
    elif isinstance(value, list):
        for item in value:
            no_credentials(item, secrets)
    elif isinstance(value, str):
        require(not any(secret and secret in value for secret in secrets), 'An authentication literal would enter the export')
    else:
        require(value is None or type(value) is bool or finite(value))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        raise ExportFailure('API redirects are refused; no redirected request was sent')


class ApiClient:
    def __init__(self, api_origin, exchange=None):
        self.origin = origin(api_origin)
        self.exchange = exchange
        self.token = ''
        self.question_ids = set()
        self.auth_attempted = False
        self.requests = 0
        self.opener = None

    def request(self, method, route, body=None):
        if method == 'POST' and route == AUTH:
            require(not self.auth_attempted and not self.token and isinstance(body, dict) and
                    set(body) == {'identity', 'password'}, 'Authentication cannot be retried or repurposed')
            self.auth_attempted = True
        else:
            require(method == 'GET' and body is None and self.token, 'Only authenticated read-only GETs are allowed')
            match = re.fullmatch(r'/api/questions/v1/admin/questions/([a-z0-9]{15})/clues', route)
            require(route in (ME, CATALOG) or match and match[1] in self.question_ids,
                    'The request is outside the exact content-read allowlist')
        self.requests += 1
        if self.exchange is not None:
            return self.exchange(method, route, body, self.token)
        if self.opener is None:
            context = ssl.create_default_context()
            require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Strict HTTPS verification is required')
            self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                                                     urllib.request.HTTPSHandler(context=context))
        request = urllib.request.Request(self.origin + route, method=method,
            data=None if body is None else json.dumps(body, ensure_ascii=False).encode(),
            headers={'Accept': 'application/json', **({'Content-Type': 'application/json'} if body is not None else {}),
                     **({'Authorization': self.token} if self.token else {})})
        try:
            with self.opener.open(request, timeout=20) as response:
                require(response.status == 200 and response.geturl() == self.origin + route,
                        'The exact content request did not return200 without redirect')
                encoded = response.read(MAX_RESPONSE + 1)
                require(len(encoded) <= MAX_RESPONSE, 'The content response exceeds the reviewed size limit')
                value = json.loads(encoded)
                require(isinstance(value, dict), 'The content response is not a JSON object')
                return value
        except ExportFailure:
            raise
        except Exception:
            raise ExportFailure('The strict content request failed; response and credential values omitted') from None


def collect(client, account, password):
    require(isinstance(account, str) and account.strip() and len(account) <= 128 and
            isinstance(password, str) and password and len(password) <= 4096, 'Admin credentials are required in memory')
    account = account.strip().lower()
    auth = client.request('POST', AUTH, {'identity': account, 'password': password})
    fields(auth, {'token': lambda v: text(v) and bool(v) and v == v.strip() and not v.lower().startswith('bearer '),
                  'record': lambda v: isinstance(v, dict)})
    admin = auth['record']
    fields(admin, {'id': record_id, 'collectionName': lambda v: v == 'game_admins',
                   'account': lambda v: v == account, 'status': lambda v: v == 'active'})
    identity = (admin['id'], admin['account'])
    client.token = auth['token']
    del auth, admin

    def verify_account():
        me = client.request('GET', ME)
        fields(me, {'id': lambda v: v == identity[0], 'account': lambda v: v == identity[1], 'displayName': text})

    verify_account()
    catalog = validate_catalog(client.request('GET', CATALOG))
    client.question_ids = {row['id'] for row in catalog['questions']}
    clue_sets, mismatch = [], 0
    for question in catalog['questions']:
        value = validate_clues(client.request('GET', '/api/questions/v1/admin/questions/' + question['id'] + '/clues'), question['id'])
        mismatch += len(value['items']) != question['commonClueCount']
        clue_sets.append({'question': question['id'], **value})
    verify_account()
    coverage = {'apiProjectionOnly': True, 'databaseFullExport': False, 'sameTransaction': False,
        'catalogAllReturnedStatusesAndVersionsRetained': True, 'allCatalogQuestionsActiveCluesRead': True,
        'archivedQuestionCluesVisible': False, 'mediaUrlsRetainedPrivately': True, 'mediaBytesDownloaded': False,
        'playersPersisted': False, 'authCredentialsPersisted': False, 'extraConfigurationsQueried': False,
        'catalogVsClueCountMismatches': mismatch,
        'limitations': ['The API returns a content projection rather than raw database records.',
            'Catalog and per-question active-clue reads are separate requests, without a shared read transaction.',
            'Archived question clues are filtered by the server and cannot be recovered through this API.',
            'Player-specific data, answer histories, private grants and generic extra-config definitions/instances are excluded.',
            'Referenced media bytes are not downloaded and server deployment source identity is not verified.']}
    payload = {'schemaVersion': 1, 'projection': 'admin-content-api', 'fetchedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'sourceOrigin': client.origin, 'schemaEvidenceBackendCommit': BACKEND_SCHEMA_COMMIT,
        'catalog': catalog, 'questionClueSets': clue_sets, 'coverage': coverage}
    no_credentials(payload, (password, client.token))
    counts = {name: len(catalog[name]) for name in SECTIONS}
    counts.update({'questionClueSets': len(clue_sets), 'activeQuestionClues': sum(len(row['items']) for row in clue_sets),
                   'apiRequests': client.requests, 'catalogVsClueCountMismatches': mismatch})
    return payload, counts


def destination_path(value):
    path = Path(value)
    path = (ROOT / path).absolute() if not path.is_absolute() else path.absolute()
    require(path == path.resolve() and path.is_relative_to(OUTPUT_ROOT) and path != OUTPUT_ROOT,
            'Choose a fresh explicit directory beneath artifacts/private/ui-reference')
    for item in path.relative_to(OUTPUT_ROOT).parts:
        require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,79}', item), 'Private output directory names must be simple local names')
    return path


def prepare_destination(path):
    for candidate in reversed((path, *path.parents)):
        if candidate == ROOT or ROOT not in candidate.parents:
            continue
        if candidate.exists() or candidate.is_symlink():
            info = candidate.lstat()
            require(not stat.S_ISLNK(info.st_mode) and stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid(),
                    'An output ancestor is not an owned real directory')
            if candidate == PRIVATE_ROOT or candidate.is_relative_to(PRIVATE_ROOT):
                require(stat.S_IMODE(info.st_mode) == 0o700, 'Private output directories must be owned mode700')
            require(candidate != path, 'The output directory already exists; choose a fresh path')
        else:
            candidate.mkdir(mode=0o700)


def write_private(path, value):
    encoded = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(encoded)
    return hashlib.sha256(encoded).hexdigest()


def credentials(interactive):
    if interactive:
        return input('管理员账号: '), getpass.getpass('管理员密码（不回显）: ')
    return os.environ.get('QUESTIONS_ADMIN_ACCOUNT', ''), os.environ.get('QUESTIONS_ADMIN_PASSWORD', '')


def run(args):
    origin(args.origin)
    path = destination_path(args.output_dir)
    prepare_destination(path)
    account, password = credentials(args.interactive)
    client = ApiClient(args.origin)
    try:
        payload, counts = collect(client, account, password)
        # Keep stdout paths free of credential literals even with caller-chosen names.
        public_path = str(path.relative_to(ROOT))
        require(not any(secret and secret in public_path for secret in (account, password, client.token)),
                'A credential literal occurs in the chosen output path')
        ids = {row['id'] for name in SECTIONS for row in payload['catalog'][name]}
        ids.update(item['id'] for group in payload['questionClueSets'] for item in group['items'])
        ids.update(step['id'] for scene in payload['catalog']['sessions'] for step in scene['levels'])
        require(not any(value in public_path for value in ids), 'A content record identifier occurs in the chosen output path')
        content_sha = write_private(path / 'content.json', payload)
        receipt = {'status': 'exported_api_projection', 'counts': counts, 'contentSha256': content_sha,
                   'coverage': payload['coverage'], 'authentications': 1, 'businessWriteRequests': 0}
        no_credentials(receipt, (password, client.token))
        receipt_sha = write_private(path / 'receipt.json', receipt)
        print(json.dumps({'status': 'exported_api_projection', 'counts': counts,
            'contentSha256': content_sha, 'receiptSha256': receipt_sha, 'directory': public_path}), flush=True)
        return 0
    finally:
        client.token = ''
        account = password = ''


def self_test():
    """Pure in-memory contract, credential and endpoint guards; no file creation."""
    from contextlib import redirect_stdout
    from unittest.mock import patch
    checks = 0

    def expect_failure(call):
        nonlocal checks
        try:
            call()
        except ExportFailure:
            checks += 1
            return
        raise AssertionError('An offline guard unexpectedly accepted its input')

    qid, aid, sid, lid, rid = 'q' * 15, 'a' * 15, 's' * 15, 'l' * 15, 'r' * 15
    password, token = 'offline-admin-password-probe', 'offline-auth-token-probe'
    question = {'id': qid, 'seriesKey': 'question-series', 'revision': 1, 'status': 'published', 'kind': 'text',
        'title': 'Offline content', 'placeholder': '', 'content': [{'text': 'Question', 'hint': '', 'imageUrl': '',
        'imageUrls': [], 'videoUrl': ''}], 'options': [], 'acceptedAnswers': ['answer'], 'fuzzyMatch': False,
        'groupName': '', 'commonClueCount': 1}
    clue_content_value = {'title': 'Clue', 'text': 'Text', 'url': '', 'imageUrls': [], 'buttonText': '',
                          'description': '', 'tips': ''}
    active_clue = {'id': 'c' * 15, 'question': qid, 'position': 0, 'kind': 'text', 'content': clue_content_value,
                   'autoPlay': False, 'status': 'active', 'updated': ''}
    scene = {'id': sid, 'seriesKey': 'scene-series', 'revision': 1, 'status': 'published', 'title': 'Scene',
        'description': '', 'minLevel': '', 'maxLevel': '', 'presentation': {}, 'completionTarget': None,
        'levels': [{'id': lid, 'question': qid, 'position': 1, 'xp': 50, 'autoNext': False,
                    'penaltyPolicy': [], 'presentationOverride': {}}],
        'clues': [{'id': 'd' * 15, 'sessionLevel': '', 'trigger': 'start', 'position': 0, 'kind': 'letter',
                   'narrative': 'n' * 15, 'autoPlay': False, 'content': clue_content_value}],
        'rewardRules': [], 'liveSettingsVersion': 'v1'}
    archived, draft = copy.deepcopy(question), copy.deepcopy(question)
    archived.update({'id': 'y' * 15, 'status': 'archived', 'revision': 2, 'commonClueCount': 0})
    draft.update({'id': 'x' * 15, 'status': 'draft', 'revision': 3, 'commonClueCount': 0})
    catalog = {'players': [{'password': 'player-domain-probe'}], 'questions': [question, archived, draft], 'sessions': [scene],
        'narratives': [{'id': 'n' * 15, 'seriesKey': 'story-series', 'revision': 1, 'status': 'published',
                        'kind': 'letter', 'title': 'Story', 'payload': {'paragraphs': [{'content': 'Story text'}]}}],
        'ranks': [{'id': rid, 'order': 1, 'name': 'Rank', 'minTotalXp': 0, 'visualConfig': None}],
        'rewards': [{'id': 'w' * 15, 'name': 'Reward', 'image': '', 'description': '', 'claimMethod': 'staff',
                     'publicInstructions': '', 'active': False}],
        'token': 'unknown-top-level-probe', 'password': 'unknown-password-probe',
        'capabilities': {'playerTitles': True, 'extraConfig': True}}

    def fake(method, route, body, actual_token):
        if route == AUTH:
            require(method == 'POST' and not actual_token and body == {'identity': 'offline_admin', 'password': password})
            return {'token': token, 'record': {'id': aid, 'account': 'offline_admin', 'status': 'active', 'collectionName': 'game_admins'}}
        require(actual_token == token and method == 'GET' and body is None)
        if route == ME:
            return {'id': aid, 'account': 'offline_admin', 'displayName': 'Offline'}
        if route == CATALOG:
            return copy.deepcopy(catalog)
        match = re.fullmatch(r'/api/questions/v1/admin/questions/([a-z0-9]{15})/clues', route)
        require(match and match[1] in {qid, 'y' * 15, 'x' * 15})
        return {'items': [copy.deepcopy(active_clue)] if match[1] == qid else [], 'version': 'f' * 64}

    client = ApiClient(ORIGIN, fake)
    payload, counts = collect(client, ' Offline_Admin ', password)
    encoded = json.dumps(payload)
    require(counts['questions'] == counts['questionClueSets'] == 3 and counts['sessions'] == counts['activeQuestionClues'] == 1 and
            counts['apiRequests'] == 7 and {row['status'] for row in payload['catalog']['questions']} == {'draft', 'published', 'archived'})
    require(all(value not in encoded for value in (password, token, 'player-domain-probe', 'unknown-top-level-probe', 'unknown-password-probe')))
    checks += 2
    for method, route in [('POST', CATALOG), ('PATCH', CATALOG), ('GET', AUTH),
        ('POST', '/api/questions/v1/admin/questions'), ('GET', '/api/questions/v1/admin/players'),
        ('POST', '/reset'), ('POST', '/fault'), ('GET', '/api/collections/game_questions/records'),
        ('GET', '/api/questions/v1/admin/questions/' + 'z' * 15 + '/clues'),
        ('GET', CATALOG + '?page=2'), ('GET', CATALOG + '/'), ('GET', ORIGIN + CATALOG)]:
        expect_failure(lambda m=method, r=route: client.request(m, r))
    expect_failure(lambda: client.request('POST', AUTH, {'identity': 'offline_admin', 'password': password}))
    for bad in ('http://api.sitkin.top', ORIGIN + '/', ORIGIN + ':443', ORIGIN + '?probe=1', 'https://other.invalid'):
        expect_failure(lambda value=bad: ApiClient(value, fake))
    expect_failure(lambda: ApiClient(ORIGIN, fake).request('GET', CATALOG))
    expect_failure(lambda: NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.invalid'))
    for missing in ('questions', 'sessions', 'narratives', 'ranks', 'rewards', 'players'):
        broken = copy.deepcopy(catalog)
        del broken[missing]
        expect_failure(lambda value=broken: validate_catalog(value))
    broken = copy.deepcopy(catalog)
    del broken['questions'][0]['acceptedAnswers']
    expect_failure(lambda: validate_catalog(broken))
    expect_failure(lambda: validate_clues({'items': [{'id': 'c' * 15, 'question': 'z' * 15, 'position': 1,
        'kind': 'text', 'content': {}, 'autoPlay': False, 'status': 'active', 'updated': ''}], 'version': 'f' * 64}, qid))
    for mismatch in ('record', 'account', 'me'):
        def foreign(method, route, body, actual_token, which=mismatch):
            value = fake(method, route, body, actual_token)
            if which == 'record' and route == AUTH:
                value['record']['collectionName'] = 'game_players'
            if which == 'account' and route == AUTH:
                value['record']['account'] = 'another_admin'
            if which == 'me' and route == ME:
                value['id'] = 'z' * 15
            return value
        expect_failure(lambda exchange=foreign: collect(ApiClient(ORIGIN, exchange), 'offline_admin', password))
    expect_failure(lambda: no_credentials({'payload': {'token': 'secret'}}))
    expect_failure(lambda: no_credentials({'payload': 'contains-' + password}, (password,)))
    # Default help may not construct the client, touch output metadata or read credentials.
    with patch.object(sys.modules[__name__], 'ApiClient', side_effect=AssertionError('client IO')) as factory, \
         patch.object(sys.modules[__name__], 'prepare_destination', side_effect=AssertionError('private IO')) as output, \
         patch.object(sys.modules[__name__], 'credentials', side_effect=AssertionError('credential IO')) as auth, \
         redirect_stdout(io.StringIO()):
        require(main([]) == 0)
        require(not factory.called and not output.called and not auth.called)
    checks += 1
    print(json.dumps({'status': 'passed', 'scope': 'pure in-memory fake API and offline guards only', 'checks': checks,
                      'networkRequests': 0, 'privateFilesReadOrWritten': 0}), flush=True)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    execute = sub.add_parser('run', help='Explicit authorized real admin authentication and content GET export')
    execute.add_argument('--origin', required=True, help='Exact reviewed HTTPS API origin')
    execute.add_argument('--output-dir', required=True, help='Fresh path inside artifacts/private/ui-reference')
    execute.add_argument('--interactive', action='store_true', help='Explicitly prompt for account and hidden password instead of environment')
    sub.add_parser('self-test', help='Pure in-memory fake-client and offline guard checks; never connects')
    args = parser.parse_args(argv)
    if not args.action:
        parser.print_help()
        return 0
    try:
        return self_test() if args.action == 'self-test' else run(args)
    except Exception:
        print(json.dumps({'status': 'not_exported_or_incomplete',
            'error': 'An explicit input, authentication, schema, private-output or HTTPS guard failed; raw values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
