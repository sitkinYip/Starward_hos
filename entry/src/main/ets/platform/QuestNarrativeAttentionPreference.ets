import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountPreferenceKey } from './AccountPreferenceKey';

/** Remembers which granted cues the player has opened in this assignment. */
export class QuestNarrativeAttentionPreference {
  private static store(context: common.UIAbilityContext): preferences.Preferences {
    return preferences.getPreferencesSync(context, { name: 'starward_quest_narrative_attention' });
  }

  private static key(account: string, assignment: string): string {
    return accountPreferenceKey(JSON.stringify([account, assignment]));
  }

  static load(context: common.UIAbilityContext, account: string, assignment: string): string[] {
    try {
      const saved = QuestNarrativeAttentionPreference.store(context).getSync(
        QuestNarrativeAttentionPreference.key(account, assignment), '');
      if (!Array.isArray(saved)) { return []; }
      return (saved as string[]).filter((id: string) => typeof id === 'string' && id.length > 0).slice(-128);
    } catch {
      return [];
    }
  }

  static save(context: common.UIAbilityContext, account: string, assignment: string, openedIds: string[]): void {
    try {
      const store: preferences.Preferences = QuestNarrativeAttentionPreference.store(context);
      store.putSync(QuestNarrativeAttentionPreference.key(account, assignment), openedIds);
      store.flush().catch(() => { /* The current visit still remembers the opening. */ });
    } catch {
      // Navigation does not depend on local preferences.
    }
  }
}
