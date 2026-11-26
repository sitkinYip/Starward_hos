import { AssignmentSummary } from '../business/models';
import { GameReward } from '../business/GameReward';
import { LobbyUnreadHistory, LobbyUnreadStore } from '../business/LobbyUnreadHistory';

/** Acknowledgements are durable for the signed-in account and independent of server progress. */
@ObservedV2
export class LobbyUnread {
  @Trace private owner: string = '';
  @Trace private history: LobbyUnreadHistory = new LobbyUnreadHistory();
  private store?: LobbyUnreadStore;

  attach(store: LobbyUnreadStore): void {
    this.store = store;
    if (this.owner.length > 0) { this.history = store.load(this.owner); }
  }

  bindOwner(owner: string): void {
    if (owner === this.owner) { return; }
    this.owner = owner;
    this.history = owner.length > 0 ? this.store?.load(owner) ?? new LobbyUnreadHistory() : new LobbyUnreadHistory();
  }

  assignments(items: AssignmentSummary[]): string[] {
    const seen: Set<string> = new Set(this.history.assignments);
    return items.filter((item: AssignmentSummary) => item.player === this.owner && this.owner.length > 0 &&
      item.status === 'assigned' && !seen.has(item.id)).map((item: AssignmentSummary) => item.id);
  }

  rewards(items: GameReward[]): string[] {
    const seen: Set<string> = new Set(this.history.rewards);
    return items.filter((item: GameReward) => item.player === this.owner && this.owner.length > 0 &&
      item.status === 'available' && !seen.has(item.id)).map((item: GameReward) => item.id);
  }

  acknowledgeAssignments(ids: string[]): void { this.acknowledge(ids, []); }

  acknowledgeRewards(ids: string[]): void { this.acknowledge([], ids); }

  private acknowledge(assignments: string[], rewards: string[]): void {
    if (this.owner.length === 0 || (assignments.length === 0 && rewards.length === 0)) { return; }
    const history: LobbyUnreadHistory = new LobbyUnreadHistory();
    history.assignments = Array.from(new Set(this.history.assignments.concat(assignments)));
    history.rewards = Array.from(new Set(this.history.rewards.concat(rewards)));
    if (history.assignments.length === this.history.assignments.length &&
      history.rewards.length === this.history.rewards.length) { return; }
    this.history = history;
    this.store?.save(this.owner, history);
  }
}
