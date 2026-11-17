import { GameFailure } from './models';

export class SavedSession {
  readonly token: string;
  readonly playerId: string;

  constructor(token: string, playerId: string) {
    this.token = token;
    this.playerId = playerId;
  }
}

/** Stores one session for the repository's configured environment. */
export interface CredentialStore {
  read(): Promise<SavedSession | null>;
  save(session: SavedSession): Promise<void>;
  clear(): Promise<void>;
}
/** Only expiry or an explicit player lookup failure invalidates a saved session. */
export function isRestoredSessionInvalid(error: Object): boolean {
  return error instanceof GameFailure && (error.status === 401 ||
    (error.status === 403 && error.code === 'ACCOUNT_DISABLED') ||
    (error.status === 404 && error.code === 'NOT_FOUND'));
}
