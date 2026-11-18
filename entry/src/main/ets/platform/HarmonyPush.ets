import { common, UIAbility } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { notificationManager } from '@kit.NotificationKit';
import { pushCommon, pushService } from '@kit.PushKit';
import { PushDevice, PushLease } from '../business/PushRegistration';
import { AppEnvironment } from './AppEnvironment';

const STORE: string = 'starward_push_installation';
const NOTIFICATION_DISABLED: number = 1600004;
const INSTALLATION_UUID: RegExp = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/;

/** OS and app-scoped storage boundary. The caller enforces player and consent gates. */
export class HarmonyPush {
  private static installationIds: Map<string, Promise<string>> = new Map();
  private static owner: UIAbility | null = null;

  static setAbility(ability: UIAbility): void { HarmonyPush.owner = ability; }

  static forgetAbility(ability: UIAbility): void {
    if (HarmonyPush.owner === ability) { HarmonyPush.owner = null; }
  }

  static watchTokenUpdates(callback: () => void): (() => void) | null {
    const ability: UIAbility | null = HarmonyPush.owner;
    if (ability === null) { return null; }
    try {
      return HarmonyPush.subscribeTokenUpdates(ability, (_token: string): void => callback());
    } catch {
      return null;
    }
  }

  /** @throws If the platform cannot compute or encode the environment key. */
  private static storageScope(): string {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const digest: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    digest.updateSync({ data: encoder.encodeInto(JSON.stringify([AppEnvironment.endpoint, AppEnvironment.caData])) });
    return new util.Base64Helper().encodeToStringSync(digest.digestSync().data);
  }

  /** @throws If the installation UUID cannot be persisted. */
  private static async loadInstallationId(context: common.UIAbilityContext, key: string): Promise<string> {
    const store: preferences.Preferences = preferences.getPreferencesSync(context.getApplicationContext(),
      { name: STORE });
    const existing: preferences.ValueType = store.getSync(key, '');
    let id: string = '';
    if (typeof existing === 'string' && INSTALLATION_UUID.test(existing)) {
      id = existing;
    } else {
      id = util.generateRandomUUID();
      store.putSync(key, id);
    }
    // Even an existing in-memory value may follow a failed flush; never use an ID before it is durable.
    await store.flush();
    return id;
  }

  /** @throws If this environment's installation identity cannot be obtained. */
  static async getInstallationId(context: common.UIAbilityContext): Promise<string> {
    const key: string = `id_v1_${HarmonyPush.storageScope()}`;
    const existing: Promise<string> | undefined = HarmonyPush.installationIds.get(key);
    if (existing !== undefined) { return existing; }
    const pending: Promise<string> = HarmonyPush.loadInstallationId(context, key).catch(() => {
      HarmonyPush.installationIds.delete(key);
      throw new Error('Push installation preferences unavailable');
    });
    HarmonyPush.installationIds.set(key, pending);
    return pending;
  }

  /** @throws If Notification Kit cannot read the current permission. */
  static async isPermissionEnabled(): Promise<boolean> {
    return notificationManager.isNotificationEnabled();
  }

