import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME: string = 'starward_answer_feedback';
const ENABLED_KEY: string = 'haptics_enabled';

export class AnswerHapticsPreference {
  private static store(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context.getApplicationContext(), { name: STORE_NAME });
  }

  static load(context: common.UIAbilityContext): boolean {
    try {
      return AnswerHapticsPreference.store(context).getSync(ENABLED_KEY, true) !== false;
    } catch {
      return true;
    }
  }

  static save(context: common.UIAbilityContext, enabled: boolean): boolean {
    try {
      const store = AnswerHapticsPreference.store(context);
      store.putSync(ENABLED_KEY, enabled);
      store.flushSync();
      return true;
    } catch {
      return false;
    }
  }
}
