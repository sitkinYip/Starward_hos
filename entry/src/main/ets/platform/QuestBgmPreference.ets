import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppEnvironment } from './AppEnvironment';
import { QuestBgmPosition } from '../business/QuestBgmDock';

/** Stores the local playback choice and position for this account and backend. */
export class QuestBgmPreference {
  private static store(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'starward_quest_audio' });
  }

  private static key(account: string): string {
    const scope: string = AppEnvironment.endpoint || 'mock';
    const input: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify([scope, account]));
    const hash: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    hash.updateSync({ data: input });
    return new util.Base64Helper().encodeToStringSync(hash.digestSync().data);
  }

  static load(context: common.UIAbilityContext, account: string): boolean {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      return store.getSync(QuestBgmPreference.key(account), true) !== false;
    } catch {
      return true;
    }
  }

  static save(context: common.UIAbilityContext, account: string, enabled: boolean): void {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      store.putSync(QuestBgmPreference.key(account), enabled);
      store.flush().catch(() => { /* Current-session playback still honors the choice. */ });
    } catch {
      // Media control does not depend on access to preferences.
    }
  }

  static loadPosition(context: common.UIAbilityContext, account: string): QuestBgmPosition {
    try {
      const store: preferences.Preferences = QuestBgmPreference.store(context);
      const value = store.getSync('dock_' + QuestBgmPreference.key(account), [1, 1]);
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
      store.putSync('dock_' + QuestBgmPreference.key(account), [position.x, position.y]);
      store.flush().catch(() => { /* The page still retains the position for this visit. */ });
    } catch {
      // Moving the control does not depend on access to preferences.
    }
  }
}
