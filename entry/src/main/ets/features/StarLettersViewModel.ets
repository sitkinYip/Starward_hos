import { GameRepository } from '../business/GameRepository';
import { GameplaySnapshot } from '../business/GameplayModels';
import { NarrativeContent } from '../business/NarrativeModels';
import { ReadCancellation } from '../business/ReadCancellation';
import { compareStarLetters, grantedStarLetters, StarLetterEntry, starLetterFinale } from '../business/StarLetters';
import { AssignmentSummary, GameFailure } from '../business/models';

const MAX_PARALLEL_ASSIGNMENTS: number = 4;
const SCOPE_MISMATCH: string = 'STAR_LETTERS_SCOPE_MISMATCH';

export class StarLettersReadError {
  readonly assignmentId: string;
  readonly message: string;

  constructor(assignmentId: string, message: string) {
    this.assignmentId = assignmentId;
    this.message = message;
  }
}

class StarLettersResolution {
  entries: StarLetterEntry[] = [];
  problem: string = '';
}

@ObservedV2
export class StarLettersViewModel {
  @Trace entries: StarLetterEntry[] = [];
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace detailErrors: StarLettersReadError[] = [];
  private owner: string = '';
  private revision: number = 0;
  private assignmentIds: string[] = [];
  private readonly rows = new Map<string, StarLetterEntry[]>();
  private readonly issues = new Map<string, StarLettersReadError>();
  private readonly suppressed = new Set<string>();
  private readonly pending = new Set<ReadCancellation>();
  private readonly repository: GameRepository;
  private readonly expireSession: (message: string) => void;

  constructor(repository: GameRepository, expireSession: (message: string) => void) {
    this.repository = repository;
    this.expireSession = expireSession;
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.owner = owner;
    this.suspend();
    this.suppressed.clear();
    this.clearAssignments();
    this.error = '';
  }

  suspend(): void {
    this.revision++;
    this.pending.forEach((read: ReadCancellation) => read.cancel());
    this.pending.clear();
    this.loading = false;
  }

  canOpen(assignmentId: string, contentId: string): boolean {
    return this.owner.length > 0 && this.entries.some((entry: StarLetterEntry) =>
      entry.assignmentId === assignmentId && entry.contentId === contentId);
  }

  hideEntry(assignmentId: string, contentId: string): void {
    if (!this.canOpen(assignmentId, contentId)) { return; }
    this.suppressed.add(`${assignmentId}:${contentId}`);
    this.rows.set(assignmentId, (this.rows.get(assignmentId) ?? []).filter((entry: StarLetterEntry) =>
      entry.contentId !== contentId));
    this.publish();
  }

  async refresh(): Promise<void> {
    if (this.owner.length === 0 || this.loading) { return; }
    const revision: number = ++this.revision;
    this.loading = true;
    this.error = '';
    try {
      const summaries: AssignmentSummary[] = await this.read((attempt: ReadCancellation) =>
        this.repository.assignments(attempt));
      if (revision !== this.revision) { return; }
      if (summaries.some((item: AssignmentSummary) => item.player !== this.owner || item.id.length === 0)) {
        throw new GameFailure(SCOPE_MISMATCH, '信笺目录与当前账号不一致，请重试。');
      }
      this.acceptAssignments(summaries);
      for (let offset: number = 0; revision === this.revision && offset < this.assignmentIds.length;
        offset += MAX_PARALLEL_ASSIGNMENTS) {
        await Promise.all(this.assignmentIds.slice(offset, offset + MAX_PARALLEL_ASSIGNMENTS)
          .map((id: string) => this.loadAssignment(id, revision)));
      }
    } catch (error) {
      if (revision === this.revision && !this.endExpiredSession(error as Object)) {
        if (this.accessLost(error as Object)) { this.clearAssignments(); }
        this.error = this.message(error as Object);
      }
    } finally {
      if (revision === this.revision) { this.loading = false; }
    }
  }

  async retryAssignment(assignmentId: string): Promise<void> {
    if (this.loading || this.owner.length === 0 || !this.assignmentIds.includes(assignmentId)) { return; }
    const revision: number = ++this.revision;
    this.loading = true;
    try {
      await this.loadAssignment(assignmentId, revision);
    } finally {
      if (revision === this.revision) { this.loading = false; }
    }
  }

