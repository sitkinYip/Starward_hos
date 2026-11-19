import { ColorMetrics, ImageModifier, LengthMetrics, TextModifier, UIContext } from '@kit.ArkUI';
import { HdsSnackBar, SnackBarOperationType } from '@kit.UIDesignKit';

const DISMISS_AFTER_MS: number = 6500;
const EDGE_GAP_VP: number = 12;

/** One non-modal message per owning page; the platform owns placement and dismissal. */
export class StarwardErrorToast {
  private snackBar: HdsSnackBar | undefined = undefined;

  show(context: UIContext, message: string, bottomInset: number): void {
    if (message.length === 0) { return; }
    this.dismiss();
    try {
      if (!context.isAvailable()) { return; }
      context.runScopedTask(() => {
        const iconStyle = new ImageModifier();
        iconStyle.fillColor($r('app.color.accent_text'));
        const messageStyle = new TextModifier();
        messageStyle.fontSize('14fp').lineHeight('20fp').maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis });
        const bar = new HdsSnackBar(context);
        this.snackBar = bar;
        bar.show({ icon: $r('app.media.icon_warning'), iconModifier: iconStyle },
          { title: message, titleColor: ColorMetrics.resourceColor($r('app.color.strong')), titleModifier: messageStyle },
          { operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY, cancelButtonId: 'network-toast-dismiss',
            closeButtonAccessibilityText: '关闭提示' },
          { duration: DISMISS_AFTER_MS, isHeightAdaptive: true,
            backgroundColor: ColorMetrics.resourceColor($r('app.color.raised')),
            keyboardDownAvoidHeight: LengthMetrics.vp(Math.max(0, bottomInset) + EDGE_GAP_VP),
            keyboardUpAvoidHeight: LengthMetrics.vp(EDGE_GAP_VP) });
      });
    } catch {
      // Navigation can destroy the owning context while the notification is being shown.
      this.dismiss();
    }
  }

  dismiss(): void {
    const bar = this.snackBar;
    this.snackBar = undefined;
    try {
      bar?.dismiss();
    } catch {
      // The platform can clear the overlay before the owning page disappears.
    }
  }
}
