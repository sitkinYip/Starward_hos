/** Explicit, isolated synthetic image-failure derivation. Default/help is inert.
 * prepare reads only reviewed private content/assets and writes one fresh private
 * spec. It never requests the candidate URL. The runner alone calls the exported
 * creator with its in-memory official admin/player API closures.
 */
import { constants } from 'node:fs';
import { chmod, lstat, mkdir, open } from 'node:fs/promises';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { readUiContentFixture } from './ui-content-case.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const HASH = /^[a-f0-9]{64}$/;
const ID = /^[a-z0-9]{15}$/;
const OVERRIDE = 'question.content[0].imageUrl';
const sha = value => createHash('sha256').update(value).digest('hex');
class DerivationError extends Error { constructor(code) { super(code); this.code = code; } }
function requireThat(value, code) { if (!value) throw new DerivationError(code); }
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
function exactKeys(value, keys, code) { requireThat(object(value) && Object.keys(value).length === keys.length && Object.keys(value).every(key => keys.includes(key)), code); }
const canonical = value => Array.isArray(value) ? '[' + value.map(canonical).join(',') + ']' : object(value) ?
  '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}' : JSON.stringify(value);
function equal(actual, expected, code) { requireThat(canonical(actual) === canonical(expected), code); }
function verifyFields(row, fields) { requireThat(object(row), 'target_readback_missing'); for (const [key, value] of Object.entries(fields)) equal(row[key], value, 'target_content_readback_mismatch'); }

