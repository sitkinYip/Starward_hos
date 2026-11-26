import { GameNotification } from './GameNotification';
import { GameReward } from './GameReward';
import { AssignmentSummary } from './models';

export class LobbyFeed {
  assignments: AssignmentSummary[] = [];
  rewards: GameReward[] = [];
  notifications: GameNotification[] = [];
}
