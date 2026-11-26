import { AssignmentDetail, AssignmentSummary, ExtraDisplay, GameFailure, Player, Rank } from '../business/models';
import { GameNotification } from '../business/GameNotification';
import { GameReward } from '../business/GameReward';
import { LobbyFeed } from '../business/LobbyFeed';
import { PROGRESS_EVENT_KINDS, ProgressAttempt, ProgressWatch, ProgressWatchDetail, ProgressWatchList } from '../business/ProgressWatch';

export class LoginResult {
  token: string = '';
  playerId: string = '';
}

export class PasswordResult {
  token: string = '';
  player: Player = new Player();
}

function contractFailure(): GameFailure {
  return new GameFailure('CONTRACT_ERROR', '服务返回了不兼容的数据，请更新应用或联系管理员。');
}

function record(value: Object): Record<string, Object> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw contractFailure();
  }
  return value as Record<string, Object>;
}

function parse(body: string): Record<string, Object> {
  try {
    const value: Object = JSON.parse(body) as Object;
    return record(value);
  } catch (error) {
    throw contractFailure();
  }
}

function stringField(source: Record<string, Object>, name: string, nonempty: boolean = false): string {
  const value: Object = source[name];
  if (typeof value !== 'string' || (nonempty && value.length === 0)) {
    throw contractFailure();
  }
  return value as string;
}

function intField(source: Record<string, Object>, name: string): number {
  const value: Object = source[name];
  if (typeof value !== 'number' || !Number.isFinite(value as number) ||
    !Number.isInteger(value as number) || (value as number) < 0) {
    throw contractFailure();
  }
  return value as number;
}

function boolField(source: Record<string, Object>, name: string): boolean {
  const value: Object = source[name];
  if (typeof value !== 'boolean') {
    throw contractFailure();
  }
  return value as boolean;
}

function dateField(source: Record<string, Object>, name: string, required: boolean = false): string {
  const value: string = stringField(source, name, required);
  if (value.length > 0 && !Number.isFinite(Date.parse(value))) {
    throw contractFailure();
  }
  return value;
}

function decodeRank(value: Object): Rank {
  const source: Record<string, Object> = record(value);
  const rank: Rank = new Rank();
  rank.id = stringField(source, 'id', true);
  rank.order = intField(source, 'order');
  rank.name = stringField(source, 'name');
  rank.minTotalXp = intField(source, 'minTotalXp');
  return rank;
}

export function decodeExtraDisplay(value: Object): ExtraDisplay[] {
  // Match the formal Web extra.schema.ts optional-namespace compatibility:
  // isolate malformed historical extensions while keeping required DTO fields strict.
  const result: ExtraDisplay[] = [];
  if (!Array.isArray(value)) {
    return result;
  }
  const values: Object[] = value as Object[];
  const seen: string[] = [];
  for (let i: number = 0; i < Math.min(values.length, 100); i++) {
    const item: Object = values[i];
    if (item === null || typeof item !== 'object' || Array.isArray(item)) {
      continue;
    }
    const source: Record<string, Object> = item as Record<string, Object>;
    const key: Object = source['key'];
    const label: Object = source['label'];
    const text: Object = source['text'];
    if (typeof key !== 'string' || key.length > 60 || typeof label !== 'string' || label.length > 100 ||
      typeof text !== 'string' || text.length > 4000 || seen.indexOf(key as string) !== -1) {
      continue;
    }
    const display: ExtraDisplay = new ExtraDisplay();
    display.key = key as string;
    display.label = label as string;
    display.text = text as string;
    result.push(display);
    seen.push(display.key);
  }
  return result;
}

