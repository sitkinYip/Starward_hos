import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppEnvironment } from './AppEnvironment';

/** @throws If the platform cannot compute or encode the preference key. */
export function accountPreferenceKey(account: string): string {
  const scope: string = AppEnvironment.endpoint || 'mock';
  const input: Uint8Array = new util.TextEncoder().encodeInto(JSON.stringify([scope, account]));
  const hash: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
  hash.updateSync({ data: input });
  return new util.Base64Helper().encodeToStringSync(hash.digestSync().data);
}
