import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, Player } from './models';

export interface GameRepository {
  readonly mode: string;
  login(account: string, password: string): Promise<Player>;
  me(): Promise<Player>;
  changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player>;
  updateProfile(displayName: string, avatar?: AvatarUpload | null): Promise<Player>;
  avatar(forceRefresh?: boolean): Promise<AvatarImage | null>;
  assignments(): Promise<AssignmentSummary[]>;
  assignment(id: string): Promise<AssignmentDetail>;
  logout(): void;
}
