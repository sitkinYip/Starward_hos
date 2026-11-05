import { GameRepository } from '../business/GameRepository';
import { GameplayAnswerResult, GameplayContentBlock, GameplayLevel, GameplayOption, GameplayQuestion,
  GameplaySnapshot } from '../business/GameplayModels';
import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, GameFailure, Player, Rank,
  validateAvatarUpload, validateDisplayName, validatePasswordChange } from '../business/models';
import { decodeAssignment } from './DtoDecoder';

export function sampleAssignment(): AssignmentDetail {
  const value: AssignmentDetail = new AssignmentDetail();
  value.id = 'assignment1';
  value.player = 'playeralice';
  value.session = 'session1';
  value.title = '星辰探险';
  value.description = '解开谜题，发现惊喜。';
  value.minLevel = 1;
  value.totalLevels = 2;
  value.serverTime = new Date().toISOString();
  return value;
}

/** Explicit demo-only payload; real gameplay is always decoded from the HTTPS backend. */
export function sampleGameplaySnapshot(detail: AssignmentDetail = sampleAssignment()): GameplaySnapshot {
  const snapshot: GameplaySnapshot = new GameplaySnapshot();
  snapshot.detail = decodeAssignment(JSON.stringify(detail));
  snapshot.detail.serverTime = new Date().toISOString();
  snapshot.presentation.bgmMode = 'silent';
  snapshot.presentation.completionStyle = 'normal';
  const unlocked: boolean = detail.startedAt.length > 0 && detail.status !== 'cancelled';
  for (let i: number = 0; i < detail.totalLevels; i++) {
    const level: GameplayLevel = new GameplayLevel();
    level.id = 'step' + i;
    level.position = i + 1;
    level.xp = 50;
    if (i < detail.completedLevels) {
      level.completedAt = detail.startedAt || snapshot.detail.serverTime;
    }
    if (unlocked && i <= detail.currentIndex) {
      const question: GameplayQuestion = new GameplayQuestion();
      question.id = 'demo-question-' + i;
      question.kind = i === 0 ? 'text' : 'choice';
      question.title = i === 0 ? '星辰之门' : '守门人的选择';
      question.placeholder = '输入你的答案';
      const content: GameplayContentBlock = new GameplayContentBlock();
      content.text = i === 0 ? '这是演示环境中的谜题。沿着星光寻找答案。' : '演示谜题：选择为旅人指路的星星。';
      question.content.push(content);
      if (question.kind === 'choice') {
        const moon: GameplayOption = new GameplayOption();
        moon.key = 'A';
        moon.text = '月亮';
        const star: GameplayOption = new GameplayOption();
        star.key = 'B';
        star.text = '北极星';
        question.options = [moon, star];
      }
      level.question = question;
    }
    snapshot.levels.push(level);
  }
  return snapshot;
}

class DemoStartReceipt {
  assignmentId: string = '';
  requestId: string = '';
  rawRequestId: string = '';
}

class DemoAnswerReceipt {
  assignmentId: string = '';
  requestId: string = '';
  rawRequestId: string = '';
  rawLevelId: string = '';
  rawAnswer: string = '';
  result: string = '';
  xpDelta: number = 0;
}

export class MockGameRepository implements GameRepository {
  readonly mode: string = 'mock';
  delayMs: number;
  nextFailure: GameFailure | null = null;
  calls: string[] = [];
  emptyAssignments: boolean = false;
  fixture: AssignmentDetail = sampleAssignment();
  private generation: number = 0;
  private authenticated: boolean = false;
  private currentPassword: string = 'Starward1234';
  private mustChange: boolean = true;
  private currentDisplayName: string = '远航者';
  private currentAvatar: AvatarImage | null = null;
  private avatarRevision: number = 0;
  private demoTotalXp: number = 0;
  private progressAssignmentId: string = '';
  private demoProgress: GameplayLevel[] = [];
  private startReceipts: DemoStartReceipt[] = [];
  private answerReceipts: DemoAnswerReceipt[] = [];
  private submissionTimes: number[] = [];

  constructor(delayMs: number = 160) {
    this.delayMs = delayMs;
  }

