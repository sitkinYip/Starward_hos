import { LengthMetrics } from '@kit.ArkUI';
import { InlineError } from './ErrorMessages';
import { STARWARD_RADIUS_PANEL, STARWARD_RADIUS_ROUND } from './StarwardRadii';

/** This drawer introduces the hosted agreement; the platform owns consent. */
@ComponentV2
export struct StarwardPrivacySheet {
  @Param visible: boolean = false;
  @Param busy: boolean = false;
  @Param error: string = '';
  @Param displayFont: string = 'serif';
  @Param viewportHeight: number = 640;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param bottomInset: number = 0;
  @Event continueConsent: () => void = () => {};
  @Event openPolicy: () => void = () => {};
  @BuilderParam anchor: () => void;

  private bodyHeightLimit(): number {
    const height = Number.isFinite(this.viewportHeight) && this.viewportHeight > 0 ? this.viewportHeight : 640;
    return height * 0.76;
  }

  @Builder
  private body() {
    Scroll() {
      Column({ space: 12 }) {
        Text('隐私保护').id('privacy-gate-heading').fontFamily(this.displayFont).fontSize(26)
          .fontWeight(FontWeight.Medium).lineHeight('36fp').fontColor($r('app.color.strong')).width('100%')
        Text('请阅读《赴星之约隐私政策》，并在系统提示中完成选择。同意后即可登录。')
          .fontSize(15).lineHeight('25.5fp').fontColor($r('app.color.muted')).width('100%')
        InlineError({ message: this.error, fieldId: 'privacy-gate-error' })
        Row({ space: 12 }) {
          Button('隐私政策', { type: ButtonType.Normal }).id('privacy-gate-policy')
            .constraintSize({ minHeight: 48 }).layoutWeight(4).borderRadius(STARWARD_RADIUS_ROUND)
            .padding({ left: 8, right: 8, top: 8, bottom: 8 }).fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .enabled(!this.busy).onClick(() => this.openPolicy())
          Button(this.busy ? '正在打开…' : '继续', { type: ButtonType.Normal }).id('privacy-continue')
            .constraintSize({ minHeight: 48 }).layoutWeight(5).borderRadius(STARWARD_RADIUS_ROUND)
            .padding({ left: 8, right: 8, top: 8, bottom: 8 }).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .enabled(!this.busy).onClick(() => this.continueConsent())
        }.width('100%').margin({ top: 4 })
      }.width('100%').constraintSize({ maxWidth: 440 }).alignItems(HorizontalAlign.Start)
        .padding({ top: 24, left: 24 + this.leftInset, right: 24 + this.rightInset, bottom: 16 + this.bottomInset })
    }.id('privacy-gate-sheet').width('100%').constraintSize({ maxHeight: this.bodyHeightLimit() })
      .align(Alignment.Top).scrollBar(BarState.Auto)
  }

  build() {
    Stack() {
      this.anchor()
    }.width('100%').height('100%').bindSheet(this.visible, this.body, {
      height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM, dragBar: false, showClose: false,
      backgroundColor: $r('app.color.surface'), maskColor: $r('app.color.modal_mask'),
      radius: LengthMetrics.vp(STARWARD_RADIUS_PANEL), enableOutsideInteractive: false,
      onWillDismiss: (action: DismissSheetAction): void => {
        // A mask tap, swipe, or Back cannot bypass the agreement. The owner closes it after verification.
        if (!this.visible) { action.dismiss(); }
      }
    })
  }
}
