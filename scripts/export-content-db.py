#!/usr/bin/env python3
"""Export declared question-library content from an explicitly supplied SQLite DB.

Default/help is inert. Explicit run opens only a filesystem path with SQLite
URI mode=ro, query_only=ON and one read transaction. It neither copies the DB nor
runs migrations, maintenance, authentication, services or network requests.
Outputs are a new project-private directory (0700) containing JSON files (0600).
"""
import argparse
import base64
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import stat
import sys

# ROOT is used only by the file-output CLI; capture_content also supports being
# loaded through exec/SSH stdin without an actual remote script file.
ROOT = Path(globals().get('__file__', 'export-content-db.py')).resolve().parent.parent
PRIVATE_BASE = ROOT / 'artifacts/private/ui-reference'

# Exact content-domain tables/fields from the current backend migrations.
# No table discovery may expand this allowlist to auth or player runtime data.
INITIAL = '1787788800_game_schema.js'
TABLES = {
    'game_questions': (INITIAL,
        ('seriesKey', 'revision', 'status', 'kind', 'title', 'content', 'options', 'placeholder'),
        ('content', 'options')),
    'game_answer_keys': (INITIAL,
        ('question', 'acceptedAnswers', 'normalizationVersion'), ('acceptedAnswers',)),
    'game_question_settings': ('1788176000_question_settings.js',
        ('question', 'answerMatchMode', 'groupName'), ()),
    'game_question_clues': ('1788143000_question_clues.js',
        ('question', 'position', 'kind', 'content', 'autoPlay', 'status'), ('content',)),
    'game_sessions': (INITIAL,
        ('seriesKey', 'revision', 'status', 'title', 'description', 'minLevel', 'maxLevel',
         'presentation', 'completionTarget'), ('presentation', 'completionTarget')),
    'game_session_levels': (INITIAL,
        ('session', 'question', 'position', 'xp', 'penaltyPolicy', 'autoNext', 'presentationOverride'),
        ('penaltyPolicy', 'presentationOverride')),
    'game_clues': (INITIAL,
        ('session', 'sessionLevel', 'trigger', 'position', 'kind', 'content', 'narrative', 'autoPlay'),
        ('content',)),
    'game_narratives': (INITIAL,
        ('seriesKey', 'revision', 'status', 'kind', 'title', 'payload'), ('payload',)),
    'game_level_definitions': (INITIAL,
        ('order', 'name', 'minTotalXp', 'visualConfig'), ('visualConfig',)),
    'game_rewards': (INITIAL,
        ('name', 'image', 'description', 'claimMethod', 'publicInstructions', 'active'), ()),
    'game_reward_rules': (INITIAL,
        ('session', 'sessionLevel', 'trigger', 'reward', 'quantity'), ()),
    'game_extra_definitions': ('1788825600_player_titles_extra.js',
        ('revision', 'key', 'label', 'status', 'schema'), ('schema',)),
}
DECLARED_COLUMNS = {name: ('id', 'created', 'updated') + spec[1] for name, spec in TABLES.items()}
RELATIONS = (
    ('game_answer_keys', 'question', 'game_questions', True),
    ('game_question_settings', 'question', 'game_questions', True),
    ('game_question_clues', 'question', 'game_questions', True),
    ('game_sessions', 'minLevel', 'game_level_definitions', False),
    ('game_sessions', 'maxLevel', 'game_level_definitions', False),
    ('game_session_levels', 'session', 'game_sessions', True),
    ('game_session_levels', 'question', 'game_questions', True),
    ('game_clues', 'session', 'game_sessions', True),
    ('game_clues', 'sessionLevel', 'game_session_levels', False),
    ('game_clues', 'narrative', 'game_narratives', False),
    ('game_reward_rules', 'session', 'game_sessions', True),
    ('game_reward_rules', 'sessionLevel', 'game_session_levels', False),
    ('game_reward_rules', 'reward', 'game_rewards', True),
)
EXCLUDED = ('auth collections', 'game_players', 'game_admins', 'game_player_stats',
    'game_assignments', 'game_level_progress', 'game_answer_submissions', 'game_xp_ledger',
    'game_player_rewards', 'game_clue_unlocks', 'game_notifications',
    'game_notification_receipts', 'game_admin_audit_logs', 'game_command_receipts',
    'game_player_level_titles', 'game_extra_configs')
