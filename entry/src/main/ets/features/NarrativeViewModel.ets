import { GameRepository } from '../business/GameRepository';
import { NarrativeContent } from '../business/NarrativeModels';
import { ReadCancellation } from '../business/ReadCancellation';
import { GameFailure } from '../business/models';

type NarrativeSource = 'quest' | 'quest-clue' | 'star-letters' | 'journey';

export class NarrativeRoute {
  readonly assignmentId: string;
  readonly contentId: string;
  readonly source: NarrativeSource;

  constructor(assignmentId: string, contentId: string, source: NarrativeSource = 'quest') {
    this.assignmentId = assignmentId;
    this.contentId = contentId;
    this.source = source;
  }
}

@ObservedV2
export class NarrativeViewModel {
  @Trace route: NarrativeRoute | null = null;
  @Trace content: NarrativeContent | null = null;
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace retryable: boolean = false;
  @Trace revision: number = 0;
  accessLost: boolean = false;
  private owner: string = '';
  private pending: ReadCancellation | null = null;
  private readonly repository: GameRepository;
  private readonly expireSession: (message: string) => void;

  constructor(repository: GameRepository, expireSession: (message: string) => void) {
    this.repository = repository;
    this.expireSession = expireSession;
  }

  bindOwner(owner: string): void {
    if (owner !== this.owner) {
      this.close();
      this.owner = owner;
    }
  }

  open(route: NarrativeRoute): boolean {
    if (this.route !== null || this.owner.length === 0 || route.assignmentId.length === 0 ||
      route.contentId.length === 0) { return false; }
    this.revision++;
    this.route = route;
    this.read(route);
    return true;
  }

  retry(): void {
    const route: NarrativeRoute | null = this.route;
    if (route !== null && this.retryable && !this.loading) { this.read(route); }
  }

  close(): void {
    const pending: ReadCancellation | null = this.pending;
    this.pending = null;
    pending?.cancel();
    this.content = null;
    this.route = null;
    this.loading = false;
    this.error = '';
    this.retryable = false;
    this.accessLost = false;
  }

  private async read(route: NarrativeRoute): Promise<void> {
    const attempt: ReadCancellation = new ReadCancellation();
    this.pending = attempt;
    this.loading = true;
    this.error = '';
    this.retryable = false;
    this.accessLost = false;
    try {
      const content: NarrativeContent = await this.repository.narrative(route.assignmentId, route.contentId, attempt);
      if (this.pending !== attempt) { return; }
      if (content.hasPresentation()) {
        this.content = content;
      } else {
        this.error = '这份剧情暂不可阅读。';
      }
    } catch (error) {
      if (this.pending !== attempt) { return; }
      const message: string = error instanceof Error && error.message.length > 0 ? error.message :
        '故事暂时无法打开，请稍后重试。';
      if (error instanceof GameFailure && (error.status === 401 || error.code === 'ACCOUNT_DISABLED' ||
        error.code === 'PASSWORD_CHANGE_REQUIRED')) {
        this.expireSession(message);
      } else {
        this.error = message;
        this.retryable = true;
        this.accessLost = error instanceof GameFailure && (error.status === 403 || error.status === 404 ||
          error.status === 410 || error.code === 'SESSION_OFFLINE');
      }
    } finally {
      if (this.pending === attempt) {
        this.pending = null;
        this.loading = false;
      }
    }
  }
}
