/** Dedicated synthetic mixed-gallery fixture. Default/help is inert.
 * prepare reads private reviewed inputs only; it never requests a media URL.
 * The future runner route alone calls createUiViewerMediaCase under caseCreationBusy.
 */
import { constants } from 'node:fs';
import { chmod, lstat, mkdir, open, readFile } from 'node:fs/promises';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { readUiContentFixture } from './ui-content-case.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const HASH = /^[a-f0-9]{64}$/;
const ID = /^[a-z0-9]{15}$/;
const OVERRIDE = 'question.content[0].imageUrls';
const SOURCE_FILE = 'scripts/ui-viewer-test-media.mjs';
const TABLES = ['game_questions', 'game_answer_keys', 'game_question_settings', 'game_question_clues', 'game_sessions', 'game_session_levels', 'game_clues'];
const sha = value => createHash('sha256').update(value).digest('hex');
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const canonical = value => Array.isArray(value) ? '[' + value.map(canonical).join(',') + ']' : object(value) ?
  '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}' : JSON.stringify(value);
class FixtureError extends Error { constructor(code) { super(code); this.code = code; } }
function requireThat(value, code) { if (!value) throw new FixtureError(code); }
function keys(value, expected, code) { requireThat(object(value) && Object.keys(value).length === expected.length && Object.keys(value).every(key => expected.includes(key)), code); }
function equal(actual, expected, code) { requireThat(canonical(actual) === canonical(expected), code); }
function fields(row, expected) { requireThat(object(row), 'readback_missing'); for (const [key, value] of Object.entries(expected)) equal(row[key], value, 'readback_field_mismatch'); }

