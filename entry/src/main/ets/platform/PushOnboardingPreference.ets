import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PushOnboardingStore } from '../business/PushOnboarding';
import { PERSONAL_JOURNEY_SCOPE } from '../business/PushSubscription';
import { accountPreferenceKey } from './AccountPreferenceKey';
import { AppEnvironment } from './AppEnvironment';

/** Only presentation history is stored, hashed by endpoint, trust configuration, scope and account. */
export class PushOnboardingPreference implements PushOnboardingStore {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) { this.context = context; }

  private store(): preferences.Preferences {
    return preferences.getPreferencesSync(this.context.getApplicationContext(), { name: 'starward_push_onboarding' });
  }

  private key(owner: string): string {
    return accountPreferenceKey(JSON.stringify([AppEnvironment.caData, PERSONAL_JOURNEY_SCOPE, owner]));
  }

  /** Malformed existing history is conservatively treated as already presented. */
  wasPrompted(owner: string): boolean {
    return this.store().getSync(this.key(owner), '') !== '';
  }

  claim(owner: string): boolean {
    if (owner.length === 0) { return false; }
    const store: preferences.Preferences = this.store();
    const key: string = this.key(owner);
    if (store.getSync(key, '') !== '') { return false; }
    store.putSync(key, JSON.stringify({ version: 1, scope: PERSONAL_JOURNEY_SCOPE, prompted: true }));
    // A restart or a failed dialog must never turn a dismissal into another automatic prompt.
    store.flushSync();
    return true;
  }
}
