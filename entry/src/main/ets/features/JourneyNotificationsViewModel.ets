import { GameNotification } from '../business/GameNotification';
import { GameRepository } from '../business/GameRepository';
import { ReadCancellation } from '../business/ReadCancellation';
import { GameFailure } from '../business/models';

const POLL_MS: number = 5000;

class RouteArchiveNote {
  readonly assignmentId: string;
  readonly noteId: string;

  constructor(assignmentId: string, noteId: string) {
    this.assignmentId = assignmentId;
    this.noteId = noteId;
  }
}

@ObservedV2
export class JourneyNotificationsViewModel {
  @Trace entries: GameNotification[] = [];
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace activeNotificationId: string = '';
  @Trace readingId: string = '';
  @Trace readErrorId: string = '';
  @Trace readErrorMessage: string = '';
  @Trace gameplayReady: boolean = false;
  @Trace routeArchive: RouteArchiveNote | null = null;
  @Trace newUnreadRevision: number = 0;
  @Trace newUnreadCount: number = 0;
  @Trace unreadClearedRevision: number = 0;
  @Trace automaticDismissedRevision: number = 0;
  @Trace private automaticDismissals: RouteArchiveNote[] = [];
  private owner: string = '';
  private generation: number = 0;
  private pending: ReadCancellation | null = null;
  private timer: number = -1;
  private questDelayTimer: number = -1;
  private questPolling: boolean = false;
  private questDelayReady: boolean = false;
  private questReadReady: boolean = false;
  private inboxPolling: boolean = false;
  private hasBaseline: boolean = false;
  private readonly seenIds: Set<string> = new Set<string>();
  private readonly pendingUnreadIds: Set<string> = new Set<string>();
  private readonly repository: GameRepository;
  private readonly expireSession: (message: string) => void;
  private readonly questDelayMs: number;

  constructor(repository: GameRepository, expireSession: (message: string) => void, questDelayMs: number = POLL_MS) {
    this.repository = repository;
    this.expireSession = expireSession;
    this.questDelayMs = Math.max(0, questDelayMs);
  }

  get unreadCount(): number {
    return this.unreadEntries.length;
  }

  get unreadEntries(): GameNotification[] {
    return this.entries.filter((note: GameNotification) => note.readAt.length === 0);
  }

  get current(): GameNotification | null {
    return this.entries.find((note: GameNotification) => note.id === this.activeNotificationId) ?? null;
  }

  get oldestUnread(): GameNotification | null {
    // The service orders receipts newest-first, including ties.
    for (let index: number = this.entries.length - 1; index >= 0; index--) {
      if (this.entries[index].readAt.length === 0) { return this.entries[index]; }
    }
    return null;
  }

  automaticUnreadOnRoute(assignmentId: string): GameNotification | null {
    if (assignmentId.length === 0) { return null; }
    for (let index: number = this.entries.length - 1; index >= 0; index--) {
      const note: GameNotification = this.entries[index];
      if (note.readAt.length === 0 && !this.automaticDismissals.some((selection: RouteArchiveNote) =>
        selection.assignmentId === assignmentId && selection.noteId === note.id)) { return note; }
    }
    return null;
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.owner = owner;
    this.generation++;
    this.suspend();
    this.entries = [];
    this.error = '';
    this.readingId = '';
    this.readErrorId = '';
    this.readErrorMessage = '';
    this.hasBaseline = false;
    this.seenIds.clear();
    this.dismissNewUnread();
    this.newUnreadRevision = 0;
    this.unreadClearedRevision = 0;
  }

  setPolling(active: boolean): void {
    const next: boolean = active && this.owner.length > 0;
    if (next !== this.questPolling) {
      this.questPolling = next;
      this.resetQuestReadiness();
      if (next) {
        this.questDelayTimer = setTimeout(() => {
          this.questDelayTimer = -1;
          if (!this.questPolling) { return; }
          this.questDelayReady = true;
          this.publishQuestReadiness();
        }, this.questDelayMs);
      }
    }
    this.updatePolling();
  }