async function privateBytes(filename, expected, root) {
  requireThat(typeof filename === 'string' && HASH.test(expected || ''), 'private_input_invalid');
  const absolute = path.resolve(root, filename), base = path.join(root, 'artifacts/private/ui-reference'), checked = [];
  requireThat(absolute.startsWith(base + path.sep), 'private_input_outside_reference');
  for (let current = absolute; ; current = path.dirname(current)) {
    const info = await lstat(current);
    requireThat(!info.isSymbolicLink() && (current === absolute ? info.isFile() : info.isDirectory()), 'private_path_type');
    if (current === absolute || current === path.join(root, 'artifacts/private') || current.startsWith(path.join(root, 'artifacts/private') + path.sep)) {
      requireThat(info.uid === process.getuid() && (info.mode & 0o777) === (current === absolute ? 0o600 : 0o700), 'private_path_owner_mode');
    }
    checked.push({ path: current, dev: info.dev, ino: info.ino });
    if (current === path.parse(current).root) break;
  }
  const handle = await open(absolute, constants.O_RDONLY | constants.O_NOFOLLOW);
  let bytes;
  try {
    const before = await handle.stat();
    requireThat(before.dev === checked[0].dev && before.ino === checked[0].ino && before.size > 0 && before.size <= 5 * 1024 * 1024 &&
      before.uid === process.getuid() && (before.mode & 0o777) === 0o600, 'private_input_changed');
    bytes = await handle.readFile();
    const after = await handle.stat();
    requireThat(before.size === after.size && before.mtimeMs === after.mtimeMs && before.ctimeMs === after.ctimeMs, 'private_input_changed');
  } finally { await handle.close(); }
  for (const item of checked) { const info = await lstat(item.path); requireThat(!info.isSymbolicLink() && info.dev === item.dev && info.ino === item.ino, 'private_path_changed'); }
  requireThat(sha(bytes) === expected, 'private_input_hash_mismatch');
  return { filename: absolute, bytes };
}
async function privateJson(filename, expected, root) {
  const value = await privateBytes(filename, expected, root);
  let parsed; try { parsed = JSON.parse(value.bytes.toString('utf8')); } catch { throw new FixtureError('private_json_invalid'); }
  requireThat(object(parsed), 'private_json_not_object'); return { ...value, value: parsed };
}
function publicHttps(value) {
  requireThat(typeof value === 'string' && !/[\s\\\u0000-\u001f\u007f]/.test(value), 'media_url_invalid');
  let parsed; try { parsed = new URL(value); } catch { throw new FixtureError('media_url_invalid'); }
  const host = parsed.hostname.toLowerCase().replace(/\.$/, '');
  requireThat(parsed.protocol === 'https:' && !parsed.username && !parsed.password && !parsed.hash && !parsed.search &&
    !/^https:\/\/[^/?#]*@/i.test(value) &&
    (!parsed.port || parsed.port === '443') && /^[a-z0-9.-]+$/.test(host) && host.includes('.') && !/\.[0-9]+$/.test(host) &&
    !/^[0-9.]+$/.test(host) && !/(^|\.)(localhost|local|localdomain|internal|lan|home|test|invalid|onion)$/.test(host) &&
    host !== 'home.arpa' && !host.endsWith('.home.arpa'), 'media_url_not_public_https');
  requireThat(host.split('.').every(label => label.length > 0 && label.length <= 63 && !label.startsWith('-') && !label.endsWith('-')), 'media_hostname_invalid');
  return parsed;
}
function originalGood(base) {
  const plan = base.plans[0], block = plan?.questionBody?.content?.[0];
  requireThat(plan.questionBody.kind === 'text' && block && typeof block.imageUrl === 'string' && block.imageUrl &&
    Array.isArray(block.imageUrls) && block.imageUrls.length === 0 && block.videoUrl === '' &&
    5 + plan.commonClues.length + plan.clues.length === 7, 'original_case0_scope_changed');
  // The original URL is preserved byte-for-byte, including any legitimate query.
  let parsed; try { parsed = new URL(block.imageUrl); } catch { throw new FixtureError('original_good_url_invalid'); }
  requireThat(parsed.protocol === 'https:' && !parsed.username && !parsed.password, 'original_good_url_invalid');
  return block.imageUrl;
}

async function registeredGood(input, base, root) {
  const manifest = await privateJson(input.imagesManifest, input.expectedImagesManifestSha256, root), value = manifest.value;
  requireThat(value.status === 'reference_image_bytes_captured' && value.fixtureSha256 === input.expectedSha256 &&
    value.referer === 'https://sitkin.top/' && value.nativeLoadVerified === false && Array.isArray(value.assets) && value.assets.length === 8, 'original_image_manifest_invalid');
  const matches = value.assets.filter(asset => asset.url === originalGood(base));
  requireThat(matches.length === 1, 'original_good_not_unique');
  const asset = matches[0];
  requireThat(asset.authorizationSent === false && HASH.test(asset.sha256 || '') && ['image/jpeg', 'image/png'].includes(asset.detectedMime) &&
    Number.isSafeInteger(asset.bytes) && asset.bytes > 0 && asset.bytes <= 5 * 1024 * 1024, 'original_good_registration_invalid');
  const file = await privateBytes(asset.file, asset.sha256, root);
  requireThat(file.bytes.length === asset.bytes, 'original_good_byte_count_changed');
  return { manifest, file, reference: { manifestFile: path.relative(root, manifest.filename), manifestSha256: input.expectedImagesManifestSha256,
    file: path.relative(root, file.filename), sha256: asset.sha256, bytes: asset.bytes, detectedMime: asset.detectedMime } };
}

async function boundMedia(input, root) {
  const receipt = await privateJson(input.mediaReceiptFile, input.expectedMediaReceiptSha256, root), value = receipt.value;
  keys(value, ['formatVersion', 'fixture', 'status', 'serverSourceFile', 'sourceSha256', 'specFile', 'specSha256', 'publicOrigin', 'paths', 'urls', 'png', 'nativeLoadVerified'], 'media_receipt_fields');
  requireThat(value.formatVersion === 1 && value.fixture === 'ui-viewer-test-media' && value.status === 'public_https_bound_not_native_verified' &&
    value.serverSourceFile === SOURCE_FILE && HASH.test(value.sourceSha256 || '') && HASH.test(value.specSha256 || '') && value.nativeLoadVerified === false, 'media_receipt_invalid');
  const sourceFile = path.join(root, SOURCE_FILE), sourceInfo = await lstat(sourceFile);
  requireThat(!sourceInfo.isSymbolicLink() && sourceInfo.isFile() && sourceInfo.uid === process.getuid() && !(sourceInfo.mode & 0o022), 'media_server_source_owner');
  const sourceBytes = await readFile(sourceFile), sourceAfter = await lstat(sourceFile);
  requireThat(sourceAfter.dev === sourceInfo.dev && sourceAfter.ino === sourceInfo.ino && sourceAfter.mtimeMs === sourceInfo.mtimeMs &&
    sourceAfter.ctimeMs === sourceInfo.ctimeMs && sha(sourceBytes) === value.sourceSha256, 'media_server_source_changed');
  const spec = await privateJson(value.specFile, value.specSha256, root), source = spec.value;
  keys(source, ['formatVersion', 'fixture', 'status', 'createdAt', 'sourceSha256', 'mediaPort', 'controlPort', 'nonce', 'controlKey', 'paths', 'png'], 'media_spec_fields');
  requireThat(source.formatVersion === 1 && source.fixture === 'ui-viewer-test-media' && source.status === 'prepared_offline' &&
    source.sourceSha256 === value.sourceSha256 && /^[a-f0-9]{32}$/.test(source.nonce || '') && HASH.test(source.controlKey || '') &&
    Number.isInteger(source.mediaPort) && Number.isInteger(source.controlPort) && source.mediaPort >= 1024 && source.mediaPort <= 65535 &&
    source.controlPort >= 1024 && source.controlPort <= 65535 && source.mediaPort !== source.controlPort, 'media_spec_invalid');
  const prefix = '/viewer-' + source.nonce + '/';
  equal(value.paths, { health: '/health', png: prefix + 'small.png', missing: prefix + 'missing.png' }, 'media_literal_paths_changed');
  equal(source.paths, value.paths, 'media_spec_paths_changed');
  keys(value.urls, ['small', 'missing'], 'media_urls_fields');
  const origin = publicHttps(value.publicOrigin);
  requireThat(value.publicOrigin === origin.origin && origin.pathname === '/', 'media_origin_invalid');
  equal(value.urls, { small: value.publicOrigin + value.paths.png, missing: value.publicOrigin + value.paths.missing }, 'media_url_binding_changed');
  publicHttps(value.urls.small); publicHttps(value.urls.missing);
  keys(value.png, ['file', 'sha256', 'bytes', 'width', 'height', 'mime'], 'synthetic_png_fields');
  equal(value.png, source.png, 'synthetic_png_spec_changed');
  requireThat(HASH.test(value.png.sha256 || '') && Number.isSafeInteger(value.png.bytes) && value.png.bytes > 24 && value.png.bytes <= 5 * 1024 * 1024 &&
    value.png.width === 64 && value.png.height === 40 && value.png.mime === 'image/png', 'synthetic_png_metadata_invalid');
  const png = await privateBytes(value.png.file, value.png.sha256, root);
  requireThat(png.bytes.length === value.png.bytes && png.bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) &&
    png.bytes.toString('ascii', 12, 16) === 'IHDR' && png.bytes.readUInt32BE(16) === 64 && png.bytes.readUInt32BE(20) === 40, 'synthetic_png_bytes_invalid');
  return { receipt, spec, png, reference: { receiptFile: path.relative(root, receipt.filename), receiptSha256: input.expectedMediaReceiptSha256,
    sourceSha256: value.sourceSha256, specSha256: value.specSha256, smallUrl: value.urls.small, missingUrl: value.urls.missing,
    pngSha256: value.png.sha256, pngBytes: value.png.bytes, width: 64, height: 40 } };
}

