import { inputMethod } from '@kit.IMEKit';
import { UIContext } from '@kit.ArkUI';

/** Dismiss the current native input session without popping its page. */
export class StarwardKeyboard {
  static dismiss(context: UIContext): void {
    try {
      context.getFocusController().clearFocus();
      inputMethod.getController().hideTextInput().catch(() => {});
    } catch {
      // The input session may already have ended during system Back handling.
      return;
    }
  }
}
