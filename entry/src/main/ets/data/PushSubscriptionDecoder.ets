import { GameFailure } from '../business/models';
import { JourneyPushSubscription, PERSONAL_JOURNEY_SCOPE } from '../business/PushSubscription';

function invalid(): GameFailure {
  return new GameFailure('CONTRACT_ERROR', '通知订阅数据暂时无法确认，请重试。');
}

export function decodeJourneyPushSubscription(body: string): JourneyPushSubscription {
  let parsed: Object;
  try { parsed = JSON.parse(body) as Object; } catch { throw invalid(); }
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) { throw invalid(); }
  const source: Record<string, Object> = parsed as Record<string, Object>;
  if (source['scope'] !== PERSONAL_JOURNEY_SCOPE || typeof source['subscribed'] !== 'boolean' ||
    typeof source['pushEnabled'] !== 'boolean' || typeof source['subscriptionApproved'] !== 'boolean' ||
    typeof source['revision'] !== 'number' || !Number.isInteger(source['revision'] as number) ||
    (source['revision'] as number) < 0 || (source['revision'] as number) > Number.MAX_SAFE_INTEGER ||
    (source['pushEnabled'] === true && source['subscribed'] !== true)) { throw invalid(); }
  const result: JourneyPushSubscription = new JourneyPushSubscription();
  result.subscribed = source['subscribed'] as boolean;
  result.pushEnabled = source['pushEnabled'] as boolean;
  result.revision = source['revision'] as number;
  result.subscriptionApproved = source['subscriptionApproved'] as boolean;
  return result;
}
