"""Strict offline comparison of the private2000ms/15000ms profile HAP pair.

Only integration.json's timeout may change application configuration. The fixed
SDK may reorder complete symbolMap.map records when workers finish in another
order. Each self-contained record must remain byte-for-byte present exactly once
under its unique module/function key. This is not a general sourcemap exemption.

The official SymbolTable reader processes each LF record into keyed maps:
https://github.com/openharmony/arkcompiler_ets_frontend/blob/
3271e689443900dbce3ad766c881f397a38e2c76/es2panda/util/symbolTable.cpp#L72
The actual fixed-SDK pair uses the three-field function form, not the newer
four-field special-function form; unknown formats deliberately fail closed.
"""
from collections import Counter
import hashlib
import json
import re

CONFIG_ENTRY = 'resources/rawfile/integration.json'
SYMBOL_ENTRY = 'ets/symbolMap.map'
MODULE = re.compile(r'&entry/(?:src/main/ets|build/generated/r)/[A-Za-z0-9_./-]+&')
DECIMAL = re.compile(r'(?:0|[1-9][0-9]*)')
MAX_ENTRY_BYTES = 30 * 1024 * 1024


class VariantMismatch(ValueError):
    """An application, mapping record or unexpected archive entry changed."""


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unsigned(value, bits):
    return bool(DECIMAL.fullmatch(value)) and int(value) < 2 ** bits


def fields(value, separator):
    # Match the compiler reader's GetStringItems: ignore empty separator tokens.
    return [item for item in value.split(separator) if item]


def function_name(value):
    module, separator, suffix = value.partition('&.')
    return bool(separator and suffix and MODULE.fullmatch(module + '&'))


def symbol_records(data):
    """Validate the observed fixed-SDK format without normalising record bytes."""
    if not isinstance(data, bytes) or not data or len(data) > MAX_ENTRY_BYTES or not data.endswith(b'\n'):
        raise VariantMismatch('The symbol map must be a bounded nonempty LF-terminated record file')
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        raise VariantMismatch('The symbol map is not strict UTF-8') from None
    if any((ord(char) < 32 and char != '\n') or ord(char) == 127 for char in text):
        raise VariantMismatch('The symbol map contains unsupported control characters or line endings')
    raw_records = data.split(b'\n')[:-1]
    keys, module_count, function_count = set(), 0, 0
    for raw in raw_records:
        if not raw:
            raise VariantMismatch('Blank symbol-map records are not permitted')
        row = raw.decode('utf-8')
        sections = fields(row, '|')
        if row.count('|') == 0 and len(sections) == 1:
            item = fields(sections[0], ';')
            if len(item) != 2 or not MODULE.fullmatch(item[0]) or not unsigned(item[1], 64):
                raise VariantMismatch('The symbol map contains an invalid module record')
            key = ('module', item[0])
            module_count += 1
        elif row.count('|') == 2 and len(sections) == 3:
            function, classes, lexical = [fields(section, ';') for section in sections]
            if (len(function) != 3 or not function_name(function[0]) or
                    function[0] != function[1] or not unsigned(function[2], 64) or
                    len(classes) % 2 or len(lexical) % 3):
                raise VariantMismatch('The symbol map contains an unknown or invalid function record')
            if any(not unsigned(classes[index + 1], 64) for index in range(0, len(classes), 2)):
                raise VariantMismatch('A symbol-map class hash is invalid')
            if any(not unsigned(lexical[index + 1], 32) or not unsigned(lexical[index + 2], 32)
                   for index in range(0, len(lexical), 3)):
                raise VariantMismatch('A symbol-map lexical slot or type is invalid')
            key = ('function', function[1])
            function_count += 1
        else:
            raise VariantMismatch('The symbol map record format is not the observed fixed-SDK format')
        # A conflicting duplicate key could make insertion order significant.
        if key in keys:
            raise VariantMismatch('Duplicate symbol-map module/function keys are not permitted')
        keys.add(key)
    if not module_count or not function_count:
        raise VariantMismatch('Both complete module and function records are required')
    return Counter(raw_records), {'recordCount': len(raw_records), 'moduleCount': module_count,
        'functionCount': function_count, 'uniqueRecordKeys': True,
        'canonicalRecordsSha256': digest(b''.join(row + b'\n' for row in sorted(raw_records)))}


def config(data):
    def unique(items):
        result = {}
        for key, value in items:
            if key in result:
                raise VariantMismatch('Duplicate configuration keys are not permitted')
            result[key] = value
        return result

    def nonfinite(_):
        raise VariantMismatch('Nonfinite configuration JSON is not permitted')

    try:
        value = json.loads(data.decode('utf-8'), object_pairs_hook=unique, parse_constant=nonfinite)
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise VariantMismatch('The packaged integration configuration is not valid JSON') from None
    if not isinstance(value, dict):
        raise VariantMismatch('The packaged integration configuration must be an object')
    return value


def validate_timeout_entries(base, variant):
    """Compare original uncompressed entries; never rewrite or re-sign a HAP."""
    if not base or set(base) != set(variant) or CONFIG_ENTRY not in base:
        raise VariantMismatch('The timeout variant changed the packaged entry set')
    if any(not isinstance(value, bytes) or len(value) > MAX_ENTRY_BYTES
           for entries in (base, variant) for value in entries.values()):
        raise VariantMismatch('Packaged entry bytes exceed the strict comparison bound')
    original, changed_config = config(base[CONFIG_ENTRY]), config(variant[CONFIG_ENTRY])
    if (original.get('timeoutMs') != 2000 or original.get('isolated') is not True or
            changed_config != {**original, 'timeoutMs': 15000}):
        raise VariantMismatch('Application configuration may change only timeout2000-to15000')
    changed = sorted(name for name in base if base[name] != variant[name])
    if CONFIG_ENTRY not in changed or set(changed) - {CONFIG_ENTRY, SYMBOL_ENTRY}:
        raise VariantMismatch('The timeout variant changed an unexpected packaged entry')
    mapping = {'entry': SYMBOL_ENTRY, 'present': SYMBOL_ENTRY in base}
    if mapping['present']:
        old_records, old_shape = symbol_records(base[SYMBOL_ENTRY])
        new_records, new_shape = symbol_records(variant[SYMBOL_ENTRY])
        if old_records != new_records or old_shape != new_shape:
            raise VariantMismatch('Complete symbol-map records changed; only their order may differ')
        mapping.update(old_shape)
        mapping.update({'baseSha256': digest(base[SYMBOL_ENTRY]),
            'variantSha256': digest(variant[SYMBOL_ENTRY]),
            'bytesIdentical': base[SYMBOL_ENTRY] == variant[SYMBOL_ENTRY],
            'completeRecordMultisetIdentical': True,
            'onlyRecordOrderChanged': base[SYMBOL_ENTRY] != variant[SYMBOL_ENTRY]})
    return {'changedPackagedEntries': changed, 'uncompressedPackagedEntries': len(base),
        'onlyTimeoutConfigurationChanged': True, 'allOtherPackagedEntriesByteIdentical': True,
        'packagedByteChangeScope': 'integration timeout; optional complete symbol-map record reordering only',
        'symbolMap': mapping}
