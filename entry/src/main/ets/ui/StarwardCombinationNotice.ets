import { curves, UIUtils } from '@kit.ArkUI';

/** The moving panel decoration has the same lifetime as the native dialog content. */
@ComponentV2
struct StarwardCompletionDecoration {
  @Require @Param panelWidth: number;
  @Require @Param panelHeight: number;
  @Local private edgeLit: boolean = false;
  @Local private bloomExpanded: boolean = false;
  @Local private outerAngle: number = 45;
  @Local private middleAngle: number = 45;
  @Local private innerAngle: number = 45;

  private start(): void {
    const context = this.getUIContext();
    const smooth = curves.cubicBezierCurve(0.22, 1, 0.36, 1);
    const orbit = curves.cubicBezierCurve(0.45, 0.02, 0.55, 0.98);
    context.animateTo({ duration: 2600, curve: smooth, iterations: -1, playMode: PlayMode.Alternate },
      () => { this.edgeLit = true; });
    context.animateTo({ duration: 2800, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate },
      () => { this.bloomExpanded = true; });
    context.animateTo({ duration: 18000, curve: orbit, iterations: -1 }, () => { this.outerAngle = 405; });
    context.animateTo({ duration: 12000, curve: orbit, iterations: -1 }, () => { this.middleAngle = -315; });
    context.animateTo({ duration: 8000, curve: orbit, iterations: -1 }, () => { this.innerAngle = 405; });
  }

  private diameter(): number { return Math.min(760, this.panelWidth * 1.52); }

  @Builder
  rune(size: number, angle: number, style: BorderStyle) {
    Column() {}
      .width(size).height(size)
      .border({ width: 1, color: '#FFE5A8', style: style })
      .opacity(0.16).rotate({ angle: angle })
  }

  build() {
    Stack() {
      Column() {}
        .id('gameplay-combination-notice-bloom')
        .width(this.diameter() * 0.68).height(this.diameter() * 0.68)
        .radialGradient({ center: ['50%', '50%'], radius: this.diameter() * 0.34,
          colors: [['#33EDCA70', 0], ['#0AC69E3E', 0.36], [Color.Transparent, 0.68]] })
        .opacity(this.bloomExpanded ? 0.68 : 0.29)
        .scale({ x: this.bloomExpanded ? 1.18 : 0.82, y: this.bloomExpanded ? 1.18 : 0.82 })
      this.rune(this.diameter() * 0.82, this.outerAngle, BorderStyle.Solid)
      this.rune(this.diameter() * 0.54, this.middleAngle, BorderStyle.Dashed)
      this.rune(this.diameter() * 0.28, this.innerAngle, BorderStyle.Solid)
      Particle({
        particles: [{
          emitter: {
            particle: { type: ParticleType.POINT, config: { radius: 1.5 }, count: -1, lifetime: 3800 },
            emitRate: 2, position: ['50%', '54%'], size: [1, 1]
          },
          color: { range: ['#9ACDBD', '#9ACDBD'] },
          velocity: { speed: [42, 64], angle: [0, 360] },
          opacity: { range: [0, 0], updater: { type: ParticleUpdater.CURVE, config: [
            { from: 0, to: 0.85, startMillis: 0, endMillis: 836, curve: Curve.EaseOut },
            { from: 0.85, to: 0.22, startMillis: 836, endMillis: 2964, curve: Curve.EaseOut },
            { from: 0.22, to: 0, startMillis: 2964, endMillis: 3800, curve: Curve.EaseIn }
          ] } }
        }]
      }).width('100%').height('100%')
      Column() {}
        .id('gameplay-combination-notice-edge')
        .width(this.panelWidth * 0.76).height(2)
        .linearGradient({ direction: GradientDirection.Right,
          colors: [[Color.Transparent, 0], ['#E6FFE59E', 0.5], [Color.Transparent, 1]] })
        .position({ x: this.panelWidth * 0.12, y: 0 })
        .scale({ x: this.edgeLit ? 1 : 0.42, y: 1 })
        .opacity(this.edgeLit ? 1 : 0.36)
    }.id('gameplay-combination-notice-decoration').width(this.panelWidth).height(this.panelHeight)
      .clip(true).hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => this.start())
  }
}

/** Branded content for the native combination completion modal. */
@ComponentV2
export struct StarwardCombinationNotice {
  @Require @Param completedCount: number;
  @Require @Param hasResults: boolean;
  @Require @Param panelWidth: number;
  @Require @Param maxHeight: number;
  @Require @Param viewportWidth: number;
  @Param displayFont: string = 'serif';
  @Param motionEnabled: boolean = false;
  @Event acknowledge: () => void = () => {};
  @Local private panelHeight: number = 0;
  @Local private sigilAwake: boolean = false;

