import { GameRepository } from '../business/GameRepository';
import { completionCombinations } from '../business/GameplayClues';
import { GameplayAnswerResult, GameplayClue, GameplayLevel, GameplaySnapshot } from '../business/GameplayModels';
import { GameFailure, Player } from '../business/models';
import { createRequestIdentity } from '../platform/RequestIdentity';

class EntryIntent {
  assignmentId: string;
  requestId: string;

  constructor(assignmentId: string, requestId: string) {
    this.assignmentId = assignmentId;
    this.requestId = requestId;
  }
}

class AnswerIntent {
  assignmentId: string;
  sessionLevelId: string;
  answer: string;
  requestId: string;

  constructor(assignmentId: string, sessionLevelId: string, answer: string, requestId: string) {
    this.assignmentId = assignmentId;
    this.sessionLevelId = sessionLevelId;
    this.answer = answer;
    this.requestId = requestId;
  }
}

class AnswerDraft {
  levelId: string;
  answer: string;

  constructor(levelId: string, answer: string) {
    this.levelId = levelId;
    this.answer = answer;
  }
}

/** Server-owned gameplay facts; page lifetime and account lifetime are separate. */
@ObservedV2
export class GameplayViewModel {
  @Trace snapshot: GameplaySnapshot | null = null;
  @Trace visible: boolean = false;
  @Trace loading: boolean = false;
  @Trace refreshing: boolean = false;
  @Trace refreshError: string = '';
  @Trace starting: boolean = false;
  @Trace error: string = '';
  @Trace errorCode: string = '';
  @Trace retryEntry: boolean = false;
  @Trace activeIndex: number = 0;
  @Trace draftAnswer: string = '';
  @Trace submitting: boolean = false;
  @Trace retryAnswer: boolean = false;
  @Trace answerError: string = '';
  @Trace feedback: string = '';
  @Trace feedbackDanger: boolean = false;
  @Trace feedbackVersion: number = 0;
  @Trace feedbackTransient: boolean = false;
  @Trace completionRevision: number = 0;
  completionClues: GameplayClue[] = [];
  @Trace advancing: boolean = false;
  @Trace now: number = Date.now();
  private readonly repository: GameRepository;
  private readonly accepted: (snapshot: GameplaySnapshot) => void;
  private readonly authenticationFailed: (message: string) => void;
  private readonly requestIdentity: () => string;
  private readonly playerAccepted: (player: Player) => void;
  private owner: string = '';
  private epoch: number = 0;
  private revision: number = 0;
  private assignmentId: string = '';
  private contentGeneration: number = 0;
  private intents: EntryIntent[] = [];
  private answers: AnswerIntent[] = [];
  private drafts: AnswerDraft[] = [];
  private serverOffset: number = 0;
  private advanceTimer: number = -1;

  constructor(repository: GameRepository, accepted: (snapshot: GameplaySnapshot) => void = () => {},
    authenticationFailed: (message: string) => void = () => {}, requestIdentity: () => string = createRequestIdentity,
    playerAccepted: (player: Player) => void = () => {}) {
    this.repository = repository;
    this.accepted = accepted;
    this.authenticationFailed = authenticationFailed;
    this.requestIdentity = requestIdentity;
    this.playerAccepted = playerAccepted;
  }

  bindOwner(playerId: string): void {
    if (playerId !== this.owner) {
      this.reset();
      this.owner = playerId;
    }
  }

  reset(): void {
    this.epoch++;
    this.owner = '';
    this.intents = [];
    this.answers = [];
    this.leave();
  }

  leave(): void {
    this.cancelAdvance();
    this.contentGeneration++;
    this.revision++;
    this.assignmentId = '';
    this.visible = false;
    this.snapshot = null;
    this.loading = false;
    this.refreshing = false;
    this.refreshError = '';
    this.starting = false;
    this.error = '';
    this.errorCode = '';
    this.retryEntry = false;
    this.activeIndex = 0;
    this.draftAnswer = '';
    this.submitting = false;
    this.retryAnswer = false;
    this.answerError = '';
    this.feedback = '';
    this.feedbackDanger = false;
    this.completionRevision = 0;
    this.completionClues = [];
    this.drafts = [];
    this.serverOffset = 0;
  }

  private current(epoch: number, revision: number, assignmentId: string): boolean {
    return epoch === this.epoch && revision === this.revision && this.owner.length > 0 &&
      assignmentId === this.assignmentId;
  }

  /** A UI resource owner survives GET refresh but cannot survive page or account exit. */
  imageOwnerKey(): string {
    return `${this.epoch}:${this.contentGeneration}:${this.assignmentId}`;
  }