export function describeUiViewerMedia(base, fixtureSha256, reference, media) {
  return { formatVersion: 1, fixture: 'ui-viewer-media', status: 'prepared_offline_not_imported', baseFixtureSha256: fixtureSha256,
    sourceSnapshotSha256: base.packet.sourceSnapshotSha256, sourceCaseIndex: 0, sourceRefs: base.plans[0].sourceRefs,
    sourceRevisions: { question: base.plans[0].question.row.revision, session: base.plans[0].session.row.revision },
    overridePath: OVERRIDE, originalGoodUrlSha256: sha(originalGood(base)), appendedUrls: [media.missingUrl, media.smallUrl],
    referenceImage: reference, syntheticMedia: media, sourceRowsRewritten: false, nativeLoadVerified: false, importExecuted: false };
}
function deriveQuestion(base, spec) {
  const questionBody = structuredClone(base.plans[0].questionBody);
  questionBody.content[0].imageUrls = [...spec.appendedUrls];
  const restored = structuredClone(questionBody); restored.content[0].imageUrls = [];
  equal(restored, base.plans[0].questionBody, 'mixed_gallery_changed_other_fields');
  requireThat(questionBody.content[0].imageUrl === originalGood(base) && new Set([originalGood(base), ...spec.appendedUrls]).size === 3, 'mixed_gallery_sources_not_distinct');
  return questionBody;
}
function sourceIdentity(spec) {
  return sha(canonical({ fixture: 'ui-viewer-media', sourceSnapshotSha256: spec.sourceSnapshotSha256, sourceCaseIndex: 0,
    overridePath: OVERRIDE, originalGoodUrlSha256: spec.originalGoodUrlSha256 }));
}
async function inputs(input, root) {
  keys(input, ['fixtureFile', 'expectedSha256', 'derivationFile', 'expectedDerivationSha256', 'label'], 'viewer_control_fields');
  requireThat(/^[a-z][a-z0-9-]{0,23}$/.test(input.label || ''), 'viewer_label_invalid');
  const base = await readUiContentFixture({ fixtureFile: input.fixtureFile, expectedSha256: input.expectedSha256, label: input.label }, root);
  const derivation = await privateJson(input.derivationFile, input.expectedDerivationSha256, root), spec = derivation.value;
  const referenceInput = { ...input, imagesManifest: spec.referenceImage?.manifestFile, expectedImagesManifestSha256: spec.referenceImage?.manifestSha256,
    mediaReceiptFile: spec.syntheticMedia?.receiptFile, expectedMediaReceiptSha256: spec.syntheticMedia?.receiptSha256 };
  const registered = await registeredGood(referenceInput, base, root), media = await boundMedia(referenceInput, root);
  equal(spec, describeUiViewerMedia(base, input.expectedSha256, registered.reference, media.reference), 'viewer_derivation_changed');
  const questionBody = deriveQuestion(base, spec);
  const revalidate = async () => {
    await privateBytes(input.fixtureFile, input.expectedSha256, root); await privateBytes(input.derivationFile, input.expectedDerivationSha256, root);
    await registeredGood(referenceInput, base, root); await boundMedia(referenceInput, root);
  };
  return { base, derivation, questionBody, revalidate };
}

function previousActors(state, fixtureSha256) {
  requireThat(state.uiContent?.schema === 1 && object(state.uiContent.imports) && state.uiImageFailures?.schema === 1 && object(state.uiImageFailures.imports), 'original_registries_missing');
  const real = Object.values(state.uiContent.imports).filter(row => row.fixtureSha256 === fixtureSha256);
  const failure = Object.values(state.uiImageFailures.imports).filter(row => row.baseFixtureSha256 === fixtureSha256);
  requireThat(real.length === 1 && real[0].fixture === 'ui-real-content' && real[0].status === 'ready' && real[0].verifiedRecordCount === 19 &&
    real[0].verifiedBy === 'official-admin-and-player-readbacks' && Array.isArray(real[0].caseIds) && real[0].caseIds.length === 3 &&
    failure.length === 1 && failure[0].fixture === 'ui-image-failure' && failure[0].status === 'ready' && failure[0].targetContentRecordCount === 7 &&
    failure[0].verifiedBy === 'official-admin-and-player-readbacks', 'original_case_provenance_missing');
  const ids = [...real[0].caseIds, failure[0].caseId];
  requireThat(new Set(ids).size === 4 && canonical(Object.keys(state.gameplay.cases).sort()) === canonical([...ids].sort()) &&
    ids.every((id, index) => state.gameplay.cases[id]?.caseId === id && state.gameplay.cases[id]?.fixture === (index < 3 ? 'ui-real-content' : 'ui-image-failure')), 'original_four_actor_scope_changed');
}

