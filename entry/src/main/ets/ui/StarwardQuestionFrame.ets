import { curves, UIUtils } from '@kit.ArkUI';

const SHEEN_INITIAL_WAIT: number = 7000;
const SHEEN_PERIOD: number = 9000;
const SHEEN_ENTER: number = 720;
const SHEEN_EXIT: number = 1260;
const SHEEN_START: number = -1.3;
const SHEEN_END: number = 3.3;
const ANSWER_EFFECT_LIFETIME: number = 1100;

@ComponentV2
struct StarwardAnswerWash {
  @Require @Param cardWidth: number;
  @Require @Param cardHeight: number;
  @Local private strength: number = 0;
  @Local private expansion: number = 0.72;

  private start(): void {
    const context = this.getUIContext();
    const curve = curves.cubicBezierCurve(0.32, 0.72, 0, 1);
    context.animateTo({ duration: ANSWER_EFFECT_LIFETIME, curve }, () => UIUtils.applySync(() => {
      this.expansion = 1.24;
    }));
    context.keyframeAnimateTo({ iterations: 1 }, [
      { duration: 418, curve, event: () => UIUtils.applySync(() => { this.strength = 0.22; }) },
      { duration: 682, curve, event: () => UIUtils.applySync(() => { this.strength = 0; }) }
    ]);
  }

  build() {
    Stack() {
      Column() {}
        .width(this.cardWidth).height(this.cardHeight)
        .radialGradient({ center: ['50%', '48%'], radius: 278,
          colors: [[$r('app.color.accent'), 0], [Color.Transparent, 0.54]] })
        .opacity(this.strength).scale({ x: this.expansion, y: this.expansion })
    }.width(this.cardWidth).height(this.cardHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => this.start())
  }
}

@ComponentV2
struct StarwardAnswerBurstRing {
  @Require @Param tint: ResourceColor;
  @Param delay: number = 0;
  @Local private diameterScale: number = 0.2;
  @Local private strength: number = 0;

  private start(): void {
    const context = this.getUIContext();
    const curve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    context.animateTo({ duration: 980, delay: this.delay, curve }, () => UIUtils.applySync(() => {
      this.diameterScale = 24;
    }));
    context.keyframeAnimateTo({ delay: this.delay, iterations: 1 }, [
      { duration: 216, curve, event: () => UIUtils.applySync(() => { this.strength = 0.82; }) },
      { duration: 764, curve, event: () => UIUtils.applySync(() => { this.strength = 0; }) }
    ]);
  }

  build() {
    Circle().width(1).height(1).fill(Color.Transparent).stroke(this.tint).strokeWidth(1)
      .opacity(this.strength).scale({ x: this.diameterScale, y: this.diameterScale })
      .hitTestBehavior(HitTestMode.None).onAppear(() => this.start())
  }
}

@ComponentV2
struct StarwardAnswerBurst {
  @Require @Param cardWidth: number;
  @Require @Param cardHeight: number;
  @Require @Param danger: boolean;

  private tint(): ResourceColor { return this.danger ? '#D78B79' : '#C8DF9E'; }