  private retryable(error: Object): boolean {
    return error instanceof GameFailure && (error.code === 'NETWORK_ERROR' || error.code === 'TIMEOUT' ||
      error.code === 'CONTRACT_ERROR' || error.status === 408 || error.status === 429 || error.status >= 500);
  }

  private fail(error: Object): void {
    this.error = error instanceof Error && error.message.length > 0 ? error.message : '请求失败，请稍后重试。';
    this.errorCode = error instanceof GameFailure ? error.code : 'UNKNOWN_ERROR';
    if (error instanceof GameFailure && (error.status === 401 || error.code === 'ACCOUNT_DISABLED' ||
      error.code === 'PASSWORD_CHANGE_REQUIRED')) {
      this.authenticationFailed(this.error);
    }
  }

  private transientRefreshFailure(error: Object): boolean {
    if (!(error instanceof GameFailure) || error.code === 'CONTRACT_ERROR' ||
      error.code === 'ACCOUNT_DISABLED' || error.code === 'PASSWORD_CHANGE_REQUIRED' ||
      error.code === 'SESSION_OFFLINE' || error.status === 401 || error.status === 403 ||
      error.status === 404 || error.status === 410) {
      return false;
    }
    return error.code === 'NETWORK_ERROR' || error.code === 'TIMEOUT' || error.status === 408 ||
      error.status === 429 || (error.status >= 500 && error.status < 600);
  }

  private clearRefreshFacts(): void {
    this.snapshot = null;
    this.activeIndex = 0;
    this.draftAnswer = '';
    this.drafts = [];
    this.answerError = '';
    this.feedback = '';
    this.feedbackDanger = false;
    this.completionRevision = 0;
    this.completionClues = [];
  }

  private accept(snapshot: GameplaySnapshot): void {
    if (snapshot.detail.id !== this.assignmentId || snapshot.detail.player !== this.owner) {
      throw new GameFailure('CONTRACT_ERROR', '服务返回的场次身份不一致。');
    }
    this.snapshot = snapshot;
    this.visible = snapshot.detail.startedAt.length > 0;
    this.error = '';
    this.errorCode = '';
    this.refreshError = '';
    this.serverOffset = Date.parse(snapshot.detail.serverTime) - Date.now();
    this.tick();
    this.accepted(snapshot);
  }

  tick(): void {
    this.now = Date.now() + this.serverOffset;
  }

  private cancelAdvance(): void {
    if (this.advanceTimer !== -1) {
      clearTimeout(this.advanceTimer);
      this.advanceTimer = -1;
    }
    this.advancing = false;
  }

  currentLevel(): GameplayLevel | null {
    return this.snapshot !== null && this.activeIndex >= 0 && this.activeIndex < this.snapshot.levels.length ?
      this.snapshot.levels[this.activeIndex] : null;
  }

  private restoreForm(index: number): void {
    const snapshot: GameplaySnapshot | null = this.snapshot;
    if (snapshot === null) {
      return;
    }
    this.answers = this.answers.filter((item: AnswerIntent) => item.assignmentId !== this.assignmentId ||
      (snapshot.detail.status !== 'cancelled' && snapshot.levels.some((level: GameplayLevel) =>
        level.id === item.sessionLevelId && level.completedAt.length === 0)));
    const unresolved: AnswerIntent | undefined = this.answers.find((item: AnswerIntent) =>
      item.assignmentId === this.assignmentId);
    const pendingIndex: number = unresolved === undefined ? -1 :
      snapshot.levels.findIndex((level: GameplayLevel) => level.id === unresolved.sessionLevelId);
    this.activeIndex = pendingIndex >= 0 ? pendingIndex : index >= 0 && index < snapshot.levels.length &&
      snapshot.levels[index].question !== null ? index : snapshot.detail.currentIndex;
    this.retryAnswer = unresolved !== undefined;
    const level: GameplayLevel | null = this.currentLevel();
    const draft: AnswerDraft | undefined = this.drafts.find((item: AnswerDraft) => item.levelId === level?.id);
    this.draftAnswer = unresolved !== undefined ? unresolved.answer : level !== null && level.completedAt.length > 0 ?
      level.lastAnswer : draft !== undefined ? draft.answer : level?.lastAnswer || '';
  }

