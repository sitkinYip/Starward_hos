import { curves, UIUtils } from '@kit.ArkUI';
import { StarwardAnswerResultOverlay } from './StarwardAnswerResultOverlay';
import { STARWARD_PAGE_TRANSITION_MS } from './StarwardMotion';

const INCORRECT_ANSWER_DISMISS_MS: number = 4500;

/** Displays one server judgment. Dismissal never edits the answer or advances the question. */
@ComponentV2
export struct StarwardIncorrectAnswer {
  @Require @Param message: string;
  @Param reducedMotion: boolean = true;
  @Event dismiss: () => void = () => {};
  @Local private ringScale: number = 0.68;
  @Local private ringOpacity: number = 0.9;
  @Local private remainingMs: number = INCORRECT_ANSWER_DISMISS_MS;
  private countdownTimer: number = -1;
  private countdownEndsAt: number = 0;

  private present(): void {
    if (this.countdownTimer !== -1) { return; }
    this.countdownEndsAt = Date.now() + INCORRECT_ANSWER_DISMISS_MS;
    this.tickCountdown();
    if (this.reducedMotion) { return; }
    this.getUIContext().animateTo({ duration: STARWARD_PAGE_TRANSITION_MS * 2,
      curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }, () => UIUtils.applySync(() => {
      this.ringScale = 1;
      this.ringOpacity = 0.48;
    }));
  }

  private tickCountdown(): void {
    this.remainingMs = Math.max(0, this.countdownEndsAt - Date.now());
    if (this.remainingMs === 0) {
      this.countdownTimer = -1;
      this.dismiss();
      return;
    }
    const interval: number = this.reducedMotion ? 750 : 80;
    this.countdownTimer = setTimeout(() => this.tickCountdown(), Math.min(interval, this.remainingMs));
  }

  aboutToDisappear(): void {
    clearTimeout(this.countdownTimer);
    this.countdownTimer = -1;
  }

  @Builder
  private emblem() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(208).height(144).radialGradient({ center: ['50%', '50%'], radius: '50%',
        colors: [[$r('app.color.danger_surface'), 0], [Color.Transparent, 1]] })
      Ellipse().width(208).height(68).fill(Color.Transparent)
        .stroke($r('app.color.danger')).strokeWidth(2).rotate({ angle: -14 })
        .scale({ x: this.reducedMotion ? 1 : this.ringScale, y: this.reducedMotion ? 1 : this.ringScale })
        .opacity(this.reducedMotion ? 0.48 : this.ringOpacity)
      Ellipse().width(152).height(50).fill(Color.Transparent).stroke($r('app.color.danger_border'))
        .strokeWidth(1).rotate({ angle: -14 })
      Circle().width(76).height(76).fill($r('app.color.raised')).stroke($r('app.color.danger_border')).strokeWidth(1)
      Image($r('app.media.icon_warning')).width(43).height(43)
        .fillColor($r('app.color.danger_strong'))
    }.width(220).height(180).hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  private resultContent() {
    Column({ space: 18 }) {
      this.emblem()
      Column({ space: 8 }) {
        Text('回答有误').id('gameplay-incorrect-answer-title').fontSize(28).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
        Text(this.message).id('gameplay-incorrect-answer-message').fontSize(15).lineHeight('23fp')
          .fontColor($r('app.color.text')).textAlign(TextAlign.Center)
      }.padding({ top: 12, bottom: 12, left: 28, right: 28 })
        .radialGradient({ center: ['50%', '50%'], radius: '58%',
          colors: [[$r('app.color.burst_glow_card'), 0], [$r('app.color.burst_glow_card_clear'), 1]] })
      Button('知道了', { type: ButtonType.Capsule, stateEffect: !this.reducedMotion })
        .id('gameplay-incorrect-answer-close').constraintSize({ minWidth: 132, minHeight: 48 })
        .padding({ left: 20, right: 20 }).fontSize(16).fontWeight(600)
        .backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[$r('app.color.accent_strong'), 0], [$r('app.color.accent'), 1]] })
        .shadow({ radius: 16, offsetY: 6, color: $r('app.color.glow_accent_soft') })
        .defaultFocus(true).onClick(() => this.dismiss())
      Progress({ value: this.remainingMs, total: INCORRECT_ANSWER_DISMISS_MS, type: ProgressType.Linear })
        .id('gameplay-incorrect-answer-countdown').width(132).height(3)
        .style({ strokeWidth: 3, enableSmoothEffect: !this.reducedMotion })
        .color($r('app.color.danger_strong')).backgroundColor($r('app.color.danger_surface'))
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
    }.width('100%').constraintSize({ maxWidth: 384 }).padding({ left: 22, right: 22 })
  }

  build() {
    StarwardAnswerResultOverlay({ nodeId: 'gameplay-incorrect-answer', backdropId: 'gameplay-incorrect-answer-backdrop',
      reducedMotion: this.reducedMotion, dismiss: () => this.dismiss(), content: () => { this.resultContent() } })
      .onAppear(() => this.present())
  }
}
