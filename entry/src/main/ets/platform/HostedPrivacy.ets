import { common } from '@kit.AbilityKit';
import { privacyManager } from '@kit.AppGalleryKit';
import { commonEventManager } from '@kit.BasicServicesKit';
import { externalClueLinkHref, openExternalClueLink } from './ExternalClueLink';

const PRIVACY_STATE_CHANGED: string = 'usual.event.PRIVACY_STATE_CHANGED';

export enum HostedPrivacyState {
  ALLOWED,
  CONFIRMED_NOT_ALLOWED,
  UNAVAILABLE
}

export enum HostedPrivacyRequestResult {
  PRESENTED,
  LAUNCH_FAILED
}

/** AppGallery owns the agreement and the consent record. */
export class HostedPrivacy {
  static getState(): HostedPrivacyState {
    try {
      const policy: privacyManager.AppPrivacyLink | undefined = HostedPrivacy.currentPolicy();
      if (policy === undefined) { return HostedPrivacyState.UNAVAILABLE; }
      const current: privacyManager.AppPrivacyResult | undefined =
        privacyManager.getAppPrivacyResult().find((record: privacyManager.AppPrivacyResult): boolean => {
          return record.type === privacyManager.AppPrivacyType.PRIVACY_AGREEMENT && record.id === policy.id &&
            record.versionCode === policy.versionCode;
        });
      if (current === undefined || current.result === privacyManager.AppPrivacyResultType.DISAGREED ||
        current.result === privacyManager.AppPrivacyResultType.REQUIRE_RESIGNING_VERSION_UPDATE) {
        return HostedPrivacyState.CONFIRMED_NOT_ALLOWED;
      }
      return current.result === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED ?
        HostedPrivacyState.ALLOWED : HostedPrivacyState.UNAVAILABLE;
    } catch {
      return HostedPrivacyState.UNAVAILABLE;
    }
  }

  static async requestConsent(context: common.UIAbilityContext): Promise<HostedPrivacyRequestResult> {
    try {
      // ConsentResult also covers refusal. Authorization always comes from getState().
      await privacyManager.requestAppPrivacyConsent(context);
      return HostedPrivacyRequestResult.PRESENTED;
    } catch {
      return HostedPrivacyRequestResult.LAUNCH_FAILED;
    }
  }

  static async openPolicy(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const policy: privacyManager.AppPrivacyLink | undefined = HostedPrivacy.currentPolicy();
      if (policy === undefined) { return false; }
      const href: string = externalClueLinkHref(policy.url);
      return href.startsWith('https://') && await openExternalClueLink(context, href);
    } catch {
      return false;
    }
  }

  /** The event only prompts the caller to requery; it cannot confer consent. */
  static subscribe(listener: () => void): () => void {
    let active: boolean = true;
    try {
      const subscriber: commonEventManager.CommonEventSubscriber =
        commonEventManager.createSubscriberSync({ events: [PRIVACY_STATE_CHANGED] });
      commonEventManager.subscribe(subscriber, (error, data) => {
        if (active && !error && data?.event === PRIVACY_STATE_CHANGED) { listener(); }
      });
      return (): void => {
        if (!active) { return; }
        active = false;
        try { commonEventManager.unsubscribe(subscriber); } catch { return; }
      };
    } catch {
      active = false;
      return (): void => {};
    }
  }

  private static currentPolicy(): privacyManager.AppPrivacyLink | undefined {
    const info: privacyManager.AppPrivacyMgmtInfo = privacyManager.getAppPrivacyMgmtInfo();
    if (info.type !== privacyManager.AppPrivacyMgmtType.FULL_MODE) { return undefined; }
    return info.privacyInfo.find((link: privacyManager.AppPrivacyLink): boolean => {
      return link.type === privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK;
    });
  }
}
