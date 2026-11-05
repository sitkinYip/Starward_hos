import { util } from '@kit.ArkTS';

/** One identity per logical write; retries reuse the ViewModel's frozen command. */
export function createRequestIdentity(): string {
  return util.generateRandomUUID();
}
