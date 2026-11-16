import { describe, expect, it } from '@ohos/hypium';
import { GameplayClue, GameplayCompletionTarget, GameplaySnapshot } from '../main/ets/business/GameplayModels';
import { NarrativeBless, NarrativeContent, NarrativeLetter } from '../main/ets/business/NarrativeModels';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { StarLetterEntry } from '../main/ets/business/StarLetters';
import { AssignmentSummary, GameFailure } from '../main/ets/business/models';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { StarLettersViewModel } from '../main/ets/features/StarLettersViewModel';

const FIRST_DAY: string = '2026-11-01T00:00:00Z';
const SECOND_DAY: string = '2026-11-02T00:00:00Z';

function clue(id: string, title: string, kind: string = 'letter'): GameplayClue {
  const result: GameplayClue = new GameplayClue();
  result.kind = kind;
  result.narrative = id;
  result.unlockedAt = FIRST_DAY;
  result.content.title = title;
  result.content.text = '来自获授权的场次线索。';
  return result;
}

function assignment(id: string, status: string, clues: GameplayClue[], target: string = '',
  owner: string = 'owner'): GameplaySnapshot {
  const result: GameplaySnapshot = new GameplaySnapshot();
  result.detail.id = id;
  result.detail.player = owner;
  result.detail.title = `场次 ${id}`;
  result.detail.status = status;
  if (status === 'completed') { result.detail.completedAt = SECOND_DAY; }
  result.clues = clues;
  if (target.length > 0) {
    const completion: GameplayCompletionTarget = new GameplayCompletionTarget();
    completion.kind = 'narrative';
    completion.id = target;
    result.completionTarget = completion;
  }
  return result;
}

function story(id: string, letter: boolean): NarrativeContent {
  const result: NarrativeContent = new NarrativeContent();
  result.id = id;
  result.kind = letter ? 'letter' : 'bless';
  if (letter) { result.letter = new NarrativeLetter(); }
  else { result.bless = new NarrativeBless(); }
  return result;
}

class PendingNarrative {
  readonly cancellation: ReadCancellation | undefined;
  readonly resolve: (value: NarrativeContent) => void;

  constructor(cancellation: ReadCancellation | undefined, resolve: (value: NarrativeContent) => void) {
    this.cancellation = cancellation;
    this.resolve = resolve;
  }
}

class StarLettersRepository extends MockGameRepository {
  summaries: AssignmentSummary[] = [];
  readonly snapshots = new Map<string, GameplaySnapshot>();
  readonly snapshotFails = new Map<string, GameFailure>();
  readonly narratives = new Map<string, NarrativeContent>();
  readonly narrativeIds: string[] = [];
  readonly detailIds: string[] = [];
  holdNarrative: ((work: PendingNarrative) => void) | null = null;
  listCalls: number = 0;
  listFailure: GameFailure | null = null;

  setup(snapshots: GameplaySnapshot[]): void {
    this.summaries = snapshots.map((item: GameplaySnapshot) => item.detail);
    this.snapshots.clear();
    for (const snapshot of snapshots) { this.snapshots.set(snapshot.detail.id, snapshot); }
  }

  async assignments(_cancellation?: ReadCancellation): Promise<AssignmentSummary[]> {
    this.listCalls++;
    if (this.listFailure !== null) { throw this.listFailure; }
    return this.summaries;
  }

  async gameplay(id: string, _cancellation?: ReadCancellation): Promise<GameplaySnapshot> {
    this.detailIds.push(id);
    const failure: GameFailure | undefined = this.snapshotFails.get(id);
    if (failure !== undefined) { throw failure; }
    const match: GameplaySnapshot | undefined = this.snapshots.get(id);
    if (match === undefined) { throw new GameFailure('NOT_FOUND', '场次不存在。', 404); }
    return match;
  }

  async narrative(assignmentId: string, contentId: string, cancellation?: ReadCancellation): Promise<NarrativeContent> {
    const key: string = `${assignmentId}:${contentId}`;
    this.narrativeIds.push(key);
    const announced: ((work: PendingNarrative) => void) | null = this.holdNarrative;
    this.holdNarrative = null;
    if (announced !== null) {
      return new Promise<NarrativeContent>((resolve: (value: NarrativeContent) => void) =>
        announced(new PendingNarrative(cancellation, resolve)));
    }
    const match: NarrativeContent | undefined = this.narratives.get(key);
    if (match === undefined) { throw new GameFailure('NOT_FOUND', '内容尚未解锁。', 404); }
    return match;
  }
}

