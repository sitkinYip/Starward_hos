/** Specific scene subscriptions are server facts, separate from OS notification permission. */
export class PushSubscription {
  assignmentId: string = '';
  subscribed: boolean = false;
  pushEnabled: boolean = false;
  revision: number = 0;
}

export class PushSubscriptionItem extends PushSubscription {
  title: string = '';
  /** Projection of the current assignment list; historical subscriptions remain cancellable. */
  available: boolean = true;
}

export class PushSubscriptionList {
  items: PushSubscriptionItem[] = [];
  subscriptionApproved: boolean = false;
}

/** A command keeps its identity, payload and initiating revision across explicit retries. */
export class PushSubscriptionCommand {
  readonly requestId: string;
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