/** Only this private core is exercised with fake API closures; production always calls inputs first. */
async function createPrepared(input, prepared, { root, state, save, admin, api, secret, superToken }) {
  requireThat(state?.mode === 'real isolated PocketBase' && /^http:\/\/127\.0\.0\.1:[1-9][0-9]{3,4}$/.test(state.backendBase || '') &&
    object(state.gameplay?.cases) && typeof superToken === 'string' && superToken, 'disposable_runner_boundary_invalid');
  const plan = prepared.base.plans[0], spec = prepared.derivation.value;
  if (state.uiViewerMedia !== undefined) requireThat(state.uiViewerMedia.schema === 1 && object(state.uiViewerMedia.imports), 'viewer_registry_invalid');
  const imports = state.uiViewerMedia?.imports || {}, sourceIdentitySha256 = sourceIdentity(spec);
  requireThat(!Object.values(imports).some(row => row.derivationSha256 === input.expectedDerivationSha256 || row.sourceIdentitySha256 === sourceIdentitySha256), 'viewer_derivation_already_attempted');
  previousActors(state, input.expectedSha256);
  const baseline = await api('/api/questions/v1/admin/catalog');
  requireThat(['ranks', 'questions', 'sessions', 'players'].every(key => Array.isArray(baseline[key])) && baseline.ranks.length > 0, 'catalog_incomplete');
  const previous = structuredClone(state), existingIds = new Set(Object.values(baseline).filter(Array.isArray).flat().map(row => row.id).filter(Boolean));
  const fresh = id => { requireThat(ID.test(id || '') && !existingIds.has(id) && !prepared.base.allSourceIds.has(id), 'new_identity_not_fresh'); existingIds.add(id); return id; };
  const importId = randomBytes(8).toString('hex'), caseId = randomBytes(8).toString('hex');
  requireThat(!Object.hasOwn(imports, importId) && !Object.hasOwn(state.gameplay.cases, caseId), 'new_identity_collision');
  const record = { importId, caseId, fixture: 'ui-viewer-media', status: 'creating', baseFixtureSha256: input.expectedSha256,
    derivationFile: path.relative(root, prepared.derivation.filename), derivationSha256: input.expectedDerivationSha256, sourceIdentitySha256,
    sourceSnapshotSha256: spec.sourceSnapshotSha256, sourceCaseIndex: 0, sourceRefs: spec.sourceRefs, sourceRevisions: spec.sourceRevisions,
    overridePath: OVERRIDE, originalGoodUrlSha256: spec.originalGoodUrlSha256, appendedUrlSha256: spec.appendedUrls.map(sha),
    mediaReceiptSha256: spec.syntheticMedia.receiptSha256, syntheticPngSha256: spec.syntheticMedia.pngSha256,
    syntheticDerivation: true, sourceRowsRewritten: false, nativeLoadVerified: false, gameplayStarted: false, gameplayAnswered: false,
    sourceTargetMap: Object.fromEntries(TABLES.map(table => [table, {}])),
    metadataPolicy: 'new isolated identities/series/revisions/timestamps/published status; only imageUrls appended; complete original session semantics retained' };
  const value = { caseId, label: input.label, fixture: 'ui-viewer-media', fixtureLevelKinds: ['text'], setupStatus: 'creating', ordinaryLoginPrepared: false,
    account: 'hm_' + randomBytes(6).toString('hex'), initialPassword: secret(), newPassword: secret(), playerId: '', assignmentId: '', assignments: {}, uiViewerMediaImportId: importId,
    sourceContent: { baseFixtureSha256: input.expectedSha256, sourceCaseIndex: 0, derivationSha256: input.expectedDerivationSha256, sourceIdentitySha256,
      overridePath: OVERRIDE, originalGoodUrlSha256: spec.originalGoodUrlSha256, appendedUrlSha256: spec.appendedUrls.map(sha) } };
  state.uiViewerMedia = { schema: 1, imports: { ...imports, [importId]: record } }; state.gameplay.cases[caseId] = value;
  const mapped = (table, sourceId, targetId) => { requireThat(!Object.hasOwn(record.sourceTargetMap[table], sourceId), 'source_mapped_twice'); record.sourceTargetMap[table][sourceId] = fresh(targetId); return targetId; };
  const rows = async (table, field, id) => {
    requireThat(TABLES.includes(table) && ['question', 'session'].includes(field) && ID.test(id), 'readback_scope_invalid');
    const result = await api('/api/collections/' + table + '/records?perPage=100&filter=' + encodeURIComponent(field + '="' + id + '"'), undefined, superToken);
    requireThat(Array.isArray(result.items) && result.totalItems === result.items.length && result.items.every(row => row[field] === id), 'readback_incomplete'); return result.items;
  };
  try {
    await save(state); value.setupStage = 'question';
    const questionId = mapped('game_questions', plan.question.row.id, (await admin('questions', prepared.questionBody)).id); await save(state);
    const [answerKeys, settings] = await Promise.all([rows('game_answer_keys', 'question', questionId), rows('game_question_settings', 'question', questionId)]);
    requireThat(answerKeys.length === 1 && settings.length === 1, 'question_support_missing');
    fields(answerKeys[0], { question: questionId, acceptedAnswers: prepared.questionBody.acceptedAnswers, normalizationVersion: 'nfkc-v1' });
    fields(settings[0], { question: questionId, answerMatchMode: plan.settings.row.answerMatchMode, groupName: prepared.questionBody.groupName });
    mapped('game_answer_keys', plan.answerKey.row.id, answerKeys[0].id); mapped('game_question_settings', plan.settings.row.id, settings[0].id);
    const clueRoute = '/api/questions/v1/admin/questions/' + questionId + '/clues', before = await api(clueRoute);
    requireThat(Array.isArray(before.items) && before.items.length === 0 && HASH.test(before.version || ''), 'new_common_clues_not_empty');
    if (plan.commonClues.length) {
      const after = await api(clueRoute, { requestId: randomUUID(), reason: '合成查看器媒体夹具', expectedVersion: before.version, clues: plan.commonClues.map(clue => clue.body) }, undefined, 'PATCH');
      requireThat(Array.isArray(after.items) && after.items.length === plan.commonClues.length && HASH.test(after.version || ''), 'common_clues_incomplete');
      plan.commonClues.forEach((clue, index) => { fields(after.items[index], { ...clue.body, question: questionId, status: 'active' }); mapped('game_question_clues', clue.sourceId, after.items[index].id); });
    }
    await admin('questions/' + questionId + '/publish'); value.setupStage = 'session'; await save(state);
    const sessionBody = { ...plan.sessionBody, levels: [{ ...plan.sessionBody.levels[0], question: questionId }] };
    const sessionId = mapped('game_sessions', plan.session.row.id, (await admin('sessions', sessionBody)).id); await save(state);
    const [levels, clues] = await Promise.all([rows('game_session_levels', 'session', sessionId), rows('game_clues', 'session', sessionId)]);
    requireThat(levels.length === 1 && clues.length === plan.clues.length, 'whole_session_readback_incomplete');
    fields(levels[0], { ...sessionBody.levels[0], session: sessionId, position: 1 });
    const levelId = mapped('game_session_levels', plan.level.row.id, levels[0].id); clues.sort((a, b) => a.position - b.position);
    plan.clues.forEach((clue, index) => { const { levelIndex: _index, ...body } = clue.body;
      fields(clues[index], { ...body, session: sessionId, position: index, sessionLevel: clue.sourceLevelId ? levelId : '' }); mapped('game_clues', clue.sourceId, clues[index].id); });
    await admin('sessions/' + sessionId + '/publish'); value.setupStage = 'player'; await save(state);
    value.playerId = fresh((await admin('players', { account: value.account, displayName: '查看器媒体验证旅行者', password: value.initialPassword })).id); await save(state);
    const assigned = await admin('assignments', { sessionId, target: 'selected', playerIds: [value.playerId], order: 0 });
    requireThat(Array.isArray(assigned.results) && assigned.results.length === 1 && assigned.results[0].playerId === value.playerId && assigned.results[0].status === 'assigned', 'new_assignment_unconfirmed');
    value.assignmentId = fresh(assigned.results[0].assignmentId); value.assignments = { ready: { assignmentId: value.assignmentId, sessionId } }; value.setupStage = 'ordinary-login'; await save(state);
    const initial = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.initialPassword }, '');
    requireThat(typeof initial.token === 'string' && initial.token && initial.record?.id === value.playerId, 'initial_login_identity');
    const changed = await api('/api/questions/v1/me/change-password', { oldPassword: value.initialPassword, password: value.newPassword, passwordConfirm: value.newPassword }, initial.token);
    requireThat(changed.player?.id === value.playerId && changed.player.mustChangePassword === false, 'ordinary_password_preparation');
    const loggedIn = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.newPassword }, '');
    requireThat(typeof loggedIn.token === 'string' && loggedIn.token && loggedIn.record?.id === value.playerId, 'ordinary_login_identity');
    fields(await api('/api/questions/v1/me', undefined, loggedIn.token), { id: value.playerId, account: value.account, mustChangePassword: false, totalXp: 0 });
    const detail = await api('/api/questions/v1/admin/assignments/' + value.assignmentId);
    fields(detail, { id: value.assignmentId, player: value.playerId, session: sessionId, status: 'assigned', sessionStatus: 'published', title: plan.sessionBody.title,
      description: plan.sessionBody.description, minLevel: 1, maxLevel: null, startedAt: '', completedAt: '', completedLevels: 0, totalLevels: 1, currentIndex: 0, presentation: plan.sessionBody.presentation });
    requireThat(Array.isArray(detail.levels) && detail.levels.length === 1, 'assignment_levels_incomplete');
    fields(detail.levels[0], { id: levelId, position: 1, xp: plan.level.row.xp, autoNext: sessionBody.levels[0].autoNext,
      presentationOverride: sessionBody.levels[0].presentationOverride, completedAt: '', wrongCount: 0, locked: false });
    const { id: returnedId, ...question } = detail.levels[0].question || {};
    requireThat(returnedId === questionId, 'question_identity_mismatch');
    equal(question, { ...plan.expectedQuestion, content: prepared.questionBody.content }, 'derived_question_readback_changed');
    const listing = await api('/api/questions/v1/assignments', undefined, loggedIn.token);
    requireThat(Array.isArray(listing.items) && listing.items.length === 1, 'ordinary_listing_incomplete'); fields(listing.items[0], { id: value.assignmentId, player: value.playerId, session: sessionId });
    // Ordinary players must still see the protected question as null before entry.
    const playerDetail = await api('/api/questions/v1/assignments/' + value.assignmentId, undefined, loggedIn.token);
    fields(playerDetail, { id: value.assignmentId, player: value.playerId, status: 'assigned', startedAt: '', completedAt: '', completedLevels: 0, totalLevels: 1 });
    requireThat(playerDetail.levels?.length === 1 && playerDetail.levels[0].question === null, 'unstarted_player_question_exposed');
    const after = await api('/api/questions/v1/admin/catalog'); equal(after.ranks, baseline.ranks, 'existing_ranks_changed');
    for (const kind of ['questions', 'sessions', 'players']) { requireThat(Array.isArray(after[kind]), 'catalog_incomplete');
      for (const old of baseline[kind]) equal(after[kind].find(row => row.id === old.id), old, 'existing_catalog_record_changed'); }
    fields(after.questions.find(row => row.id === questionId), { ...prepared.questionBody, status: 'published', commonClueCount: plan.commonClues.length });
    fields(after.sessions.find(row => row.id === sessionId), { title: plan.sessionBody.title, description: plan.sessionBody.description, minLevel: '', maxLevel: '',
      presentation: plan.sessionBody.presentation, completionTarget: plan.sessionBody.completionTarget, rewardRules: [], status: 'published' });
    for (const [key, old] of Object.entries(previous)) {
      if (key === 'uiViewerMedia') continue;
      if (key === 'gameplay') { const { cases: _cases, ...oldRest } = old, { cases: _newCases, ...newRest } = state.gameplay;
        equal(newRest, oldRest, 'existing_gameplay_metadata_changed'); for (const [id, row] of Object.entries(old.cases)) equal(state.gameplay.cases[id], row, 'existing_case_changed'); }
      else equal(state[key], old, 'existing_state_or_registry_changed');
    }
    for (const [id, row] of Object.entries(imports)) equal(state.uiViewerMedia.imports[id], row, 'existing_viewer_import_changed');
    equal(Object.keys(state.gameplay.cases).sort(), [...Object.keys(previous.gameplay.cases), caseId].sort(), 'unexpected_extra_case');
    equal(Object.keys(state.uiViewerMedia.imports).sort(), [...Object.keys(imports), importId].sort(), 'unexpected_extra_viewer_import');
    await prepared.revalidate();
    record.targetContentRecordCount = Object.values(record.sourceTargetMap).reduce((sum, mapping) => sum + Object.keys(mapping).length, 0);
    requireThat(record.targetContentRecordCount === 7, 'new_record_count_not_seven');
    record.status = 'ready'; record.verifiedBy = 'official-admin-and-player-readbacks'; value.setupStatus = 'ready'; value.setupStage = 'verified-not-started'; value.ordinaryLoginPrepared = true; await save(state);
    return { created: true, fixture: 'ui-viewer-media', importId, caseId, caseCount: 1, targetContentRecordCount: 7,
      ordinaryLoginPrepared: true, syntheticDerivation: true, nativeLoadVerified: false, gameplayStarted: false, gameplayAnswered: false, existingCasesModified: false };
  } catch (error) {
    record.status = 'incomplete'; record.failureCode = error instanceof FixtureError ? error.code : 'official_setup_failed'; value.setupStatus = 'incomplete';
    await save(state); throw new FixtureError('viewer_media_case_incomplete');
  }
}

