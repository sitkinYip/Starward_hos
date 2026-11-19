import { ColorMetrics, ImageModifier, LengthMetrics, TextModifier, UIContext } from '@kit.ArkUI';
import { HdsSnackBar, SnackBarOperationType } from '@kit.UIDesignKit';

/** Read-only navigation feedback. Closing a notice never acknowledges a letter. */
export class StarwardJourneyToast {
  private current: HdsSnackBar | undefined = undefined;

  show(context: UIContext, message: string, bottomInset: number, openInbox: () => void): void {
    this.dismiss();
    try {
      if (!context.isAvailable()) { return; }
      context.runScopedTask(() => {
        const iconStyle = new ImageModifier();
        iconStyle.fillColor($r('app.color.accent_text'));
        const bar: HdsSnackBar = new HdsSnackBar(context);
        const open: () => void = () => {
          if (this.current !== bar) { return; }
          this.dismiss();
          openInbox();
        };
        const textStyle = new TextModifier();
        textStyle.fontSize('14fp').lineHeight('21fp').maxLines(3).onClick(() => open());
        this.current = bar;
        bar.show({ icon: $r('app.media.icon_envelope'), iconModifier: iconStyle },
          { title: message, titleColor: ColorMetrics.resourceColor($r('app.color.strong')),
            titleModifier: textStyle },
          { operationType: SnackBarOperationType.TEXT_WITH_CLOSE, content: '查看',
            contentColor: ColorMetrics.resourceColor($r('app.color.accent_text')),
            textButtonId: 'journey-toast-view', cancelButtonId: 'journey-toast-dismiss',
            contentAccessibilityText: '前往旅途来信', closeButtonAccessibilityText: '关闭来信提示',
            onContentClick: open },
          { duration: 7000, isHeightAdaptive: true,
            backgroundColor: ColorMetrics.resourceColor($r('app.color.raised')),
            keyboardDownAvoidHeight: LengthMetrics.vp(Math.max(0, bottomInset) + 12),
            keyboardUpAvoidHeight: LengthMetrics.vp(12) });
      });
    } catch {
      this.dismiss();
    }
  }

  dismiss(): void {
    const current: HdsSnackBar | undefined = this.current;
    this.current = undefined;
    try { current?.dismiss(); } catch { /* The owning window may already be gone. */ }
  }
}
