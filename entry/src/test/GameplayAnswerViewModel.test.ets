import { describe, expect, it } from '@ohos/hypium';
import { GameplayAnswerResult, GameplayClue, GameplayEffect, GameplaySnapshot } from '../main/ets/business/GameplayModels';
import { GameFailure, Player } from '../main/ets/business/models';
import { decodeGameplay } from '../main/ets/data/GameplayDecoder';
import { decodePlayer } from '../main/ets/data/DtoDecoder';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { GameplayViewModel } from '../main/ets/features/GameplayViewModel';
import { GAMEPLAY_CHOICE_JSON, GAMEPLAY_STARTED_JSON } from './fixtures/GameplayFixture';
import { WEB_PLAYER_JSON } from './fixtures/WebFixture';

function textSnapshot(): GameplaySnapshot {
  const value: GameplaySnapshot = decodeGameplay(GAMEPLAY_STARTED_JSON);
  value.detail.serverTime = new Date().toISOString();
  return value;
}

function choiceSnapshot(): GameplaySnapshot {
  const value: GameplaySnapshot = decodeGameplay(GAMEPLAY_CHOICE_JSON);
  value.detail.serverTime = new Date().toISOString();
  value.levels[0].lastAnswer = '星辰大海';
  return value;
}

function completedSnapshot(): GameplaySnapshot {
  const value: GameplaySnapshot = choiceSnapshot();
  value.detail.status = 'completed';
  value.detail.completedLevels = 2;
  value.detail.completedAt = value.detail.serverTime;
  value.levels[1].completedAt = value.detail.serverTime;
  value.levels[1].lastAnswer = 'B';
  return value;
}

