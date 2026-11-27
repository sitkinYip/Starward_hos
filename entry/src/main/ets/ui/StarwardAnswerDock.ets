import { Binding, CommonModifier, curves, uiMaterial, UIUtils, window } from '@kit.ArkUI';
import { DividerMode, HdsTabs } from '@kit.UIDesignKit';
import { watchLeftHoldingHand } from '../platform/HoldingHand';
import { StarwardMaterial } from './StarwardMaterial';

const COMPOSER_HEIGHT: number = 50;
export const STARWARD_ANSWER_BAR_VERTICAL_PADDING: number = 4;
export const STARWARD_ANSWER_BAR_HEIGHT: number = COMPOSER_HEIGHT + STARWARD_ANSWER_BAR_VERTICAL_PADDING * 2;
const COMPOSER_MAX_WIDTH: number = 680;
const ACTION_GAP: number = 10;
const ACTION_BLUR_RADIUS: number = 12;
const HAND_CHANGE_CURVE: ICurve = curves.interpolatingSpring(0, 1, 200, 17);

export interface StarwardAnswerDockLayout {
  popupWidth: number;
  popupAnchorLeft: number;
  fieldGlass: boolean;
  actionMaxWidth: number;
}

/** A transparent native TabBar provides the scope for two separate material surfaces. */
@ComponentV2
export struct StarwardAnswerDock {
  @Param nativeGlass: boolean = false;
  @Param visible: boolean = false;
  @Param active: boolean = false;
  @Param hasAction: boolean = false;
  @Param actionEnabled: boolean = false;
  @Param placementLocked: boolean = false;
  @Param editing: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param viewportWidth: number = 0;
  @Param leftMargin: number = 16;
  @Param rightMargin: number = 16;
  @Param bottomMargin: number = 0;
  @BuilderParam content: () => void;
  @BuilderParam composer: (layout: Binding<StarwardAnswerDockLayout>) => void;
  @BuilderParam action: (layout: Binding<StarwardAnswerDockLayout>) => void;
  @Env(ReadonlyEnvKey.WINDOW_SIZE) private windowSize: window.SizeInVP;
  @Local private bar: CommonModifier = UIUtils.makeObserved(new CommonModifier());
  @Local private actionWidth: number = COMPOSER_HEIGHT;
  @Local private actionOnLeft: boolean = false;
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private reportedLeft: boolean = false;
  private touched: boolean = false;
  private releaseTimer: number = -1;
  private stopWatching: (() => void) | undefined;
  private watching: boolean = false;
  private readonly layout: Binding<StarwardAnswerDockLayout> = UIUtils.makeBinding<StarwardAnswerDockLayout>(() => ({
    popupWidth: this.groupWidth(),
    popupAnchorLeft: this.popupAnchorLeft(),
    fieldGlass: this.material !== undefined,
    actionMaxWidth: this.actionMaxWidth()
  }));

  aboutToAppear(): void {
    this.bar.id('gameplay-native-answer-bar').accessibilityLevel('no');
    this.updateVisibility();
    this.updateMaterial();
    this.updateGripWatch();
  }

  aboutToDisappear(): void {
    this.stopGripWatch();
  }

  @Monitor('visible')
  private updateVisibility(): void {
    this.bar.visibility(this.visible ? Visibility.Visible : Visibility.None);
  }

