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

  /** Informational completion only; dismissal never performs a business write. */
  static notice(context: UIContext, title: string, message: string, disappeared?: () => void): boolean {
    if (!StarwardFeedback.isAvailable(context)) {
      return false;
    }
    try {
      context.showAlertDialog({
        title: title,
        message: message,
        primaryButton: { value: '知晓了', action: () => {} },
        onDidDisappear: disappeared,
        systemMaterial: StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THICK)
      });
      return true;
    } catch {
      // The page still displays the server-confirmed completion.
      return false;
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
