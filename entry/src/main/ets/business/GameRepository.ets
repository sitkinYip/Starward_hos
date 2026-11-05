import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, Player } from './models';
import { GameplayAnswerResult, GameplaySnapshot } from './GameplayModels';

export interface GameRepository {
  readonly mode: string;
  login(account: string, password: string): Promise<Player>;
  me(): Promise<Player>;
  changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player>;
  updateProfile(displayName: string, avatar?: AvatarUpload | null): Promise<Player>;
  avatar(forceRefresh?: boolean): Promise<AvatarImage | null>;
  assignments(): Promise<AssignmentSummary[]>;
  assignment(id: string): Promise<AssignmentDetail>;
  startAssignment(id: string, requestId: string): Promise<GameplaySnapshot>;
  gameplay(id: string): Promise<GameplaySnapshot>;
  answerAssignment(id: string, sessionLevelId: string, rawAnswer: string, requestId: string): Promise<GameplayAnswerResult>;
  logout(): void;
}
