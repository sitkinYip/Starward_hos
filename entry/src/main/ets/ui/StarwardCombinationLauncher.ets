import { curves, uiMaterial } from '@kit.ArkUI';
import { QUEST_BGM_SIZE } from '../business/QuestBgmDock';
import { COMBINATION_LAUNCHER_DEFAULT_Y, CombinationLauncherPosition } from '../platform/CombinationLauncherPosition';
import { StarwardMaterial } from './StarwardMaterial';

const LAUNCHER_WIDTH: number = 166;
const LAUNCHER_HEIGHT: number = 46;

@ComponentV2
export struct StarwardCombinationLauncher {
  @Require @Param viewportWidth: number;
  @Require @Param viewportHeight: number;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param bgmLeft: number = -1;
  @Param bgmTop: number = -1;
  @Param reducedMotion: boolean = true;
  @Event open: () => void = () => {};
  @Event dockChanged: (area: Area | null) => void = () => {};
  @Env(WritableEnvKey.FONT_SCALE) fontScale: number;
  @Local private x: number = 1;
  @Local private y: number = COMBINATION_LAUNCHER_DEFAULT_Y;
  @Local private entered: boolean = true;
  @Local private dragging: boolean = false;
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private preferences: CombinationLauncherPosition | undefined;
  private startX: number = 1;
  private startY: number = COMBINATION_LAUNCHER_DEFAULT_Y;
  private suppressTapUntil: number = 0;

  aboutToAppear(): void {
    this.preferences = CombinationLauncherPosition.load();
    this.x = this.ratio(this.preferences.x, 1);
    this.y = this.ratio(this.preferences.y, COMBINATION_LAUNCHER_DEFAULT_Y);
    this.entered = this.reducedMotion;
    this.motionPolicyChanged();
  }

  aboutToDisappear(): void {
    this.dockChanged(null);
  }

  @Monitor('reducedMotion')
  motionPolicyChanged(): void {
    this.material = StarwardMaterial.create(uiMaterial.ImmersiveStyle.THIN,
      !this.reducedMotion, $r('app.color.accent'));
    if (this.reducedMotion && !this.entered) {
      this.getUIContext().animateTo({ duration: 0 }, () => { this.entered = true; });
    }
  }

  private appear(): void {
    if (this.reducedMotion) { return; }
    this.getUIContext().animateTo({ duration: 600, curve: curves.springMotion(0.32, 0.82) }, () => {
      this.entered = true;
    });
  }

  private ratio(value: number, fallback: number = 0): number {
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : fallback;
  }

  private fontGrowth(): number { return Math.max(0, Math.min(0.6, (this.fontScale || 1) - 1)); }
  private buttonWidth(): number {
    return Math.min(this.viewportWidth - 24, LAUNCHER_WIDTH + 90 * this.fontGrowth());
  }
  private buttonHeight(): number { return LAUNCHER_HEIGHT + 24 * this.fontGrowth(); }
  private travelX(): number {
    return Math.max(0, this.viewportWidth - this.buttonWidth() - 24);
  }
  private travelY(): number {
    return Math.max(0, this.viewportHeight - this.topInset - this.bottomInset - this.buttonHeight() - 24);
  }

  private dockY(): number {
    const top: number = this.topInset + 12;
    const preferred: number = top + this.y * this.travelY();
    const left: number = 12 + this.x * this.travelX();
    const gap: number = 8;
    if (this.bgmLeft < 0 || this.bgmTop < 0 ||
      left >= this.bgmLeft + QUEST_BGM_SIZE + gap || left + this.buttonWidth() + gap <= this.bgmLeft) {
      return preferred;
    }
    const above: number = this.bgmTop - this.buttonHeight() - gap;
    const below: number = this.bgmTop + QUEST_BGM_SIZE + gap;
    if (preferred <= above || preferred >= below) { return preferred; }
    const canFitAbove: boolean = above >= top;
    const canFitBelow: boolean = below <= top + this.travelY();
    if (canFitAbove && (!canFitBelow || preferred - above <= below - preferred)) { return above; }
    return canFitBelow ? below : preferred;
  }

