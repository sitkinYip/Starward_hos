import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, Player } from './models';
import { GameplayAnswerResult, GameplaySnapshot } from './GameplayModels';
import { NarrativeContent } from './NarrativeModels';
import { ReadCancellation } from './ReadCancellation';
import { GameNotification } from './GameNotification';
import { GameReward } from './GameReward';

export interface GameRepository {
  readonly mode: string;
  login(account: string, password: string): Promise<Player>;
  me(cancellation?: ReadCancellation): Promise<Player>;
  changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player>;
  updateProfile(displayName: string, avatar?: AvatarUpload | null): Promise<Player>;
  avatar(forceRefresh?: boolean): Promise<AvatarImage | null>;
  assignments(cancellation?: ReadCancellation): Promise<AssignmentSummary[]>;
  assignment(id: string): Promise<AssignmentDetail>;
  startAssignment(id: string, requestId: string): Promise<GameplaySnapshot>;
  gameplay(id: string, cancellation?: ReadCancellation): Promise<GameplaySnapshot>;
  narrative(assignmentId: string, contentId: string, cancellation?: ReadCancellation): Promise<NarrativeContent>;
  rewards(cancellation?: ReadCancellation): Promise<GameReward[]>;
  notifications(cancellation?: ReadCancellation): Promise<GameNotification[]>;
  readNotification(id: string): Promise<string>;
  answerAssignment(id: string, sessionLevelId: string, rawAnswer: string, requestId: string): Promise<GameplayAnswerResult>;
  logout(): void;
}