function playerFrom(value: Object): Player {
  const source: Record<string, Object> = record(value);
  const player: Player = new Player();
  player.id = stringField(source, 'id', true);
  player.account = stringField(source, 'account', true);
  player.displayName = stringField(source, 'displayName');
  player.avatar = stringField(source, 'avatar');
  player.mustChangePassword = boolField(source, 'mustChangePassword');
  player.totalXp = intField(source, 'totalXp');
  player.level = decodeRank(source['level']);
  const next: Object = source['nextLevel'];
  player.nextLevel = next === null ? null : decodeRank(next);
  player.extraDisplay = decodeExtraDisplay(source['extraDisplay']);
  return player;
}

function fillSummary(target: AssignmentSummary, source: Record<string, Object>): void {
  target.id = stringField(source, 'id', true);
  target.player = stringField(source, 'player', true);
  target.session = stringField(source, 'session', true);
  target.status = stringField(source, 'status', true);
  if (target.status !== 'assigned' && target.status !== 'active' &&
    target.status !== 'completed' && target.status !== 'cancelled') {
    throw contractFailure();
  }
  target.order = intField(source, 'order');
  target.startsAt = dateField(source, 'startsAt');
  target.endsAt = dateField(source, 'endsAt');
  target.startedAt = dateField(source, 'startedAt');
  target.completedAt = dateField(source, 'completedAt');
  target.previousAssignment = stringField(source, 'previousAssignment');
  target.title = stringField(source, 'title');
  target.description = stringField(source, 'description');
  target.minLevel = intField(source, 'minLevel');
  target.maxLevel = source['maxLevel'] === null ? null : intField(source, 'maxLevel');
  target.completedLevels = intField(source, 'completedLevels');
  target.totalLevels = intField(source, 'totalLevels');
  if (target.completedLevels > target.totalLevels) {
    throw contractFailure();
  }
}

export function decodeLogin(body: string): LoginResult {
  const source: Record<string, Object> = parse(body);
  const result: LoginResult = new LoginResult();
  result.token = stringField(source, 'token', true);
  result.playerId = stringField(record(source['record']), 'id', true);
  return result;
}

export function decodePlayer(body: string): Player {
  return playerFrom(parse(body));
}

export function decodePassword(body: string): PasswordResult {
  const source: Record<string, Object> = parse(body);
  const result: PasswordResult = new PasswordResult();
  result.token = stringField(source, 'token', true);
  result.player = playerFrom(source['player']);
  return result;
}

export function decodeFileToken(body: string): string {
  return stringField(parse(body), 'token', true);
}

export function decodeAssignments(body: string): AssignmentSummary[] {
  return decodeAssignmentItems(parse(body)['items']);
}

function decodeAssignmentItems(items: Object): AssignmentSummary[] {
  if (!Array.isArray(items)) {
    throw contractFailure();
  }
  const values: Object[] = items as Object[];
  const result: AssignmentSummary[] = [];
  for (let i: number = 0; i < values.length; i++) {
    const summary: AssignmentSummary = new AssignmentSummary();
    fillSummary(summary, record(values[i]));
    result.push(summary);
  }
  return result;
}

export function decodeNotifications(body: string): GameNotification[] {
  return decodeNotificationItems(parse(body)['items']);
}

function decodeNotificationItems(items: Object): GameNotification[] {
  if (!Array.isArray(items)) { throw contractFailure(); }
  const ids: Set<string> = new Set<string>();
  return (items as Object[]).map((value: Object) => {
    const note: Record<string, Object> = record(value);
    const id: string = stringField(note, 'id', true);
    if (ids.has(id)) { throw contractFailure(); }
    ids.add(id);
    return new GameNotification(id, stringField(note, 'title'), stringField(note, 'content'),
      stringField(note, 'popupTitle'), stringField(note, 'buttonText'), dateField(note, 'sentAt', true),
      dateField(note, 'readAt'), stringField(note, 'assignmentId'));
  });
}

export function decodeRewards(body: string, playerId: string): GameReward[] {
  return decodeRewardItems(parse(body)['items'], playerId);
}

