/** One explicitly agreed scope, separate from OS permission and former per-scene consent. */
export const PERSONAL_JOURNEY_SCOPE: string = 'personal_journey_v1';

export class JourneyPushSubscription {
  scope: string = PERSONAL_JOURNEY_SCOPE;
  subscribed: boolean = false;
  pushEnabled: boolean = false;
  revision: number = 0;
  subscriptionApproved: boolean = false;
}

/** A command keeps its identity, payload and initiating revision across explicit retries. */
export class PushSubscriptionCommand {
  readonly requestId: string;
  readonly scope: string = PERSONAL_JOURNEY_SCOPE;
  readonly subscribed: boolean;
  readonly pushEnabled: boolean;
  readonly expectedRevision: number;

  constructor(requestId: string, subscribed: boolean, pushEnabled: boolean, expectedRevision: number) {
    this.requestId = requestId;
    this.subscribed = subscribed;
    this.pushEnabled = pushEnabled;
    this.expectedRevision = expectedRevision;
  }
}
