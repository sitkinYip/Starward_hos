import { describe, expect, it } from '@ohos/hypium';
import { GameReward } from '../main/ets/business/GameReward';
import { GameFailure } from '../main/ets/business/models';
import { ReadCancellation } from '../main/ets/business/ReadCancellation';
import { MockGameRepository } from '../main/ets/data/MockGameRepository';
import { RewardsViewModel } from '../main/ets/features/RewardsViewModel';

function grant(owner: string, id: string = 'gift'): GameReward {
  const reward: GameReward = new GameReward();
  reward.id = id;
  reward.player = owner;
  reward.status = 'available';
  reward.claimDetails = '领取口令';
  reward.snapshot.name = '礼物';
  return reward;
}

class RewardRepository extends MockGameRepository {
  entries: GameReward[] = [];
  readFailure: GameFailure | null = null;
  hold: boolean = false;
  lastRead: ReadCancellation | undefined;
  deliver: ((entries: GameReward[]) => void) | undefined;

  async rewards(cancellation?: ReadCancellation): Promise<GameReward[]> {
    this.lastRead = cancellation;
    if (this.hold) {
      this.hold = false;
      return new Promise<GameReward[]>((resolve: (entries: GameReward[]) => void) => { this.deliver = resolve; });
    }
    if (this.readFailure !== null) { throw this.readFailure; }
    return this.entries;
  }
}

export default function rewardsViewModelTests(): void {
  describe('RewardsViewModel', () => {
    it('keepsOpenDetailOnTransientFailureAndUpdatesItsServerStatus', 0, async () => {
      const repository: RewardRepository = new RewardRepository();
      const model: RewardsViewModel = new RewardsViewModel(repository, () => {});
      try {
        repository.entries = [grant('owner')];
        model.bindOwner('owner');
        model.setActive(true);
        await model.refresh();
        model.open('gift');
        const selected: GameReward | null = model.selected;
        repository.entries = [grant('owner')];
        await model.refresh();
        expect(model.selected === selected).assertTrue();
        repository.readFailure = new GameFailure('REQUEST_FAILED', '暂时无法打开收藏', 503);
        await model.refresh();
        expect(model.error).assertEqual('');
        expect(model.showSyncNotice).assertTrue();
        expect(model.selected?.claimDetails).assertEqual('领取口令');
        repository.readFailure = null;
        const redeemed: GameReward = grant('owner');
        redeemed.status = 'redeemed';
        redeemed.claimDetails = '';
        repository.entries = [redeemed];
        await model.refresh();
        expect(model.showSyncNotice).assertFalse();
        expect(model.selected?.status).assertEqual('redeemed');
        expect(model.selected?.claimDetails).assertEqual('');
        repository.entries = [];
        await model.refresh();
        expect(model.selected).assertNull();
      } finally {
        model.setActive(false);
      }
    });

    it('keepsFirstReadRetryAndOnlyShowsOneNoticePerOutageAfterAConfirmedEmptyList', 0, async () => {
      const repository: RewardRepository = new RewardRepository();
      const model: RewardsViewModel = new RewardsViewModel(repository, () => {});
      try {
        const failure: GameFailure = new GameFailure('NETWORK_ERROR', '连接中断');
        repository.readFailure = failure;
        model.bindOwner('owner');
        model.setActive(true);
        await model.refresh();
        expect(model.loaded).assertFalse();
        expect(model.error).assertEqual('连接中断');
        expect(model.showSyncNotice).assertFalse();

        repository.readFailure = null;
        await model.refresh();
        expect(model.loaded).assertTrue();
        expect(model.entries.length).assertEqual(0);
        repository.readFailure = failure;
        await model.refresh();
        expect(model.showSyncNotice).assertTrue();
        expect(model.error).assertEqual('');
        expect(model.loaded).assertTrue();

        model.dismissSyncNotice();
        await model.refresh();
        expect(model.showSyncNotice).assertFalse();
        repository.readFailure = null;
        await model.refresh();
        repository.readFailure = failure;
        await model.refresh();
        expect(model.showSyncNotice).assertTrue();
        model.bindOwner('next');
        expect(model.showSyncNotice).assertFalse();
        expect(model.loaded).assertFalse();
      } finally {
        model.setActive(false);
      }
    });

    it('discardsAnOldAccountReadEvenIfItCompletesAfterTheNewOne', 0, async () => {
      const repository: RewardRepository = new RewardRepository();
      const model: RewardsViewModel = new RewardsViewModel(repository, () => {});
      try {
        model.bindOwner('first');
        model.setActive(true);
        repository.hold = true;
        const oldRead = model.refresh();
        const cancellation: ReadCancellation | undefined = repository.lastRead;
        model.bindOwner('second');
        expect(cancellation?.cancelled).assertTrue();
        repository.entries = [grant('second', 'new')];
        model.setActive(true);
        await model.refresh();
        repository.deliver?.([grant('first', 'old')]);
        await oldRead;
        expect(model.entries[0].id).assertEqual('new');
      } finally {
        model.setActive(false);
      }
    });

    it('clearsTheListAndOpenDetailOnAForbiddenRead', 0, async () => {
      const repository: RewardRepository = new RewardRepository();
      let rejected: boolean = false;
      const model: RewardsViewModel = new RewardsViewModel(repository, () => { rejected = true; });
      try {
        repository.entries = [grant('owner')];
        model.bindOwner('owner');
        model.setActive(true);
        await model.refresh();
        model.open('gift');
        repository.readFailure = new GameFailure('ACCOUNT_DISABLED', '账号已停用', 403);
        await model.refresh();
        expect(rejected).assertTrue();
        expect(model.selected).assertNull();
        expect(model.entries.length).assertEqual(0);
      } finally {
        model.setActive(false);
      }
    });

    it('keepsTheAccountSignedInWhenOnlyTheCollectionRouteIsUnavailable', 0, async () => {
      const repository: RewardRepository = new RewardRepository();
      let rejected: boolean = false;
      const model: RewardsViewModel = new RewardsViewModel(repository, () => { rejected = true; });
      try {
        repository.entries = [grant('owner')];
        model.bindOwner('owner');
        model.setActive(true);
        await model.refresh();
        model.open('gift');
        repository.readFailure = new GameFailure('NOT_FOUND', '收藏暂时不可访问', 404);
        await model.refresh();
        expect(rejected).assertFalse();
        expect(model.selected).assertNull();
        expect(model.entries.length).assertEqual(0);
        expect(model.error).assertEqual('收藏暂时不可访问');
        repository.readFailure = null;
        await model.refresh();
        expect(model.entries.length).assertEqual(1);
      } finally {
        model.setActive(false);
      }
    });
  });
}