  @Monitor('motionEnabled')
  private animateSigil(): void {
    if (!this.motionEnabled) {
      this.getUIContext().animateTo({ duration: 0 }, () => UIUtils.applySync(() => {
        this.sigilAwake = false;
      }));
      return;
    }
    this.getUIContext().animateTo({ duration: 2800, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate },
      () => UIUtils.applySync(() => {
        this.sigilAwake = true;
      }));
  }

  private compact(): boolean { return this.viewportWidth <= 620; }
  private wideInset(): number { return Math.max(38, Math.min(78, this.viewportWidth * 0.08)); }
  private titleSize(): number {
    const width: number = this.viewportWidth;
    return this.compact() ? Math.max(32, Math.min(46, width * 0.11)) : Math.max(34, Math.min(62, width * 0.07));
  }

  @Builder
  panelContent() {
    Column() {
      Scroll() {
        Column({ space: this.compact() ? 15 : 18 }) {
          Text(`${this.completedCount}`).id('gameplay-combination-notice-count')
            .width(82).height(82).fontSize(34).fontFamily('serif').textAlign(TextAlign.Center)
            .fontColor($r('app.color.completion_sigil_text'))
            .radialGradient({ center: ['50%', '50%'], radius: 41,
              colors: [[$r('app.color.completion_sigil_center'), 0], [$r('app.color.completion_sigil_edge'), 0.7]] })
            .border({ width: 1, radius: 41, color: $r('app.color.completion_sigil_border') })
            .scale({ x: this.sigilAwake ? 1.06 : 1, y: this.sigilAwake ? 1.06 : 1 })
            .rotate({ angle: this.sigilAwake ? 4 : 0 }).translate({ y: this.sigilAwake ? -4 : 0 })
            .accessibilityLevel('no')
          Text('QUEST SET COMPLETE').id('gameplay-combination-notice-eyebrow')
            .fontFamily('monospace').fontWeight(600).fontSize(12).lineHeight('14.4fp').letterSpacing('1.68fp')
            .fontColor($r('app.color.accent_muted')).textAlign(TextAlign.Center).accessibilityLevel('no')
          Text('组合谜题全部破解').id('gameplay-combination-notice-title').width('100%')
            .fontFamily(this.displayFont).fontWeight(FontWeight.Medium).fontSize(this.titleSize())
            .lineHeight(`${this.titleSize() * 1.08}fp`).letterSpacing(`${-0.035 * this.titleSize()}fp`)
            .fontColor($r('app.color.strong')).textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
          Text(`你已完成本次组合中的 ${this.completedCount} 道谜题。`).id('gameplay-combination-notice-detail')
            .constraintSize({ maxWidth: 500 }).fontSize(16).lineHeight('28.8fp').textAlign(TextAlign.Center)
            .fontColor($r('app.color.muted')).margin({ bottom: 8 })
          Button(this.hasResults ? '查看组合结果' : '知晓了', { type: ButtonType.Capsule })
            .id('gameplay-combination-notice-ack').constraintSize({ minHeight: 46, maxWidth: '100%' })
            .padding({ left: 20, right: 20, top: 8, bottom: 8 }).fontSize(16).fontWeight(600)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .defaultFocus(true).onClick(() => this.acknowledge())
        }.width('100%').alignItems(HorizontalAlign.Center)
          // The outer and inner frames account for 8 vp of the content inset.
          .padding({ top: this.compact() ? 54 : this.wideInset() + 11,
            left: this.compact() ? 16 : this.wideInset() - 8, right: this.compact() ? 16 : this.wideInset() - 8,
            bottom: this.compact() ? 32 : this.wideInset() - 8 })
      }.width('100%').constraintSize({ maxHeight: this.maxHeight - 16 }).align(Alignment.Top)
        .scrollBar(BarState.Off).border({ width: 1, color: $r('app.color.completion_frame_inner') })
    }.width('100%').padding(7)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.motionEnabled && this.panelHeight > 16) {
        StarwardCompletionDecoration({ panelWidth: this.panelWidth - 2, panelHeight: this.panelHeight - 2 })
          .position({ x: 0, y: 0 })
      }
      this.panelContent()
    }.id('gameplay-combination-notice').width(this.panelWidth)
      .backgroundColor($r('app.color.completion_surface'))
      .border({ width: 1, color: $r('app.color.completion_frame_outer') })
      .onAppear(() => this.animateSigil())
      .onAreaChange((_previous: Area, current: Area) => {
        const height: number = Number(current.height);
        if (Number.isFinite(height) && height > 0 && height !== this.panelHeight) { this.panelHeight = height; }
      })
  }
}