  static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      if (await HarmonyPush.isPermissionEnabled()) { return true; }
      await notificationManager.requestEnableNotification(context);
      return await HarmonyPush.isPermissionEnabled();
    } catch (error) {
      if ((error as BusinessError).code === NOTIFICATION_DISABLED) { return false; }
      throw new Error('Push notification permission request failed');
    }
  }

  /** @throws If the system cannot present notification settings. */
  static async openSettings(context: common.UIAbilityContext): Promise<boolean> {
    const setting: notificationManager.NotificationSetting =
      await notificationManager.openNotificationSettingsWithResult(context);
    return setting.notificationEnabled ?? await HarmonyPush.isPermissionEnabled();
  }

  /** @throws If Push Kit cannot obtain a token. */
  static async getToken(): Promise<string> {
    return pushService.getToken();
  }

  /** @throws If Push Kit cannot invalidate this token. */
  static async deleteToken(): Promise<void> {
    return pushService.deleteToken();
  }

  static newProfileId(): string {
    return util.generateRandomUUID();
  }

  /** @throws If Push Kit cannot bind the anonymous profile. */
  static async bindProfile(profileId: string): Promise<void> {
    return pushService.bindAppProfileId(pushCommon.AppProfileType.PROFILE_TYPE_APPLICATION_ACCOUNT, profileId);
  }

  /** @throws If Push Kit cannot unbind the anonymous profile. */
  static async unbindProfile(profileId: string): Promise<void> {
    return pushService.unbindAppProfileId(profileId);
  }

  /** @throws If the ability cannot watch token updates. */
  static subscribeTokenUpdates(ability: UIAbility, callback: (token: string) => void): () => void {
    pushService.on('tokenUpdate', ability, callback);
    return () => {
      try { pushService.off('tokenUpdate', callback); } catch { /* The owner is tearing down. */ }
    };
  }

  /** @throws If the platform cannot compute or encode the environment key. */
  private static selector(): asset.AssetMap {
    const query: asset.AssetMap = new Map();
    const alias: string = `starward-push-lease-v1:${HarmonyPush.storageScope()}`;
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(alias));
    return query;
  }

  private static validateLease(profileId: Object, revokeTicket: Object, revoking: Object, ownerId: Object): PushLease {
    if (typeof profileId !== 'string' || profileId.length < 1 || profileId.length > 64 ||
      typeof revokeTicket !== 'string' || revokeTicket.length > 384 || typeof revoking !== 'boolean' ||
      typeof ownerId !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(ownerId)) {
      throw new Error('Invalid push lease');
    }
    return new PushLease(profileId, revokeTicket, revoking, ownerId);
  }

  static async readLease(_context: common.UIAbilityContext): Promise<PushLease | null> {
    let result: asset.AssetMap[];
    try {
      const query: asset.AssetMap = HarmonyPush.selector();
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      result = await asset.query(query);
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) { return null; }
      throw new Error('Push lease storage unavailable');
    }
    const bytes: asset.Value | undefined = result[0]?.get(asset.Tag.SECRET);
    if (!(bytes instanceof Uint8Array)) { throw new Error('Invalid push lease'); }
    try {
      const payload: Record<string, Object> = JSON.parse(util.TextDecoder.create('utf-8', { fatal: true })
        .decodeToString(bytes)) as Record<string, Object>;
      return HarmonyPush.validateLease(payload['profileId'], payload['revokeTicket'], payload['revoking'],
        payload['ownerId']);
    } catch {
      throw new Error('Invalid push lease');
    } finally {
      bytes.fill(0);
    }
  }

  static async saveLease(_context: common.UIAbilityContext, value: PushLease | null): Promise<void> {
    if (value === null) {
      try {
        await asset.remove(HarmonyPush.selector());
      } catch (error) {
        if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) {
          throw new Error('Push lease storage unavailable');
        }
      }
      return;
    }
    HarmonyPush.validateLease(value.profileId, value.revokeTicket, value.revoking, value.ownerId);
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify(value));
    try {
      const settings: asset.AssetMap = HarmonyPush.selector();
      settings.set(asset.Tag.SECRET, bytes);
      settings.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
      settings.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
      settings.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(settings);
    } catch {
      throw new Error('Push lease storage unavailable');
    } finally {
      bytes.fill(0);
    }
  }
}

export class HarmonyPushDevice implements PushDevice {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) { this.context = context; }

  /** @throws If Notification Kit is unavailable. */
  isPermissionEnabled(): Promise<boolean> { return HarmonyPush.isPermissionEnabled(); }
  /** @throws If Push Kit cannot obtain a token. */
  getToken(): Promise<string> { return HarmonyPush.getToken(); }
  /** @throws If Push Kit cannot invalidate the token. */
  deleteToken(): Promise<void> { return HarmonyPush.deleteToken(); }
  /** @throws If the installation identity cannot be persisted. */
  getInstallationId(): Promise<string> { return HarmonyPush.getInstallationId(this.context); }
  newProfileId(): string { return HarmonyPush.newProfileId(); }
  /** @throws If Push Kit cannot bind the profile. */
  bindProfile(id: string): Promise<void> { return HarmonyPush.bindProfile(id); }
  /** @throws If Push Kit cannot unbind the profile. */
  unbindProfile(id: string): Promise<void> { return HarmonyPush.unbindProfile(id); }
  readLease(): Promise<PushLease | null> { return HarmonyPush.readLease(this.context); }
  saveLease(lease: PushLease | null): Promise<void> { return HarmonyPush.saveLease(this.context, lease); }
}