  private player(): Player {
    const player: Player = new Player();
    player.id = 'playeralice';
    player.account = 'alice';
    player.displayName = this.currentDisplayName;
    player.avatar = this.currentAvatar === null ? '' : 'demo-avatar.jpg';
    player.mustChangePassword = this.mustChange;
    player.totalXp = this.demoTotalXp;
    const level: Rank = new Rank();
    level.id = this.demoTotalXp >= 100 ? 'rank2' : 'rank1';
    level.name = this.demoTotalXp >= 100 ? '同行' : '初见';
    level.order = this.demoTotalXp >= 100 ? 2 : 1;
    level.minTotalXp = this.demoTotalXp >= 100 ? 100 : 0;
    player.level = level;
    const next: Rank = new Rank();
    next.id = 'rank2';
    next.name = '同行';
    next.order = 2;
    next.minTotalXp = 100;
    player.nextLevel = this.demoTotalXp >= 100 ? null : next;
    return player;
  }

  private assertCurrent(generation: number): void {
    if (generation !== this.generation) {
      throw new GameFailure('CANCELLED', '账号已切换，本次请求已取消。');
    }
  }

  private requireSession(): number {
    if (!this.authenticated) {
      throw new GameFailure('UNAUTHORIZED', '请重新登录。', 401);
    }
    return this.generation;
  }