  private startDrag(): void {
    this.dragging = true;
    this.startX = this.x;
    this.startY = this.y;
  }

  private updateDrag(event: GestureEvent): void {
    if (!this.dragging) { return; }
    this.x = this.travelX() > 0 ? this.ratio(this.startX + event.offsetX / this.travelX()) : this.startX;
    this.y = this.travelY() > 0 ? this.ratio(this.startY + event.offsetY / this.travelY()) : this.startY;
  }

  private endDrag(cancelled: boolean): void {
    if (!this.dragging) { return; }
    this.dragging = false;
    this.suppressTapUntil = Date.now() + 120;
    const x: number = cancelled ? this.startX : (this.x < 0.5 ? 0 : 1);
    const y: number = cancelled ? this.startY : this.y;
    if (!cancelled && this.preferences !== undefined) {
      this.preferences.x = x;
      this.preferences.y = y;
    }
    if (this.reducedMotion) {
      this.x = x;
      this.y = y;
    } else {
      this.getUIContext().animateTo({ duration: 260, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }, () => {
        this.x = x;
        this.y = y;
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Button({ type: ButtonType.Capsule }) {
          Row({ space: 8 }) {
            Stack() {
              Image($r('app.media.icon_nav_sparkle_fill')).width(18).height(18)
                .fillColor($r('app.color.on_accent'))
            }.width(34).height(34).borderRadius(999)
              .linearGradient({ direction: GradientDirection.Bottom,
                colors: [[$r('app.color.accent_strong'), 0], [$r('app.color.accent'), 1]] })
              .shadow({ radius: 12, color: $r('app.color.glow_accent_soft'), offsetY: 3 })
              .accessibilityLevel('no-hide-descendants')
            Text('查看本场线索').fontSize(13).fontWeight(600)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.strong'))
              .layoutWeight(1)
            Image($r('app.media.icon_arrow_up_right')).width(15).height(15).fillColor($r('app.color.accent_text'))
              .accessibilityLevel('no')
          }.width('100%').padding({ left: 6, right: 14 })
        }.id('gameplay-combination-launcher').width(this.buttonWidth()).height(this.buttonHeight()).padding(0)
          .backgroundColor(this.material ? $r('app.color.glass_floating') : $r('app.color.raised'))
          .systemMaterial(this.material).border({ width: 1, color: $r('app.color.accent_border'), radius: 999 })
          .shadow({ radius: 16, color: $r('app.color.choice_shadow'), offsetY: 5 })
          .scale({ x: this.dragging ? 0.96 : 1, y: this.dragging ? 0.96 : 1 })
          .accessibilityText('查看本场线索').accessibilityDescription('可拖动移动并贴边')
          .onClick(() => { if (!this.dragging && Date.now() >= this.suppressTapUntil) { this.open(); } })
          .gesture(PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5, isFingerCountLimited: true })
            .onActionStart((event: GestureEvent) => { this.startDrag(); this.updateDrag(event); })
            .onActionUpdate((event: GestureEvent) => this.updateDrag(event))
            .onActionEnd((event: GestureEvent) => { this.updateDrag(event); this.endDrag(false); })
            .onActionCancel(() => this.endDrag(true)))
      }.width(this.buttonWidth()).height(this.buttonHeight())
        .position({ x: 12 + this.x * this.travelX(), y: this.dockY() })
        .opacity(this.entered ? 1 : 0).scale({ x: this.entered ? 1 : 0.78, y: this.entered ? 1 : 0.78 })
        .translate({ x: this.entered ? 0 : 18, y: this.entered ? 0 : 24 })
        .hitTestBehavior(HitTestMode.None).onAppear(() => this.appear())
        .onAreaChange((_oldArea: Area, area: Area) => this.dockChanged(area), { expectedUpdateInterval: 16 })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }
}