CONSISTENCY_CHECKS = ('required tables and declared column allowlist/schema drift', 'JSON storage decoding',
    'record identity uniqueness', 'existing content relation targets', 'completion narrative targets')
CONSISTENCY_NOT_CHECKED = ('every question has an answer key or explicit settings row',
    'sessionLevel belongs to the same session as a clue or reward rule',
    'answer semantics, publishing invariants, media availability or effective presentation')


class ExportFailure(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def require(value, code):
    if not value:
        raise ExportFailure(code)


def no_symlinks(path):
    for part in (path, *path.parents):
        require(not part.is_symlink(), 'symlink_path')


def within(path, parent):
    # Path.is_relative_to is unavailable on the production host's Python3.6.
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def database_path(value):
    path = value.absolute()
    no_symlinks(path)
    path = path.resolve(strict=True)
    info = path.stat()
    require(stat.S_ISREG(info.st_mode), 'database_not_regular')
    with path.open('rb') as stream:
        require(stream.read(16) == b'SQLite format 3\x00', 'database_not_sqlite')
    return path


def output_path(value, database):
    original = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    no_symlinks(original)
    path = original.resolve()
    require(within(path, PRIVATE_BASE.resolve()) and path != PRIVATE_BASE.resolve(),
            'output_outside_private_reference')
    require(path != database and not within(database, path) and not within(path, database),
            'database_output_overlap')
    require(not path.exists(), 'output_exists')
    return path


def reserve_output(path):
    # Anchor every operation to an opened directory. A checked parent replaced
    # by a symlink cannot redirect mkdir/chmod or later JSON writes elsewhere.
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    current = os.open(ROOT, flags)
    try:
        parts = path.relative_to(ROOT).parts
        for index, part in enumerate(parts):
            final = index == len(parts) - 1
            private = index >= 1  # artifacts/private and every descendant.
            created = False
            try:
                os.mkdir(part, 0o700 if private else 0o755, dir_fd=current)
                created = True
            except FileExistsError:
                require(not final, 'output_exists')
            child = os.open(part, flags, dir_fd=current)
            try:
                if created:
                    os.fchmod(child, 0o700 if private else 0o755)
                info = os.fstat(child)
                require(stat.S_ISDIR(info.st_mode), 'output_parent_not_directory')
                if private:
                    require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o700,
                            'private_directory_not_owned_0700')
            except Exception:
                os.close(child)
                raise
            os.close(current)
            current = child
        return current
    except Exception:
        os.close(current)
        raise


def identifier(value):
    require(value in TABLES, 'table_not_allowlisted')
    return '"' + value + '"'


def column_identifier(table, column):
    require(column in DECLARED_COLUMNS[table], 'column_not_allowlisted')
    return '"' + column + '"'


def raw_value(value):
    if isinstance(value, bytes):
        return {'$sqliteBlobBase64': base64.b64encode(value).decode('ascii')}
    if isinstance(value, float) and not math.isfinite(value):
        return {'$sqliteNonFinite': repr(value)}
    require(value is None or isinstance(value, (str, int, float)), 'unsupported_sqlite_value')
    return value


def json_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate_json_key')
        result[key] = value
    return result


def invalid_constant(_):
    raise ValueError('non_json_constant')


def decode_json(value):
    # Raw SQLite values are always retained separately, including whitespace,
    # unset NULL/empty text and unknown JSON keys. No presentation is merged.
    if value is None:
        return {'storage': 'sql_null'}
    if value == '':
        return {'storage': 'empty_text'}
    if not isinstance(value, str):
        return {'storage': 'invalid_json_type'}
    try:
        return {'storage': 'json', 'value': json.loads(value, object_pairs_hook=json_pairs,
                                                     parse_constant=invalid_constant)}
    except (ValueError, TypeError):
        return {'storage': 'invalid_json'}