  private async pause(operation: string, generation: number): Promise<void> {
    this.calls.push(operation);
    const failure: GameFailure | null = this.nextFailure;
    this.nextFailure = null;
    await new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, this.delayMs);
    });
    this.assertCurrent(generation);
    if (failure !== null) {
      if (failure.status === 401) {
        this.logout();
      }
      throw failure;
    }
  }

  async login(account: string, password: string): Promise<Player> {
    this.logout();
    const generation: number = this.generation;
    await this.pause('login', generation);
    if (account.trim().toLowerCase() !== 'alice' || password !== this.currentPassword) {
      throw new GameFailure('INVALID_CREDENTIALS', '账号或密码不正确', 400);
    }
    this.authenticated = true;
    return this.player();
  }

  async me(): Promise<Player> {
    const generation: number = this.requireSession();
    await this.pause('me', generation);
    return this.player();
  }

  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player> {
    const generation: number = this.requireSession();
    const validation: string = validatePasswordChange(oldPassword, password, confirmation);
    if (validation.length > 0) {
      throw new GameFailure('VALIDATION_ERROR', validation);
    }
    await this.pause('changePassword', generation);
    if (oldPassword !== this.currentPassword) {
      throw new GameFailure('INVALID_PASSWORD', '当前密码不正确，请重新输入。', 400);
    }
    this.currentPassword = password;
    this.mustChange = false;
    this.generation++;
    return this.player();
  }

  private ensureChanged(): void {
    if (this.mustChange) {
      throw new GameFailure('PASSWORD_CHANGE_REQUIRED', '首次登录，请先修改密码', 403);
    }
  }

  async updateProfile(displayName: string, avatar: AvatarUpload | null = null): Promise<Player> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    const validation: string = validateDisplayName(displayName);
    if (validation.length > 0) {
      throw new GameFailure('VALIDATION_ERROR', validation);
    }
    if (avatar !== null) {
      const avatarValidation: string = validateAvatarUpload(avatar);
      if (avatarValidation.length > 0) {
        throw new GameFailure('VALIDATION_ERROR', avatarValidation);
      }
    }
    await this.pause('updateProfile', generation);
    this.currentDisplayName = displayName.trim();
    if (avatar !== null) {
      const image: AvatarImage = new AvatarImage();
      image.data = avatar.data.slice(0);
      image.mimeType = avatar.mimeType;
      this.currentAvatar = image;
      this.avatarRevision++;
    }
    return this.player();
  }

  async avatar(forceRefresh: boolean = false): Promise<AvatarImage | null> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    const revision: number = this.avatarRevision;
    await this.pause(forceRefresh ? 'avatarRefresh' : 'avatar', generation);
    if (revision !== this.avatarRevision) {
      throw new GameFailure('CANCELLED', '头像已更新，本次请求已取消。');
    }
    if (this.currentAvatar === null) {
      return null;
    }
    const result: AvatarImage = new AvatarImage();
    result.data = this.currentAvatar.data.slice(0);
    result.mimeType = this.currentAvatar.mimeType;
    return result;
  }

  async assignments(): Promise<AssignmentSummary[]> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    await this.pause('assignments', generation);
    if (this.emptyAssignments) {
      return [];
    }
    return [decodeAssignment(JSON.stringify(this.fixture))];
  }

  async assignment(id: string): Promise<AssignmentDetail> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    await this.pause('assignment', generation);
    if (id !== this.fixture.id) {
      throw new GameFailure('NOT_FOUND', '这段旅程暂时无法访问。', 404);
    }
    const detail: AssignmentDetail = decodeAssignment(JSON.stringify(this.fixture));
    detail.serverTime = new Date().toISOString();
    return detail;
  }

  async startAssignment(id: string, requestId: string): Promise<GameplaySnapshot> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    if (requestId.trim().length === 0 || requestId.length > 100) {
      throw new GameFailure('VALIDATION_ERROR', '无法确认本次入场请求，请返回后重试。');
    }
    await this.pause('startAssignment', generation);
    if (id !== this.fixture.id) {
      throw new GameFailure('NOT_FOUND', '这段旅程暂时无法访问。', 404);
    }
    const previous: DemoStartReceipt | undefined = this.startReceipts.find((item: DemoStartReceipt) =>
      item.assignmentId === id && item.requestId === requestId.trim());
    if (previous !== undefined) {
      if (previous.rawRequestId !== requestId) {
        throw new GameFailure('IDEMPOTENCY_CONFLICT', '请求标识已用于不同内容', 409);
      }
      return this.demoSnapshot();
    }
    if (this.fixture.status === 'cancelled') {
      throw new GameFailure('ASSIGNMENT_CANCELLED', '场次已取消', 409);
    }
    const now: number = Date.now();
    if (this.fixture.startsAt.length > 0 && Date.parse(this.fixture.startsAt) > now) {
      throw new GameFailure('NOT_STARTED', '场次尚未开放', 409);
    }
    if (this.fixture.endsAt.length > 0 && Date.parse(this.fixture.endsAt) <= now) {
      throw new GameFailure('EXPIRED', '本次场次已结束', 409);
    }
    if (this.fixture.startedAt.length === 0) {
      const order: number = this.player().level.order;
      if (order < this.fixture.minLevel || (this.fixture.maxLevel !== null && order > this.fixture.maxLevel)) {
        throw new GameFailure('LEVEL_NOT_ELIGIBLE', '当前等级不符合参与要求', 409);
      }
      this.fixture.status = 'active';
      this.fixture.startedAt = new Date().toISOString();
      this.ensureDemoProgress();
    }
    const receipt: DemoStartReceipt = new DemoStartReceipt();
    receipt.assignmentId = id;
    receipt.requestId = requestId.trim();
    receipt.rawRequestId = requestId;
    this.startReceipts.push(receipt);
    return this.demoSnapshot();
  }

  async gameplay(id: string): Promise<GameplaySnapshot> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    await this.pause('gameplay', generation);
    if (id !== this.fixture.id) {
      throw new GameFailure('NOT_FOUND', '这段旅程暂时无法访问。', 404);
    }
    return this.demoSnapshot();
  }

  private ensureDemoProgress(): void {
    if (this.progressAssignmentId !== this.fixture.id || this.demoProgress.length !== this.fixture.totalLevels) {
      this.demoProgress = sampleGameplaySnapshot(this.fixture).levels;
      this.progressAssignmentId = this.fixture.id;
    }
  }

  private demoSnapshot(): GameplaySnapshot {
    const result: GameplaySnapshot = sampleGameplaySnapshot(this.fixture);
    if (this.progressAssignmentId === this.fixture.id && this.demoProgress.length === result.levels.length) {
      for (let i: number = 0; i < result.levels.length; i++) {
        const source: GameplayLevel = this.demoProgress[i];
        result.levels[i].completedAt = source.completedAt;
        result.levels[i].wrongCount = source.wrongCount;
        result.levels[i].cooldownUntil = source.cooldownUntil;
        result.levels[i].locked = source.locked;
        result.levels[i].lastAnswer = result.levels[i].question === null ? '' : source.lastAnswer;
      }
    }
    return result;
  }

  private demoAnswerResult(receipt: DemoAnswerReceipt): GameplayAnswerResult {
    const result: GameplayAnswerResult = new GameplayAnswerResult();
    result.result = receipt.result;
    result.xpDelta = receipt.xpDelta;
    result.assignment = this.demoSnapshot();
    result.player = this.player();
    return result;
  }

  private requireDemoAvailability(): void {
    if (this.fixture.status === 'cancelled') {
      throw new GameFailure('ASSIGNMENT_CANCELLED', '本次场次已撤回', 409);
    }
    const now: number = Date.now();
    if (this.fixture.startsAt.length > 0 && now < Date.parse(this.fixture.startsAt)) {
      throw new GameFailure('NOT_STARTED', '场次尚未开放', 409);
    }
    if (this.fixture.endsAt.length > 0 && now >= Date.parse(this.fixture.endsAt)) {
      throw new GameFailure('EXPIRED', '本次场次已结束', 409);
    }
    if (this.fixture.startedAt.length === 0) {
      throw new GameFailure('NOT_STARTED', '请先进入场次', 409);
    }
  }

  async answerAssignment(id: string, sessionLevelId: string, rawAnswer: string,
    requestId: string): Promise<GameplayAnswerResult> {
    const generation: number = this.requireSession();
    this.ensureChanged();
    if (sessionLevelId.trim().length === 0 || sessionLevelId.trim().length > 30 ||
      rawAnswer.trim().length === 0 || rawAnswer.trim().length > 4000 ||
      requestId.trim().length === 0 || requestId.trim().length > 100) {
      throw new GameFailure('VALIDATION_ERROR', '请填写有效答案后再提交。');
    }
    await this.pause('answerAssignment', generation);
    if (id !== this.fixture.id) {
      throw new GameFailure('NOT_FOUND', '这段旅程暂时无法访问。', 404);
    }
    const previous: DemoAnswerReceipt | undefined = this.answerReceipts.find((item: DemoAnswerReceipt) =>
      item.assignmentId === id && item.requestId === requestId.trim());
    if (previous !== undefined) {
      if (previous.rawLevelId !== sessionLevelId || previous.rawAnswer !== rawAnswer ||
        previous.rawRequestId !== requestId) {
        throw new GameFailure('IDEMPOTENCY_CONFLICT', '请求标识已用于不同内容', 409);
      }
      return this.demoAnswerResult(previous);
    }
    this.requireDemoAvailability();
    this.ensureDemoProgress();
    const index: number = this.demoProgress.findIndex((level: GameplayLevel) => level.id === sessionLevelId.trim());
    if (index < 0) {
      throw new GameFailure('NOT_FOUND', '关卡不存在', 404);
    }
    const progress: GameplayLevel = this.demoProgress[index];
    const receipt: DemoAnswerReceipt = new DemoAnswerReceipt();
    receipt.assignmentId = id;
    receipt.requestId = requestId.trim();
    receipt.rawRequestId = requestId;
    receipt.rawLevelId = sessionLevelId;
    receipt.rawAnswer = rawAnswer;
    if (progress.completedAt.length > 0) {
      receipt.result = 'already_completed';
    } else {
      const first: number = this.demoProgress.findIndex((level: GameplayLevel) => level.completedAt.length === 0);
      if (first !== index) {
        throw new GameFailure('PREVIOUS_LEVEL_REQUIRED', '请先完成前一关', 409);
      }
      if (progress.locked) {
        throw new GameFailure('LOCKED', '本关已锁定，请联系工作人员', 409);
      }
      const now: number = Date.now();
      if (progress.cooldownUntil.length > 0 && Date.parse(progress.cooldownUntil) > now) {
        throw new GameFailure('COOLDOWN', '请等待冷却结束', 409);
      }
      this.submissionTimes = this.submissionTimes.filter((time: number) => time > now - 60000);
      if (this.submissionTimes.length >= 30) {
        throw new GameFailure('RATE_LIMITED', '提交过于频繁，请稍后再试', 429);
      }
      const answer: string = rawAnswer.trim();
      if (index > 0 && answer !== 'A' && answer !== 'B') {
        throw new GameFailure('INVALID_INPUT', '请选择有效选项', 400);
      }
      // These answers belong only to this explicit in-memory demo fixture.
      const correct: boolean = index === 0 ? answer === '星辰大海' : answer === 'B';
      receipt.result = correct ? 'correct' : 'incorrect';
      progress.lastAnswer = answer;
      this.submissionTimes.push(now);
      if (correct) {
        progress.completedAt = new Date(now).toISOString();
        progress.cooldownUntil = '';
        progress.locked = false;
        receipt.xpDelta = progress.xp;
        this.demoTotalXp += receipt.xpDelta;
        this.fixture.completedLevels = this.demoProgress.filter((level: GameplayLevel) =>
          level.completedAt.length > 0).length;
        const next: number = this.demoProgress.findIndex((level: GameplayLevel) => level.completedAt.length === 0);
        this.fixture.currentIndex = next < 0 ? Math.max(0, this.demoProgress.length - 1) : next;
        if (next < 0) {
          this.fixture.status = 'completed';
          this.fixture.completedAt = new Date(now).toISOString();
        }
      } else if (index > 0) {
        // The demo has no configured penalty policy. Real cooldown/lock facts
        // are supplied by the isolated backend, never inferred by the UI.
        progress.wrongCount++;
      }
    }
    this.answerReceipts.push(receipt);
    return this.demoAnswerResult(receipt);
  }

  logout(): void {
    this.generation++;
    this.authenticated = false;
  }
}
