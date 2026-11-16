import { describe, expect, it } from '@ohos/hypium';
import { NarrativeBless, NarrativeContent, NarrativeLetter } from '../main/ets/business/NarrativeModels';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { GameFailure } from '../main/ets/business/models';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { NarrativeRoute, NarrativeViewModel } from '../main/ets/features/NarrativeViewModel';

class NarrativeRead {
  readonly route: NarrativeRoute;
  readonly cancellation: ReadCancellation | undefined;
  readonly resolve: (value: NarrativeContent) => void;
  readonly reject: (error: GameFailure) => void;

  constructor(route: NarrativeRoute, cancellation: ReadCancellation | undefined,
    resolve: (value: NarrativeContent) => void, reject: (error: GameFailure) => void) {
    this.route = route;
    this.cancellation = cancellation;
    this.resolve = resolve;
    this.reject = reject;
  }
}

class NarrativeRepository extends MockGameRepository {
  reads: NarrativeRead[] = [];

  narrative(assignmentId: string, contentId: string, cancellation?: ReadCancellation): Promise<NarrativeContent> {
    return new Promise<NarrativeContent>((resolve, reject) => {
      this.reads.push(new NarrativeRead(new NarrativeRoute(assignmentId, contentId), cancellation, resolve, reject));
    });
  }
}

function letter(id: string): NarrativeContent {
  const content: NarrativeContent = new NarrativeContent();
  content.id = id;
  content.kind = 'letter';
  content.letter = new NarrativeLetter();
  return content;
}

function blessing(id: string): NarrativeContent {
  const content: NarrativeContent = new NarrativeContent();
  content.id = id;
  content.kind = 'bless';
  content.bless = new NarrativeBless();
  return content;
}

export default function narrativeViewModelTests(): void {
  describe('NarrativeViewModel', () => {
    it('RetriesOnlyTheSameNarrativeReadAndDoesNotRepeatAnInFlightRequest', 0, async () => {
      const repository: NarrativeRepository = new NarrativeRepository();
      const model: NarrativeViewModel = new NarrativeViewModel(repository, () => {});
      const route: NarrativeRoute = new NarrativeRoute('assignment', 'narrative');
      expect(model.open(route)).assertFalse();
      model.bindOwner('player');
      expect(model.open(route)).assertTrue();
      expect(model.loading).assertTrue();
      expect(model.content).assertNull();
      model.retry();
      repository.reads[0].reject(new GameFailure('UNAVAILABLE', '请稍后重试。', 503));
      await Promise.resolve();
      expect(model.retryable).assertTrue();
      model.retry();
      model.retry();
      expect(repository.reads.length).assertEqual(2);
      expect(repository.reads[1].route.assignmentId).assertEqual(route.assignmentId);
      expect(repository.reads[1].route.contentId).assertEqual(route.contentId);
      repository.reads[1].resolve(letter(route.contentId));
      await Promise.resolve();
      expect(model.content?.id).assertEqual(route.contentId);
      expect(model.loading).assertFalse();
      expect(model.error).assertEqual('');
    });

    it('IgnoresReadResultsAfterLeavingAndSwitchingAccounts', 0, async () => {
      const repository: NarrativeRepository = new NarrativeRepository();
      const model: NarrativeViewModel = new NarrativeViewModel(repository, () => {});
      model.bindOwner('first-player');
      model.open(new NarrativeRoute('first-assignment', 'first-narrative'));
      model.close();
      expect(repository.reads[0].cancellation?.cancelled).assertTrue();
      model.bindOwner('second-player');
      model.open(new NarrativeRoute('second-assignment', 'second-narrative'));
      repository.reads[0].resolve(blessing('first-narrative'));
      await Promise.resolve();
      expect(model.content).assertNull();
      expect(model.loading).assertTrue();
      repository.reads[1].resolve(letter('second-narrative'));
      await Promise.resolve();
      expect(model.content?.id).assertEqual('second-narrative');
      model.bindOwner('');
      expect(model.route).assertNull();
      expect(model.content).assertNull();
    });

    it('ReopeningBlessingFromArchiveCreatesANewPresentationAfterARead', 0, async () => {
      const repository: NarrativeRepository = new NarrativeRepository();
      const model: NarrativeViewModel = new NarrativeViewModel(repository, () => {});
      const route: NarrativeRoute = new NarrativeRoute('assignment', 'blessing', 'star-letters');
      model.bindOwner('player');
      expect(model.open(route)).assertTrue();
      const first: number = model.revision;
      repository.reads[0].resolve(blessing(route.contentId));
      await Promise.resolve();
      expect(model.content?.kind).assertEqual('bless');
      expect(model.content?.id).assertEqual(route.contentId);
      model.close();
      expect(model.content).assertNull();
      expect(model.open(route)).assertTrue();
      expect(model.revision).assertEqual(first + 1);
      expect(model.content).assertNull();
      expect(repository.reads[1].route.contentId).assertEqual(route.contentId);
      repository.reads[1].resolve(blessing(route.contentId));
      await Promise.resolve();
      expect(model.content?.kind).assertEqual('bless');
      expect(model.error).assertEqual('');
    });
  });
}
