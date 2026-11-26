import { CommonModifier, UIUtils, window } from '@kit.ArkUI';
import { DividerMode, HdsTabs, hdsMaterial } from '@kit.UIDesignKit';

const COMPOSER_HEIGHT: number = 50;
export const STARWARD_ANSWER_BAR_VERTICAL_PADDING: number = 4;
export const STARWARD_ANSWER_BAR_HEIGHT: number = COMPOSER_HEIGHT + STARWARD_ANSWER_BAR_VERTICAL_PADDING * 2;
const COMPOSER_MAX_WIDTH: number = 680;
const NATIVE_BAR_SIDE_PADDING: number = 12;

/** The native TabBar owns glass and placement. The page owns the answer and actions. */
@ComponentV2
export struct StarwardAnswerDock {
  @Param nativeGlass: boolean = false;
  @Param visible: boolean = false;
  @Param editing: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param viewportWidth: number = 0;
  @Param leftMargin: number = 16;
  @Param rightMargin: number = 16;
  @Param bottomMargin: number = 0;
  @BuilderParam content: () => void;
  @BuilderParam composer: () => void;
  @Env(ReadonlyEnvKey.WINDOW_SIZE) private windowSize: window.SizeInVP;
  @Local private bar: CommonModifier = UIUtils.makeObserved(new CommonModifier());

  aboutToAppear(): void {
    this.bar.id('gameplay-native-answer-bar').accessibilityLevel('no');
    this.updateVisibility();
  }

  @Monitor('visible')
  private updateVisibility(): void {
    this.bar.visibility(this.visible ? Visibility.Visible : Visibility.None);
  }

  private sideMargin(): number { return Math.max(this.leftMargin, this.rightMargin); }

  private nativeWidth(): number {
    const width: number = this.viewportWidth > 0 ? this.viewportWidth : this.windowSize.width;
    return Math.min(COMPOSER_MAX_WIDTH + NATIVE_BAR_SIDE_PADDING * 2,
      Math.max(0, width - this.sideMargin() * 2));
  }

  private barHeight(): number {
    return this.editing ? COMPOSER_HEIGHT + (this.bottomMargin + STARWARD_ANSWER_BAR_VERTICAL_PADDING) * 2 :
      STARWARD_ANSWER_BAR_HEIGHT;
  }

  @Builder
  private nativeComposer() {
    if (this.visible) {
      Column() {
        this.composer()
      }.width(this.editing ? this.nativeWidth() : '100%').height(COMPOSER_HEIGHT)
        .alignItems(HorizontalAlign.Center)
    }
  }

  build() {
    if (this.nativeGlass) {
      HdsTabs({ barPosition: BarPosition.End, barModifier: this.bar }) {
        TabContent() {
          this.content()
        }.tabBar(this.nativeComposer)
      }.id('gameplay-native-answer-dock').width('100%').height('100%')
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .vertical(false).scrollable(false).barOverlap(true).animationDuration(0)
        .divider({ mode: DividerMode.NONE })
        .barHeight(this.barHeight()).barWidth(this.nativeWidth())
        .barBackgroundColor(Color.Transparent).barBackgroundBlurStyle(BlurStyle.NONE)
        .barFloatingStyle(this.editing ? undefined : { barSideMargin: this.sideMargin(), barBottomMargin: this.bottomMargin,
          gradientMask: { maskColor: Color.Transparent },
          lightColor: this.reducedMotion ? Color.Transparent : $r('app.color.accent'),
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
          }
        })
    } else {
      Stack() {
        this.content()
        if (this.visible) {
          Column() {
            this.composer()
          }.width('100%').height('100%').justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
            .padding({ bottom: this.bottomMargin, left: this.leftMargin, right: this.rightMargin })
            .hitTestBehavior(HitTestMode.None)
        }
      }.width('100%').height('100%').alignContent(Alignment.Top)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    }
  }
}