  private async loadAssignment(id: string, revision: number): Promise<void> {
    try {
      const snapshot: GameplaySnapshot = await this.read((attempt: ReadCancellation) =>
        this.repository.gameplay(id, attempt));
      if (revision !== this.revision) { return; }
      if (snapshot.detail.id !== id || snapshot.detail.player !== this.owner) {
        throw new GameFailure(SCOPE_MISMATCH, '信笺来源与当前账号不一致，请重试。');
      }
      const result: StarLettersResolution = await this.resolveEntries(snapshot, revision);
      if (revision !== this.revision) { return; }
      this.rows.set(id, result.entries.filter((entry: StarLetterEntry) => !this.suppressed.has(entry.id)));
      if (result.problem.length > 0) {
        this.issues.set(id, new StarLettersReadError(id, result.problem));
      } else {
        this.issues.delete(id);
      }
    } catch (error) {
      if (revision !== this.revision || this.endExpiredSession(error as Object)) { return; }
      if (this.accessLost(error as Object)) { this.rows.delete(id); }
      this.issues.set(id, new StarLettersReadError(id, this.message(error as Object)));
    }
    this.publish();
  }

  private async resolveEntries(snapshot: GameplaySnapshot, revision: number): Promise<StarLettersResolution> {
    const resolution: StarLettersResolution = new StarLettersResolution();
    const id: string = snapshot.detail.id;
    const clues: StarLetterEntry[] = grantedStarLetters(snapshot);
    const probes: StarLetterEntry[] = [];
    for (const entry of clues) {
      if (this.suppressed.has(entry.id)) { probes.push(entry); } else { resolution.entries.push(entry); }
    }
    const finale: StarLetterEntry | null = starLetterFinale(snapshot);
    if (finale !== null && !clues.some((entry: StarLetterEntry) => entry.id === finale.id)) { probes.push(finale); }
    for (const entry of probes) {
      if (revision !== this.revision) { break; }
      try {
        const content: NarrativeContent = await this.read((attempt: ReadCancellation) =>
          this.repository.narrative(id, entry.contentId, attempt));
        if (revision !== this.revision) { break; }
        if (content.id !== entry.contentId) {
          throw new GameFailure(SCOPE_MISMATCH, '信笺内容与当前来源不一致，请重试。');
        }
        if (content.hasPresentation()) {
          this.suppressed.delete(entry.id);
          resolution.entries.push(entry);
        }
      } catch (error) {
        if (revision !== this.revision) { break; }
        if (this.endExpiredSession(error as Object)) { break; }
        if (!this.accessLost(error as Object) && !this.suppressed.has(entry.id) &&
          (this.rows.get(id) ?? []).some((previous: StarLetterEntry) => previous.id === entry.id)) {
          resolution.entries.push(entry);
        }
        if (resolution.problem.length === 0) { resolution.problem = this.message(error as Object); }
      }
    }
    return resolution;
  }

  private acceptAssignments(summaries: AssignmentSummary[]): void {
    const ids: Set<string> = new Set<string>();
    for (const item of summaries) {
      if (item.status !== 'cancelled') { ids.add(item.id); }
    }
    for (const id of this.assignmentIds) {
      if (!ids.has(id)) {
        this.rows.delete(id);
        this.issues.delete(id);
      }
    }
    this.assignmentIds = Array.from(ids);
    this.publish();
  }

  private clearAssignments(): void {
    this.assignmentIds = [];
    this.rows.clear();
    this.issues.clear();
    this.publish();
  }

  private publish(): void {
    const entries: StarLetterEntry[] = [];
    const errors: StarLettersReadError[] = [];
    for (const id of this.assignmentIds) {
      const rows: StarLetterEntry[] | undefined = this.rows.get(id);
      if (rows !== undefined) { entries.push(...rows); }
      const issue: StarLettersReadError | undefined = this.issues.get(id);
      if (issue !== undefined) { errors.push(issue); }
    }
    this.entries = entries.sort(compareStarLetters);
    this.detailErrors = errors;
  }

  private async read<T>(operation: (attempt: ReadCancellation) => Promise<T>): Promise<T> {
    const attempt: ReadCancellation = new ReadCancellation();
    this.pending.add(attempt);
    try {
      return await operation(attempt);
    } finally {
      this.pending.delete(attempt);
    }
  }

  private sessionExpired(error: Object): boolean {
    return error instanceof GameFailure && (error.status === 401 || error.code === 'ACCOUNT_DISABLED' ||
      error.code === 'PASSWORD_CHANGE_REQUIRED');
  }

  private endExpiredSession(error: Object): boolean {
    if (!this.sessionExpired(error)) { return false; }
    this.bindOwner('');
    this.expireSession(this.message(error));
    return true;
  }

  private accessLost(error: Object): boolean {
    return error instanceof GameFailure && (error.status === 403 || error.status === 404 || error.status === 410 ||
      error.code === 'SESSION_OFFLINE' || error.code === SCOPE_MISMATCH);
  }

  private message(error: Object): string {
    return error instanceof Error && error.message.length > 0 ? error.message : '信笺暂时无法读取，请稍后重试。';
  }
}
