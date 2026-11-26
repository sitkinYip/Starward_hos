import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { LobbyUnreadHistory, LobbyUnreadStore } from '../business/LobbyUnreadHistory';
import { accountPreferenceKey } from './AccountPreferenceKey';
import { AppEnvironment } from './AppEnvironment';

export class LobbyUnreadPreference implements LobbyUnreadStore {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) { this.context = context; }

  private preferences(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context.getApplicationContext(), { name: 'starward_lobby_unread' });
  }

  private key(owner: string): string { return accountPreferenceKey(JSON.stringify([AppEnvironment.caData, owner])); }

  load(owner: string): LobbyUnreadHistory {
    const history: LobbyUnreadHistory = new LobbyUnreadHistory();
    try {
      const raw: string = this.preferences().getSync(this.key(owner), '') as string;
      if (!raw.length) { return history; }
      const decoded: Record<string, Object> = JSON.parse(raw) as Record<string, Object>;
      history.assignments = this.ids(decoded['assignments']);
      history.rewards = this.ids(decoded['rewards']);
    } catch { /* A missing or unreadable preference has no acknowledged entries. */ }
    return history;
  }

  save(owner: string, history: LobbyUnreadHistory): void {
    try {
      const store: preferences.Preferences = this.preferences();
      store.putSync(this.key(owner), JSON.stringify(history));
      store.flushSync();
    } catch { /* The current session still keeps the acknowledgement in memory. */ }
  }

  private ids(value: Object): string[] {
    return Array.isArray(value) ? (value as Object[]).filter((id: Object) => typeof id === 'string') as string[] : [];
  }
}