function decodeRewardItems(items: Object, playerId: string): GameReward[] {
  if (!Array.isArray(items)) { throw contractFailure(); }
  const ids: Set<string> = new Set<string>();
  return (items as Object[]).map((value: Object) => {
    const source: Record<string, Object> = record(value);
    const reward: GameReward = new GameReward();
    reward.id = stringField(source, 'id', true);
    reward.player = stringField(source, 'player', true);
    if (reward.player !== playerId) {
      throw new GameFailure('REWARDS_SCOPE_MISMATCH', '收藏与当前账号不一致，请重试。');
    }
    if (ids.has(reward.id)) { throw contractFailure(); }
    ids.add(reward.id);
    reward.assignment = stringField(source, 'assignment');
    reward.quantity = intField(source, 'quantity');
    const status: string = stringField(source, 'status');
    if (status !== 'available' && status !== 'redeemed' && status !== 'voided') { throw contractFailure(); }
    reward.status = status;
    const claimDetails: string = stringField(source, 'claimDetails');
    reward.claimDetails = status === 'available' ? claimDetails : '';
    reward.redeemedAt = dateField(source, 'redeemedAt');
    reward.created = dateField(source, 'created', true);
    const snapshot: Record<string, Object> = record(source['snapshot']);
    reward.snapshot.id = stringField(snapshot, 'id', true);
    reward.snapshot.name = stringField(snapshot, 'name', true);
    reward.snapshot.image = stringField(snapshot, 'image');
    reward.snapshot.description = stringField(snapshot, 'description');
    const method: string = stringField(snapshot, 'claimMethod');
    if (method !== 'staff' && method !== 'location' && method !== 'locker') { throw contractFailure(); }
    reward.snapshot.claimMethod = method;
    reward.snapshot.publicInstructions = stringField(snapshot, 'publicInstructions');
    return reward;
  });
}

export function decodeNotificationReceipt(body: string): string {
  return dateField(parse(body), 'readAt', true);
}

export function decodeLobbyFeed(body: string, playerId: string): LobbyFeed {
  const source: Record<string, Object> = parse(body);
  const result: LobbyFeed = new LobbyFeed();
  result.assignments = decodeAssignmentItems(record(source['assignments'])['items']);
  if (result.assignments.some((item: AssignmentSummary) => item.player !== playerId)) { throw contractFailure(); }
  result.rewards = decodeRewardItems(record(source['rewards'])['items'], playerId);
  result.notifications = decodeNotificationItems(record(source['notifications'])['items']);
  return result;
}

export function decodeNotificationReceipts(body: string, requested: string[]): Map<string, string> {
  const items: Object = parse(body)['items'];
  if (!Array.isArray(items)) { throw contractFailure(); }
  const allowed: Set<string> = new Set(requested);
  const receipts: Map<string, string> = new Map();
  for (const item of items as Object[]) {
    const source: Record<string, Object> = record(item);
    const id: string = stringField(source, 'id', true);
    if (!allowed.has(id) || receipts.has(id)) { throw contractFailure(); }
    receipts.set(id, dateField(source, 'readAt', true));
  }
  return receipts;
}

export function decodeAssignment(body: string): AssignmentDetail {
  const source: Record<string, Object> = parse(body);
  const detail: AssignmentDetail = new AssignmentDetail();
  fillSummary(detail, source);
  detail.currentIndex = intField(source, 'currentIndex');
  detail.serverTime = dateField(source, 'serverTime', true);
  detail.extraDisplay = decodeExtraDisplay(source['extraDisplay']);
  // Legacy start receipts can omit effects, so retain only the pre-entry grant identities here.
  const clues: Object = source['clues'];
  if (clues !== undefined) {
    if (!Array.isArray(clues)) { throw contractFailure(); }
    const values: Object[] = clues as Object[];
    detail.clueIds = values.map((item: Object) => stringField(record(item), 'id', true));
  }
  return detail;
}

