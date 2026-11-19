import { GameFailure } from '../business/models';
import { PushSubscription, PushSubscriptionItem, PushSubscriptionList } from '../business/PushSubscription';

function invalid(): GameFailure {
  return new GameFailure('CONTRACT_ERROR', '通知订阅数据暂时无法确认，请重试。');
}

function record(value: Object): Record<string, Object> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) { throw invalid(); }
  return value as Record<string, Object>;
}

function parse(body: string): Record<string, Object> {
  try { return record(JSON.parse(body) as Object); } catch { throw invalid(); }
}

function state(source: Record<string, Object>): PushSubscription {
  if (typeof source['assignmentId'] !== 'string' || (source['assignmentId'] as string).length === 0 ||
    typeof source['subscribed'] !== 'boolean' || typeof source['pushEnabled'] !== 'boolean' ||
    typeof source['revision'] !== 'number' || !Number.isInteger(source['revision'] as number) ||
    (source['revision'] as number) < 0 || (source['pushEnabled'] === true && source['subscribed'] !== true)) {
    throw invalid();
  }
  const result: PushSubscription = new PushSubscription();
  result.assignmentId = source['assignmentId'] as string;
  result.subscribed = source['subscribed'] as boolean;
  result.pushEnabled = source['pushEnabled'] as boolean;
  result.revision = source['revision'] as number;
  return result;
}

export function decodePushSubscription(body: string, assignmentId: string): PushSubscription {
  const result: PushSubscription = state(parse(body));
  if (result.assignmentId !== assignmentId) { throw invalid(); }
  return result;
}

export function decodePushSubscriptions(body: string): PushSubscriptionList {
  const source: Record<string, Object> = parse(body);
  if (!Array.isArray(source['items']) || typeof source['subscriptionApproved'] !== 'boolean') { throw invalid(); }
  const result: PushSubscriptionList = new PushSubscriptionList();
  result.subscriptionApproved = source['subscriptionApproved'] as boolean;
  const rows: Object[] = source['items'] as Object[];
  const seen: string[] = [];
  rows.forEach((value: Object) => {
    const row: Record<string, Object> = record(value);
    const parsed: PushSubscription = state(row);
    if (typeof row['title'] !== 'string' || seen.indexOf(parsed.assignmentId) !== -1) { throw invalid(); }
    const item: PushSubscriptionItem = new PushSubscriptionItem();
    item.assignmentId = parsed.assignmentId;
    item.title = row['title'] as string;
    item.subscribed = parsed.subscribed;
    item.pushEnabled = parsed.pushEnabled;
    item.revision = parsed.revision;
    result.items.push(item);
    seen.push(item.assignmentId);
  });
  return result;
}
