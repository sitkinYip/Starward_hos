import { UIContext, uiMaterial } from '@kit.ArkUI';
import { StarwardMaterial } from './StarwardMaterial';

/** Window-scoped official feedback. Framework owns dismissal, focus and motion. */
export class StarwardFeedback {
  private static isAvailable(context: UIContext): boolean {
    try {
      return context.isAvailable();
    } catch {
      return false;
    }
  }

  static toast(context: UIContext, message: string): void {
    if (!StarwardFeedback.isAvailable(context)) {
      return;
    }
    try {
      context.getPromptAction().showToast({
        message: message,
        duration: 2000,
        systemMaterial: StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK)
      });
    } catch {
      // The owning window can disappear between the availability check and display.
      return;
    }
  }

  static confirm(context: UIContext, title: string, message: string, accepted: () => void): void {
    if (!StarwardFeedback.isAvailable(context)) {
      return;
    }
    try {
      context.showAlertDialog({
        title: title,
        message: message,
        primaryButton: { value: '取消', action: () => {} },
        secondaryButton: {
          value: '确认',
          action: () => {
            if (StarwardFeedback.isAvailable(context)) {
              accepted();
            }
          }
        },
        systemMaterial: StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THICK)
      });
    } catch {
      // Failure to present a confirmation never implies acceptance.
      return;
    }
  }
}