async function privateBytes(filename, expectedSha256, root) {
  requireThat(typeof filename === 'string' && HASH.test(expectedSha256 || ''), 'private_input_invalid');
  const absolute = path.resolve(root, filename), base = path.join(root, 'artifacts/private/ui-reference');
  requireThat(absolute.startsWith(base + path.sep), 'private_input_outside_ui_reference');
  const checked = [];
  for (let current = absolute; ; current = path.dirname(current)) {
    const info = await lstat(current);
    requireThat(!info.isSymbolicLink() && (current === absolute ? info.isFile() : info.isDirectory()), 'private_path_symlink_or_type');
    if (current === absolute || current === path.join(root, 'artifacts/private') || current.startsWith(path.join(root, 'artifacts/private') + path.sep)) {
      requireThat(info.uid === process.getuid() && (info.mode & 0o777) === (current === absolute ? 0o600 : 0o700), 'private_path_mode_or_owner');
    }
    checked.push({ path: current, dev: info.dev, ino: info.ino });
    if (current === path.parse(current).root) break;
  }
  const handle = await open(absolute, constants.O_RDONLY | constants.O_NOFOLLOW);
  let bytes;
  try {
    const before = await handle.stat();
    requireThat(before.dev === checked[0].dev && before.ino === checked[0].ino && before.size > 0 && before.size <= 5 * 1024 * 1024 &&
      before.uid === process.getuid() && (before.mode & 0o777) === 0o600, 'private_input_changed_or_too_large');
    bytes = await handle.readFile();
    const after = await handle.stat(); requireThat(before.size === after.size && before.mtimeMs === after.mtimeMs && before.ctimeMs === after.ctimeMs, 'private_input_changed');
  } finally { await handle.close(); }
  for (const item of checked) { const info = await lstat(item.path); requireThat(!info.isSymbolicLink() && info.dev === item.dev && info.ino === item.ino, 'private_path_changed'); }
  requireThat(sha(bytes) === expectedSha256, 'private_input_hash_mismatch');
  return { filename: absolute, bytes };
}
async function privateJson(filename, expectedSha256, root) {
  const result = await privateBytes(filename, expectedSha256, root);
  let value; try { value = JSON.parse(result.bytes.toString('utf8')); } catch { throw new DerivationError('private_json_invalid'); }
  requireThat(object(value), 'private_json_not_object'); return { ...result, value };
}
function originalImage(plan) {
  requireThat(plan.questionBody.kind === 'text' && plan.questionBody.content.length > 0 &&
    plan.questionBody.content[0].imageUrl.length > 0 && plan.questionBody.content[0].imageUrls.length === 0 &&
    plan.questionBody.content[0].videoUrl === '', 'reviewed_base_image_scope_changed');
  const original = plan.questionBody.content[0].imageUrl;
  let parsed; try { parsed = new URL(original); } catch { throw new DerivationError('registered_image_url_invalid'); }
  requireThat(parsed.protocol === 'https:' && !parsed.username && !parsed.password && !parsed.hash &&
    (!parsed.port || parsed.port === '443') && /^[a-z0-9.-]+$/i.test(parsed.hostname) && parsed.hostname.includes('.') &&
    !/^[0-9.]+$/.test(parsed.hostname) && !/(^|\.)(localhost|local|internal|lan|home|test|invalid)$/.test(parsed.hostname) &&
    !/[\s\\\u0000-\u001f\u007f]/.test(original), 'registered_image_not_public_https');
  requireThat(parsed.pathname && !parsed.pathname.endsWith('/'), 'registered_image_directory_invalid');
  return { original, parsed };
}
function missingCandidate(plan, nonce) {
  requireThat(/^[a-f0-9]{32}$/.test(nonce || ''), 'missing_candidate_nonce_invalid');
  const { parsed } = originalImage(plan), target = new URL(parsed.href);
  target.pathname = parsed.pathname.slice(0, parsed.pathname.lastIndexOf('/') + 1) + 'starward-ui-missing-' + nonce + '.png';
  target.search = ''; target.hash = '';
  requireThat(target.origin === parsed.origin && path.posix.dirname(target.pathname) === path.posix.dirname(parsed.pathname), 'missing_candidate_directory_changed');
  return target.href;
}
function magicMime(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  throw new DerivationError('registered_image_magic_invalid');
}
async function registration(manifestFile, manifestSha256, fixtureSha256, plan, root) {
  const manifest = await privateJson(manifestFile, manifestSha256, root), value = manifest.value;
  requireThat(value.status === 'reference_image_bytes_captured' && value.fixtureSha256 === fixtureSha256 &&
    value.referer === 'https://sitkin.top/' && value.nativeLoadVerified === false && Array.isArray(value.assets), 'registered_image_manifest_invalid');
  const matches = value.assets.filter(asset => asset.url === originalImage(plan).original);
  requireThat(matches.length === 1, 'registered_source_image_missing_or_duplicate');
  const asset = matches[0];
  requireThat(asset.authorizationSent === false && HASH.test(asset.sha256 || '') && Number.isSafeInteger(asset.bytes) && asset.bytes > 0 &&
    asset.bytes <= 5 * 1024 * 1024 && ['image/jpeg', 'image/png'].includes(asset.detectedMime), 'registered_source_image_invalid');
  const image = await privateBytes(asset.file, asset.sha256, root);
  requireThat(image.bytes.length === asset.bytes && magicMime(image.bytes) === asset.detectedMime, 'registered_source_image_bytes_invalid');
  return { reference: { manifestFile: path.relative(root, manifest.filename), manifestSha256,
    assetSha256: asset.sha256, detectedMime: asset.detectedMime, bytes: asset.bytes },
    manifest, image };
}

/** Pure derivation description. No source rows or input packet are mutated. */
export function describeUiImageFailure(base, fixtureSha256, reference, nonce) {
  const plan = base.plans[0];
  return { formatVersion: 1, fixture: 'ui-image-failure', status: 'prepared_offline_unverified_missing_candidate',
    baseFixtureSha256: fixtureSha256, sourceSnapshotSha256: base.packet.sourceSnapshotSha256, sourceCaseIndex: 0,
    overridePath: OVERRIDE, originalUrlSha256: sha(originalImage(plan).original), missingUrl: missingCandidate(plan, nonce), nonce,
    referenceImage: reference, expectedHttpStatus: 404, retryPolicy: 'same-url-explicit-get-only', networkVerified: false, importExecuted: false };
}

