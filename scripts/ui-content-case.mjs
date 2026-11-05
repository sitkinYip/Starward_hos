/** Explicit local-control import of a reviewed private content fixture.
 * Importing/running this module alone is inert. Content writes use official
 * admin commands; ordinary-login preparation uses the official player API.
 * Both use the injected disposable runner; collection access is GET only.
 */
import { constants } from 'node:fs';
import { lstat, open } from 'node:fs/promises';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';

const ID = /^[a-z0-9]{15}$/;
const HASH = /^[a-f0-9]{64}$/;
const TARGETS = ['visible_title', 'hidden_title', 'multiple_content_blocks', 'choice_option_image', 'gallery'];
const COMMON = ['id', 'created', 'updated'];
const TABLES = {
  game_questions: ['seriesKey', 'revision', 'status', 'kind', 'title', 'content', 'options', 'placeholder'],
  game_answer_keys: ['question', 'acceptedAnswers', 'normalizationVersion'],
  game_question_settings: ['question', 'answerMatchMode', 'groupName'],
  game_question_clues: ['question', 'position', 'kind', 'content', 'autoPlay', 'status'],
  game_sessions: ['seriesKey', 'revision', 'status', 'title', 'description', 'minLevel', 'maxLevel', 'presentation', 'completionTarget'],
  game_session_levels: ['session', 'question', 'position', 'xp', 'penaltyPolicy', 'autoNext', 'presentationOverride'],
  game_clues: ['session', 'sessionLevel', 'trigger', 'position', 'kind', 'content', 'narrative', 'autoPlay'],
  game_narratives: ['seriesKey', 'revision', 'status', 'kind', 'title', 'payload'],
  game_level_definitions: ['order', 'name', 'minTotalXp', 'visualConfig'],
  game_rewards: ['name', 'image', 'description', 'claimMethod', 'publicInstructions', 'active'],
  game_reward_rules: ['session', 'sessionLevel', 'trigger', 'reward', 'quantity'],
  game_extra_definitions: ['revision', 'key', 'label', 'status', 'schema'],
};
const JSON_FIELDS = {
  game_questions: ['content', 'options'], game_answer_keys: ['acceptedAnswers'], game_question_settings: [],
  game_question_clues: ['content'], game_sessions: ['presentation', 'completionTarget'],
  game_session_levels: ['penaltyPolicy', 'presentationOverride'], game_clues: ['content'],
  game_narratives: ['payload'], game_level_definitions: ['visualConfig'], game_rewards: [], game_reward_rules: [],
  game_extra_definitions: ['schema'],
};

class FixtureError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const requireThat = (value, code) => { if (!value) throw new FixtureError(code); };
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const canonical = value => Array.isArray(value) ? '[' + value.map(canonical).join(',') + ']' : object(value) ?
  '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}' : JSON.stringify(value);