  blockedReason(): string {
    const level: GameplayLevel | null = this.currentLevel();
    const snapshot: GameplaySnapshot | null = this.snapshot;
    if (snapshot === null || level === null || level.question === null) {
      return '题目尚未解锁。';
    }
    if (snapshot.detail.status === 'cancelled') {
      return '本场冒险已取消。';
    }
    if (level.completedAt.length > 0) {
      return '当前题目已完成。';
    }
    if (snapshot.detail.endsAt.length > 0 && Date.parse(snapshot.detail.endsAt) <= this.now) {
      return '本次冒险已经结束。';
    }
    if (snapshot.detail.startsAt.length > 0 && Date.parse(snapshot.detail.startsAt) > this.now) {
      return '冒险尚未开始，请耐心等待。';
    }
    if (snapshot.detail.status !== 'active') {
      return '当前场次不能提交答案。';
    }
    if (this.activeIndex !== snapshot.detail.currentIndex) {
      return '请先完成前面的题目。';
    }
    if (level.locked) {
      return '此题已永久锁定';
    }
    const remaining: number = Math.ceil((Date.parse(level.cooldownUntil) - this.now) / 1000);
    if (Number.isFinite(remaining) && remaining > 0) {
      const minutes: string = Math.floor(remaining / 60).toString().padStart(2, '0');
      const seconds: string = (remaining % 60).toString().padStart(2, '0');
      return `距离再次尝试还有 ${minutes}:${seconds}`;
    }
    return '';
  }

  answerEditable(): boolean {
    return this.owner.length > 0 && !this.loading && !this.starting && !this.submitting &&
      !this.advancing && !this.retryAnswer && this.blockedReason().length === 0;
  }

  answerAllowed(): boolean {
    // Empty input remains actionable so validation can explain what is missing.
    return !this.refreshing && this.answerEditable();
  }

  editAnswer(value: string): void {
    const level: GameplayLevel | null = this.currentLevel();
    if (value === this.draftAnswer || level === null || !this.answerEditable()) {
      return;
    }
    this.draftAnswer = value;
    const existing: AnswerDraft | undefined = this.drafts.find((item: AnswerDraft) => item.levelId === level.id);
    if (existing !== undefined) {
      existing.answer = value;
    } else {
      this.drafts.push(new AnswerDraft(level.id, value));
    }
    this.answerError = '';
    this.feedback = '';
  }

  canMoveTo(index: number): boolean {
    return !this.loading && !this.submitting && !this.retryAnswer && this.snapshot !== null &&
      index >= 0 && index < this.snapshot.levels.length && this.snapshot.levels[index].question !== null;
  }

  moveTo(index: number): void {
    if (this.refreshing || !this.canMoveTo(index)) {
      return;
    }
    this.cancelAdvance();
    this.restoreForm(index);
    this.answerError = '';
    this.feedback = '';
  }

  nextQuestion(): void {
    const level: GameplayLevel | null = this.currentLevel();
    if (level !== null && level.completedAt.length > 0) {
      this.moveTo(this.activeIndex + 1);
    }
  }

  async enter(id: string): Promise<void> {
    if (this.owner.length === 0 || id.length === 0 || this.starting || this.loading || this.refreshing) {
      return;
    }
    const epoch: number = this.epoch;
    const revision: number = ++this.revision;
    this.assignmentId = id;
    this.starting = true;
    this.error = '';
    this.errorCode = '';
    this.refreshError = '';
    let intent: EntryIntent | undefined = this.intents.find((item: EntryIntent) => item.assignmentId === id);
    if (intent === undefined) {
      intent = new EntryIntent(id, this.requestIdentity());
      this.intents.push(intent);
    }
    this.retryEntry = true;
    try {
      const snapshot: GameplaySnapshot = await this.repository.startAssignment(id, intent.requestId);
      if (epoch !== this.epoch) {
        return;
      }
      if (snapshot.detail.id !== id || snapshot.detail.player !== this.owner ||
        snapshot.detail.startedAt.length === 0 || (snapshot.detail.status !== 'active' &&
        snapshot.detail.status !== 'completed' && snapshot.detail.status !== 'cancelled')) {
        throw new GameFailure('CONTRACT_ERROR', '服务尚未确认入场，请重试原请求。');
      }
      if (this.current(epoch, revision, id)) {
        this.accept(snapshot);
        this.intents = this.intents.filter((item: EntryIntent) => item !== intent);
        this.retryEntry = false;
        this.restoreForm(snapshot.detail.currentIndex);
      }
    } catch (error) {
      if (this.current(epoch, revision, id)) {
        if (!this.retryable(error as Object)) {
          this.intents = this.intents.filter((item: EntryIntent) => item !== intent);
        }
        this.retryEntry = this.retryable(error as Object);
        this.fail(error as Object);
      }
    } finally {
      if (this.current(epoch, revision, id)) {
        this.starting = false;
      }
    }
  }