  build() {
    Stack() {
      StarwardAnswerBurstRing({ tint: this.tint() })
      StarwardAnswerBurstRing({ tint: this.tint(), delay: 110 })
      Particle({
        particles: [{
          emitter: {
            particle: { type: ParticleType.POINT, config: { radius: 2 }, count: 18, lifetime: 920 },
            emitRate: 180, position: ['50%', '50%'], size: [1, 1]
          },
          color: { range: [this.tint(), this.tint()] },
          velocity: { speed: [110, 280], angle: [0, 360] },
          opacity: { range: [0, 0], updater: { type: ParticleUpdater.CURVE, config: [
            { from: 0, to: 1, startMillis: 0, endMillis: 166, curve: Curve.EaseOut },
            { from: 1, to: 0, startMillis: 166, endMillis: 920, curve: Curve.EaseOut }
          ] } }
        }]
      }).width(this.cardWidth).height(this.cardHeight)
    }.width(this.cardWidth).height(this.cardHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}

@ComponentV2
struct StarwardQuestionSheen {
  @Require @Param cardWidth: number;
  @Require @Param cardHeight: number;
  @Local private bandPosition: number = SHEEN_START;
  @Local private strength: number = 0;
  private pending: number = -1;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.schedule(SHEEN_INITIAL_WAIT);
  }

  aboutToDisappear(): void {
    this.mounted = false;
    clearTimeout(this.pending);
    this.pending = -1;
  }

  private schedule(delay: number): void {
    this.pending = setTimeout(() => {
      if (!this.mounted) { return; }
      UIUtils.applySync(() => {
        this.bandPosition = SHEEN_START;
        this.strength = 0;
      });
      const context = this.getUIContext();
      const curve = curves.cubicBezierCurve(0.32, 0.72, 0, 1);
      context.animateTo({ duration: SHEEN_ENTER + SHEEN_EXIT, curve }, () => UIUtils.applySync(() => {
        this.bandPosition = SHEEN_END;
      }));
      context.keyframeAnimateTo({ iterations: 1 }, [
        { duration: SHEEN_ENTER, curve, event: () => UIUtils.applySync(() => { this.strength = 0.13 * 0.56; }) },
        { duration: SHEEN_EXIT, curve, event: () => UIUtils.applySync(() => { this.strength = 0; }) }
      ]);
      this.schedule(SHEEN_PERIOD);
    }, delay);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .width(this.cardWidth * 0.58).height(this.cardHeight * 1.9)
        .position({ x: this.cardWidth * -0.28, y: this.cardHeight * -0.48 })
        .linearGradient({ angle: 90, colors: [[Color.Transparent, 0], [$r('app.color.strong'), 0.5],
          [Color.Transparent, 1]] })
        .rotate({ angle: 17 })
        .translate({ x: this.cardWidth * 0.58 * this.bandPosition })
        .opacity(this.strength)
    }.id('question-card-sheen').width(this.cardWidth).height(this.cardHeight).clip(true)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}

/** The content owns height; the frame and sheen cannot intercept input. */
@ComponentV2
export struct StarwardQuestionFrame {
  @Param frameId: string = '';
  @Param motionEnabled: boolean = false;
  @Param selectionRevision: number = 0;
  @Param feedbackVersion: number = 0;
  @Param feedbackDanger: boolean = false;
  @Param feedbackSuccess: boolean = false;
  @BuilderParam content: () => void;
  @Local frameWidth: number = 0;
  @Local frameHeight: number = 0;
  @Local private frameInView: boolean = false;
  @Local private playingVersion: number = 0;
  @Local private impactX: number = 0;
  @Local private impactRotation: number = 0;
  @Local private impactScale: number = 1;
  @Local private contentPresented: boolean = true;
  @Local private settledEntrance: boolean = true;
  private consumedVersion: number = 0;
  private consumedSelection: number = 0;
  private startTimer: number = -1;
  private finishTimer: number = -1;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    this.consumedVersion = this.feedbackVersion;
    this.consumedSelection = this.selectionRevision;
    // Preloaded neighboring Swiper pages are already painted during the native swipe.
    this.contentPresented = !this.motionEnabled || this.frameId.length === 0;
    this.settledEntrance = !this.motionEnabled || this.frameId.length === 0;
  }

  aboutToDisappear(): void {
    clearTimeout(this.startTimer);
    clearTimeout(this.finishTimer);
    clearTimeout(this.entranceTimer);
  }

  @Monitor('motionEnabled', 'selectionRevision', 'frameInView')
  private selectionChanged(): void {
    clearTimeout(this.entranceTimer);
    this.entranceTimer = -1;
    const revision: number = this.selectionRevision;
    if (this.frameId.length === 0) {
      this.consumedSelection = 0;
      this.settledEntrance = true;
      return;
    }
    if (!this.motionEnabled) {
      this.consumedSelection = revision;
      this.settledEntrance = true;
      return;
    }
    if (!this.frameInView || revision <= 0 || revision === this.consumedSelection) { return; }
    this.entranceTimer = setTimeout(() => {
      this.entranceTimer = -1;
      if (this.motionEnabled && this.frameInView && this.selectionRevision === revision) {
        this.consumedSelection = revision;
        this.getUIContext().animateTo({ duration: 0 },
          () => UIUtils.applySync(() => { this.settledEntrance = false; }));
        this.settleEntrance();
      }
    }, 0);
  }

