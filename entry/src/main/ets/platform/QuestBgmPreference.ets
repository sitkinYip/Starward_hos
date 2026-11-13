import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountPreferenceKey } from './AccountPreferenceKey';
import { QuestBgmPosition } from '../business/QuestBgmDock';

/** Stores the local playback choice and position for this account and backend. */
export class QuestBgmPreference {
  private static store(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'starward_quest_audio' });
  }

  static load(context: common.UIAbilityContext, account: string): boolean {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      return store.getSync(accountPreferenceKey(account), true) !== false;
    } catch {
      return true;
    }
  }

  static save(context: common.UIAbilityContext, account: string, enabled: boolean): void {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      store.putSync(accountPreferenceKey(account), enabled);
      store.flush().catch(() => { /* Current-session playback still honors the choice. */ });
    } catch {
      // Media control does not depend on access to preferences.
    }
  }

  static loadPosition(context: common.UIAbilityContext, account: string): QuestBgmPosition {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      const value = store.getSync('dock_' + accountPreferenceKey(account), [1, 1]);
      if (Array.isArray(value) && value.length === 2 && typeof value[0] === 'number' && typeof value[1] === 'number') {
        return new QuestBgmPosition(value[0], value[1]);
      }
    } catch {
      // A missing local position uses the default dock.
    }
    return new QuestBgmPosition();
  }

  static savePosition(context: common.UIAbilityContext, account: string, position: QuestBgmPosition): void {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      store.putSync('dock_' + accountPreferenceKey(account), [position.x, position.y]);
      store.flush().catch(() => { /* The page still retains the position for this visit. */ });
    } catch {
      // Moving the control does not depend on access to preferences.
    }
  }
}