async function inputs(input, root) {
  exactKeys(input, ['fixtureFile', 'expectedSha256', 'derivationFile', 'expectedDerivationSha256', 'label'], 'image_failure_control_fields_invalid');
  requireThat(/^[a-z][a-z0-9-]{0,23}$/.test(input.label || ''), 'image_failure_label_invalid');
  const base = await readUiContentFixture({ fixtureFile: input.fixtureFile, expectedSha256: input.expectedSha256, label: input.label }, root);
  const derivation = await privateJson(input.derivationFile, input.expectedDerivationSha256, root), spec = derivation.value;
  exactKeys(spec, ['formatVersion', 'fixture', 'status', 'baseFixtureSha256', 'sourceSnapshotSha256', 'sourceCaseIndex', 'overridePath',
    'originalUrlSha256', 'missingUrl', 'nonce', 'referenceImage', 'expectedHttpStatus', 'retryPolicy', 'networkVerified', 'importExecuted'], 'derivation_scope_changed');
  exactKeys(spec.referenceImage, ['manifestFile', 'manifestSha256', 'assetSha256', 'detectedMime', 'bytes'], 'derivation_reference_scope_changed');
  const registered = await registration(spec.referenceImage.manifestFile, spec.referenceImage.manifestSha256, input.expectedSha256, base.plans[0], root);
  equal(spec, describeUiImageFailure(base, input.expectedSha256, registered.reference, spec.nonce), 'derivation_not_exact_reviewed_override');
  const questionBody = structuredClone(base.plans[0].questionBody);
  questionBody.content[0].imageUrl = spec.missingUrl;
  const restored = structuredClone(questionBody); restored.content[0].imageUrl = base.plans[0].questionBody.content[0].imageUrl;
  equal(restored, base.plans[0].questionBody, 'derivation_changed_other_question_fields');
  return { base, derivation, registered, questionBody };
}

