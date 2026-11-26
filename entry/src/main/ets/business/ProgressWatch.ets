export const PROGRESS_EVENT_KINDS: string[] = ['correct', 'incorrect', 'completed'];

export class ProgressWatch {
  id: string = '';
  assignmentId: string = '';
  playerName: string = '';
  title: string = '';
  expiresAt: string = '';
  status: string = '';
  subscribed: boolean = false;
  pushEnabled: boolean = false;
  eventKinds: string[] = [];
  revision: number = 0;
}

export class ProgressWatchList {
  items: ProgressWatch[] = [];
}

export class ProgressAttempt {
  id: string = '';
  position: number = 0;
  result: string = '';
  submittedAt: string = '';
}

export class ProgressWatchDetail {
  watch: ProgressWatch = new ProgressWatch();
  pushAvailable: boolean = false;
  solved: number = 0;
  total: number = 0;
  currentPosition: number = 0;
  completedAt: string = '';
  recent: ProgressAttempt[] = [];
}

export class ProgressWatchCommand {
  readonly requestId: string;
  readonly expectedRevision: number;
  readonly subscribed: boolean;
  readonly pushEnabled: boolean;
  readonly eventKinds: string[];

  constructor(requestId: string, revision: number, subscribed: boolean, pushEnabled: boolean, eventKinds: string[]) {
    this.requestId = requestId;
    this.expectedRevision = revision;
    this.subscribed = subscribed;
    this.pushEnabled = pushEnabled;
    this.eventKinds = eventKinds.slice();
  }
}
