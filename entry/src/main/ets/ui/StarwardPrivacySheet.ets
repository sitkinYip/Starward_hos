import { InlineError } from './ErrorMessages';
import { StarwardModalBackdropState } from './StarwardGlassBackdrop';
import { STARWARD_RADIUS_ROUND } from './StarwardRadii';
import { STARWARD_SHEET_HEADER_MIN_HEIGHT, StarwardSheetHeader, StarwardSheetStyle } from './StarwardSheet';

/** This drawer introduces the hosted agreement; the platform owns consent. */
@ComponentV2
export struct StarwardPrivacySheet {
  @Consumer('starwardModalBackdrop') private modalBackdrop: StarwardModalBackdropState =
    new StarwardModalBackdropState();
  @Param visible: boolean = false;
  @Param busy: boolean = false;
  @Param error: string = '';
  @Param viewportHeight: number = 640;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param bottomInset: number = 0;
  @Event continueConsent: () => void = () => {};
  @Event openPolicy: () => void = () => {};
  @BuilderParam anchor: () => void;
  private readonly sheetStyle: StarwardSheetStyle = new StarwardSheetStyle();
  private readonly backdropOwner: Object = new Object();
  private active: boolean = false;

  aboutToAppear(): void { this.active = true; }

  aboutToDisappear(): void {
    this.active = false;
    this.modalBackdrop.hide(this.backdropOwner);
  }

  private bodyHeightLimit(): number {
    const height = Number.isFinite(this.viewportHeight) && this.viewportHeight > 0 ? this.viewportHeight : 640;
    return Math.max(60, height * 0.76 - STARWARD_SHEET_HEADER_MIN_HEIGHT);
  }

  @Builder
  private consentControls() {
    Column({ space: 12 }) {
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
      .padding({ top: 16, left: 24 + this.leftInset, right: 24 + this.rightInset, bottom: 16 + this.bottomInset })
  }

  @Builder
  private body() {
    Column() {
      StarwardSheetHeader({ title: '隐私保护', titleId: 'privacy-gate-heading', dismissible: false,
        leftInset: this.leftInset, rightInset: this.rightInset })
      Scroll() {
        this.consentControls()
      }.width('100%').height(LayoutPolicy.wrapContent).constraintSize({ maxHeight: this.bodyHeightLimit() })
        .align(Alignment.Top).scrollBar(BarState.Auto)
    }.id('privacy-gate-sheet').width('100%')
  }

  build() {
    Stack() {
      this.anchor()
    }.width('100%').height('100%').bindSheet(this.visible, this.body, this.sheetStyle.apply({
      height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM,
      maskColor: Color.Transparent, enableOutsideInteractive: false,
      onWillAppear: () => {
        if (this.active && this.visible) { this.modalBackdrop.show(this.backdropOwner); }
      },
      onWillDismiss: (action: DismissSheetAction): void => {
        // A mask tap, swipe, or Back cannot bypass the agreement. The owner closes it after verification.
        if (!this.visible) { action.dismiss(); }
      },
      onDisappear: () => this.modalBackdrop.hide(this.backdropOwner)
    }))
  }
}
