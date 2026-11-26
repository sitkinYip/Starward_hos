import { describe, expect, it } from '@ohos/hypium';
import { GameReward } from '../main/ets/business/GameReward';
import { AssignmentSummary } from '../main/ets/business/models';
import { LobbyUnreadHistory, LobbyUnreadStore } from '../main/ets/business/LobbyUnreadHistory';
import { LobbyUnread } from '../main/ets/features/LobbyUnread';

class MemoryUnreadHistory implements LobbyUnreadStore {
  private histories: Map<string, LobbyUnreadHistory> = new Map();

  load(owner: string): LobbyUnreadHistory { return this.histories.get(owner) ?? new LobbyUnreadHistory(); }

  save(owner: string, history: LobbyUnreadHistory): void { this.histories.set(owner, history); }
}

export default function lobbyUnreadTests(): void {
  describe('LobbyUnread', () => {
    it('keepsAccountAcknowledgementsAcrossRestartAndLeavesNewGrantsUnread', 0, () => {
      const history: MemoryUnreadHistory = new MemoryUnreadHistory();
      const model: LobbyUnread = new LobbyUnread();
      model.attach(history);
      model.bindOwner('first');
      const assignment: AssignmentSummary = new AssignmentSummary();
      assignment.id = 'assignment';
      assignment.player = 'first';
      const reward: GameReward = new GameReward();
      reward.id = 'reward';
      reward.player = 'first';
      expect(model.assignments([assignment]).length).assertEqual(1);
      expect(model.rewards([reward]).length).assertEqual(1);
      model.acknowledgeAssignments(model.assignments([assignment]));
      model.acknowledgeRewards(model.rewards([reward]));
      expect(assignment.status).assertEqual('assigned');
      expect(reward.status).assertEqual('available');
      const restarted: LobbyUnread = new LobbyUnread();
      restarted.attach(history);
      restarted.bindOwner('first');
      expect(restarted.assignments([assignment]).length).assertEqual(0);
      expect(restarted.rewards([reward]).length).assertEqual(0);
      const newReward: GameReward = new GameReward();
      newReward.id = 'new-reward';
      newReward.player = 'first';
      expect(restarted.rewards([reward, newReward]).join(',')).assertEqual('new-reward');
      restarted.bindOwner('second');
      expect(restarted.assignments([assignment]).length).assertEqual(0);
      assignment.player = 'second';
      expect(restarted.assignments([assignment]).join(',')).assertEqual('assignment');
      assignment.status = 'active';
      expect(restarted.assignments([assignment]).length).assertEqual(0);
    });
  });
}
