import { curves, UIUtils } from '@kit.ArkUI';
import { CombinationLauncherPosition } from '../platform/CombinationLauncherPosition';

@ComponentV2
export struct StarwardCombinationLauncher {
  @Require @Param viewportWidth: number;
  @Require @Param viewportHeight: number;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param reducedMotion: boolean = true;
  @Event open: () => void = () => {};
  @Env(WritableEnvKey.FONT_SCALE) fontScale: number;
  @Local private x: number = 1;
  @Local private y: number = 0.72;
  @Local private entered: boolean = true;
  @Local private haloOpacity: number = 0.55;
  @Local private haloScale: number = 1;
  @Local private orbitAngle: number = 0;
  private preferences: CombinationLauncherPosition | undefined;
  private mounted: boolean = false;
  private startX: number = 1;
  private startY: number = 0.72;
  private dragging: boolean = false;
  private suppressTapUntil: number = 0;

  aboutToAppear(): void {
    this.preferences = CombinationLauncherPosition.load();
    this.x = this.ratio(this.preferences.x, 1);
    this.y = this.ratio(this.preferences.y, 0.72);
    if (!this.reducedMotion) {
      this.entered = false;
      this.haloOpacity = 0.34;
      this.haloScale = 0.96;
    }
  }

  aboutToDisappear(): void { this.mounted = false; }

  @Monitor('reducedMotion')
  motionPolicyChanged(): void {
    if (!this.mounted) { return; }
    this.getUIContext().animateTo({ duration: 0 }, () => UIUtils.applySync(() => {
      this.entered = true;
      this.haloOpacity = this.reducedMotion ? 0.55 : 0.34;
      this.haloScale = this.reducedMotion ? 1 : 0.96;
      this.orbitAngle = 0;
    }));
    if (!this.reducedMotion) { this.playLight(); }
  }

  private playLight(): void {
    const ui = this.getUIContext();
    ui.animateTo({ duration: 1400, iterations: -1, playMode: PlayMode.Alternate,
      curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) }, () => UIUtils.applySync(() => {
      this.haloOpacity = 0.72;
      this.haloScale = 1.035;
    }));
    ui.animateTo({ duration: 7000, iterations: -1, curve: Curve.Linear }, () => UIUtils.applySync(() => {
      this.orbitAngle = 360;
    }));
  }

  private appear(): void {
    this.mounted = true;
    if (this.reducedMotion) { return; }
    this.getUIContext().animateTo({ duration: 720, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) }, () => {
      this.entered = true;
    });
    this.playLight();
  }

  private ratio(value: number, fallback: number = 0): number {
    return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : fallback;
  }

  private fontGrowth(): number { return Math.max(0, Math.min(0.6, (this.fontScale || 1) - 1)); }
  private compact(): boolean { return this.viewportWidth <= 620; }
  private buttonWidth(): number {
    return Math.min(this.viewportWidth - 24, (this.compact() ? 164 : 174) + 90 * this.fontGrowth());
  }
  private buttonHeight(): number { return (this.compact() ? 60 : 64) + 24 * this.fontGrowth(); }
  private travelX(): number {
    // Web reserves the wide control footprint when calculating the mobile dock.
    return Math.max(0, this.viewportWidth - this.buttonWidth() - 24 - (this.compact() ? 10 : 0));
  }
  private travelY(): number {
    return Math.max(0, this.viewportHeight - this.topInset - this.bottomInset - this.buttonHeight() - 24 -
      (this.compact() ? 4 : 0));
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
      this.getUIContext().animateTo({ duration: 240, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) }, () => {
        this.x = x;
        this.y = y;
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width(this.buttonWidth() + 16).height(this.buttonHeight() + 16).position({ x: -8, y: -8 })
          .border({ width: 1, color: $r('app.color.accent_border'),
            radius: { topLeft: 18, topRight: 7, bottomLeft: 7, bottomRight: 18 } })
          .shadow({ radius: 26, color: $r('app.color.accent_border') })
          .opacity(this.haloOpacity).scale({ x: this.haloScale, y: this.haloScale })
          .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Button({ type: ButtonType.Normal }) {
          Row({ space: 9 }) {
            Stack() {
              Circle().width('100%').height('100%').fill($r('app.color.accent_faint'))
                .stroke($r('app.color.accent_border')).strokeWidth(1)
              Circle().width('77%').height('77%').fill(Color.Transparent)
                .stroke($r('app.color.accent_border')).strokeWidth(1).strokeDashArray([2, 2])
                .rotate({ z: 1, angle: this.orbitAngle })
              Image($r('app.media.icon_archive_box')).width(21).height(21).fillColor($r('app.color.accent_text'))
            }.width(this.compact() ? 38 : 42).height(this.compact() ? 38 : 42).accessibilityLevel('no-hide-descendants')
            Column({ space: 2 }) {
              Text('UNLOCKED ARCHIVE').fontSize(8).fontFamily('monospace').fontWeight(700).letterSpacing('1.12fp')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.accent_text'))
              Text('查看本场线索').fontSize(14).fontWeight(700).letterSpacing('0.35fp')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.strong'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Image($r('app.media.icon_arrow_up_right')).width(16).height(16).fillColor($r('app.color.accent_muted'))
              .accessibilityLevel('no')
          }.width('100%').padding({ left: 8, right: 10 })
        }.id('gameplay-combination-launcher').width(this.buttonWidth()).height(this.buttonHeight()).padding(0)
          .backgroundColor($r('app.color.raised'))
          .radialGradient({ center: ['18%', '50%'], radius: this.buttonWidth() * 0.48,
            colors: [[$r('app.color.accent_soft'), 0], [Color.Transparent, 1]] })
          .border({ width: 1, color: $r('app.color.accent_border'),
            radius: { topLeft: 13, topRight: 4, bottomLeft: 4, bottomRight: 13 } })
          .shadow({ radius: 16, color: $r('app.color.choice_shadow'), offsetY: 5 })
          .accessibilityText('查看本场线索').accessibilityDescription('可拖动移动并贴边')
          .onClick(() => { if (!this.dragging && Date.now() >= this.suppressTapUntil) { this.open(); } })
          .gesture(PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5, isFingerCountLimited: true })
            .onActionStart((event: GestureEvent) => { this.startDrag(); this.updateDrag(event); })
            .onActionUpdate((event: GestureEvent) => this.updateDrag(event))
            .onActionEnd((event: GestureEvent) => { this.updateDrag(event); this.endDrag(false); })
            .onActionCancel(() => this.endDrag(true)))
      }.width(this.buttonWidth()).height(this.buttonHeight())
        .position({ x: 12 + this.x * this.travelX(), y: this.topInset + 12 + this.y * this.travelY() })
        .opacity(this.entered ? 1 : 0).scale({ x: this.entered ? 1 : 0.78, y: this.entered ? 1 : 0.78 })
        .translate({ x: this.entered ? 0 : 18, y: this.entered ? 0 : 24 })
        .hitTestBehavior(HitTestMode.None).onAppear(() => this.appear())
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }
}
