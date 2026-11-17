import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { asset } from '@kit.AssetStoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { CredentialStore, SavedSession } from '../business/CredentialStore';
import { GameFailure } from '../business/models';

/** One encrypted session for the packaged endpoint and its trust configuration. */
export class AssetCredentialStore implements CredentialStore {
  private readonly endpoint: string;
  private readonly ca: string;

  constructor(endpoint: string, ca: string) {
    this.endpoint = endpoint;
    this.ca = ca;
  }

  private selector(): asset.AssetMap {
    // Separate independently trusted backends even when their loopback URL is identical.
    const encoder: util.TextEncoder = new util.TextEncoder();
    const hash: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
    hash.updateSync({ data: encoder.encodeInto(JSON.stringify([this.endpoint, this.ca])) });
    const scope: string = new util.Base64Helper().encodeToStringSync(hash.digestSync().data);
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, encoder.encodeInto(`starward-session-v1:${scope}`));
    return query;
  }

  private storageError(error: Object): GameFailure {
    if ((error as BusinessError).code === asset.ErrorCode.STATUS_MISMATCH) {
      return new GameFailure('SESSION_STORAGE_LOCKED', '解锁设备后再试。');
    }
    return new GameFailure('SESSION_STORAGE_UNAVAILABLE', '暂时无法访问本机的安全登录记录，请重试。');
  }

  async read(): Promise<SavedSession | null> {
    let result: asset.AssetMap[];
    try {
      const query: asset.AssetMap = this.selector();
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      result = await asset.query(query);
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) { return null; }
      throw this.storageError(error as Object);
    }
    const value: asset.Value | undefined = result[0]?.get(asset.Tag.SECRET);
    if (value instanceof Uint8Array) {
      try {
        const clear: string = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(value);
        const payload: Record<string, Object> = JSON.parse(clear) as Record<string, Object>;
        const token: Object = payload['token'];
        const playerId: Object = payload['playerId'];
        if (typeof token === 'string' && token.length > 0 && !/[\r\n]/.test(token) &&
          typeof playerId === 'string' && playerId.length > 0) {
          return new SavedSession(token, playerId);
        }
      } catch (error) {
        // A damaged record is discarded below, without exposing its contents.
      } finally {
        value.fill(0);
      }
    }
    await this.clear();
    return null;
  }

  async save(session: SavedSession): Promise<void> {
    const bytes: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify({
      token: session.token, playerId: session.playerId
    }));
    try {
      const settings: asset.AssetMap = this.selector();
      settings.set(asset.Tag.SECRET, bytes);
      settings.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
      settings.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
      settings.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
      await asset.add(settings);
    } catch (error) {
      throw this.storageError(error as Object);
    } finally {
      bytes.fill(0);
    }
  }

  async clear(): Promise<void> {
    try {
      await asset.remove(this.selector());
    } catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) {
        throw this.storageError(error as Object);
      }
    }
  }
}