  private settleEntrance(delay: number = 0): void {
    if (this.settledEntrance) { return; }
    this.getUIContext().animateTo({ duration: 880, delay, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) },
      () => UIUtils.applySync(() => { this.settledEntrance = true; }));
  }

  @Monitor('feedbackVersion', 'motionEnabled', 'frameInView')
  private feedbackChanged(): void {
    const version: number = this.feedbackVersion;
    const newFeedback: boolean = version > 0 && version !== this.consumedVersion;
    if (newFeedback) { this.consumedVersion = version; }
    if (!this.motionEnabled || !this.frameInView || version <= 0) {
      clearTimeout(this.startTimer);
      if (this.playingVersion !== 0) { this.stopImpact(); }
      if (!this.motionEnabled) { this.contentPresented = true; }
      return;
    }
    if (!newFeedback) { return; }
    clearTimeout(this.startTimer);
    this.startTimer = setTimeout(() => {
      this.startTimer = -1;
      if (this.motionEnabled && this.frameInView && this.feedbackVersion === version) {
        this.startImpact(version);
      }
    }, 0);
  }

  private presentContent(): void {
    if (this.contentPresented) { return; }
    this.getUIContext().animateTo({ duration: 720, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) },
      () => UIUtils.applySync(() => { this.contentPresented = true; }));
  }

  private setImpact(x: number, angle: number, scale: number): void {
    UIUtils.applySync(() => {
      this.impactX = x;
      this.impactRotation = angle;
      this.impactScale = scale;
    });
  }

  private stopImpact(): void {
    clearTimeout(this.finishTimer);
    this.finishTimer = -1;
    this.playingVersion = 0;
    this.getUIContext().animateTo({ duration: 0 }, () => this.setImpact(0, 0, 1));
  }

  private startImpact(version: number): void {
    if (!this.feedbackDanger && !this.feedbackSuccess) { return; }
    this.stopImpact();
    this.playingVersion = version;
    const curve = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    const context = this.getUIContext();
    if (this.feedbackDanger) {
      context.keyframeAnimateTo({ iterations: 1 }, [
        { duration: 190, curve, event: () => this.setImpact(-7, -0.12, 1) },
        { duration: 164, curve, event: () => this.setImpact(5, 0.08, 1) },
        { duration: 163, curve, event: () => this.setImpact(-2, 0, 1) },
        { duration: 163, curve, event: () => this.setImpact(0, 0, 1) }
      ]);
    } else {
      context.keyframeAnimateTo({ iterations: 1 }, [
        { duration: 331, curve, event: () => this.setImpact(0, 0, 1.012) },
        { duration: 589, curve, event: () => this.setImpact(0, 0, 1) }
      ]);
    }
    this.finishTimer = setTimeout(() => this.stopImpact(), ANSWER_EFFECT_LIFETIME);
  }

  @Builder
  decoration() {
    // Match the measured Web border box: CSS corners at12 inside the1px
    // border are13 from the outside; a1px outline at offset-7 paints at6.
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}
        .id('question-frame-inner')
        .width(this.frameWidth - 12).height(this.frameHeight - 12)
        .border({ width: 1, color: $r('app.color.accent'), radius: 0 }).opacity(0.09)
        .position({ x: 5, y: 5 })
      Column() {}
        .id('question-frame-top-left').width(28).height(28)
        // Web's later border-side shorthand resolves these lines to inherited currentColor.
        .border({ width: { top: 1, left: 1, right: 0, bottom: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ top: 12, left: 12 })
      Column() {}
        .id('question-frame-top-right').width(28).height(28)
        .border({ width: { top: 1, right: 1, left: 0, bottom: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ top: 12, right: 12 })
      Column() {}
        .id('question-frame-bottom-right').width(28).height(28)
        .border({ width: { bottom: 1, right: 1, left: 0, top: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ bottom: 12, right: 12 })
      Column() {}
        .id('question-frame-bottom-left').width(28).height(28)
        .border({ width: { bottom: 1, left: 1, right: 0, top: 0 }, color: $r('app.color.text') })
        .opacity(0.48).position({ bottom: 12, left: 12 })
    }.width(this.frameWidth - 2).height(this.frameHeight - 2).position({ x: 1, y: 1 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  build() {
    // Absolute decoration in Column is excluded from size measurement, so a
    // disappearing feedback message can also shrink the frame without a loop.
    Column() {
      if (this.motionEnabled && this.frameInView && this.frameWidth > 14 && this.frameHeight > 14) {
        StarwardQuestionSheen({ cardWidth: this.frameWidth - 2, cardHeight: this.frameHeight - 2 })
          .position({ x: 1, y: 1 })
      }
      if (this.playingVersion > 0 && this.feedbackSuccess && this.frameWidth > 14 && this.frameHeight > 14) {
        ForEach([this.playingVersion], (_version: number) => {
          StarwardAnswerWash({ cardWidth: this.frameWidth - 2, cardHeight: this.frameHeight - 2 })
            .position({ x: 1, y: 1 })
        }, (version: number) => version.toString())
      }
      Stack({ alignContent: Alignment.TopStart }) {
        this.content()
      }.width('100%').opacity(this.contentPresented ? 1 : 0)
        .translate({ y: this.contentPresented ? 0 : 18 }).onAppear(() => this.presentContent())
      if (this.frameWidth > 14 && this.frameHeight > 14) {
        this.decoration()
      }
      if (this.playingVersion > 0 && this.frameWidth > 14 && this.frameHeight > 14) {
        ForEach([this.playingVersion], (_version: number) => {
          StarwardAnswerBurst({ cardWidth: this.frameWidth - 2, cardHeight: this.frameHeight - 2,
            danger: this.feedbackDanger }).position({ x: 1, y: 1 })
        }, (version: number) => version.toString())
      }
    }.id(this.frameId).width('100%').alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border_strong'), radius: 0 })
      .translate({ x: this.impactX, y: !this.motionEnabled || this.settledEntrance ? 0 : 34 })
      .rotate({ angle: this.impactRotation })
      .scale({ x: this.impactScale * (!this.motionEnabled || this.settledEntrance ? 1 : 0.975),
        y: this.impactScale * (!this.motionEnabled || this.settledEntrance ? 1 : 0.975) })
      .onAppear(() => this.settleEntrance(120))
      .onVisibleAreaChange([0], (_expanding: boolean, ratio: number) => { this.frameInView = ratio > 0; })
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0 && width !== this.frameWidth) {
          this.frameWidth = width;
        }
        if (Number.isFinite(height) && height > 0 && height !== this.frameHeight) {
          this.frameHeight = height;
        }
      })
  }
}
