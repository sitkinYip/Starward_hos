export class LobbyUnreadHistory {
  assignments: string[] = [];
  rewards: string[] = [];
}

export interface LobbyUnreadStore {
  load(owner: string): LobbyUnreadHistory;
  save(owner: string, history: LobbyUnreadHistory): void;
}