  private resetQuestReadiness(): void {
    clearTimeout(this.questDelayTimer);
    this.questDelayTimer = -1;
    this.questDelayReady = false;
    this.questReadReady = false;
    this.gameplayReady = false;
  }

  private publishQuestReadiness(): void {
    this.gameplayReady = this.questPolling && this.questDelayReady && this.questReadReady;
  }

  setInboxPolling(active: boolean): void {
    const starting: boolean = active && !this.inboxPolling && this.owner.length > 0;
    this.inboxPolling = active && this.owner.length > 0;
    this.updatePolling();
    if (starting) { void this.load(false); }
  }

  dismissNewUnread(): void {
    this.pendingUnreadIds.clear();
    this.newUnreadCount = 0;
  }

  private updatePolling(): void {
    if ((this.questPolling || this.inboxPolling) && this.owner.length > 0) {
      if (this.timer === -1) {
        this.timer = setInterval(() => { void this.load(false); }, POLL_MS);
      }
    } else if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
      this.gameplayReady = false;
      this.cancelRead();
    }
  }

  suspend(): void {
    this.pauseReads();
    this.close();
    this.clearRouteArchive();
    this.clearAutomaticDismissals();
  }

  pauseReads(): void {
    this.inboxPolling = false;
    this.setPolling(false);
    this.cancelRead();
  }

  open(id: string): void {
    if (this.owner.length > 0 && this.entries.some((note: GameNotification) => note.id === id)) {
      this.activeNotificationId = id;
    }
  }

  close(): void {
    this.activeNotificationId = '';
  }

  archivedOnRoute(assignmentId: string): GameNotification | null {
    const selection: RouteArchiveNote | null = this.routeArchive;
    if (selection === null || selection.assignmentId !== assignmentId) { return null; }
    return this.entries.find((note: GameNotification) => note.id === selection.noteId) ?? null;
  }

  openRouteArchive(assignmentId: string, id: string): void {
    if (this.owner.length === 0 || assignmentId.length === 0 ||
      !this.unreadEntries.some((note: GameNotification) => note.id === id)) { return; }
    this.routeArchive = new RouteArchiveNote(assignmentId, id);
  }

  clearRouteArchive(): void {
    this.routeArchive = null;
  }

  leaveRoute(assignmentId: string): void {
    const remaining: RouteArchiveNote[] = this.automaticDismissals.filter((selection: RouteArchiveNote) =>
      selection.assignmentId !== assignmentId);
    if (remaining.length !== this.automaticDismissals.length) {
      this.automaticDismissals = remaining;
      this.automaticDismissedRevision++;
    }
    if (this.routeArchive?.assignmentId === assignmentId) { this.clearRouteArchive(); }
  }

  async closeRouteNote(assignmentId: string, id: string, acknowledge: boolean): Promise<void> {
    const selection: RouteArchiveNote | null = this.routeArchive;
    if (selection === null || selection.assignmentId !== assignmentId || selection.noteId !== id) {
      if (this.automaticUnreadOnRoute(assignmentId)?.id === id) {
        if (acknowledge) { await this.markRead(id); } else { this.deferAutomatic(assignmentId, id); }
      }
      return;
    }
    if (acknowledge && !await this.markRead(id)) { return; }
    if (!acknowledge) { this.deferAutomatic(assignmentId, id); }
    if (this.routeArchive === selection) { this.clearRouteArchive(); }
  }

  private deferAutomatic(assignmentId: string, id: string): void {
    if (this.automaticDismissals.some((selection: RouteArchiveNote) =>
      selection.assignmentId === assignmentId && selection.noteId === id)) { return; }
    this.automaticDismissals = [...this.automaticDismissals, new RouteArchiveNote(assignmentId, id)];
    this.automaticDismissedRevision++;
  }

  private clearAutomaticDismissals(): void {
    if (this.automaticDismissals.length === 0) { return; }
    this.automaticDismissals = [];
    this.automaticDismissedRevision++;
  }

  async refresh(): Promise<void> {
    await this.load(true);
  }

  async markRead(id: string): Promise<boolean> {
    if (this.owner.length === 0 || this.readingId.length > 0) { return false; }
    const note: GameNotification | undefined = this.entries.find((item: GameNotification) => item.id === id);
    if (note === undefined) { return false; }
    if (note.readAt.length > 0) { return true; }

    // Supersede a GET started before the receipt write, so it cannot restore an old unread state.
    this.cancelRead();
    const generation: number = this.generation;
    this.readingId = id;
    this.readErrorId = '';
    this.readErrorMessage = '';
    try {
      const readAt: string = await this.repository.readNotification(id);
      if (generation !== this.generation) { return false; }
      this.entries = this.entries.map((item: GameNotification) => item.id === id ? item.withReadAt(readAt) : item);
      this.pendingUnreadIds.delete(id);
      this.newUnreadCount = this.pendingUnreadIds.size;
      if (this.unreadCount === 0) { this.unreadClearedRevision++; }
      return true;
    } catch (error) {
      if (generation === this.generation && !this.endExpiredSession(error as Object)) {
        this.readErrorId = id;
        this.readErrorMessage = this.message(error as Object, '已读状态暂时无法保存，请重试。');
      }
      return false;
    } finally {
      if (generation === this.generation) { this.readingId = ''; }
    }
  }

  private async load(manual: boolean): Promise<void> {
    if (this.owner.length === 0 || this.pending !== null || this.readingId.length > 0) { return; }
    const attempt: ReadCancellation = new ReadCancellation();
    this.pending = attempt;
    if (manual) {
      this.loading = true;
      this.error = '';
    }
    try {
      const entries: GameNotification[] = await this.repository.notifications(attempt);
      if (this.pending !== attempt) { return; }
      this.acceptEntries(entries);
      this.error = '';
      if (!manual && this.questPolling && this.timer !== -1) {
        this.questReadReady = true;
        this.publishQuestReadiness();
      }
      if (this.activeNotificationId.length > 0 &&
        !entries.some((note: GameNotification) => note.id === this.activeNotificationId)) { this.close(); }
    } catch (error) {
      if (this.pending === attempt && !this.endExpiredSession(error as Object) && manual) {
        this.error = this.message(error as Object, '来信暂时无法读取，请重试。');
      }
    } finally {
      if (this.pending === attempt) {
        this.pending = null;
        this.loading = false;
      }
    }
  }

  private acceptEntries(entries: GameNotification[]): void {
    let newUnread: boolean = false;
    if (this.hasBaseline) {
      for (const note of entries) {
        if (note.readAt.length === 0 && !this.seenIds.has(note.id)) {
          this.pendingUnreadIds.add(note.id);
          newUnread = true;
        }
      }
    }
    for (const note of entries) { this.seenIds.add(note.id); }
    for (const id of this.pendingUnreadIds) {
      if (!entries.some((note: GameNotification) => note.id === id && note.readAt.length === 0)) {
        this.pendingUnreadIds.delete(id);
      }
    }
    this.hasBaseline = true;
    this.entries = entries;
    this.newUnreadCount = this.pendingUnreadIds.size;
    if (newUnread) { this.newUnreadRevision++; }
  }

  private cancelRead(): void {
    const pending: ReadCancellation | null = this.pending;
    this.pending = null;
    pending?.cancel();
    this.loading = false;
  }

  private endExpiredSession(error: Object): boolean {
    if (!(error instanceof GameFailure) || (error.status !== 401 && error.code !== 'ACCOUNT_DISABLED' &&
      error.code !== 'PASSWORD_CHANGE_REQUIRED')) { return false; }
    this.bindOwner('');
    this.expireSession(this.message(error, '请重新登录。'));
    return true;
  }

  private message(error: Object, fallback: string): string {
    return error instanceof Error && error.message.length > 0 ? error.message : fallback;
  }
}