/** Only the new runner route can invoke writes, under caseCreationBusy. */
export async function createUiImageFailureCase(input, { root, state, save, admin, api, secret, superToken }) {
  requireThat(state?.mode === 'real isolated PocketBase' && /^http:\/\/127\.0\.0\.1:[1-9][0-9]{3,4}$/.test(state.backendBase || '') &&
    object(state.gameplay?.cases) && typeof superToken === 'string' && superToken.length > 0, 'disposable_runner_boundary_invalid');
  const prepared = await inputs(input, root), plan = prepared.base.plans[0], spec = prepared.derivation.value;
  requireThat(Object.keys(state.gameplay.cases).length < 24, 'gameplay_case_limit');
  if (state.uiImageFailures !== undefined) requireThat(state.uiImageFailures.schema === 1 && object(state.uiImageFailures.imports), 'image_failure_registry_invalid');
  const imports = state.uiImageFailures?.imports || {};
  const candidateIdentitySha256 = sha(canonical({ sourceSnapshotSha256: spec.sourceSnapshotSha256, sourceCaseIndex: 0,
    overridePath: OVERRIDE, originalUrlSha256: spec.originalUrlSha256, missingUrlSha256: sha(spec.missingUrl) }));
  requireThat(!Object.values(imports).some(value => value.derivationSha256 === input.expectedDerivationSha256 ||
    value.candidateIdentitySha256 === candidateIdentitySha256), 'derivation_already_attempted_do_not_replay');
  const baseline = await api('/api/questions/v1/admin/catalog');
  requireThat(Array.isArray(baseline.ranks) && baseline.ranks.length > 0 && ['questions', 'sessions', 'players'].every(key => Array.isArray(baseline[key])), 'admin_catalog_incomplete');
  const previousCases = structuredClone(state.gameplay.cases), previousContentRegistry = structuredClone(state.uiContent);
  const targetIds = new Set(Object.values(baseline).filter(Array.isArray).flat().map(row => row.id).filter(Boolean));
  const fresh = id => { requireThat(ID.test(id || '') && !targetIds.has(id) && !prepared.base.allSourceIds.has(id), 'target_identity_not_fresh'); targetIds.add(id); return id; };
  const importId = randomBytes(8).toString('hex'), caseId = randomBytes(8).toString('hex');
  requireThat(!Object.hasOwn(imports, importId) && !Object.hasOwn(state.gameplay.cases, caseId), 'synthetic_identity_collision');
  const tables = ['game_questions', 'game_answer_keys', 'game_question_settings', 'game_question_clues', 'game_sessions', 'game_session_levels', 'game_clues'];
  const record = { importId, fixture: 'ui-image-failure', status: 'creating', caseId, baseFixtureSha256: input.expectedSha256,
    derivationFile: path.relative(root, prepared.derivation.filename), derivationSha256: input.expectedDerivationSha256, candidateIdentitySha256,
    sourceSnapshotSha256: prepared.base.packet.sourceSnapshotSha256, sourceCaseIndex: 0, syntheticDerivation: true,
    sourceRowsRewritten: false, overridePath: OVERRIDE, originalImageUrlSha256: spec.originalUrlSha256, missingImageUrlSha256: sha(spec.missingUrl),
    referenceImageSha256: spec.referenceImage.assetSha256, expectedImageHttpStatus: 404, observedImageHttpStatus: null,
    imageFailureVerified: false, sourceTargetMap: Object.fromEntries(tables.map(table => [table, {}])),
    metadataPolicy: 'fresh isolated identities/series/revision/timestamps/published status; one explicit synthetic URL override',
    gameplayStarted: false, gameplayAnswered: false };
  const value = { caseId, label: input.label, fixture: 'ui-image-failure', fixtureLevelKinds: ['text'], setupStatus: 'creating',
    ordinaryLoginPrepared: false, account: 'hm_' + randomBytes(6).toString('hex'), initialPassword: secret(), newPassword: secret(),
    playerId: '', assignmentId: '', assignments: {}, uiImageFailureImportId: importId,
    sourceContent: { baseFixtureSha256: input.expectedSha256, sourceCaseIndex: 0, derivationSha256: input.expectedDerivationSha256,
      overridePath: OVERRIDE, originalImageUrlSha256: spec.originalUrlSha256, missingImageUrlSha256: sha(spec.missingUrl) } };
  state.uiImageFailures = { schema: 1, imports: { ...imports, [importId]: record } }; state.gameplay.cases[caseId] = value;
  const mapped = (table, sourceId, targetId) => { requireThat(!Object.hasOwn(record.sourceTargetMap[table], sourceId), 'source_identity_mapped_twice');
    record.sourceTargetMap[table][sourceId] = fresh(targetId); return targetId; };
  const rows = async (table, field, owner) => {
    requireThat(tables.includes(table) && ['question', 'session'].includes(field) && ID.test(owner), 'readback_route_invalid');
    const data = await api('/api/collections/' + table + '/records?perPage=100&filter=' + encodeURIComponent(field + '="' + owner + '"'), undefined, superToken);
    requireThat(Array.isArray(data.items) && data.totalItems === data.items.length && data.items.every(row => row[field] === owner), 'owned_readback_incomplete'); return data.items;
  };
  try {
    await save(state); value.setupStage = 'question';
    const questionId = mapped('game_questions', plan.question.row.id, (await admin('questions', prepared.questionBody)).id); await save(state);
    const [keys, settings] = await Promise.all([rows('game_answer_keys', 'question', questionId), rows('game_question_settings', 'question', questionId)]);
    requireThat(keys.length === 1 && settings.length === 1, 'question_support_records_missing');
    verifyFields(keys[0], { question: questionId, acceptedAnswers: prepared.questionBody.acceptedAnswers, normalizationVersion: 'nfkc-v1' });
    verifyFields(settings[0], { question: questionId, answerMatchMode: plan.settings.row.answerMatchMode, groupName: prepared.questionBody.groupName });
    mapped('game_answer_keys', plan.answerKey.row.id, keys[0].id); mapped('game_question_settings', plan.settings.row.id, settings[0].id);
    const clueRoute = '/api/questions/v1/admin/questions/' + questionId + '/clues', before = await api(clueRoute);
    requireThat(Array.isArray(before.items) && before.items.length === 0 && HASH.test(before.version || ''), 'new_common_clues_not_empty');
    if (plan.commonClues.length) {
      const after = await api(clueRoute, { requestId: randomUUID(), reason: '合成图片失败重试夹具', expectedVersion: before.version,
        clues: plan.commonClues.map(clue => clue.body) }, undefined, 'PATCH');
      requireThat(Array.isArray(after.items) && after.items.length === plan.commonClues.length && HASH.test(after.version || ''), 'common_clue_readback_incomplete');
      plan.commonClues.forEach((clue, position) => { verifyFields(after.items[position], { ...clue.body, question: questionId, status: 'active' }); mapped('game_question_clues', clue.sourceId, after.items[position].id); });
    }
    await admin('questions/' + questionId + '/publish'); value.setupStage = 'session'; await save(state);
    const sessionBody = { ...plan.sessionBody, levels: [{ ...plan.sessionBody.levels[0], question: questionId }] };
    const sessionId = mapped('game_sessions', plan.session.row.id, (await admin('sessions', sessionBody)).id); await save(state);
    const [levels, clues] = await Promise.all([rows('game_session_levels', 'session', sessionId), rows('game_clues', 'session', sessionId)]);
    requireThat(levels.length === 1 && clues.length === plan.clues.length, 'whole_session_readback_incomplete');
    verifyFields(levels[0], { ...sessionBody.levels[0], position: 1, session: sessionId });
    const levelId = mapped('game_session_levels', plan.level.row.id, levels[0].id); clues.sort((a, b) => a.position - b.position);
    plan.clues.forEach((clue, position) => { const { levelIndex: _index, ...body } = clue.body;
      verifyFields(clues[position], { ...body, session: sessionId, position, sessionLevel: clue.sourceLevelId ? levelId : '' }); mapped('game_clues', clue.sourceId, clues[position].id); });
    await admin('sessions/' + sessionId + '/publish'); value.setupStage = 'player'; await save(state);
    value.playerId = fresh((await admin('players', { account: value.account, displayName: '图片故障验证旅行者', password: value.initialPassword })).id); await save(state);
    const assigned = await admin('assignments', { sessionId, target: 'selected', playerIds: [value.playerId], order: 0 });
    requireThat(Array.isArray(assigned.results) && assigned.results.length === 1 && assigned.results[0].playerId === value.playerId && assigned.results[0].status === 'assigned', 'dedicated_assignment_not_created');
    value.assignmentId = fresh(assigned.results[0].assignmentId); value.assignments = { ready: { assignmentId: value.assignmentId, sessionId } }; value.setupStage = 'ordinary-login'; await save(state);
    const initial = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.initialPassword }, '');
    requireThat(typeof initial.token === 'string' && initial.token.length > 0 && initial.record?.id === value.playerId, 'initial_login_identity_mismatch');
    const changed = await api('/api/questions/v1/me/change-password', { oldPassword: value.initialPassword, password: value.newPassword, passwordConfirm: value.newPassword }, initial.token);
    requireThat(changed.player?.id === value.playerId && changed.player.mustChangePassword === false, 'ordinary_login_preparation_unconfirmed');
    const loggedIn = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.newPassword }, '');
    requireThat(typeof loggedIn.token === 'string' && loggedIn.token.length > 0 && loggedIn.record?.id === value.playerId, 'ordinary_login_identity_mismatch');
    const me = await api('/api/questions/v1/me', undefined, loggedIn.token);
    verifyFields(me, { id: value.playerId, account: value.account, mustChangePassword: false, totalXp: 0 });
    const detail = await api('/api/questions/v1/admin/assignments/' + value.assignmentId);
    verifyFields(detail, { id: value.assignmentId, player: value.playerId, session: sessionId, status: 'assigned', sessionStatus: 'published',
      title: plan.sessionBody.title, description: plan.sessionBody.description, minLevel: 1, maxLevel: null, startedAt: '', completedAt: '',
      completedLevels: 0, totalLevels: 1, currentIndex: 0, presentation: plan.sessionBody.presentation });
    requireThat(Array.isArray(detail.levels) && detail.levels.length === 1, 'assignment_readback_incomplete');
    verifyFields(detail.levels[0], { id: levelId, position: 1, xp: plan.level.row.xp, autoNext: sessionBody.levels[0].autoNext,
      presentationOverride: sessionBody.levels[0].presentationOverride, completedAt: '', wrongCount: 0, locked: false });
    const { id: actualQuestionId, ...actualQuestion } = detail.levels[0].question || {};
    requireThat(actualQuestionId === questionId, 'assignment_question_identity_mismatch');
    equal(actualQuestion, { ...plan.expectedQuestion, content: prepared.questionBody.content }, 'derived_question_readback_mismatch');
    const listing = await api('/api/questions/v1/assignments', undefined, loggedIn.token);
    requireThat(Array.isArray(listing.items) && listing.items.length === 1, 'dedicated_listing_incomplete'); verifyFields(listing.items[0], { id: value.assignmentId, player: value.playerId, session: sessionId });
    const after = await api('/api/questions/v1/admin/catalog'); equal(after.ranks, baseline.ranks, 'existing_ranks_changed');
    for (const kind of ['questions', 'sessions']) { requireThat(Array.isArray(after[kind]), 'final_catalog_incomplete'); for (const old of baseline[kind]) equal(after[kind].find(row => row.id === old.id), old, 'existing_seed_content_changed'); }
    verifyFields(after.questions.find(row => row.id === questionId), { ...prepared.questionBody, status: 'published', commonClueCount: plan.commonClues.length });
    verifyFields(after.sessions.find(row => row.id === sessionId), { title: plan.sessionBody.title, description: plan.sessionBody.description, minLevel: '', maxLevel: '',
      presentation: plan.sessionBody.presentation, completionTarget: plan.sessionBody.completionTarget, rewardRules: [], status: 'published' });
    for (const [oldId, old] of Object.entries(previousCases)) equal(state.gameplay.cases[oldId], old, 'existing_case_state_changed'); equal(state.uiContent, previousContentRegistry, 'real_content_registry_changed');
    await privateBytes(input.fixtureFile, input.expectedSha256, root); await privateBytes(input.derivationFile, input.expectedDerivationSha256, root);
    await privateBytes(spec.referenceImage.manifestFile, spec.referenceImage.manifestSha256, root);
    await privateBytes(prepared.registered.image.filename, spec.referenceImage.assetSha256, root);
    record.targetContentRecordCount = Object.values(record.sourceTargetMap).reduce((sum, mapping) => sum + Object.keys(mapping).length, 0);
    requireThat(record.targetContentRecordCount === 5 + plan.commonClues.length + plan.clues.length, 'derived_record_mapping_incomplete');
    record.status = 'ready'; record.verifiedBy = 'official-admin-and-player-readbacks'; value.setupStatus = 'ready'; value.setupStage = 'verified-not-started'; value.ordinaryLoginPrepared = true; await save(state);
    return { created: true, fixture: 'ui-image-failure', importId, caseId, caseCount: 1, targetContentRecordCount: record.targetContentRecordCount,
      ordinaryLoginPrepared: true, expectedImageHttpStatus: 404, imageFailureVerified: false, gameplayStarted: false, gameplayAnswered: false, existingCasesModified: false };
  } catch (error) {
    record.status = 'incomplete'; record.failureCode = error instanceof DerivationError ? error.code : 'official_setup_failed'; value.setupStatus = 'incomplete';
    await save(state); throw new DerivationError('image_failure_case_incomplete');
  }
}

