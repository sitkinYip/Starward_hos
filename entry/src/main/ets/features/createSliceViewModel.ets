import { HttpsGameRepository } from '../data/HttpsGameRepository';
import { GameRepository } from '../business/GameRepository';
import { AssignmentDetail, AssignmentSummary, AvatarImage, AvatarUpload, GameFailure, Player } from '../business/models';
import { AppEnvironment } from '../platform/AppEnvironment';
import { NativeHttpTransport } from '../platform/HttpTransport';
import { SliceViewModel } from './SliceViewModel';

// An invalid packaged configuration is different from an absent one: it must
// never fall back to successful demo authentication.
class UnavailableRepository implements GameRepository {
  readonly mode: string = 'unavailable';
  private readonly reason: string;

  constructor(reason: string) {
    this.reason = reason;
  }

  async login(account: string, password: string): Promise<Player> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  async me(): Promise<Player> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  async changePassword(oldPassword: string, password: string, confirmation: string): Promise<Player> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  async assignments(): Promise<AssignmentSummary[]> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  async assignment(id: string): Promise<AssignmentDetail> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  async updateProfile(displayName: string, avatar: AvatarUpload | null = null): Promise<Player> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  async avatar(forceRefresh: boolean = false): Promise<AvatarImage | null> {
    throw new GameFailure('CONFIG_ERROR', this.reason);
  }

  logout(): void {
    // This repository never holds a credential or private state.
  }
}

export function createSliceViewModel(): SliceViewModel {
  if (AppEnvironment.configurationError.length > 0) {
    const unavailable: SliceViewModel = new SliceViewModel(new UnavailableRepository(AppEnvironment.configurationError));
    unavailable.error = AppEnvironment.configurationError;
    unavailable.errorCode = 'CONFIG_ERROR';
    return unavailable;
  }
  const model: SliceViewModel = AppEnvironment.endpoint.length > 0 ?
    new SliceViewModel(new HttpsGameRepository(AppEnvironment.endpoint, new NativeHttpTransport(AppEnvironment.caData, AppEnvironment.timeoutMs))) : new SliceViewModel();
  return model;
}