export async function createUiViewerMediaCase(input, context) { return createPrepared(input, await inputs(input, context.root), context); }

async function freshDirectory(value, root) {
  const directory = path.resolve(root, value), base = path.join(root, 'artifacts/private/ui-reference');
  requireThat(directory.startsWith(base + path.sep), 'output_outside_reference');
  let current = root;
  for (const [index, part] of directory.slice(root.length + 1).split(path.sep).entries()) {
    current = path.join(current, part); let created = false;
    try { await mkdir(current, { mode: index >= 1 ? 0o700 : 0o755 }); created = true; }
    catch (error) { if (error.code !== 'EEXIST') throw error; requireThat(current !== directory, 'output_already_exists'); }
    const info = await lstat(current);
    requireThat(!info.isSymbolicLink() && info.isDirectory() && info.uid === process.getuid(), 'output_owner_type');
    if (created && index >= 1) await chmod(current, 0o700);
    requireThat(index === 0 || (info.mode & 0o777) === 0o700, 'output_not_private');
  }
  return directory;
}
async function prepare(options) {
  keys(options, ['fixture-file', 'expected-sha256', 'images-manifest', 'expected-images-manifest-sha256', 'media-receipt-file', 'expected-media-receipt-sha256', 'output-dir'], 'prepare_options_invalid');
  const input = { fixtureFile: options['fixture-file'], expectedSha256: options['expected-sha256'], label: 'viewer-media',
    imagesManifest: options['images-manifest'], expectedImagesManifestSha256: options['expected-images-manifest-sha256'],
    mediaReceiptFile: options['media-receipt-file'], expectedMediaReceiptSha256: options['expected-media-receipt-sha256'] };
  const base = await readUiContentFixture({ fixtureFile: input.fixtureFile, expectedSha256: input.expectedSha256, label: input.label }, ROOT);
  const reference = await registeredGood(input, base, ROOT), media = await boundMedia(input, ROOT);
  const value = describeUiViewerMedia(base, input.expectedSha256, reference.reference, media.reference);
  deriveQuestion(base, value);
  await privateBytes(input.fixtureFile, input.expectedSha256, ROOT);
  await registeredGood(input, base, ROOT); await boundMedia(input, ROOT);
  const directory = await freshDirectory(options['output-dir'], ROOT), filename = path.join(directory, 'derivation.json');
  const bytes = Buffer.from(JSON.stringify(value, null, 2) + '\n');
  const descriptor = await open(filename, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
  try { await descriptor.chmod(0o600); await descriptor.writeFile(bytes); } finally { await descriptor.close(); }
  await privateBytes(filename, sha(bytes), ROOT);
  console.log(JSON.stringify({ status: value.status, fixture: value.fixture, derivationSha256: sha(bytes), baseFixtureSha256: input.expectedSha256,
    sourceIdentitySha256: sourceIdentity(value), bodyImageCount: 3, overrideCount: 1, syntheticDerivation: true, nativeLoadVerified: false, importExecuted: false }));
}

/** Entirely in-memory protocol simulation. No private input, filesystem write or network API. */
async function selfTest() {
  let checks = 0;
  const check = (value, code) => { requireThat(value, code); checks++; };
  const sid = letter => letter + '0'.repeat(14), sourceRefs = { questionId: sid('q'), sessionId: sid('s'), sessionLevelId: sid('l') };
  const fakePrepared = () => {
    const questionBody = { kind: 'text', title: '合成原题', placeholder: '合成输入', content: [{ imageUrl: 'https://images.example.com/original.png', imageUrls: [], videoUrl: '', text: '保留原文', hint: '保留提示' }],
      options: [], acceptedAnswers: ['synthetic-key-not-submitted'], fuzzyMatch: false, groupName: '' };
    const common = { position: 0, kind: 'text', content: { text: '保留公共线索' }, autoPlay: false };
    const clue = { levelIndex: 0, trigger: 'start', kind: 'text', content: { text: '保留场次线索' }, narrative: '', autoPlay: false };
    const level = { question: '', xp: 50, autoNext: false, penaltyPolicy: {}, presentationOverride: { hideTitle: true } };
    const plan = { sourceRefs, questionBody, question: { row: { id: sid('q'), revision: 3 } }, session: { row: { id: sid('s'), revision: 2 } },
      level: { row: { id: sid('l'), xp: 50 } }, answerKey: { row: { id: sid('a') } }, settings: { row: { id: sid('b'), answerMatchMode: 'exact' } },
      expectedQuestion: Object.fromEntries(['kind', 'title', 'placeholder', 'content', 'options'].map(key => [key, structuredClone(questionBody[key])])),
      commonClues: [{ sourceId: sid('c'), body: common }], clues: [{ sourceId: sid('d'), sourceLevelId: sid('l'), body: clue }],
      sessionBody: { title: '完整合成场次', description: '保留描述', minLevel: '', maxLevel: '', presentation: { hideTitle: false }, completionTarget: null, levels: [level], clues: [clue], rewardRules: [] } };
    const base = { plans: [plan], packet: { sourceSnapshotSha256: '1'.repeat(64) }, allSourceIds: new Set(['q', 's', 'l', 'a', 'b', 'c', 'd'].map(sid)) };
    const reference = { manifestFile: 'synthetic/manifest.json', manifestSha256: '2'.repeat(64), file: 'synthetic/original.png', sha256: '3'.repeat(64), bytes: 70, detectedMime: 'image/png' };
    const media = { receiptFile: 'synthetic/media.json', receiptSha256: '4'.repeat(64), sourceSha256: '5'.repeat(64), specSha256: '6'.repeat(64),
      missingUrl: 'https://media.example.com/viewer-test/missing.png', smallUrl: 'https://media.example.com/viewer-test/small.png', pngSha256: '7'.repeat(64), pngBytes: 200, width: 64, height: 40 };
    const value = describeUiViewerMedia(base, '8'.repeat(64), reference, media);
    return { base, derivation: { filename: path.join(ROOT, 'artifacts/private/ui-reference/synthetic/derivation.json'), value }, questionBody: deriveQuestion(base, value), revalidate: async () => {} };
  };
  const fakeContext = (fault = '') => {
    let counter = 0, writes = 0, changed = false, password = '';
    const next = () => 't' + String(++counter).padStart(14, '0');
    const cases = Object.fromEntries(['case0', 'case1', 'case2', 'failure'].map((caseId, index) => [caseId, { caseId, fixture: index < 3 ? 'ui-real-content' : 'ui-image-failure', preserved: true }]));
    const state = { mode: 'real isolated PocketBase', backendBase: 'http://127.0.0.1:19000', seed: { preserved: true }, gameplay: { cases, seedMetadata: ['unchanged'] },
      uiContent: { schema: 1, imports: { original: { fixture: 'ui-real-content', fixtureSha256: '8'.repeat(64), status: 'ready', verifiedRecordCount: 19, verifiedBy: 'official-admin-and-player-readbacks', caseIds: ['case0', 'case1', 'case2'] } } },
      uiImageFailures: { schema: 1, imports: { failure: { fixture: 'ui-image-failure', baseFixtureSha256: '8'.repeat(64), status: 'ready', targetContentRecordCount: 7, verifiedBy: 'official-admin-and-player-readbacks', caseId: 'failure' } } } };
    const db = { ranks: [{ id: sid('r'), order: 0 }], questions: [{ id: sid('j'), title: '旧题' }], sessions: [{ id: sid('k'), title: '旧场次' }], players: [{ id: sid('p'), totalXp: 100 }],
      game_answer_keys: [], game_question_settings: [], game_question_clues: [], game_session_levels: [], game_clues: [] };
    let player, assignment, question, session;
    const clone = value => structuredClone(value);
    const detail = () => ({ id: assignment.id, player: player.id, session: session.id, status: 'assigned', sessionStatus: 'published', title: session.title, description: session.description,
      minLevel: 1, maxLevel: null, startedAt: '', completedAt: '', completedLevels: 0, totalLevels: 1, currentIndex: 0, presentation: session.presentation,
      levels: [{ ...clone(db.game_session_levels[0]), completedAt: '', wrongCount: 0, locked: false,
        question: { id: question.id, ...Object.fromEntries(['kind', 'title', 'placeholder', 'content', 'options'].map(key => [key, clone(question[key])])) } }] });
    const admin = async (route, body = {}) => {
      writes++;
      if (route === 'questions') {
        question = { id: next(), ...clone(body), status: 'draft', commonClueCount: 0 }; db.questions.push(question);
        db.game_answer_keys.push({ id: next(), question: question.id, acceptedAnswers: clone(body.acceptedAnswers), normalizationVersion: 'nfkc-v1' });
        db.game_question_settings.push({ id: next(), question: question.id, answerMatchMode: body.fuzzyMatch ? 'contains_all' : 'exact', groupName: body.groupName }); return clone(question);
      }
      if (route === 'questions/' + question?.id + '/publish') { question.status = 'published'; return clone(question); }
      if (route === 'sessions') {
        session = { id: next(), ...clone(body), status: 'draft' }; db.sessions.push(session);
        const level = { id: next(), ...clone(body.levels[0]), session: session.id, position: 1 }; db.game_session_levels.push(level);
        for (const [position, value] of body.clues.entries()) { const { levelIndex, ...rest } = clone(value); db.game_clues.push({ id: next(), ...rest, position, session: session.id, sessionLevel: levelIndex === 0 ? level.id : '' }); }
        return clone(session);
      }
      if (route === 'sessions/' + session?.id + '/publish') { session.status = 'published'; return clone(session); }
      if (route === 'players') {
        player = { id: next(), account: body.account, displayName: body.displayName, totalXp: 0, mustChangePassword: true }; password = body.password; db.players.push(player);
        if (fault === 'old-player') db.players[0].totalXp++;
        return clone(player);
      }
      if (route === 'assignments') { assignment = { id: next(), player: body.playerIds[0], session: body.sessionId }; return { results: [{ assignmentId: assignment.id, playerId: player.id, status: 'assigned' }] }; }
      throw new FixtureError('unexpected_fake_admin_write');
    };
    const api = async (route, body, token, method) => {
      if (route === '/api/questions/v1/admin/catalog') return clone(Object.fromEntries(['ranks', 'questions', 'sessions', 'players'].map(key => [key, db[key]])));
      const records = route.match(/^\/api\/collections\/([^/]+)\/records\?/);
      if (records) { const filter = new URL('http://fixture.example' + route).searchParams.get('filter').match(/^(question|session)="([a-z0-9]{15})"$/);
        requireThat(!!filter && Array.isArray(db[records[1]]), 'fake_read_scope'); const items = db[records[1]].filter(row => row[filter[1]] === filter[2]); return { items: clone(items), totalItems: items.length }; }
      if (route === '/api/questions/v1/admin/questions/' + question?.id + '/clues') {
        if (method === 'PATCH') { for (const clue of body.clues) db.game_question_clues.push({ id: next(), ...clone(clue), question: question.id, status: 'active' }); question.commonClueCount = body.clues.length; }
        return { items: clone(db.game_question_clues), version: '9'.repeat(64) };
      }
      if (route === '/api/collections/game_players/auth-with-password') { requireThat(body.identity === player.account && body.password === password, 'fake_auth_identity'); return { token: 'synthetic-token', record: { id: player.id } }; }
      if (route === '/api/questions/v1/me/change-password') { requireThat(token === 'synthetic-token' && body.oldPassword === password && body.password === body.passwordConfirm && !changed, 'fake_password_scope'); password = body.password; changed = true; player.mustChangePassword = false; return { player: clone(player) }; }
      if (route === '/api/questions/v1/me') return clone(player);
      if (route === '/api/questions/v1/assignments') return { items: [clone(assignment)] };
      if (route === '/api/questions/v1/admin/assignments/' + assignment?.id) { const value = detail(); if (fault === 'question-readback') value.levels[0].question.content[0].text = '意外变化'; return value; }
      if (route === '/api/questions/v1/assignments/' + assignment?.id) { const value = detail(); value.levels[0].question = null; return value; }
      throw new FixtureError('unexpected_fake_api_route');
    };
    return { root: ROOT, state, admin, api, superToken: 'synthetic-super-token', save: async () => {}, secret: () => 'Synthetic-' + randomUUID(), writeCount: () => writes };
  };
  const input = { expectedSha256: '8'.repeat(64), expectedDerivationSha256: 'a'.repeat(64), label: 'offline-only' };
  const prepared = fakePrepared(), original = structuredClone(prepared.base.plans[0].questionBody), context = fakeContext();
  check(prepared.questionBody.content[0].imageUrl === original.content[0].imageUrl && prepared.questionBody.content[0].imageUrls.length === 2, 'fake_gallery_order');
  check(canonical(prepared.base.plans[0].questionBody) === canonical(original), 'fake_source_not_mutated');
  const oldState = structuredClone(context.state), result = await createPrepared(input, prepared, context);
  check(result.targetContentRecordCount === 7 && result.nativeLoadVerified === false && result.gameplayStarted === false && result.gameplayAnswered === false, 'fake_seven_not_nineteen');
  check(Object.keys(context.state.gameplay.cases).length === 5 && context.state.gameplay.cases[result.caseId].ordinaryLoginPrepared === true, 'fake_fifth_actor_direct_login');
  check(canonical(context.state.uiContent) === canonical(oldState.uiContent) && canonical(context.state.uiImageFailures) === canonical(oldState.uiImageFailures), 'fake_old_registries_preserved');
  const writes = context.writeCount(); let replay = false;
  try { await createPrepared({ ...input, expectedDerivationSha256: 'b'.repeat(64), label: 'other-label' }, fakePrepared(), context); } catch (error) { replay = error.code === 'viewer_derivation_already_attempted'; }
  check(replay && context.writeCount() === writes, 'fake_source_identity_replay_rejected');
  for (const fault of ['question-readback', 'old-player']) {
    const failedContext = fakeContext(fault); let failed = false;
    try { await createPrepared(input, fakePrepared(), failedContext); } catch (error) { failed = error.code === 'viewer_media_case_incomplete'; }
    const rows = Object.values(failedContext.state.uiViewerMedia.imports);
    check(failed && rows.length === 1 && rows[0].status === 'incomplete', 'fake_failure_reservation');
    const before = failedContext.writeCount(); let blocked = false;
    try { await createPrepared({ ...input, expectedDerivationSha256: 'c'.repeat(64) }, fakePrepared(), failedContext); } catch (error) { blocked = error.code === 'viewer_derivation_already_attempted'; }
    check(blocked && failedContext.writeCount() === before, 'fake_partial_replay_rejected');
  }
  console.log(JSON.stringify({ status: 'passed', scope: 'Pure offline fakeAdmin/API fixture protocol only', checksPassed: checks, filesystemOrNetworkInputsUsed: false, realImportExecuted: false }));
}

async function main() {
  if (!process.argv[2] || ['help', '--help', '-h'].includes(process.argv[2]) || (process.argv[2] === 'prepare' && process.argv.slice(3).some(value => ['--help', '-h'].includes(value)))) {
    console.log('Usage: ui-viewer-media-case.mjs prepare --fixture-file PATH --expected-sha256 SHA --images-manifest PATH --expected-images-manifest-sha256 SHA --media-receipt-file PATH --expected-media-receipt-sha256 SHA --output-dir FRESH_PRIVATE_DIR | self-test'); return;
  }
  try {
    if (process.argv[2] === 'self-test') { requireThat(process.argv.length === 3, 'self_test_arguments'); await selfTest(); return; }
    requireThat(process.argv[2] === 'prepare', 'unknown_command'); const args = process.argv.slice(3), options = {};
    requireThat(args.length % 2 === 0, 'prepare_options_invalid');
    for (let index = 0; index < args.length; index += 2) { requireThat(/^--[a-z0-9-]+$/.test(args[index]) && !Object.hasOwn(options, args[index].slice(2)) && !args[index + 1].startsWith('--'), 'prepare_options_invalid'); options[args[index].slice(2)] = args[index + 1]; }
    await prepare(options);
  } catch { console.log(JSON.stringify({ status: 'not_prepared', error: 'The dedicated mixed-gallery fixture boundary failed; values omitted' })); process.exitCode = 1; }
}
if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) await main();
