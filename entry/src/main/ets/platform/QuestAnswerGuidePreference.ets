import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountPreferenceKey } from './AccountPreferenceKey';

/** Local onboarding state scoped to the backend and signed-in player. */
export class QuestAnswerGuidePreference {
  private static readonly seen: Set<string> = new Set<string>();

  static load(context: common.UIAbilityContext, account: string): boolean {
    try {
      const key: string = accountPreferenceKey(account);
      if (QuestAnswerGuidePreference.seen.has(key)) { return true; }
      return preferences.getPreferencesSync(context, { name: 'starward_quest_guide' }).getSync(key, false) === true;
    } catch {
      return false;
    }
  }

  static save(context: common.UIAbilityContext, account: string): void {
    try {
      const key: string = accountPreferenceKey(account);
      QuestAnswerGuidePreference.seen.add(key);
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: 'starward_quest_guide' });
      store.putSync(key, true);
      store.flush().catch(() => { /* The current process still remembers the guide. */ });
    } catch {
      // An unavailable preference store does not block answering.
    }
  }
}