export default function starLettersViewModelTests(): void {
  describe('StarLettersViewModel', () => {
    it('ProjectsGrantedLettersAndBlessingsAndOnlyAuthorizedFinalesInStableOrder', 0, async () => {
      const repository: StarLettersRepository = new StarLettersRepository();
      repository.setup([
        assignment('z-same', 'active', [clue('shared', '另一场同信')], 'unearned'),
        assignment('a-same', 'completed', [clue('shared', ''), clue('shared', '重复副本')], 'shared'),
        assignment('finale', 'completed', [], 'finale-letter'),
        assignment('blessing', 'completed', [clue('verse', '祝福', 'bless'), clue('verse', '重复祝福', 'bless')], 'verse'),
        assignment('bless-finale', 'completed', [], 'finale-bless'),
        assignment('locked', 'completed', [], 'locked-bless'),
        assignment('cancelled', 'cancelled', [clue('hidden', '已取消')]),
      ]);
      repository.narratives.set('finale:finale-letter', story('finale-letter', true));
      repository.narratives.set('bless-finale:finale-bless', story('finale-bless', false));
      const model: StarLettersViewModel = new StarLettersViewModel(repository, () => {});
      await model.refresh();
      expect(repository.listCalls).assertEqual(0);
      model.bindOwner('owner');
      await model.refresh();
      expect(model.entries.map((entry: StarLetterEntry) => entry.id).join(','))
        .assertEqual('bless-finale:finale-bless,finale:finale-letter,a-same:shared,blessing:verse,z-same:shared');
      expect(model.entries[0].title).assertEqual('旅途终章');
      expect(model.entries[2].title).assertEqual('星海信笺');
      expect(model.entries[2].description).assertEqual('来自获授权的场次线索。');
      expect(model.entries[3].title).assertEqual('祝福');
      expect(repository.detailIds.includes('cancelled')).assertFalse();
      expect(repository.narrativeIds.length).assertEqual(3);
      expect(repository.narrativeIds.includes('blessing:verse')).assertFalse();
      expect(model.canOpen('blessing', 'verse')).assertTrue();
      expect(model.canOpen('bless-finale', 'finale-bless')).assertTrue();
      expect(model.canOpen('locked', 'locked-bless')).assertFalse();
      expect(model.canOpen('z-same', 'unearned')).assertFalse();
      expect(model.error).assertEqual('');
      expect(model.detailErrors.length).assertEqual(1);
      expect(model.detailErrors[0].assignmentId).assertEqual('locked');
      expect(model.loading).assertFalse();
    });

    it('KeepsSuccessfulSourcesAndRetriesOnlyTheFailedAssignment', 0, async () => {
      const repository: StarLettersRepository = new StarLettersRepository();
      repository.setup([assignment('first', 'active', [clue('one', '一封')]),
        assignment('second', 'active', [clue('two', '另一封')])]);
      repository.snapshotFails.set('second', new GameFailure('UNAVAILABLE', '稍后重试。', 503));
      const model: StarLettersViewModel = new StarLettersViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      expect(model.entries.length).assertEqual(1);
      expect(model.detailErrors[0].assignmentId).assertEqual('second');
      expect(model.error).assertEqual('');
      repository.snapshotFails.delete('second');
      await model.retryAssignment('second');
      expect(repository.listCalls).assertEqual(1);
      expect(repository.detailIds.join(',')).assertEqual('first,second,second');
      expect(model.entries.length).assertEqual(2);
      expect(model.detailErrors.length).assertEqual(0);
      repository.snapshotFails.set('second', new GameFailure('NOT_FOUND', '场次暂不可访问。', 404));
      await model.refresh();
      expect(model.canOpen('second', 'two')).assertFalse();
      expect(model.canOpen('first', 'one')).assertTrue();
    });

    it('DoesNotRestoreRevokedEntriesWithoutAConfirmedNarrativeRead', 0, async () => {
      const repository: StarLettersRepository = new StarLettersRepository();
      repository.setup([assignment('sender', 'active', [clue('letter', '信笺')])]);
      const model: StarLettersViewModel = new StarLettersViewModel(repository, () => {});
      model.bindOwner('owner');
      await model.refresh();
      expect(model.canOpen('sender', 'letter')).assertTrue();
      model.hideEntry('sender', 'letter');
      await model.retryAssignment('sender');
      expect(model.canOpen('sender', 'letter')).assertFalse();
      expect(model.detailErrors.length).assertEqual(1);
      repository.narratives.set('sender:letter', story('letter', true));
      await model.refresh();
      expect(model.canOpen('sender', 'letter')).assertTrue();
      expect(model.detailErrors.length).assertEqual(0);
    });

    it('CancelsPendingReadsAndDiscardsLatePrivateResultsAfterAccountSwitch', 0, async () => {
      const repository: StarLettersRepository = new StarLettersRepository();
      repository.setup([assignment('old', 'completed', [], 'old-letter')]);
      const model: StarLettersViewModel = new StarLettersViewModel(repository, () => {});
      model.bindOwner('owner');
      const requested: Promise<PendingNarrative> = new Promise<PendingNarrative>((resolve: (work: PendingNarrative) => void) => {
        repository.holdNarrative = resolve;
      });
      const first: Promise<void> = model.refresh();
      const old: PendingNarrative = await requested;
      model.bindOwner('next');
      expect(old.cancellation?.cancelled).assertTrue();
      repository.setup([assignment('new', 'active', [clue('new-letter', '新信')], '', 'next')]);
      await model.refresh();
      old.resolve(story('old-letter', true));
      await first;
      expect(model.entries[0].id).assertEqual('new:new-letter');
      expect(model.canOpen('old', 'old-letter')).assertFalse();
      expect(model.loading).assertFalse();
    });

    it('ReportsAListFailureWithoutConfusingItWithAnEmptyArchive', 0, async () => {
      const repository: StarLettersRepository = new StarLettersRepository();
      let expired: string = '';
      const model: StarLettersViewModel = new StarLettersViewModel(repository, (message: string) => { expired = message; });
      model.bindOwner('owner');
      repository.listFailure = new GameFailure('UNAVAILABLE', '稍后重试。', 503);
      await model.refresh();
      expect(model.error).assertEqual('稍后重试。');
      repository.listFailure = null;
      await model.refresh();
      expect(model.error).assertEqual('');
      expect(model.entries.length).assertEqual(0);
      repository.listFailure = new GameFailure('UNAUTHORIZED', '请重新登录。', 401);
      await model.refresh();
      expect(expired).assertEqual('请重新登录。');
      expect(model.entries.length).assertEqual(0);
    });
  });
}