def read_snapshot(database):
    schema, tables, issues = {}, {}, []
    audit = {'uriMode': 'ro', 'queryOnly': False, 'readTransactionCount': 0,
             'readTables': [], 'readColumns': {}, 'maintenanceOrSourceCopyPerformed': False}
    read_tables = set()
    read_columns = {}

    def authorizer(action, first, second, _database, _trigger):
        if action == sqlite3.SQLITE_SELECT:
            return sqlite3.SQLITE_OK
        if action == sqlite3.SQLITE_READ:
            permitted = (first in TABLES and second in DECLARED_COLUMNS[first]) or \
                (first in ('sqlite_master', 'sqlite_schema') and second in ('name', 'type'))
            if permitted:
                read_tables.add(first)
                read_columns.setdefault(first, set()).add(second)
                return sqlite3.SQLITE_OK
            return sqlite3.SQLITE_DENY
        if action == sqlite3.SQLITE_PRAGMA:
            permitted = (first == 'table_info' and second in TABLES) or \
                (first in ('query_only', 'user_version', 'schema_version') and second is None)
            return sqlite3.SQLITE_OK if permitted else sqlite3.SQLITE_DENY
        if action == sqlite3.SQLITE_TRANSACTION and first in ('BEGIN', 'COMMIT', 'ROLLBACK'):
            if first == 'BEGIN':
                audit['readTransactionCount'] += 1
            return sqlite3.SQLITE_OK
        return sqlite3.SQLITE_DENY

    connection = None
    try:
        connection = sqlite3.connect(database.as_uri() + '?mode=ro', uri=True,
                                     isolation_level=None, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute('PRAGMA query_only=ON')
        connection.set_authorizer(authorizer)
        connection.execute('BEGIN')
        require(connection.in_transaction and connection.execute('PRAGMA query_only').fetchone()[0] == 1,
                'readonly_transaction_not_confirmed')
        audit['queryOnly'] = True
        audit['sqliteVersion'] = sqlite3.sqlite_version
        audit['userVersion'] = connection.execute('PRAGMA user_version').fetchone()[0]
        audit['schemaVersion'] = connection.execute('PRAGMA schema_version').fetchone()[0]
        placeholders = ','.join('?' for _ in TABLES)
        objects = {row['name']: dict(row) for row in connection.execute(
            'SELECT name,type FROM sqlite_master WHERE name IN (' + placeholders + ') ORDER BY name', tuple(TABLES))}
        for name, (migration, fields, json_fields) in TABLES.items():
            obj = objects.get(name)
            if obj is None or obj['type'] != 'table':
                issues.append({'code': 'required_content_table_missing_or_not_table', 'table': name})
                continue
            # Never retain dflt_value or sqlite_master.sql: an unapproved
            # column's default can itself contain a credential or private ID.
            columns = [{key: row[key] for key in ('cid', 'name', 'type', 'notnull', 'pk')}
                       for row in connection.execute('PRAGMA table_info(' + identifier(name) + ')')]
            names = {column['name'] for column in columns}
            required = set(DECLARED_COLUMNS[name])
            missing = sorted(required - names)
            unapproved = sorted(names - required)
            if missing:
                issues.append({'code': 'required_columns_missing', 'table': name, 'columns': missing})
            if unapproved:
                issues.append({'code': 'unapproved_columns_present', 'table': name, 'columns': unapproved})
            if missing or unapproved:
                schema[name] = {'migrationSource': migration,
                    'columns': [{key: column[key] for key in ('name', 'type')} for column in columns],
                    'missingRequiredColumns': missing, 'unapprovedColumns': unapproved,
                    'rowsExported': False}
                continue
            schema[name] = {'migrationSource': migration, 'columns': columns,
                            'declaredJsonColumns': list(json_fields), 'missingRequiredColumns': [],
                            'unapprovedColumns': [], 'rowsExported': True}
            selected = ','.join(column_identifier(name, column) for column in DECLARED_COLUMNS[name])
            rows = [dict(row) for row in connection.execute(
                'SELECT ' + selected + ' FROM ' + identifier(name) + ' ORDER BY "id"')]
            decoded = []
            for index, row in enumerate(rows):
                values = {}
                for field in json_fields:
                    if field not in row:
                        continue
                    value = decode_json(row[field])
                    values[field] = value
                    if value['storage'].startswith('invalid_'):
                        issues.append({'code': value['storage'], 'table': name, 'rowIndex': index, 'column': field})
                decoded.append(values)
            tables[name] = {'rawRows': rows, 'decodedJsonByRow': decoded}
        require(audit['readTransactionCount'] == 1, 'unexpected_read_transaction_count')
    except (sqlite3.Error, ExportFailure) as error:
        issues.append({'code': error.code if isinstance(error, ExportFailure) else 'sqlite_read_failed'})
    finally:
        if connection is not None:
            if connection.in_transaction:
                connection.execute('ROLLBACK')
            connection.close()
        audit['readTables'] = sorted(read_tables)
        audit['readColumns'] = {name: sorted(columns) for name, columns in read_columns.items()}
    return schema, tables, issues, audit


def relation_index(tables, issues):
    by_id, links, cases = {}, [], []
    for name, data in tables.items():
        index = {}
        for position, row in enumerate(data['rawRows']):
            value = row.get('id')
            if not isinstance(value, str) or not value or value in index:
                issues.append({'code': 'missing_or_duplicate_record_id', 'table': name, 'rowIndex': position})
            else:
                index[value] = position
        by_id[name] = index
    for source, field, target, required in RELATIONS:
        if source not in tables:
            continue
        for position, row in enumerate(tables[source]['rawRows']):
            value = row.get(field)
            if value is None or value == '':
                if required:
                    issues.append({'code': 'required_relation_empty', 'table': source, 'rowIndex': position, 'column': field})
                continue
            valid = isinstance(value, str) and value in by_id.get(target, {})
            links.append({'sourceTable': source, 'sourceRowIndex': position, 'sourceId': raw_value(row.get('id')),
                          'column': field, 'targetTable': target, 'targetId': raw_value(value), 'resolved': valid})
            if not valid:
                issues.append({'code': 'unresolved_content_relation', 'table': source, 'rowIndex': position, 'column': field})
    for position, row in enumerate(tables.get('game_sessions', {}).get('rawRows', [])):
        decoded = tables['game_sessions']['decodedJsonByRow'][position].get('completionTarget', {})
        value = decoded.get('value')
        if isinstance(value, dict) and value.get('kind') == 'narrative':
            target = value.get('id')
            valid = isinstance(target, str) and target in by_id.get('game_narratives', {})
            links.append({'sourceTable': 'game_sessions', 'sourceRowIndex': position, 'sourceId': raw_value(row.get('id')),
                          'column': 'completionTarget.id', 'targetTable': 'game_narratives',
                          'targetId': target, 'resolved': valid})
            if not valid:
                issues.append({'code': 'unresolved_completion_narrative', 'table': 'game_sessions', 'rowIndex': position})
    for row in tables.get('game_session_levels', {}).get('rawRows', []):
        cases.append({key: raw_value(row.get(field)) for key, field in
                      (('sessionId', 'session'), ('sessionLevelId', 'id'), ('questionId', 'question'), ('position', 'position'))})
    reverse = {}
    for link in links:
        target = link['targetId']
        if isinstance(target, str):
            reverse.setdefault(link['targetTable'], {}).setdefault(target, []).append({
                'sourceTable': link['sourceTable'], 'sourceId': link['sourceId'], 'column': link['column']})
    return {'rowIndexById': by_id, 'relations': links, 'incomingRelations': reverse,
            'sessionLevelRenderCases': cases, 'presentationMerged': False}


def capture_content(database):
    """Return PRIVATE content/schema/index/coverage; never print or write files.

    The caller may serialize the returned object directly into an authorized
    private pipe/file. It contains answer keys and media URLs. This function
    opens the explicitly supplied local DB only, with the same RO transaction
    and table authorizer as the CLI; it does not authenticate or contact a host.
    """
    database = database_path(Path(database))
    schema, tables, issues, audit = read_snapshot(database)
    index = relation_index(tables, issues)
    counts = {name: len(data['rawRows']) for name, data in tables.items()}
    status = 'complete' if not issues and len(tables) == len(TABLES) else 'incomplete'
    content = {name: {
        'rawRows': [{key: raw_value(value) for key, value in row.items()} for row in data['rawRows']],
        'decodedJsonByRow': data['decodedJsonByRow'],
    } for name, data in tables.items()}
    return {'formatVersion': 1, 'status': status, 'schema': schema, 'content': content,
        'index': index, 'issues': issues, 'readAudit': audit,
        'coverage': {'expectedContentTables': list(TABLES), 'capturedTableCount': len(tables),
            'missingContentTables': [name for name in TABLES if name not in schema],
            'blockedContentTables': [name for name in schema if name not in tables],
            'tableCounts': counts, 'rowCount': sum(counts.values()), 'issueCount': len(issues),
            'scope': 'Declared content-core capture only; no authentication, player runtime or personalized extra configs',
            'excludedByDesign': list(EXCLUDED), 'statusIsBusinessAcceptance': False,
            'consistencyValidationScope': list(CONSISTENCY_CHECKS),
            'consistencyNotValidated': list(CONSISTENCY_NOT_CHECKED),
            'rawJsonPreserved': True, 'rowSelectionFiltersApplied': False,
            'allRevisionsAndArchivedRowsIncluded': status == 'complete',
            'mediaBytesDownloaded': False}}


def write_json(directory_fd, name, value):
    require(re.fullmatch(r'[a-zA-Z0-9_.-]+\.json', name), 'invalid_output_file_name')
    data = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode('utf-8')
    descriptor = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=directory_fd)
    with os.fdopen(descriptor, 'wb') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(data)
    return hashlib.sha256(data).hexdigest()


