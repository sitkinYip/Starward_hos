import { GameRepository } from '../business/GameRepository';
import { GameReward } from '../business/GameReward';
import { GameFailure } from '../business/models';
import { ReadCancellation } from '../business/ReadCancellation';

const POLL_MS: number = 5000;

@ObservedV2
export class RewardsViewModel {
  @Trace entries: GameReward[] = [];
  @Trace selected: GameReward | null = null;
  @Trace loading: boolean = false;
  @Trace loaded: boolean = false;
  @Trace error: string = '';
  @Trace showSyncNotice: boolean = false;
  private owner: string = '';
  private active: boolean = false;
  private syncFailed: boolean = false;
  private pending: ReadCancellation | null = null;
  private timer: number = -1;
  private readonly repository: GameRepository;
  private readonly rejectSession: (error: Object) => void;

  constructor(repository: GameRepository, rejectSession: (error: Object) => void) {
    this.repository = repository;
    this.rejectSession = rejectSession;
  }

  bindOwner(owner: string): void {
    if (this.owner === owner) { return; }
    this.setActive(false);
    this.owner = owner;
    this.clear();
    this.error = '';
  }

  setActive(active: boolean): void {
    const visible: boolean = active && this.owner.length > 0;
    if (this.active === visible) { return; }
    this.active = visible;
    if (visible) {
      void this.refresh();
    } else {
      this.cancelRead();
      this.close();
      this.dismissSyncNotice();
    }
  }

  open(id: string): void {
    if (this.active) {
      this.selected = this.entries.find((item: GameReward) => item.id === id) ?? null;
    }
  }

  close(): void {
    this.selected = null;
  }

  dismissSyncNotice(): void {
    this.showSyncNotice = false;
  }

  async refresh(): Promise<void> {
    if (!this.active) { return; }
    // An explicit refresh supersedes a poll with a new account-bound read.
    this.cancelRead();
    await this.load(true);
  }

  private clear(): void {
    this.entries = [];
    this.loaded = false;
    this.close();
    this.resolveSyncFailure();
  }

  private resolveSyncFailure(): void {
    this.syncFailed = false;
    this.dismissSyncNotice();
  }

  private cancelRead(): void {
    clearTimeout(this.timer);
    this.timer = -1;
    const previous: ReadCancellation | null = this.pending;
    this.pending = null;
    previous?.cancel();
    this.loading = false;
  }

  private async load(showProgress: boolean): Promise<void> {
    if (!this.active || this.pending !== null) { return; }
    const attempt: ReadCancellation = new ReadCancellation();
    const owner: string = this.owner;
    this.pending = attempt;
    this.loading = showProgress || !this.loaded;
    if (showProgress) { this.error = ''; }
    try {
      const rewards: GameReward[] = await this.repository.rewards(attempt);
      if (this.pending !== attempt) { return; }
      if (rewards.some((reward: GameReward) => reward.player !== owner)) {
        throw new GameFailure('REWARDS_SCOPE_MISMATCH', '收藏与当前账号不一致，请重试。');
      }
      const open: GameReward | null = this.selected;
      this.entries = rewards;
      if (open !== null) {
        const latest: GameReward | undefined = rewards.find((reward: GameReward) => reward.id === open.id);
        if (latest === undefined || !open.sameDetails(latest)) { this.selected = latest ?? null; }
      }
      this.loaded = true;
      this.error = '';
      this.resolveSyncFailure();
    } catch (error) {
      if (this.pending !== attempt) { return; }
      this.acceptError(error as Object);
    } finally {
      if (this.pending === attempt) {
        this.pending = null;
        this.loading = false;
        this.timer = setTimeout(() => {
          this.timer = -1;
          void this.load(false);
        }, POLL_MS);
      }
    }
  }

  private acceptError(error: Object): void {
    if (error instanceof GameFailure) {
      if (error.code === 'CANCELLED') { return; }
      if (error.status === 401 || error.code === 'ACCOUNT_DISABLED' || error.code === 'PASSWORD_CHANGE_REQUIRED') {
        this.clear();
        this.rejectSession(error);
        return;
      }
      if (error.status === 403 || error.status === 404 || error.status === 410 ||
        error.code === 'REWARDS_SCOPE_MISMATCH') {
        this.clear();
      } else if (this.loaded && this.transientFailure(error)) {
        this.error = '';
        if (!this.syncFailed) {
          this.syncFailed = true;
          this.showSyncNotice = true;
        }
        return;
      }
    }
    this.resolveSyncFailure();
    this.error = error instanceof Error && error.message.length > 0 ? error.message : '暂时无法打开收藏。';
  }

  private transientFailure(error: GameFailure): boolean {
    if (error.code === 'CONTRACT_ERROR') { return false; }
    return error.code === 'NETWORK_ERROR' || error.code === 'TIMEOUT' || error.status === 408 ||
      error.status === 429 || (error.status >= 500 && error.status < 600);
  }
}
