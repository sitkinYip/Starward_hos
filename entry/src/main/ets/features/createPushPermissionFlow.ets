import { common } from '@kit.AbilityKit';
import { PushStatus } from '../business/PushRegistration';
import { HarmonyPush } from '../platform/HarmonyPush';
import { PushPermissionFlow, PushPermissionPlatform } from './PushPermissionFlow';

class HarmonyPushPermissionPlatform implements PushPermissionPlatform {
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  claimInitialPermissionPrompt(): boolean {
    return HarmonyPush.claimInitialPermissionPrompt(this.context);
  }

  requestPermission(): Promise<boolean> {
    return HarmonyPush.requestPermission(this.context);
  }

  openSettings(): Promise<boolean> {
    return HarmonyPush.openSettings(this.context);
  }

  isPermissionEnabled(): Promise<boolean> {
    return HarmonyPush.isPermissionEnabled();
  }

  watchTokenUpdates(callback: () => void): (() => void) | null {
    return HarmonyPush.watchTokenUpdates(callback);
  }
}

export function createPushPermissionFlow(context: common.UIAbilityContext, accountOwner: () => string,
  foreground: () => boolean, register: (force: boolean) => Promise<PushStatus>): PushPermissionFlow {
  return new PushPermissionFlow(new HarmonyPushPermissionPlatform(context), accountOwner, foreground, register);
}