  async open(id: string, keepPosition: boolean = false): Promise<void> {
    if (this.owner.length === 0 || id.length === 0 || this.starting || this.loading || this.submitting || this.refreshing) {
      return;
    }
    const epoch: number = this.epoch;
    const revision: number = ++this.revision;
    const index: number = keepPosition ? this.activeIndex : -1;
    this.cancelAdvance();
    this.assignmentId = id;
    this.visible = true;
    this.loading = true;
    this.snapshot = null;
    this.error = '';
    this.errorCode = '';
    this.refreshError = '';
    this.answerError = '';
    this.feedback = '';
    this.completionRevision = 0;
    this.completionClues = [];
    try {
      const snapshot: GameplaySnapshot = await this.repository.gameplay(id);
      if (this.current(epoch, revision, id)) {
        this.accept(snapshot);
        this.restoreForm(index >= 0 ? index : snapshot.detail.currentIndex);
        if (snapshot.detail.startedAt.length > 0) {
          this.intents = this.intents.filter((item: EntryIntent) => item.assignmentId !== id);
        }
      }
    } catch (error) {
      if (this.current(epoch, revision, id)) {
        this.fail(error as Object);
      }
    } finally {
      if (this.current(epoch, revision, id)) {
        this.loading = false;
      }
    }
  }

  async reload(): Promise<void> {
    await this.open(this.assignmentId, true);
  }

  canRefresh(): boolean {
    return this.owner.length > 0 && this.assignmentId.length > 0 && this.visible && this.snapshot !== null &&
      !this.loading && !this.starting && !this.submitting && !this.retryEntry && !this.retryAnswer &&
      !this.advancing && !this.refreshing;
  }

  /** A user GET refresh keeps the current level mounted and never resolves an unknown write. */
  async refresh(): Promise<void> {
    if (!this.canRefresh()) {
      return;
    }
    const epoch: number = this.epoch;
    const revision: number = ++this.revision;
    const id: string = this.assignmentId;
    const levelId: string = this.currentLevel()?.id || '';
    this.refreshing = true;
    this.refreshError = '';
    try {
      const snapshot: GameplaySnapshot = await this.repository.gameplay(id);
      if (this.current(epoch, revision, id)) {
        this.accept(snapshot);
        const index: number = snapshot.levels.findIndex((level: GameplayLevel) => level.id === levelId);
        this.restoreForm(index >= 0 ? index : snapshot.detail.currentIndex);
      }
    } catch (error) {
      if (this.current(epoch, revision, id)) {
        const failure: Object = error as Object;
        if (this.transientRefreshFailure(failure)) {
          this.refreshError = error instanceof Error ? error.message : '同步失败，请稍后重试。';
        } else {
          this.clearRefreshFacts();
          this.fail(failure);
        }
      }
    } finally {
      if (this.current(epoch, revision, id)) {
        this.refreshing = false;
      }
    }
  }

  async submitAnswer(autoNextDelay: number = 0): Promise<void> {
    const level: GameplayLevel | null = this.currentLevel();
    if (level === null || !this.answerAllowed()) {
      return;
    }
    if (this.draftAnswer.trim().length === 0) {
      this.answerError = '请先输入或选择答案。';
      this.announceFeedback(true);
      return;
    }
    if (this.draftAnswer.trim().length > 4000) {
      this.answerError = '答案不能超过4000字。';
      this.announceFeedback(true);
      return;
    }
    const intent: AnswerIntent = new AnswerIntent(this.assignmentId, level.id, this.draftAnswer, this.requestIdentity());
    this.answers.push(intent);
    await this.performAnswer(intent, autoNextDelay);
  }

  private announceFeedback(transient: boolean): void {
    this.feedbackTransient = transient;
    this.feedbackVersion++;
  }

  async retrySubmission(autoNextDelay: number = 0): Promise<void> {
    if (!this.retryAnswer || this.submitting || this.loading || this.refreshing || this.owner.length === 0) {
      return;
    }
    const intent: AnswerIntent | undefined = this.answers.find((item: AnswerIntent) =>
      item.assignmentId === this.assignmentId);
    if (intent !== undefined) {
      await this.performAnswer(intent, autoNextDelay);
    }
  }

  private async recoverRejection(epoch: number, revision: number, id: string): Promise<void> {
    this.loading = true;
    try {
      const snapshot: GameplaySnapshot = await this.repository.gameplay(id);
      if (this.current(epoch, revision, id)) {
        this.accept(snapshot);
        this.restoreForm(this.activeIndex);
      }
    } catch (error) {
      if (this.current(epoch, revision, id)) {
        this.snapshot = null;
        this.fail(error as Object);
      }
    } finally {
      if (this.current(epoch, revision, id)) {
        this.loading = false;
      }
    }
  }