const equal = (actual, expected, code) => requireThat(canonical(actual) === canonical(expected), code);
const keys = (value, allowed, code) => requireThat(object(value) && Object.keys(value).every(key => allowed.includes(key)), code);
const exactKeys = (value, allowed, code) => { keys(value, allowed, code); requireThat(Object.keys(value).length === allowed.length, code); };
const integer = (value, min, max, code) => { requireThat(Number.isSafeInteger(value) && value >= min && value <= max, code); return value; };
const flag = value => { requireThat([0, 1, false, true].includes(value), 'source_boolean_invalid'); return value === true || value === 1; };
function text(value, max, required = false) {
  requireThat(typeof value === 'string' && value.length <= max && (!required || value.trim().length > 0), 'source_text_invalid');
  requireThat(value === value.trim(), 'admin_would_trim_source_text');
  return value;
}
function url(value) {
  requireThat(typeof value === 'string' && value.length <= 4000 && (!value || /^https?:\/\/[^/\s@\\?#]+(?:[/?#][^\s\\]*)?$/i.test(value)), 'source_media_url_invalid');
  return value; // Data only. Never used as a request route or fetched here.
}
function list(value, max) { requireThat(Array.isArray(value) && value.length <= max, 'source_list_invalid'); return value; }
function presentation(value) {
  keys(value, ['backgroundMode', 'hideTitle', 'bgmMode', 'bgmUrl', 'backgroundUrl', 'completionStyle'], 'presentation_field_not_supported');
  requireThat(!value.backgroundMode || ['inherit', 'custom', 'none'].includes(value.backgroundMode), 'background_mode_invalid');
  requireThat(!value.bgmMode || ['inherit', 'custom', 'silent'].includes(value.bgmMode), 'bgm_mode_invalid');
  requireThat(!value.completionStyle || ['normal', 'finale'].includes(value.completionStyle), 'completion_style_invalid');
  if (Object.hasOwn(value, 'hideTitle')) requireThat(typeof value.hideTitle === 'boolean', 'hide_title_invalid');
  const result = { backgroundMode: value.backgroundMode || 'inherit',
    ...(typeof value.hideTitle === 'boolean' ? { hideTitle: value.hideTitle } : {}), bgmMode: value.bgmMode || 'inherit',
    bgmUrl: url(value.bgmUrl || ''), backgroundUrl: url(value.backgroundUrl || ''), completionStyle: value.completionStyle || 'normal' };
  equal(result, value, 'admin_would_change_presentation_shape');
  return result;
}
function blocks(value) {
  return list(value, 100).map(block => {
    keys(block, ['text', 'hint', 'imageUrl', 'imageUrls', 'videoUrl'], 'block_field_not_supported');
    const result = { text: text(block.text || '', 16000), hint: text(block.hint || '', 4000), imageUrl: url(block.imageUrl || ''),
      imageUrls: list(block.imageUrls || [], 30).map(url), videoUrl: url(block.videoUrl || '') };
    equal(result, block, 'admin_would_change_content_block_shape'); return result;
  });
}
function options(value) {
  const result = list(value, 30).map(option => {
    keys(option, ['key', 'text', 'imageUrl', 'videoUrl'], 'option_field_not_supported');
    const result = { key: text(option.key, 30, true), text: text(option.text || '', 4000), imageUrl: url(option.imageUrl || ''), videoUrl: url(option.videoUrl || '') };
    equal(result, option, 'admin_would_change_option_shape'); return result;
  });
  requireThat(new Set(result.map(row => row.key)).size === result.length, 'option_key_duplicate'); return result;
}
function clueContent(value) {
  keys(value, ['title', 'text', 'url', 'imageUrls', 'buttonText', 'description', 'tips'], 'clue_field_not_supported');
  const result = { title: text(value.title || '', 200), text: text(value.text || '', 16000), url: url(value.url || ''),
    imageUrls: list(value.imageUrls || [], 30).map(url), buttonText: text(value.buttonText || '', 100),
    description: text(value.description || '', 1000), tips: text(value.tips || '', 500) };
  equal(result, value, 'admin_would_change_clue_content_shape'); return result;
}
function penalties(value) {
  return list(value, 20).map(item => {
    requireThat(object(item), 'penalty_invalid');
    if (item.type === 'lock') { exactKeys(item, ['type'], 'penalty_field_not_supported'); return { type: 'lock' }; }
    exactKeys(item, ['type', 'seconds'], 'penalty_field_not_supported');
    requireThat(item.type === 'cooldown', 'penalty_type_invalid');
    return { type: 'cooldown', seconds: integer(item.seconds, 0, 86400 * 30, 'penalty_seconds_invalid') };
  });
}
function effective(base, override) {
  return { hideTitle: override.hideTitle ?? base.hideTitle ?? null,
    background: override.backgroundMode === 'none' ? null : override.backgroundMode === 'custom' ? override.backgroundUrl :
      override.backgroundUrl || (base.backgroundMode === 'none' ? null : base.backgroundUrl ?? null),
    bgmUrl: override.bgmMode === 'silent' ? null : override.bgmMode === 'custom' ? override.bgmUrl :
      base.bgmMode === 'silent' ? null : base.bgmUrl ?? null };
}
function features(question, base, override) {
  const found = [];
  if (effective(base, override).hideTitle === true) found.push('hidden_title');
  else if (question.title) found.push('visible_title');
  if (question.content.length > 1) found.push('multiple_content_blocks');
  if (question.kind === 'choice' && question.options.some(row => row.imageUrl)) found.push('choice_option_image');
  if (question.content.some(row => !row.videoUrl && new Set([...(row.imageUrl ? [row.imageUrl] : []), ...row.imageUrls]).size > 1)) found.push('gallery');
  return found.sort();
}

/** No I/O: strict source/domain preflight, including API canonicalization. */
export function validateUiContentFixture(packet) {
  requireThat(object(packet) && packet.formatVersion === 1 && packet.status === 'prepared_offline_not_imported' &&
    packet.importExecuted === false && packet.productionWrites === false && packet.uiRestorationAcceptance === false &&
    HASH.test(packet.sourceSnapshotSha256 || '') && HASH.test(packet.sourceCaseIndexSha256 || ''), 'fixture_boundary_invalid');
  requireThat(object(packet.selection) && packet.selection.wholeSourceSessionsRetained === true &&
    packet.selection.sessionLevelsTrimmed === false && packet.selection.presentationBakedIntoOverride === false,
    'whole_session_provenance_missing');
  equal(packet.selection.requiredFeatures, TARGETS, 'feature_scope_changed');
  requireThat(packet.selection.selectedCaseCount === 3 && packet.selection.globalMinimumContextCount === 3 &&
    Array.isArray(packet.cases) && packet.cases.length === 3, 'reviewed_three_case_scope_changed');
  exactKeys(packet.sourceRecords, Object.keys(TABLES), 'source_table_scope_changed');
  exactKeys(packet.retainedRecordCounts, Object.keys(TABLES), 'source_count_scope_changed');
  const tables = {}, allSourceIds = new Set();
  for (const [table, fields] of Object.entries(TABLES)) {
    const source = packet.sourceRecords[table]; exactKeys(source, ['rawRows', 'decodedJsonByRow'], 'source_table_shape_invalid');
    requireThat(Array.isArray(source.rawRows) && Array.isArray(source.decodedJsonByRow) && source.rawRows.length === source.decodedJsonByRow.length &&
      source.rawRows.length === packet.retainedRecordCounts[table] && source.rawRows.length <= 100, 'source_count_invalid');
    tables[table] = new Map();
    source.rawRows.forEach((row, index) => {
      exactKeys(row, [...COMMON, ...fields], 'source_column_scope_changed');
      requireThat(ID.test(row.id || '') && !tables[table].has(row.id), 'source_identity_invalid');
      allSourceIds.add(row.id); const decoded = source.decodedJsonByRow[index];
      exactKeys(decoded, JSON_FIELDS[table], 'decoded_field_scope_changed');
      const parsed = {};
      for (const field of JSON_FIELDS[table]) {
        const value = decoded[field]; requireThat(object(value), 'decoded_json_invalid');
        if (value.storage === 'json') {
          exactKeys(value, ['storage', 'value'], 'decoded_json_invalid');
          requireThat(typeof row[field] === 'string', 'raw_json_invalid');
          let actual; try { actual = JSON.parse(row[field]); } catch { throw new FixtureError('raw_json_invalid'); }
          equal(actual, value.value, 'raw_decoded_binding_mismatch'); parsed[field] = actual;
        } else {
          exactKeys(value, ['storage'], 'decoded_json_invalid');
          requireThat((value.storage === 'sql_null' && row[field] === null) || (value.storage === 'empty_text' && row[field] === ''), 'raw_decoded_binding_mismatch');
          parsed[field] = null;
        }
      }
      tables[table].set(row.id, { row, parsed });
    });
  }
  // This adapter deliberately cannot rewrite global ranks or reconstruct
  // archived common-clue history/narrative/reward/extra configuration.
  for (const table of ['game_level_definitions', 'game_narratives', 'game_rewards', 'game_reward_rules', 'game_extra_definitions']) {
    requireThat(tables[table].size === 0, 'dependency_needs_separate_reviewed_adapter');
  }
  const used = Object.fromEntries(Object.keys(TABLES).map(table => [table, new Set()]));
  const take = (table, id) => { const value = tables[table].get(id); requireThat(value, 'source_relation_unresolved'); used[table].add(id); return value; };
  const owned = (table, field, id) => [...tables[table].values()].filter(value => value.row[field] === id).sort((a, b) => a.row.position - b.row.position);
  const sourceSessions = new Set(), sourceQuestions = new Set(), caseKeys = new Set();
  const plans = packet.cases.map((entry, sourceCaseIndex) => {
    requireThat(object(entry) && /^ui-content-0[1-3]$/.test(entry.caseKey || '') && !caseKeys.has(entry.caseKey), 'source_case_key_invalid'); caseKeys.add(entry.caseKey);
    exactKeys(entry.sourceRefs, ['sessionId', 'sessionLevelId', 'questionId'], 'source_case_refs_invalid');
    const { sessionId, sessionLevelId, questionId } = entry.sourceRefs;
    requireThat(!sourceSessions.has(sessionId) && !sourceQuestions.has(questionId), 'reviewed_distinct_case_scope_changed');
    sourceSessions.add(sessionId); sourceQuestions.add(questionId);
    const session = take('game_sessions', sessionId), level = take('game_session_levels', sessionLevelId), question = take('game_questions', questionId);
    requireThat(session.row.minLevel === '' && session.row.maxLevel === '', 'rank_admission_requires_separate_adapter');
    requireThat(level.row.session === sessionId && level.row.question === questionId && level.row.position === 1 &&
      owned('game_session_levels', 'session', sessionId).length === 1 && entry.sourceSessionLevelCount === 1 && entry.questionNumber === 1,
      'source_whole_single_session_invalid');
    for (const content of [session, question]) requireThat(['draft', 'published', 'archived'].includes(content.row.status) &&
      typeof content.row.seriesKey === 'string' && content.row.seriesKey.length > 0 && Number.isSafeInteger(content.row.revision) && content.row.revision > 0, 'source_revision_invalid');
    equal(entry.sourceStatus, { session: session.row.status, question: question.row.status }, 'source_status_binding_mismatch');
    const answerKeys = owned('game_answer_keys', 'question', questionId), settings = owned('game_question_settings', 'question', questionId);
    requireThat(answerKeys.length === 1 && settings.length === 1, 'explicit_answer_settings_required');
    take('game_answer_keys', answerKeys[0].row.id); take('game_question_settings', settings[0].row.id);
    requireThat(answerKeys[0].row.normalizationVersion === 'nfkc-v1' && ['exact', 'contains_all'].includes(settings[0].row.answerMatchMode), 'answer_protocol_invalid');
    const answerValues = list(answerKeys[0].parsed.acceptedAnswers, 30).map(answer => text(answer, 4000, true));
    requireThat(answerValues.length > 0 && ['text', 'choice'].includes(question.row.kind), 'question_kind_or_answers_invalid');
    const questionBody = { kind: question.row.kind, title: text(question.row.title, 200, true), placeholder: text(question.row.placeholder, 500),
      content: blocks(question.parsed.content), options: options(question.parsed.options), acceptedAnswers: answerValues,
      fuzzyMatch: settings[0].row.answerMatchMode === 'contains_all', groupName: text(settings[0].row.groupName, 60, true) };
    requireThat(questionBody.kind !== 'choice' || (!questionBody.fuzzyMatch && questionBody.options.length >= 2 &&
      answerValues.every(answer => questionBody.options.some(option => option.key === answer))), 'choice_answers_invalid');
    const expectedQuestion = Object.fromEntries(['kind', 'title', 'placeholder', 'content', 'options'].map(key => [key, questionBody[key]]));
    equal(entry.expectedQuestion, expectedQuestion, 'expected_question_binding_mismatch');
    const base = presentation(session.parsed.presentation), override = presentation(level.parsed.presentationOverride);
    equal(entry.sessionPresentation, base, 'session_presentation_binding_mismatch'); equal(entry.levelPresentationOverride, override, 'override_binding_mismatch');
    const resolved = effective(base, override); equal(entry.expectedEffectivePresentation, resolved, 'effective_presentation_binding_mismatch');
    equal([...entry.covers].sort(), features(expectedQuestion, base, override), 'case_feature_binding_mismatch');
    const commonClues = owned('game_question_clues', 'question', questionId).map((clue, index) => {
      take('game_question_clues', clue.row.id); requireThat(clue.row.status === 'active' && clue.row.position === index &&
        ['text', 'image', 'video', 'link'].includes(clue.row.kind), 'common_clue_history_or_position_not_supported');
      const content = clueContent(clue.parsed.content);
      requireThat(clue.row.kind !== 'text' || content.text.length > 0, 'common_clue_text_missing');
      requireThat(clue.row.kind !== 'image' || content.imageUrls.length > 0, 'common_clue_images_missing');
      requireThat(!['video', 'link'].includes(clue.row.kind) || content.url.length > 0, 'common_clue_url_missing');
      return { sourceId: clue.row.id, body: { position: index, kind: clue.row.kind, content, autoPlay: flag(clue.row.autoPlay) } };
    });
    const clues = owned('game_clues', 'session', sessionId).map((clue, index) => {
      take('game_clues', clue.row.id);
      requireThat(clue.row.position === index && (!clue.row.sessionLevel || clue.row.sessionLevel === sessionLevelId) &&
        clue.row.narrative === '' && ['text', 'image', 'video', 'link'].includes(clue.row.kind) &&
        ['start', 'level_completed', 'session_completed', 'manual'].includes(clue.row.trigger) &&
        (clue.row.trigger !== 'level_completed' || clue.row.sessionLevel === sessionLevelId), 'session_clue_relation_or_kind_not_supported');
      return { sourceId: clue.row.id, sourceLevelId: clue.row.sessionLevel, body: { ...(clue.row.sessionLevel ? { levelIndex: 0 } : {}),
        trigger: clue.row.trigger, kind: clue.row.kind, content: clueContent(clue.parsed.content), narrative: '', autoPlay: flag(clue.row.autoPlay) } };
    });
    let completionTarget = session.parsed.completionTarget;
    if (completionTarget !== null) { exactKeys(completionTarget, ['kind', 'url'], 'completion_target_not_supported');
      requireThat(completionTarget.kind === 'link' && url(completionTarget.url).length > 0, 'completion_target_not_supported'); }
    const levelBody = { question: '', xp: integer(level.row.xp, 0, 1000000, 'source_xp_invalid'), autoNext: flag(level.row.autoNext),
      penaltyPolicy: penalties(level.parsed.penaltyPolicy), presentationOverride: override };
    const sessionBody = { title: text(session.row.title, 200, true), description: text(session.row.description, 2000),
      minLevel: '', maxLevel: '', presentation: base, completionTarget, levels: [levelBody], clues: clues.map(clue => clue.body), rewardRules: [] };
    return { sourceCaseIndex, sourceRefs: entry.sourceRefs, resolved, question, session, level, answerKey: answerKeys[0], settings: settings[0],
      questionBody, expectedQuestion, commonClues, clues, sessionBody, covers: entry.covers };
  });
  for (const table of Object.keys(TABLES)) requireThat(used[table].size === tables[table].size, 'unconsumed_source_records');
  requireThat(TARGETS.every(target => plans.some(plan => plan.covers.includes(target))), 'feature_cover_incomplete');
  requireThat(Object.values(packet.retainedRecordCounts).reduce((sum, count) => sum + count, 0) === 19, 'reviewed_nineteen_record_scope_changed');
  return { plans, allSourceIds, retainedRecordCounts: packet.retainedRecordCounts };
}

/** Only an explicit command reads the owned private JSON; URLs are never fetched. */
export async function readUiContentFixture(input, root) {
  exactKeys(input, ['fixtureFile', 'expectedSha256', 'label'], 'ui_control_fields_invalid');
  requireThat(typeof input.fixtureFile === 'string' && HASH.test(input.expectedSha256 || '') && /^[a-z][a-z0-9-]{0,23}$/.test(input.label || ''), 'ui_control_input_invalid');
  const base = path.join(root, 'artifacts/private/ui-reference');
  const filename = path.resolve(root, input.fixtureFile);
  requireThat(filename.startsWith(base + path.sep) && path.basename(filename) === 'fixture.json', 'fixture_path_outside_private_reference');
  const identities = [];
  for (let current = filename; ; current = path.dirname(current)) {
    const info = await lstat(current);
    requireThat(!info.isSymbolicLink() && (current === filename ? info.isFile() : info.isDirectory()), 'fixture_path_symlink_or_type');
    if (current === filename || current === path.join(root, 'artifacts/private') || current.startsWith(path.join(root, 'artifacts/private') + path.sep)) {
      requireThat(info.uid === process.getuid() && (info.mode & 0o777) === (current === filename ? 0o600 : 0o700), 'fixture_not_owned_private');
    }
    identities.push({ filename: current, dev: info.dev, ino: info.ino });
    if (current === path.parse(current).root) break;
  }
  const handle = await open(filename, constants.O_RDONLY | constants.O_NOFOLLOW);
  let bytes;
  try {
    const info = await handle.stat(); requireThat(info.dev === identities[0].dev && info.ino === identities[0].ino &&
      info.uid === process.getuid() && (info.mode & 0o777) === 0o600 && info.size > 0 && info.size <= 2500000, 'fixture_changed_or_too_large');
    bytes = await handle.readFile();
    const after = await handle.stat(); requireThat(after.size === info.size && after.mtimeMs === info.mtimeMs && after.ctimeMs === info.ctimeMs, 'fixture_changed_while_reading');
  } finally { await handle.close(); }
  for (const identity of identities) { const info = await lstat(identity.filename); requireThat(!info.isSymbolicLink() && info.dev === identity.dev && info.ino === identity.ino, 'fixture_path_changed_while_reading'); }
  requireThat(hash(bytes) === input.expectedSha256, 'fixture_hash_mismatch');
  let packet; try { packet = JSON.parse(bytes.toString('utf8')); } catch { throw new FixtureError('fixture_json_invalid'); }
  return { packet, ...validateUiContentFixture(packet), filename };
}

/** Runner calls this only while holding its existing caseCreationBusy guard. */
export async function createUiContentCases(input, { root, state, save, admin, api, secret, superToken }) {
  requireThat(state?.mode === 'real isolated PocketBase' && /^http:\/\/127\.0\.0\.1:[1-9][0-9]{3,4}$/.test(state.backendBase || '') &&
    state.gameplay?.cases && typeof superToken === 'string' && superToken.length > 0, 'disposable_runner_boundary_invalid');
  const fixture = await readUiContentFixture(input, root);
  requireThat(Object.keys(state.gameplay.cases).length + fixture.plans.length <= 24, 'gameplay_case_limit');
  if (state.uiContent !== undefined) requireThat(state.uiContent.schema === 1 && object(state.uiContent.imports), 'ui_import_registry_invalid');
  const imports = state.uiContent?.imports || {};
  requireThat(!Object.values(imports).some(value => value.fixtureSha256 === input.expectedSha256), 'fixture_already_attempted_do_not_replay');
  const baseline = await api('/api/questions/v1/admin/catalog');
  requireThat(Array.isArray(baseline.ranks) && baseline.ranks.length > 0 && ['players', 'questions', 'sessions'].every(key => Array.isArray(baseline[key])), 'admin_catalog_incomplete');
  const targetIds = new Set(Object.values(baseline).filter(Array.isArray).flat().map(row => row.id).filter(Boolean));
  const freshId = id => { requireThat(ID.test(id || '') && !fixture.allSourceIds.has(id) && !targetIds.has(id), 'target_identity_not_fresh'); targetIds.add(id); return id; };
  const importId = randomBytes(8).toString('hex');
  requireThat(!Object.hasOwn(imports, importId), 'synthetic_import_identity_collision');
  const record = { importId, fixture: 'ui-real-content', fixtureSha256: input.expectedSha256, fixtureFile: path.relative(root, fixture.filename),
    sourceSnapshotSha256: fixture.packet.sourceSnapshotSha256, sourceCaseIndexSha256: fixture.packet.sourceCaseIndexSha256,
    status: 'creating', caseIds: [], sourceTargetMap: Object.fromEntries(Object.keys(TABLES).map(table => [table, {}])),
    metadataPolicy: 'fresh target identity/series/revision/timestamps/published status; original provenance stays in the bound private fixture',
    sourceRecordCount: 19, verifiedRecordCount: 0, gameplayStarted: false, gameplayAnswered: false };
  state.uiContent = { schema: 1, imports: { ...imports, [importId]: record } };
  const values = fixture.plans.map((plan, index) => {
    const caseId = randomBytes(8).toString('hex');
    requireThat(!Object.hasOwn(state.gameplay.cases, caseId), 'synthetic_case_identity_collision');
    const value = { caseId, label: input.label + '-' + String(index + 1).padStart(2, '0'), fixture: 'ui-real-content',
      fixtureLevelKinds: [plan.questionBody.kind], setupStatus: 'creating', ordinaryLoginPrepared: false,
      account: 'hm_' + randomBytes(6).toString('hex'), initialPassword: secret(), newPassword: secret(), playerId: '', assignmentId: '', assignments: {},
      uiContentImportId: importId, sourceContent: { fixtureSha256: input.expectedSha256, sourceCaseIndex: index, effectiveHideTitle: plan.resolved.hideTitle === true } };
    state.gameplay.cases[caseId] = value; record.caseIds.push(caseId); return value;
  });
  const mapped = (table, sourceId, targetId) => { requireThat(!Object.hasOwn(record.sourceTargetMap[table], sourceId), 'source_identity_mapped_twice'); record.sourceTargetMap[table][sourceId] = freshId(targetId); return targetId; };
  const rows = async (table, field, owner) => {
    requireThat(Object.hasOwn(TABLES, table) && ['question', 'session'].includes(field) && ID.test(owner), 'readback_route_invalid');
    const data = await api('/api/collections/' + table + '/records?perPage=100&filter=' + encodeURIComponent(field + '="' + owner + '"'), undefined, superToken);
    requireThat(Array.isArray(data.items) && data.totalItems === data.items.length && data.items.every(row => row[field] === owner), 'owned_readback_incomplete'); return data.items;
  };
  const verifyFields = (row, expected) => { for (const [field, value] of Object.entries(expected)) equal(row[field], value, 'target_content_readback_mismatch'); };
  try {
    await save(state);
    for (const [index, plan] of fixture.plans.entries()) {
      const value = values[index]; value.setupStage = 'question';
      const question = await admin('questions', plan.questionBody);
      const questionId = mapped('game_questions', plan.question.row.id, question.id); await save(state);
      const [keys, settings] = await Promise.all([rows('game_answer_keys', 'question', questionId), rows('game_question_settings', 'question', questionId)]);
      requireThat(keys.length === 1 && settings.length === 1, 'question_support_records_missing');
      verifyFields(keys[0], { question: questionId, acceptedAnswers: plan.questionBody.acceptedAnswers, normalizationVersion: 'nfkc-v1' });
      verifyFields(settings[0], { question: questionId, answerMatchMode: plan.settings.row.answerMatchMode, groupName: plan.questionBody.groupName });
      mapped('game_answer_keys', plan.answerKey.row.id, keys[0].id); mapped('game_question_settings', plan.settings.row.id, settings[0].id);
      const clueRoute = '/api/questions/v1/admin/questions/' + questionId + '/clues';
      const before = await api(clueRoute); requireThat(Array.isArray(before.items) && before.items.length === 0 && HASH.test(before.version || ''), 'new_common_clue_set_not_empty');
      if (plan.commonClues.length) {
        const after = await api(clueRoute, { requestId: randomUUID(), reason: '独立真实内容视觉对照夹具', expectedVersion: before.version,
          clues: plan.commonClues.map(clue => clue.body) }, undefined, 'PATCH');
        requireThat(Array.isArray(after.items) && after.items.length === plan.commonClues.length && HASH.test(after.version || ''), 'common_clue_readback_incomplete');
        plan.commonClues.forEach((clue, position) => {
          const row = after.items[position]; verifyFields(row, { ...clue.body, question: questionId, status: 'active' });
          mapped('game_question_clues', clue.sourceId, row.id);
        });
      }
      await admin('questions/' + questionId + '/publish'); value.setupStage = 'session'; await save(state);
      const sessionBody = { ...plan.sessionBody, levels: [{ ...plan.sessionBody.levels[0], question: questionId }] };
      const session = await admin('sessions', sessionBody);
      const sessionId = mapped('game_sessions', plan.session.row.id, session.id); await save(state);
      const [levels, clues] = await Promise.all([rows('game_session_levels', 'session', sessionId), rows('game_clues', 'session', sessionId)]);
      requireThat(levels.length === 1 && clues.length === plan.clues.length, 'whole_session_readback_incomplete');
      verifyFields(levels[0], { ...sessionBody.levels[0], position: 1, session: sessionId });
      const levelId = mapped('game_session_levels', plan.level.row.id, levels[0].id);
      const ordered = clues.sort((a, b) => a.position - b.position);
      plan.clues.forEach((clue, position) => {
        const { levelIndex: _unused, ...body } = clue.body;
        verifyFields(ordered[position], { ...body, position, session: sessionId, sessionLevel: clue.sourceLevelId ? levelId : '' });
        mapped('game_clues', clue.sourceId, ordered[position].id);
      });
      await admin('sessions/' + sessionId + '/publish'); value.setupStage = 'player'; await save(state);
      const player = await admin('players', { account: value.account, displayName: '视觉对照旅行者', password: value.initialPassword });
      value.playerId = freshId(player.id); await save(state);
      const assigned = await admin('assignments', { sessionId, target: 'selected', playerIds: [value.playerId], order: 0 });
      requireThat(Array.isArray(assigned.results) && assigned.results.length === 1 && assigned.results[0].playerId === value.playerId &&
        assigned.results[0].status === 'assigned', 'dedicated_assignment_not_created');
      value.assignmentId = freshId(assigned.results[0].assignmentId); value.assignments = { ready: { assignmentId: value.assignmentId, sessionId } };
      value.setupStage = 'ordinary-login'; await save(state);
      const authenticated = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.initialPassword }, '');
      requireThat(typeof authenticated.token === 'string' && authenticated.token.length > 0 && authenticated.record?.id === value.playerId, 'initial_login_identity_mismatch');
      const changed = await api('/api/questions/v1/me/change-password', { oldPassword: value.initialPassword, password: value.newPassword, passwordConfirm: value.newPassword }, authenticated.token);
      requireThat(changed.player?.id === value.playerId && changed.player.mustChangePassword === false, 'ordinary_login_preparation_unconfirmed');
      const loggedIn = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.newPassword }, '');
      requireThat(typeof loggedIn.token === 'string' && loggedIn.record?.id === value.playerId, 'ordinary_login_identity_mismatch');
      const me = await api('/api/questions/v1/me', undefined, loggedIn.token);
      requireThat(me.id === value.playerId && me.account === value.account && me.mustChangePassword === false && me.totalXp === 0, 'ordinary_login_authority_invalid');
      const detail = await api('/api/questions/v1/admin/assignments/' + value.assignmentId);
      verifyFields(detail, { id: value.assignmentId, player: value.playerId, session: sessionId, status: 'assigned', sessionStatus: 'published',
        title: plan.sessionBody.title, description: plan.sessionBody.description, minLevel: 1, maxLevel: null,
        startedAt: '', completedAt: '', completedLevels: 0, totalLevels: 1, currentIndex: 0, presentation: plan.sessionBody.presentation });
      requireThat(Array.isArray(detail.levels) && detail.levels.length === 1, 'assignment_level_readback_incomplete');
      verifyFields(detail.levels[0], { id: levelId, position: 1, xp: plan.level.row.xp, autoNext: flag(plan.level.row.autoNext),
        presentationOverride: plan.sessionBody.levels[0].presentationOverride, completedAt: '', wrongCount: 0, locked: false });
      const { id: actualQuestionId, ...actualQuestion } = detail.levels[0].question || {};
      requireThat(actualQuestionId === questionId, 'assignment_question_identity_mismatch'); equal(actualQuestion, plan.expectedQuestion, 'assignment_question_content_mismatch');
      equal(effective(detail.presentation, detail.levels[0].presentationOverride), plan.resolved, 'effective_presentation_readback_mismatch');
      const listResult = await api('/api/questions/v1/assignments', undefined, loggedIn.token);
      requireThat(Array.isArray(listResult.items) && listResult.items.length === 1 && listResult.items[0].id === value.assignmentId &&
        listResult.items[0].player === value.playerId && listResult.items[0].session === sessionId, 'native_list_identity_mismatch');
      value.ordinaryLoginPrepared = true; value.setupStage = 'verified-not-started'; await save(state);
    }
    const after = await api('/api/questions/v1/admin/catalog');
    equal(after.ranks, baseline.ranks, 'existing_global_ranks_changed');
    for (const type of ['questions', 'sessions']) {
      requireThat(Array.isArray(after[type]), 'final_catalog_incomplete');
      for (const old of baseline[type]) equal(after[type].find(row => row.id === old.id), old, 'existing_seed_content_changed');
    }
    for (const [index, plan] of fixture.plans.entries()) {
      const sessionId = values[index].assignments.ready.sessionId, questionId = record.sourceTargetMap.game_questions[plan.question.row.id];
      const actualSession = after.sessions.find(row => row.id === sessionId), actualQuestion = after.questions.find(row => row.id === questionId);
      requireThat(actualSession && actualQuestion, 'final_owned_content_missing');
      verifyFields(actualSession, { title: plan.sessionBody.title, description: plan.sessionBody.description, status: 'published', minLevel: '', maxLevel: '',
        presentation: plan.sessionBody.presentation, completionTarget: plan.sessionBody.completionTarget, rewardRules: [] });
      verifyFields(actualQuestion, { ...plan.questionBody, status: 'published', commonClueCount: plan.commonClues.length });
    }
    record.verifiedRecordCount = Object.values(record.sourceTargetMap).reduce((sum, mapping) => sum + Object.keys(mapping).length, 0);
    requireThat(record.verifiedRecordCount === 19, 'source_record_mapping_incomplete');
    record.status = 'ready'; record.verifiedBy = 'official-admin-and-player-readbacks';
    for (const value of values) value.setupStatus = 'ready';
    await save(state);
    return { created: true, importId, fixture: 'ui-real-content', caseIds: record.caseIds, caseCount: values.length,
      sourceRecordCount: 19, verifiedRecordCount: record.verifiedRecordCount, ordinaryLoginPrepared: true,
      gameplayStarted: false, gameplayAnswered: false, existingFixturesReset: false };
  } catch (error) {
    record.status = 'incomplete'; record.failureCode = error instanceof FixtureError ? error.code : 'official_setup_failed';
    for (const value of values) value.setupStatus = 'incomplete';
    await save(state);
    throw new FixtureError('ui_content_import_incomplete');
  }
}
