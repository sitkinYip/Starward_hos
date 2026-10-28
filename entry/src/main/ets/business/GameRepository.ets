import { AssignmentDetail, AssignmentSummary, Player } from './models';

export interface GameRepository {
  readonly mode: string;
  login(account: string, password: string): Promise<Player>;
  me(): Promise<Player>;
  changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player>;
  assignments(): Promise<AssignmentSummary[]>;
  assignment(id: string): Promise<AssignmentDetail>;
  logout(): void;
}