function answerResult(result: string, assignment: GameplaySnapshot, totalXp: number = 50): GameplayAnswerResult {
  const value: GameplayAnswerResult = new GameplayAnswerResult();
  value.result = result;
  value.assignment = assignment;
  value.player = decodePlayer(WEB_PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":false'));
  value.player.totalXp = totalXp;
  value.xpDelta = result === 'correct' ? 50 : 0;
  return value;
}

function clueResult(kinds: string[], autoNext: boolean = true): GameplayAnswerResult {
  const settled: GameplaySnapshot = choiceSnapshot();
  settled.levels[0].autoNext = autoNext;
  const result: GameplayAnswerResult = answerResult('correct', settled);
  result.effectsProvided = true;
  for (let index: number = 0; index < kinds.length; index++) {
    const kind: string = kinds[index];
    const clue: GameplayClue = new GameplayClue();
    clue.id = `${kind}-${index}`;
    clue.kind = kind;
    clue.position = index;
    if (kind === 'video') { clue.content.url = 'https://media.example/clue.mp4'; }
    if (kind === 'image') { clue.content.imageUrls = ['https://media.example/clue.png']; }
    clue.sessionLevel = settled.levels[0].id;
    const effect: GameplayEffect = new GameplayEffect();
    effect.clueId = clue.id;
    effect.autoPlay = true;
    settled.clues.push(clue);
    result.effects.push(effect);
  }
  return result;
}

class AnswerCall {
  id: string;
  level: string;
  rawAnswer: string;
  requestId: string;
  task: Promise<GameplayAnswerResult>;
  private resolve: (value: GameplayAnswerResult) => void = () => {};
  private reject: (failure: GameFailure) => void = () => {};

  constructor(id: string, level: string, rawAnswer: string, requestId: string) {
    this.id = id;
    this.level = level;
    this.rawAnswer = rawAnswer;
    this.requestId = requestId;
    this.task = new Promise<GameplayAnswerResult>((resolve: (value: GameplayAnswerResult) => void,
      reject: (failure: GameFailure) => void) => { this.resolve = resolve; this.reject = reject; });
  }

  succeed(value: GameplayAnswerResult): void { this.resolve(value); }
  fail(failure: GameFailure): void { this.reject(failure); }
}

class AnswerRepository extends MockGameRepository {
  server: GameplaySnapshot = textSnapshot();
  answers: AnswerCall[] = [];
  reads: number = 0;
  readFailure: GameFailure | null = null;

  constructor() { super(0); }

  async gameplay(id: string): Promise<GameplaySnapshot> {
    this.reads++;
    if (this.readFailure !== null) { throw this.readFailure; }
    return this.server;
  }

  async answerAssignment(id: string, level: string, rawAnswer: string, requestId: string): Promise<GameplayAnswerResult> {
    const call: AnswerCall = new AnswerCall(id, level, rawAnswer, requestId);
    this.answers.push(call);
    return call.task;
  }
}

function viewModel(repository: AnswerRepository, playerAccepted: (player: Player) => void = () => {}): GameplayViewModel {
  let sequence: number = 0;
  const value: GameplayViewModel = new GameplayViewModel(repository, () => {}, () => {},
    () => `answer-${++sequence}`, playerAccepted);
  value.bindOwner('playeralice');
  return value;
}

export default function gameplayAnswerViewModelTests(): void {
  describe('GameplayAnswerViewModel', () => {
    it('emptyInputDoesNotWriteAndPendingUsesRawAnswerWithSingleFlight', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('   ');
      await vm.submitAnswer();
      expect(repository.answers.length).assertEqual(0);
      expect(vm.answerError).assertEqual('请先输入或选择答案。');
      vm.editAnswer(' 星辰大海 ');
      const pending: Promise<void> = vm.submitAnswer();
      await vm.submitAnswer();
      vm.editAnswer('被禁止的编辑');
      vm.moveTo(1);
      await vm.reload();
      await vm.refresh();
      expect(repository.answers.length).assertEqual(1);
      expect(repository.answers[0].level).assertEqual('step0');
      expect(repository.answers[0].rawAnswer).assertEqual(' 星辰大海 ');
      expect(vm.draftAnswer).assertEqual(' 星辰大海 ');
      expect(vm.submitting).assertTrue();
      expect(repository.reads).assertEqual(1);
      repository.answers[0].succeed(answerResult('correct', choiceSnapshot()));
      await pending;
      vm.leave();
    });

    it('incorrect200AcceptsOnlyReturnedProgressAndAllowsANewAnswerIdentity', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      let playerXp: number = -1;
      const vm: GameplayViewModel = viewModel(repository, (player: Player) => { playerXp = player.totalXp; });
      await vm.open('assignment1');
      vm.editAnswer('错误');
      const attempt: Promise<void> = vm.submitAnswer();
      const incorrect: GameplaySnapshot = textSnapshot();
      incorrect.levels[0].lastAnswer = '错误';
      repository.answers[0].succeed(answerResult('incorrect', incorrect, 0));
      await attempt;
      expect(vm.feedbackDanger).assertTrue();
      expect(vm.snapshot?.detail.completedLevels).assertEqual(0);
      expect(vm.currentLevel()?.wrongCount).assertEqual(0);
      expect(playerXp).assertEqual(0);
      expect(vm.answerAllowed()).assertTrue();
      vm.editAnswer('星辰大海');
      const next: Promise<void> = vm.submitAnswer();
      expect(repository.answers[0].requestId === repository.answers[1].requestId).assertFalse();
      repository.answers[1].succeed(answerResult('correct', choiceSnapshot()));
      await next;
      vm.leave();
    });

    it('manualNextRetainsCompletedAnswerAndReplacesFullPlayerFacts', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      let playerXp: number = 900;
      const vm: GameplayViewModel = viewModel(repository, (player: Player) => { playerXp = player.totalXp; });
      await vm.open('assignment1');
      repository.readFailure = new GameFailure('UNAVAILABLE', '同步暂时失败', 503);
      await vm.refresh();
      expect(vm.refreshError).assertEqual('同步暂时失败');
      repository.readFailure = null;
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer();
      const result: GameplayAnswerResult = answerResult('correct', choiceSnapshot(), 777);
      result.xpDelta = 50;
      repository.answers[0].succeed(result);
      await pending;
      expect(playerXp).assertEqual(777);
      expect(vm.refreshError).assertEqual('');
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.draftAnswer).assertEqual('星辰大海');
      expect(vm.answerEditable()).assertFalse();
      expect(vm.snapshot?.detail.currentIndex).assertEqual(1);
      vm.nextQuestion();
      expect(vm.activeIndex).assertEqual(1);
      expect(vm.answerEditable()).assertTrue();
      vm.moveTo(0);
      expect(vm.draftAnswer).assertEqual('星辰大海');
      expect(repository.answers.length).assertEqual(1);
      vm.leave();
    });

    it('autoNextUsesSettledConfigurationAndDelayedAdvanceCannotReopenALeftPage', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer(20);
      const settled: GameplaySnapshot = choiceSnapshot();
      settled.levels[0].autoNext = true;
      repository.answers[0].succeed(answerResult('correct', settled));
      await pending;
      expect(vm.advancing).assertTrue();
      await vm.refresh();
      expect(repository.reads).assertEqual(1);
      expect(vm.activeIndex).assertEqual(0);
      vm.leave();
      await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 40); });
      expect(vm.visible).assertFalse();
      expect(vm.snapshot).assertNull();
      expect(vm.advancing).assertFalse();
      repository.server = textSnapshot();
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const reduced: Promise<void> = vm.submitAnswer(0);
      repository.answers[1].succeed(answerResult('correct', settled));
      await reduced;
      expect(vm.activeIndex).assertEqual(1);
      expect(vm.advancing).assertFalse();
      vm.leave();
    });

    it('mixedAutomaticCluesKeepTheSettledQuestionUntilTheLastGalleryCloses', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer();
      const result: GameplayAnswerResult = clueResult(['text', 'video', 'image']);
      repository.answers[0].succeed(result);
      await pending;
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.snapshot?.detail.currentIndex).assertEqual(1);
      expect(vm.automaticClue?.kind).assertEqual('text');
      expect(vm.canRefresh()).assertFalse();
      vm.finishAutomaticClue(result.assignment.clues[0], true);
      vm.finishAutomaticClue(result.assignment.clues[0], true);
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.automaticClue?.kind).assertEqual('video');
      vm.finishAutomaticClue(result.assignment.clues[1], true);
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.automaticClue?.kind).assertEqual('image');
      vm.finishAutomaticClue(result.assignment.clues[2], true);
      expect(vm.activeIndex).assertEqual(1);
      expect(vm.automaticClue).assertNull();
      expect(repository.answers.length).assertEqual(1);
    });

    it('earlyVideoCloseCancelsAdvanceAndGetNeverReopensTheQueue', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer();
      const result: GameplayAnswerResult = clueResult(['text', 'video', 'image']);
      repository.answers[0].succeed(result);
      await pending;
      vm.finishAutomaticClue(result.assignment.clues[0], true);
      vm.finishAutomaticClue(result.assignment.clues[1], false);
      expect(vm.automaticClue?.kind).assertEqual('image');
      vm.finishAutomaticClue(result.assignment.clues[2], true);
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.automaticClue).assertNull();
      repository.server = result.assignment;
      await vm.refresh();
      await vm.reload();
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.automaticClue).assertNull();
      expect(repository.answers.length).assertEqual(1);
    });

    it('backgroundDuringSubmissionKeepsSettlementAndCancelsTheLateVideoAndAdvance', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer();
      vm.cancelAutomaticClues();
      const result: GameplayAnswerResult = clueResult(['text', 'image']);
      repository.answers[0].succeed(result);
      await pending;
      expect(vm.snapshot?.detail.currentIndex).assertEqual(1);
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.automaticClue).assertNull();
      expect(repository.answers.length).assertEqual(1);
    });

    it('naturalVideoEndRespectsDisabledAutoNextAndAccountChanges', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer();
      const result: GameplayAnswerResult = clueResult(['video', 'video'], false);
      repository.answers[0].succeed(result);
      await pending;
      vm.finishAutomaticClue(result.assignment.clues[0], true);
      vm.finishAutomaticClue(result.assignment.clues[1], true);
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.automaticClue).assertNull();
      vm.bindOwner('another-player');
      vm.finishAutomaticClue(result.assignment.clues[1], true);
      expect(vm.snapshot).assertNull();
      expect(vm.visible).assertFalse();
    });

    it('textLinkHandoffAllowsOnlyItsReadAndKeepsTheQueueWithoutAutoAdvance', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const pending: Promise<void> = vm.submitAnswer();
      const result: GameplayAnswerResult = clueResult(['text', 'image']);
      repository.answers[0].succeed(result);
      await pending;
      repository.server = result.assignment;
      await vm.refresh();
      await vm.refresh(result.assignment.clues[1]);
      expect(repository.reads).assertEqual(1);
      vm.cancelAutoAdvance();
      await vm.refresh(result.assignment.clues[0]);
      expect(repository.reads).assertEqual(2);
      expect(vm.automaticClue?.kind).assertEqual('text');
      vm.finishAutomaticClue(result.assignment.clues[0], true);
      expect(vm.automaticClue?.kind).assertEqual('image');
      vm.finishAutomaticClue(result.assignment.clues[1], true);
      expect(vm.activeIndex).assertEqual(0);
      expect(repository.answers.length).assertEqual(1);
    });

    it('unknownOutcomeFreezesOriginalBodyAcrossRetryAndPageReentry', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer(' 星辰大海 ');
      const first: Promise<void> = vm.submitAnswer();
      repository.answers[0].fail(new GameFailure('TIMEOUT', '超时'));
      await first;
      vm.editAnswer('不能替换原体');
      expect(vm.retryAnswer).assertTrue();
      expect(vm.draftAnswer).assertEqual(' 星辰大海 ');
      await vm.refresh();
      expect(repository.reads).assertEqual(1);
      vm.leave();
      await vm.open('assignment1');
      expect(vm.retryAnswer).assertTrue();
      expect(vm.draftAnswer).assertEqual(' 星辰大海 ');
      const retry: Promise<void> = vm.retrySubmission();
      expect(repository.answers[1].requestId).assertEqual(repository.answers[0].requestId);
      expect(repository.answers[1].rawAnswer).assertEqual(repository.answers[0].rawAnswer);
      expect(repository.answers[1].level).assertEqual(repository.answers[0].level);
      repository.answers[1].succeed(answerResult('correct', choiceSnapshot()));
      await retry;
      expect(vm.retryAnswer).assertFalse();
      vm.leave();
    });

    it('recoveryGetOfCommittedAnswerDoesNotReplayOrCelebrate', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const first: Promise<void> = vm.submitAnswer();
      repository.answers[0].fail(new GameFailure('NETWORK_ERROR', '响应丢失'));
      await first;
      repository.server = choiceSnapshot();
      await vm.reload();
      expect(vm.retryAnswer).assertFalse();
      expect(vm.activeIndex).assertEqual(0);
      expect(vm.draftAnswer).assertEqual('星辰大海');
      expect(vm.completionRevision).assertEqual(0);
      await vm.retrySubmission();
      expect(repository.answers.length).assertEqual(1);
      vm.leave();
    });

    it('logoutAndSamePlayerReloginDiscardLateAnswerAndGenerateANewIdentity', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      let players: number = 0;
      const vm: GameplayViewModel = viewModel(repository, () => { players++; });
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const old: Promise<void> = vm.submitAnswer();
      vm.reset();
      vm.bindOwner('playeralice');
      await vm.open('assignment1');
      vm.editAnswer('新会话答案');
      const fresh: Promise<void> = vm.submitAnswer();
      repository.answers[0].succeed(answerResult('correct', completedSnapshot(), 999));
      await old;
      expect(players).assertEqual(0);
      expect(vm.submitting).assertTrue();
      expect(vm.snapshot?.detail.completedLevels).assertEqual(0);
      expect(repository.answers[1].requestId === repository.answers[0].requestId).assertFalse();
      repository.answers[1].succeed(answerResult('incorrect', textSnapshot(), 0));
      await fresh;
      expect(players).assertEqual(1);
      vm.leave();
    });

    it('olderPageAnswerCannotRetireReenteredPageFrozenRetry', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer(' 星辰大海 ');
      const old: Promise<void> = vm.submitAnswer();
      vm.leave();
      await vm.open('assignment1');
      const current: Promise<void> = vm.retrySubmission();
      repository.answers[0].succeed(answerResult('correct', choiceSnapshot()));
      await old;
      expect(vm.submitting).assertTrue();
      repository.answers[1].fail(new GameFailure('CONTRACT_ERROR', '无法确认'));
      await current;
      const retry: Promise<void> = vm.retrySubmission();
      expect(repository.answers[2].requestId).assertEqual(repository.answers[0].requestId);
      repository.answers[2].succeed(answerResult('correct', choiceSnapshot()));
      await retry;
      vm.leave();
    });

    it('penaltyClockOnlyEnablesRetryWithoutChangingServerFacts', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      repository.server = choiceSnapshot();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('A');
      const pending: Promise<void> = vm.submitAnswer();
      const penalised: GameplaySnapshot = choiceSnapshot();
      penalised.levels[1].lastAnswer = 'A';
      penalised.levels[1].wrongCount = 1;
      penalised.levels[1].cooldownUntil = new Date(Date.now() + 60000).toISOString();
      repository.answers[0].succeed(answerResult('incorrect', penalised));
      await pending;
      expect(vm.answerAllowed()).assertFalse();
      expect(vm.blockedReason().includes('距离再次尝试')).assertTrue();
      vm.now += 61000;
      expect(vm.answerAllowed()).assertTrue();
      expect(vm.currentLevel()?.wrongCount).assertEqual(1);
      expect(vm.currentLevel()?.cooldownUntil).assertEqual(penalised.levels[1].cooldownUntil);
      expect(repository.answers.length).assertEqual(1);
      penalised.levels[1].locked = true;
      expect(vm.answerAllowed()).assertFalse();
      vm.leave();
    });

    it('terminal409RecoversAuthoritativeLockAndFailedReadHidesPrivateFacts', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      repository.server = choiceSnapshot();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('B');
      const pending: Promise<void> = vm.submitAnswer();
      repository.server = choiceSnapshot();
      repository.server.levels[1].locked = true;
      repository.answers[0].fail(new GameFailure('LOCKED', '已锁定', 409));
      await pending;
      expect(repository.reads).assertEqual(2);
      expect(vm.currentLevel()?.locked).assertTrue();
      expect(vm.answerAllowed()).assertFalse();
      expect(vm.retryAnswer).assertFalse();
      repository.readFailure = new GameFailure('NOT_FOUND', '不可访问', 404);
      await vm.reload();
      expect(vm.snapshot).assertNull();
      expect(vm.error).assertEqual('不可访问');
      vm.leave();
    });

    it('freshMultiCompletionIsReportedOnceAndCompletedRevisitIsReadOnly', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      repository.server = choiceSnapshot();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('B');
      const pending: Promise<void> = vm.submitAnswer();
      repository.answers[0].succeed(answerResult('correct', completedSnapshot(), 100));
      await pending;
      expect(vm.completionRevision).assertEqual(1);
      expect(vm.snapshot?.detail.status).assertEqual('completed');
      await vm.submitAnswer();
      expect(repository.answers.length).assertEqual(1);
      vm.leave();
      repository.server = completedSnapshot();
      await vm.open('assignment1');
      expect(vm.completionRevision).assertEqual(0);
      expect(vm.draftAnswer).assertEqual('B');
      expect(vm.answerAllowed()).assertFalse();
      vm.leave();
    });

    it('alreadyCompletedAndLatestCancelledSettlementDoNotCelebrate', 0, async () => {
      const repository: AnswerRepository = new AnswerRepository();
      repository.server = choiceSnapshot();
      const vm: GameplayViewModel = viewModel(repository);
      await vm.open('assignment1');
      vm.editAnswer('B');
      const pending: Promise<void> = vm.submitAnswer();
      repository.answers[0].succeed(answerResult('already_completed', completedSnapshot(), 100));
      await pending;
      expect(vm.completionRevision).assertEqual(0);
      expect(vm.feedback).assertEqual('');
      vm.leave();
      repository.server = textSnapshot();
      await vm.open('assignment1');
      vm.editAnswer('星辰大海');
      const cancelled: Promise<void> = vm.submitAnswer();
      const latest: GameplaySnapshot = choiceSnapshot();
      latest.detail.status = 'cancelled';
      repository.answers[1].succeed(answerResult('correct', latest));
      await cancelled;
      expect(vm.completionRevision).assertEqual(0);
      expect(vm.answerAllowed()).assertFalse();
      expect(vm.retryAnswer).assertFalse();
      vm.leave();
    });
  });
}