function decodeProgressWatch(value: Object): ProgressWatch {
  const source: Record<string, Object> = record(value);
  const watch: ProgressWatch = new ProgressWatch();
  watch.id = stringField(source, 'id', true);
  watch.assignmentId = stringField(source, 'assignmentId', true);
  watch.playerName = stringField(source, 'playerName', true);
  watch.title = stringField(source, 'title', true);
  watch.expiresAt = dateField(source, 'expiresAt', true);
  watch.status = stringField(source, 'status');
  watch.revision = intField(source, 'revision');
  watch.subscribed = boolField(source, 'subscribed');
  watch.pushEnabled = boolField(source, 'pushEnabled');
  const kinds: Object = source['eventKinds'];
  if (!/^[a-z0-9]{15}$/.test(watch.id) || !['assigned', 'active', 'completed'].includes(watch.status) ||
    !Number.isSafeInteger(watch.revision) || watch.revision < 1 || !Array.isArray(kinds)) { throw contractFailure(); }
  for (const kind of kinds as Object[]) {
    if (typeof kind !== 'string' || !PROGRESS_EVENT_KINDS.includes(kind as string) ||
      watch.eventKinds.includes(kind as string)) { throw contractFailure(); }
    watch.eventKinds.push(kind as string);
  }
  if (watch.subscribed !== (watch.eventKinds.length > 0) || (watch.pushEnabled && !watch.subscribed)) {
    throw contractFailure();
  }
  return watch;
}

export function decodeProgressWatchList(body: string): ProgressWatchList {
  const source: Record<string, Object> = parse(body);
  const items: Object = source['items'];
  if (!Array.isArray(items)) { throw contractFailure(); }
  const list: ProgressWatchList = new ProgressWatchList();
  list.items = (items as Object[]).map((item: Object) => decodeProgressWatch(item));
  return list;
}

export function decodeProgressWatchDetail(body: string, id: string): ProgressWatchDetail {
  const source: Record<string, Object> = parse(body);
  const detail: ProgressWatchDetail = new ProgressWatchDetail();
  detail.watch = decodeProgressWatch(source['watch']);
  detail.pushAvailable = boolField(source, 'pushAvailable');
  detail.solved = intField(source, 'solved');
  detail.total = intField(source, 'total');
  detail.currentPosition = intField(source, 'currentPosition');
  detail.completedAt = dateField(source, 'completedAt');
  const recent: Object = source['recent'];
  if (detail.watch.id !== id || detail.solved > detail.total || !Array.isArray(recent) || recent.length > 20) {
    throw contractFailure();
  }
  detail.recent = (recent as Object[]).map((item: Object): ProgressAttempt => {
    const row: Record<string, Object> = record(item);
    const attempt: ProgressAttempt = new ProgressAttempt();
    attempt.id = stringField(row, 'id', true);
    attempt.position = intField(row, 'position');
    attempt.result = stringField(row, 'result');
    attempt.submittedAt = dateField(row, 'submittedAt', true);
    if (attempt.position < 1 || !['correct', 'incorrect'].includes(attempt.result)) { throw contractFailure(); }
    return attempt;
  });
  return detail;
}

export function decodeApiFailure(body: string, status: number): GameFailure {
  let code: string = status === 401 ? 'UNAUTHORIZED' : 'REQUEST_FAILED';
  let message: string = status === 401 ? '账号或密码不正确' : '请求失败，请检查输入或联系游戏管理员';
  try {
    const source: Record<string, Object> = parse(body);
    const nested: Object = source['error'];
    if (nested !== null && typeof nested === 'object' && !Array.isArray(nested)) {
      const error: Record<string, Object> = record(nested);
      if (typeof error['code'] === 'string') {
        code = error['code'] as string;
      }
      if (typeof error['message'] === 'string') {
        message = error['message'] as string;
      }
    }
    // PocketBase auth failures use a different top-level schema. Keep the localized fallback.
  } catch (error) {
    // Proxies may return non-JSON error bodies; status still determines failure.
  }
  return new GameFailure(code, message, status);
}