  @Monitor('reducedMotion')
  private updateMaterial(): void {
    if (this.nativeGlass) {
      this.material = StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK,
        !this.reducedMotion, $r('app.color.accent'), false);
    }
  }

  @Monitor('visible', 'active')
  private updateGripWatch(): void {
    if (!this.visible || !this.active) {
      this.stopGripWatch();
    } else if (!this.watching) {
      this.watching = true;
      this.stopWatching = watchLeftHoldingHand((left: boolean) => {
        this.reportedLeft = left;
        this.applyGrip();
      });
    }
  }

  private stopGripWatch(): void {
    this.stopWatching?.();
    this.stopWatching = undefined;
    this.watching = false;
    this.reportedLeft = false;
    this.touched = false;
    if (this.releaseTimer >= 0) { clearTimeout(this.releaseTimer); }
    this.releaseTimer = -1;
  }

  @Monitor('placementLocked', 'active', 'visible')
  private applyGrip(): void {
    if (!this.active || !this.visible || this.placementLocked || this.touched ||
      this.actionOnLeft === this.reportedLeft) { return; }
    if (this.reducedMotion) {
      this.actionOnLeft = this.reportedLeft;
    } else {
      this.getUIContext().animateTo({ curve: HAND_CHANGE_CURVE }, () => { this.actionOnLeft = this.reportedLeft; });
    }
  }

  private trackTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      if (this.releaseTimer >= 0) { clearTimeout(this.releaseTimer); }
      this.releaseTimer = -1;
      this.touched = true;
    } else if (event.type === TouchType.Cancel || event.type === TouchType.Up) {
      if (this.releaseTimer >= 0) { clearTimeout(this.releaseTimer); }
      this.releaseTimer = setTimeout(() => {
        // Let the click or focus transaction finish before moving its target.
        this.releaseTimer = -1;
        this.touched = false;
        this.applyGrip();
      }, 0);
    }
  }

  private groupWidth(): number {
    const width: number = this.viewportWidth > 0 ? this.viewportWidth : this.windowSize.width;
    return Math.min(COMPOSER_MAX_WIDTH, Math.max(0, width - Math.max(this.leftMargin, this.rightMargin) * 2));
  }

  private actionMaxWidth(): number {
    return Math.max(COMPOSER_HEIGHT, this.groupWidth() * 0.55);
  }

  private popupAnchorLeft(): number {
    return this.hasAction && this.actionOnLeft ? -(this.actionWidth + ACTION_GAP) : 0;
  }

  private capsuleHeight(): number { return this.nativeGlass ? STARWARD_ANSWER_BAR_HEIGHT : COMPOSER_HEIGHT; }

  private idleMaterial(): uiMaterial.ImmersiveMaterial | undefined {
    return this.editing ? undefined : this.material;
  }

  private actionBackground(): ResourceColor {
    if (this.idleMaterial() !== undefined) { return Color.Transparent; }
    return this.actionEnabled ? $r('app.color.answer_action_solid') : $r('app.color.answer_action_disabled');
  }

  @Builder
  private actionCapsule() {
    Row() {
      this.action(this.layout)
    }.id('gameplay-answer-action-capsule').width(LayoutPolicy.wrapContent)
      .height(COMPOSER_HEIGHT).borderRadius(COMPOSER_HEIGHT / 2).clip(this.idleMaterial() !== undefined)
      .backgroundColor(this.actionBackground())
      .backgroundEffect(this.idleMaterial() !== undefined && !this.actionEnabled ? {
        radius: ACTION_BLUR_RADIUS, color: $r('app.color.answer_action_disabled'),
        policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE, inactiveColor: $r('app.color.answer_action_disabled')
      } : undefined)
      .systemMaterial(this.actionEnabled ? this.idleMaterial() : undefined)
      .linearGradient(this.actionEnabled ? { angle: 150,
        colors: [[$r('app.color.answer_action_glass_start'), 0], [$r('app.color.answer_action_glass_end'), 1]] } :
        undefined)
      .shadow(this.actionEnabled && this.idleMaterial() === undefined ? {
        radius: 12, offsetY: 4, color: $r('app.color.glow_accent_strong')
      } : undefined)
      .onAreaChange((_previous: Area, area: Area) => {
        const width: number = Number(area.width);
        if (width > 0 && Number.isFinite(width) && width !== this.actionWidth) { this.actionWidth = width; }
      })
  }

  @Builder
  private controls() {
    Row({ space: ACTION_GAP }) {
      Column() {
        this.composer(this.layout)
      }.id('gameplay-answer-field-capsule').layoutWeight(1).height(this.capsuleHeight())
        .justifyContent(FlexAlign.Center)
        .borderRadius(STARWARD_ANSWER_BAR_HEIGHT / 2)
        .systemMaterial(this.idleMaterial())
      if (this.hasAction) { this.actionCapsule() }
    }.width(this.groupWidth()).height(this.capsuleHeight())
      .direction(Direction.Ltr).reverse(this.actionOnLeft)
      .onTouch((event: TouchEvent) => this.trackTouch(event))
  }

  @Builder
  private nativeComposer() {
    if (this.visible) { this.controls() }
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
        .barHeight(STARWARD_ANSWER_BAR_HEIGHT + this.bottomMargin * 2).barWidth(this.groupWidth())
        .barBackgroundColor(Color.Transparent).barBackgroundBlurStyle(BlurStyle.NONE)
    } else {
      Stack() {
        this.content()
        if (this.visible) {
          Column() {
            this.controls()
          }.width('100%').height('100%').justifyContent(FlexAlign.End)
            .padding({ bottom: this.bottomMargin }).hitTestBehavior(HitTestMode.None)
        }
      }.width('100%').height('100%').alignContent(Alignment.Top)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    }
  }
}