  private async performAnswer(intent: AnswerIntent, autoNextDelay: number): Promise<void> {
    const epoch: number = this.epoch;
    const revision: number = this.revision;
    const id: string = this.assignmentId;
    const previous: GameplaySnapshot | null = this.snapshot;
    const submittedIndex: number = this.activeIndex;
    this.cancelAdvance();
    this.submitting = true;
    this.retryAnswer = true;
    this.answerError = '';
    this.feedback = '';
    try {
      const result: GameplayAnswerResult = await this.repository.answerAssignment(id,
        intent.sessionLevelId, intent.answer, intent.requestId);
      if (!this.current(epoch, revision, id)) {
        return;
      }
      if (result.player.id !== this.owner || result.assignment.detail.id !== id ||
        result.assignment.detail.player !== this.owner ||
        !result.assignment.levels.some((level: GameplayLevel) => level.id === intent.sessionLevelId)) {
        throw new GameFailure('CONTRACT_ERROR', '服务返回的答题身份不一致，请确认原请求结果。');
      }
      this.accept(result.assignment);
      this.playerAccepted(result.player);
      if (!this.current(epoch, revision, id)) {
        return;
      }
      this.answers = this.answers.filter((item: AnswerIntent) => item !== intent);
      this.restoreForm(submittedIndex);
      const settled: GameplayLevel | undefined = result.assignment.levels.find((level: GameplayLevel) =>
        level.id === intent.sessionLevelId);
      this.feedbackDanger = result.result === 'incorrect';
      if (result.assignment.detail.status === 'cancelled') {
        this.feedback = '本场冒险已取消，进度已同步。';
      } else if (result.result === 'incorrect') {
        this.feedback = settled?.locked ? '回答错误，当前题目已永久锁定。请联系游戏管理员处理。' :
          (settled?.cooldownUntil || '').length > 0 ? '回答错误，已进入惩罚时间。' : '答案不正确，可以继续尝试。';
      } else if (result.result === 'correct') {
        const completed: boolean = result.assignment.detail.status === 'completed';
        this.feedback = completed ? '全部题目已经完成。' : '回答正确，当前题目已完成。';
        if (completed && previous?.detail.status !== 'completed' && result.assignment.detail.totalLevels > 1 &&
          result.assignment.presentation.completionStyle !== 'finale') {
          this.completionClues = completionCombinations(previous, result.assignment,
            result.effectsProvided ? result.effects : undefined);
          this.completionRevision++;
        } else if (!completed && settled?.autoNext && result.assignment.detail.status === 'active') {
          const nextIndex: number = result.assignment.detail.currentIndex;
          const delay: number = Number.isFinite(autoNextDelay) ? Math.max(0, Math.min(1500, autoNextDelay)) : 0;
          if (delay === 0) {
            this.restoreForm(nextIndex);
          } else {
            this.advancing = true;
            let timer: number = -1;
            timer = setTimeout(() => {
              if (this.advanceTimer !== timer) {
                return;
              }
              this.advanceTimer = -1;
              if (this.current(epoch, revision, id) && this.activeIndex === submittedIndex) {
                this.advancing = false;
                this.restoreForm(nextIndex);
                this.feedback = '';
              }
            }, delay);
            this.advanceTimer = timer;
          }
        }
      }
      if (this.feedback.length > 0) {
        this.announceFeedback(result.result === 'incorrect' && result.assignment.detail.status !== 'cancelled');
      }
    } catch (error) {
      if (this.current(epoch, revision, id)) {
        const failure: Object = error as Object;
        const retry: boolean = this.retryable(failure);
        this.retryAnswer = retry;
        this.answerError = error instanceof Error ? error.message : '提交失败，请稍后重试。';
        if (!retry) {
          this.announceFeedback(false);
          this.answers = this.answers.filter((item: AnswerIntent) => item !== intent);
          if (error instanceof GameFailure && (error.status === 401 || error.code === 'ACCOUNT_DISABLED' ||
            error.code === 'PASSWORD_CHANGE_REQUIRED')) {
            this.fail(failure);
          } else if (error instanceof GameFailure && (error.status === 403 || error.status === 404 || error.status === 410)) {
            this.snapshot = null;
            this.fail(failure);
          } else if (error instanceof GameFailure && error.status === 409) {
            await this.recoverRejection(epoch, revision, id);
          }
        }
      }
    } finally {
      if (this.current(epoch, revision, id)) {
        this.submitting = false;
      }
    }
  }
}
