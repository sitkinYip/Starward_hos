#!/usr/bin/env python3
"""Prepare private real-content UI fixtures offline, without importing anything.

Default/help is inert. Explicit run reads only the authorized content capture
and its bound case index, selects a minimum existing case cover and preserves
whole single-level source sessions. It writes fresh private JSON only: no DB,
HTTP, Docker, SSH, device, player preparation or service operation is performed.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

ROOT = Path(__file__).resolve().parent.parent
PRIVATE_BASE = ROOT / 'artifacts/private/ui-reference'
TARGETS = ('visible_title', 'hidden_title', 'multiple_content_blocks', 'choice_option_image', 'gallery')
TABLES = ('game_questions', 'game_answer_keys', 'game_question_settings', 'game_question_clues',
          'game_sessions', 'game_session_levels', 'game_clues', 'game_narratives',
          'game_level_definitions', 'game_rewards', 'game_reward_rules', 'game_extra_definitions')
PRESENTATION_FIELDS = {'backgroundMode', 'hideTitle', 'bgmMode', 'bgmUrl', 'backgroundUrl', 'completionStyle'}
BLOCK_FIELDS = {'text', 'hint', 'imageUrl', 'imageUrls', 'videoUrl'}
OPTION_FIELDS = {'key', 'text', 'imageUrl', 'videoUrl'}


class PreparationFailure(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def require(value, code):
    if not value:
        raise PreparationFailure(code)


def sha(value):
    return hashlib.sha256(value).hexdigest()


def within(path, parent):
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def no_symlinks(path):
    for part in (path, *path.parents):
        require(not part.is_symlink(), 'symlink_path')


def read_private(value):
    original = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    no_symlinks(original)
    path = original.resolve(strict=True)
    require(within(path, PRIVATE_BASE.resolve()), 'input_outside_ui_reference')
    info = path.stat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and
            stat.S_IMODE(info.st_mode) == 0o600, 'input_not_owned_0600')
    payload = path.read_bytes()
    value = json.loads(payload)
    require(isinstance(value, dict), 'input_not_object')
    return path, payload, value


def reserve_output(value):
    original = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    no_symlinks(original)
    output = original.resolve()
    require(within(output, PRIVATE_BASE.resolve()) and output != PRIVATE_BASE.resolve(),
            'output_outside_ui_reference')
    require(not output.exists(), 'output_exists')
    current = os.open(ROOT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        parts = output.relative_to(ROOT).parts
        for index, part in enumerate(parts):
            final, private = index == len(parts) - 1, index >= 1
            created = False
            try:
                os.mkdir(part, 0o700 if private else 0o755, dir_fd=current)
                created = True
            except FileExistsError:
                require(not final, 'output_exists')
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
            try:
                if created:
                    os.fchmod(child, 0o700 if private else 0o755)
                info = os.fstat(child)
                require(stat.S_ISDIR(info.st_mode), 'output_parent_not_directory')
                if private:
                    require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o700,
                            'private_parent_not_owned_0700')
            except Exception:
                os.close(child)
                raise
            os.close(current)
            current = child
        return output, current
    except Exception:
        os.close(current)
        raise


def verify_output(path, directory):
    no_symlinks(path)
    actual, held = path.stat(), os.fstat(directory)
    require((actual.st_dev, actual.st_ino) == (held.st_dev, held.st_ino), 'output_replaced')


def write_json(directory, name, value):
    require(name in ('fixture.json', 'manifest.json'), 'unknown_output_file')
    payload = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')
    descriptor = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=directory)
    with os.fdopen(descriptor, 'wb') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(payload)
    return sha(payload)


class Library:
    def __init__(self, snapshot):
        require(snapshot.get('status') == 'complete' and not snapshot.get('issues') and
                snapshot.get('coverage', {}).get('issueCount') == 0,
                'capture_not_complete')
        require(set(snapshot.get('content', {})) == set(TABLES), 'capture_table_scope_changed')
        audit = snapshot.get('readAudit', {})
        require(audit.get('uriMode') == 'ro' and audit.get('queryOnly') is True and
                audit.get('readTransactionCount') == 1, 'capture_read_boundary_missing')
        self.snapshot = snapshot
        self.rows, self.by_id, self.positions = {}, {}, {}
        for name in TABLES:
            value = snapshot['content'][name]
            require(isinstance(value.get('rawRows'), list) and
                    len(value.get('decodedJsonByRow', [])) == len(value['rawRows']), 'capture_rows_invalid')
            self.rows[name] = value['rawRows']
            self.by_id[name], self.positions[name] = {}, {}
            for position, row in enumerate(value['rawRows']):
                key = row.get('id')
                require(isinstance(key, str) and re.fullmatch(r'[a-z0-9]{15}', key) and
                        key not in self.by_id[name], 'capture_identity_invalid')
                self.by_id[name][key], self.positions[name][key] = row, position
        self.levels_by_session = {}
        for row in self.rows['game_session_levels']:
            self.get('game_sessions', row['session'])
            self.get('game_questions', row['question'])
            self.levels_by_session.setdefault(row['session'], []).append(row)
        for levels in self.levels_by_session.values():
            levels.sort(key=lambda row: (row['position'], row['id']))

    def get(self, table, key):
        row = self.by_id[table].get(key)
        require(row is not None, 'unresolved_content_reference')
        return row

    def parsed(self, table, row, field, fallback=None):
        position = self.positions[table][row['id']]
        item = self.snapshot['content'][table]['decodedJsonByRow'][position].get(field)
        require(isinstance(item, dict), 'missing_decoded_json')
        storage = item.get('storage')
        if storage == 'json':
            value = item.get('value')
            # Verify the convenient decoded view against its original text.
            require(json.loads(row[field]) == value, 'decoded_json_binding_mismatch')
            return value
        require(storage in ('sql_null', 'empty_text') and row.get(field) in (None, ''),
                'invalid_json_storage')
        return fallback

    def effective(self, session, level):
        base = self.parsed('game_sessions', session, 'presentation', {}) or {}
        override = self.parsed('game_session_levels', level, 'presentationOverride', {}) or {}
        require(isinstance(base, dict) and isinstance(override, dict), 'presentation_not_object')
        require(set(base) <= PRESENTATION_FIELDS and set(override) <= PRESENTATION_FIELDS,
                'presentation_fields_need_import_review')
        hidden = override.get('hideTitle')
        if hidden is None:
            hidden = base.get('hideTitle')
        require(hidden is None or type(hidden) is bool, 'hide_title_not_boolean')
        bgm = None if override.get('bgmMode') == 'silent' else override.get('bgmUrl') if override.get('bgmMode') == 'custom' else \
            None if base.get('bgmMode') == 'silent' else base.get('bgmUrl')
        background = None if override.get('backgroundMode') == 'none' else override.get('backgroundUrl') if override.get('backgroundMode') == 'custom' else \
            override.get('backgroundUrl') or (None if base.get('backgroundMode') == 'none' else base.get('backgroundUrl'))
        return {'hideTitle': hidden, 'background': background, 'bgmUrl': bgm}

    def features(self, session, level, question):
        effective = self.effective(session, level)
        blocks = self.parsed('game_questions', question, 'content', [])
        options = self.parsed('game_questions', question, 'options', [])
        require(isinstance(blocks, list) and isinstance(options, list), 'question_content_not_array')
        for block in blocks:
            require(isinstance(block, dict) and set(block) <= BLOCK_FIELDS, 'question_block_needs_import_review')
        for option in options:
            require(isinstance(option, dict) and set(option) <= OPTION_FIELDS, 'question_option_needs_import_review')
        gallery = any(not block.get('videoUrl') and len(set(
            ([block['imageUrl']] if block.get('imageUrl') else []) + (block.get('imageUrls') or []))) > 1 for block in blocks)
        return {name for name, present in (
            ('hidden_title', effective['hideTitle'] is True),
            ('visible_title', effective['hideTitle'] is not True and bool(question.get('title'))),
            ('multiple_content_blocks', len(blocks) > 1),
            ('choice_option_image', question.get('kind') == 'choice' and any(option.get('imageUrl') for option in options)),
            ('gallery', gallery)) if present}


def minimum_cover(candidates):
    full = (1 << len(TARGETS)) - 1
    best = {0: []}
    for candidate in candidates:
        mask = sum(1 << index for index, target in enumerate(TARGETS) if target in candidate['features'])
        if not mask:
            continue
        for existing_mask, chosen in list(best.items()):
            combined = existing_mask | mask
            attempt = chosen + [candidate]
            def cost(items):
                return (len(items), sum(item['dependencyCost'] for item in items),
                        sum(item['bodyChars'] for item in items), tuple(item['ordinal'] for item in items))
            if combined not in best or cost(attempt) < cost(best[combined]):
                best[combined] = attempt
    require(full in best, 'required_feature_cover_unavailable')
    return best[full]


def prepare(snapshot, case_index, source_sha, index_sha):
    library = Library(snapshot)
    require(case_index.get('sourceSnapshotSha256') == source_sha and
            isinstance(case_index.get('cases'), list) and
            case_index.get('caseCount') == len(library.rows['game_session_levels']) == len(case_index['cases']),
            'case_index_binding_mismatch')
    candidates, seen = [], set()
    for ordinal, item in enumerate(case_index['cases']):
        level = library.get('game_session_levels', item['sessionLevelId'])
        require(level['id'] not in seen and level['session'] == item['sessionId'] and
                level['question'] == item['questionId'], 'case_index_relation_mismatch')
        seen.add(level['id'])
        session, question = library.get('game_sessions', level['session']), library.get('game_questions', level['question'])
        features = library.features(session, level, question)
        require(features == set(item.get('features', [])) & set(TARGETS), 'case_index_feature_mismatch')
        dependency_cost = sum(row['session'] == session['id'] for row in library.rows['game_clues']) + \
            sum(row['question'] == question['id'] for row in library.rows['game_question_clues'])
        candidates.append({'ordinal': ordinal, 'level': level, 'session': session, 'question': question,
            'features': sorted(features), 'dependencyCost': dependency_cost,
            'bodyChars': item.get('bodyDisplayChars', 0), 'levelCount': len(library.levels_by_session[session['id']])})
    global_minimum = len(minimum_cover(candidates))
    selected = minimum_cover([candidate for candidate in candidates if candidate['levelCount'] == 1])
    require(len(selected) == global_minimum, 'minimum_cover_would_require_session_projection')
    selected.sort(key=lambda item: (not ('hidden_title' in item['features']),
                                    not ('choice_option_image' in item['features']), item['ordinal']))
    retained = {table: set() for table in TABLES}
    for candidate in selected:
        session, level, question = candidate['session'], candidate['level'], candidate['question']
        require(level['position'] == 1, 'single_source_position_not_one')
        retained['game_sessions'].add(session['id']);retained['game_session_levels'].add(level['id'])
        retained['game_questions'].add(question['id'])
    for table, owner_field, owner_table in (
        ('game_answer_keys', 'question', 'game_questions'), ('game_question_settings', 'question', 'game_questions'),
        ('game_question_clues', 'question', 'game_questions'), ('game_clues', 'session', 'game_sessions'),
        ('game_reward_rules', 'session', 'game_sessions')):
        for row in library.rows[table]:
            if row[owner_field] in retained[owner_table]:
                retained[table].add(row['id'])
    for key in retained['game_sessions']:
        session = library.get('game_sessions', key)
        for field in ('minLevel', 'maxLevel'):
            if session.get(field):
                library.get('game_level_definitions', session[field]);retained['game_level_definitions'].add(session[field])
        target = library.parsed('game_sessions', session, 'completionTarget')
        if isinstance(target, dict) and target.get('kind') == 'narrative':
            library.get('game_narratives', target['id']);retained['game_narratives'].add(target['id'])
    for key in retained['game_clues']:
        clue = library.get('game_clues', key)
        require(not clue.get('sessionLevel') or clue['sessionLevel'] in retained['game_session_levels'],
                'clue_outside_retained_whole_session')
        if clue.get('narrative'):
            library.get('game_narratives', clue['narrative']);retained['game_narratives'].add(clue['narrative'])
    for key in retained['game_reward_rules']:
        rule = library.get('game_reward_rules', key)
        require(not rule.get('sessionLevel') or rule['sessionLevel'] in retained['game_session_levels'],
                'reward_rule_outside_retained_whole_session')
        library.get('game_rewards', rule['reward']);retained['game_rewards'].add(rule['reward'])
    records = {table: {'rawRows': [row for row in library.rows[table] if row['id'] in retained[table]],
        'decodedJsonByRow': [snapshot['content'][table]['decodedJsonByRow'][index] for index, row in enumerate(library.rows[table]) if row['id'] in retained[table]]}
        for table in TABLES}
    question_templates = []
    for key in sorted(retained['game_questions']):
        question = library.get('game_questions', key)
        keys = [row for row in records['game_answer_keys']['rawRows'] if row['question'] == key]
        settings = [row for row in records['game_question_settings']['rawRows'] if row['question'] == key]
        require(len(keys) == 1 and len(settings) <= 1, 'answer_or_setting_relationship_invalid')
        require(keys[0].get('normalizationVersion') == 'nfkc-v1', 'answer_normalization_needs_import_review')
        answers = library.parsed('game_answer_keys', keys[0], 'acceptedAnswers', [])
        require(isinstance(answers, list) and answers and all(isinstance(value, str) for value in answers),
                'answer_key_not_importable')
        setting = settings[0] if settings else None
        mode = setting['answerMatchMode'] if setting else 'exact'
        require(mode in ('exact', 'contains_all'), 'answer_match_mode_not_importable')
        body = {name: question[name] for name in ('kind', 'title', 'placeholder')}
        body.update({'content': library.parsed('game_questions', question, 'content', []),
            'options': library.parsed('game_questions', question, 'options', []), 'acceptedAnswers': answers,
            'fuzzyMatch': mode == 'contains_all', 'groupName': setting['groupName'] if setting else '其他'})
        question_templates.append({'sourceQuestionId': key, 'createBody': body,
            'sourceSettingsRecordPresent': setting is not None,
            'sourceStatus': question['status'], 'targetStatus': 'new draft then published in disposable environment only'})
    cases = []
    for index, candidate in enumerate(selected):
        session, level, question = candidate['session'], candidate['level'], candidate['question']
        cases.append({'caseKey': 'ui-content-' + str(index + 1).zfill(2), 'covers': candidate['features'],
            'sourceRefs': {'sessionId': session['id'], 'sessionLevelId': level['id'], 'questionId': question['id']},
            'sourceStatus': {'session': session['status'], 'question': question['status']},
            'sourceSessionLevelCount': 1, 'questionNumber': 1,
            'sessionPresentation': library.parsed('game_sessions', session, 'presentation', {}),
            'levelPresentationOverride': library.parsed('game_session_levels', level, 'presentationOverride', {}),
            'expectedEffectivePresentation': library.effective(session, level),
            'expectedQuestion': {'kind': question['kind'], 'title': question['title'], 'placeholder': question['placeholder'],
                'content': library.parsed('game_questions', question, 'content', []),
                'options': library.parsed('game_questions', question, 'options', [])},
            'targetIdentityBinding': 'Root importer must record new local player/session/level/question/assignment IDs privately; source IDs are provenance only'})
    counts = {table: len(value['rawRows']) for table, value in records.items()}
    return {'formatVersion': 1, 'status': 'prepared_offline_not_imported',
        'scope': 'Minimum real-content question-page fixture cover, only for newly owned isolated PocketBase sessions and players',
        'sourceSnapshotSha256': source_sha, 'sourceCaseIndexSha256': index_sha,
        'selection': {'requiredFeatures': list(TARGETS), 'globalMinimumContextCount': global_minimum,
            'selectedCaseCount': len(cases), 'wholeSourceSessionsRetained': True, 'sessionLevelsTrimmed': False,
            'presentationBakedIntoOverride': False, 'selectionTieBreak': 'minimum contexts, fewer attached clue dependencies, shorter body, stable input ordinal'},
        'cases': cases, 'sourceRecords': records, 'retainedRecordCounts': counts,
        'questionCreateTemplates': question_templates,
        'importContract': {'executed': False, 'target': 'fresh owned disposable environment only; never fixed preview or production',
            'sourceIds': 'Never reuse as target IDs; create new records and persist an explicit source-to-target mapping',
            'player': 'Root creates new temporary ordinary-login player(s); no production player/authentication data is included',
            'rankReferences': 'Map referenced source ranks explicitly; keep source admission range and choose a fresh target player eligible for it',
            'order': ['map required ranks', 'create and publish new questions', 'attach active common question clues with fresh version/request identities',
                'create referenced rewards/narratives and publish narratives', 'create each entire single-level session with remapped references',
                'publish new sessions, assign only new owned players, prepare ordinary login', 'read back actual assignment DTO and validate identities/content/effective presentation before native entry'],
            'sessionFields': ['title', 'description', 'minLevel', 'maxLevel', 'presentation', 'completionTarget'],
            'levelFields': ['question', 'xp', 'autoNext', 'penaltyPolicy', 'presentationOverride'],
            'relatedContent': 'Use retained raw/decoded session clues, active question clues, reward rules and narratives; remap every relation, including completionTarget and clue level bindings',
            'newCommandFields': 'Root generates requestId/reason and fetches expectedVersion for the exact target operation; package contains no replayable write commands',
            'postImportAssertions': ['new owned identity for every imported record', 'idless question DTO equal to expectedQuestion',
                'effective title/background/BGM equal to expectedEffectivePresentation', 'whole source single-level order retained',
                'original source snapshot unchanged and fixed preview untouched'],
            'media': 'Referenced URLs remain private data; no media was downloaded or played by this preparation',
            'acceptance': 'Preparation is not import success, real entry success, media success or UI parity acceptance'},
        'extraConfigBoundary': 'Personalized extra configs are outside the source capture; no effective extra display is claimed',
        'productionWrites': False, 'importExecuted': False, 'uiRestorationAcceptance': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Offline only; prepare a new private fixture package from the bound capture/index')
    run.add_argument('--snapshot', type=Path, required=True)
    run.add_argument('--case-index', type=Path, required=True)
    run.add_argument('--expected-snapshot-sha256', required=True)
    run.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    directory = None
    try:
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_snapshot_sha256 or ''), 'expected_snapshot_hash_invalid')
        snapshot_path, snapshot_bytes, snapshot = read_private(args.snapshot)
        index_path, index_bytes, case_index = read_private(args.case_index)
        require(sha(snapshot_bytes) == args.expected_snapshot_sha256, 'snapshot_hash_mismatch')
        packet = prepare(snapshot, case_index, sha(snapshot_bytes), sha(index_bytes))
        output, directory = reserve_output(args.output_dir)
        fixture_sha = write_json(directory, 'fixture.json', packet)
        manifest = {'formatVersion': 1, 'status': packet['status'], 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'sourceSnapshotSha256': sha(snapshot_bytes), 'sourceCaseIndexSha256': sha(index_bytes),
            'preparerSourceSha256': sha(Path(__file__).read_bytes()), 'fixtureSha256': fixture_sha,
            'requiredFeatures': list(TARGETS), 'selectedCaseCount': len(packet['cases']),
            'retainedRecordCounts': packet['retainedRecordCounts'], 'importExecuted': False,
            'productionWrites': False, 'uiRestorationAcceptance': False}
        verify_output(output, directory)
        manifest_sha = write_json(directory, 'manifest.json', manifest)
        verify_output(output, directory)
        require(sha(snapshot_path.read_bytes()) == sha(snapshot_bytes) and sha(index_path.read_bytes()) == sha(index_bytes),
                'source_changed_during_preparation')
        print(json.dumps({'status': packet['status'], 'selectedCaseCount': len(packet['cases']),
            'retainedRecordCount': sum(packet['retainedRecordCounts'].values()), 'fixtureSha256': fixture_sha,
            'manifestSha256': manifest_sha, 'outputDir': str(output.relative_to(ROOT))}), flush=True)
        return 0
    except PreparationFailure as error:
        print(json.dumps({'status': 'not_prepared_' + error.code, 'issueCount': 1}), flush=True)
    except (OSError, ValueError, TypeError, KeyError):
        print(json.dumps({'status': 'not_prepared_input_or_output_failure', 'issueCount': 1}), flush=True)
    finally:
        if directory is not None:
            os.close(directory)
    return 1


if __name__ == '__main__':
    sys.exit(main())