def verify_output_identity(output, directory_fd, table_fd):
    current_tables, held_tables = os.stat('tables', dir_fd=directory_fd, follow_symlinks=False), os.fstat(table_fd)
    require(stat.S_ISDIR(current_tables.st_mode) and
            (current_tables.st_dev, current_tables.st_ino) == (held_tables.st_dev, held_tables.st_ino),
            'table_output_directory_replaced')
    no_symlinks(output)
    actual, held = output.stat(), os.fstat(directory_fd)
    require((actual.st_dev, actual.st_ino) == (held.st_dev, held.st_ino), 'output_directory_replaced')


def export(database_value, output_value):
    database = database_path(database_value)
    output = output_path(output_value, database)
    directory_fd = reserve_output(output)
    table_fd = None
    try:
        captured = capture_content(database)
        schema, tables, issues, audit = (captured[key] for key in ('schema', 'content', 'issues', 'readAudit'))
        index = captured['index']
        os.mkdir('tables', 0o700, dir_fd=directory_fd)
        table_fd = os.open('tables', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory_fd)
        os.fchmod(table_fd, 0o700)
        hashes = {}
        for name, data in tables.items():
            hashes['tables/' + name + '.json'] = write_json(table_fd, name + '.json', data)
        hashes['schema.json'] = write_json(directory_fd, 'schema.json', schema)
        hashes['relationships.json'] = write_json(directory_fd, 'relationships.json', index)
        hashes['issues.json'] = write_json(directory_fd, 'issues.json', issues)
        counts, status = captured['coverage']['tableCounts'], captured['status']
        manifest = {'formatVersion': 1, 'status': status,
            'scope': 'Declared content-core tables only; all rows/revisions/statuses and original SQLite fields, not a full database or personalized UI snapshot',
            'statusMeaning': 'Capture completeness for the declared allowlist and explicit checks only; never gameplay, rendering or full business-consistency acceptance',
            'consistencyValidationScope': list(CONSISTENCY_CHECKS),
            'consistencyNotValidated': list(CONSISTENCY_NOT_CHECKED),
            'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'sourceFileName': database.name, 'readAudit': audit, 'tableCounts': counts,
            'expectedContentTables': list(TABLES), 'issueCount': len(issues),
            'excludedByDesign': list(EXCLUDED),
            'extraConfigBoundary': 'game_extra_configs is excluded because it can bind private players/assignments; definitions alone do not reproduce personalized extra display',
            'rawJsonPreserved': True, 'allRevisionsAndArchivedRowsIncluded': status == 'complete',
            'rowSelectionFiltersApplied': False,
            'mediaBytesDownloaded': False, 'businessRuntimeOrAuthenticationDataExported': False,
            'fileSha256': hashes}
        verify_output_identity(output, directory_fd, table_fd)
        digest = write_json(directory_fd, 'manifest.json', manifest)
        verify_output_identity(output, directory_fd, table_fd)
    finally:
        if table_fd is not None:
            os.close(table_fd)
        os.close(directory_fd)
    print(json.dumps({'status': status, 'tableCount': len(tables), 'rowCount': sum(counts.values()),
                      'issueCount': len(issues), 'manifestSha256': digest,
                      'outputDir': str(output.relative_to(ROOT))}), flush=True)
    return 0 if status == 'complete' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Explicit local content-only read; requires a fresh project-private output directory')
    run.add_argument('--database', type=Path, required=True)
    run.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return export(args.database, args.output_dir)
    except ExportFailure as error:
        print(json.dumps({'status': 'not_started_' + error.code, 'issueCount': 1}), flush=True)
    except (OSError, ValueError, TypeError, sqlite3.Error):
        print(json.dumps({'status': 'incomplete_io_or_database_failure', 'issueCount': 1}), flush=True)
    return 1


if __name__ == '__main__':
    sys.exit(main())