async function freshSpecDirectory(value, root) {
  const directory = path.resolve(root, value), base = path.join(root, 'artifacts/private/ui-reference');
  requireThat(directory.startsWith(base + path.sep), 'output_outside_private_ui_reference');
  const parts = directory.slice(root.length + 1).split(path.sep); let current = root;
  for (const [index, part] of parts.entries()) {
    current = path.join(current, part); let created = false;
    try { await mkdir(current, { mode: index >= 1 ? 0o700 : 0o755 }); created = true; }
    catch (error) { if (error.code !== 'EEXIST') throw error; requireThat(index !== parts.length - 1, 'output_already_exists'); }
    const info = await lstat(current); requireThat(info.isDirectory() && !info.isSymbolicLink() && info.uid === process.getuid(), 'output_directory_type_or_owner');
    if (created && index >= 1) await chmod(current, 0o700);
    requireThat(index === 0 || (info.mode & 0o777) === 0o700, 'output_directory_not_private');
  }
  return directory;
}
async function prepare(options) {
  exactKeys(options, ['fixture-file', 'expected-sha256', 'images-manifest', 'expected-images-manifest-sha256', 'output-dir'], 'prepare_options_invalid');
  const base = await readUiContentFixture({ fixtureFile: options['fixture-file'], expectedSha256: options['expected-sha256'], label: 'image-failure-spec' }, ROOT);
  const registered = await registration(options['images-manifest'], options['expected-images-manifest-sha256'], options['expected-sha256'], base.plans[0], ROOT);
  const spec = describeUiImageFailure(base, options['expected-sha256'], registered.reference, randomBytes(16).toString('hex'));
  const bytes = Buffer.from(JSON.stringify(spec, null, 2) + '\n'), directory = await freshSpecDirectory(options['output-dir'], ROOT);
  const before = await lstat(directory), filename = path.join(directory, 'derivation.json');
  const handle = await open(filename, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
  try { await handle.chmod(0o600); await handle.writeFile(bytes); }
  finally { await handle.close(); }
  const after = await lstat(directory); requireThat(!after.isSymbolicLink() && before.dev === after.dev && before.ino === after.ino, 'output_directory_changed');
  await privateBytes(filename, sha(bytes), ROOT);
  console.log(JSON.stringify({ status: spec.status, derivationSha256: sha(bytes), baseFixtureSha256: options['expected-sha256'],
    sourceCaseIndex: 0, overrideCount: 1, networkVerified: false, importExecuted: false, outputFile: path.relative(ROOT, filename) }));
}
async function main() {
  if (!process.argv[2] || ['help', '--help', '-h'].includes(process.argv[2]) || (process.argv[2] === 'prepare' && process.argv.slice(3).some(arg => ['--help', '-h'].includes(arg)))) {
    console.log('Usage: ui-image-failure-case.mjs prepare --fixture-file PATH --expected-sha256 SHA --images-manifest PATH --expected-images-manifest-sha256 SHA --output-dir FRESH_PRIVATE_DIR'); return;
  }
  try {
    requireThat(process.argv[2] === 'prepare', 'unknown_explicit_command'); const args = process.argv.slice(3), options = {};
    requireThat(args.length % 2 === 0, 'prepare_options_invalid');
    for (let index = 0; index < args.length; index += 2) { requireThat(/^--[a-z0-9-]+$/.test(args[index]) && !Object.hasOwn(options, args[index].slice(2)) && !args[index + 1].startsWith('--'), 'prepare_options_invalid'); options[args[index].slice(2)] = args[index + 1]; }
    await prepare(options);
  } catch { console.log(JSON.stringify({ status: 'not_prepared', error: 'The explicit private derivation boundary failed; values omitted' })); process.exitCode = 1; }
}
if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) await main();
