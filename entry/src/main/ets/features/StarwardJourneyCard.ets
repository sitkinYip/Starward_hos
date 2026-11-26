import { curves, UIUtils } from '@kit.ArkUI';
import { assignmentKind, assignmentState } from '../business/assignmentState';
import { AssignmentSummary } from '../business/models';
import { STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_PANEL, STARWARD_RADIUS_ROUND } from '../ui/StarwardRadii';

const RING_SIZE: number = 54;
const CARD_ENTRANCE_DELAYS: number[] = [0, 120, 240, 320];

@ComponentV2
struct JourneyCardGlow {
  @Require @Param cardWidth: number;
  @Require @Param cardHeight: number;
  @Local private bright: boolean = false;

  build() {
    Column() {}.id('journey-card-glow').width(this.cardWidth).height(this.cardHeight)
      .border({ width: 1, radius: STARWARD_RADIUS_PANEL, color: $r('app.color.glow_accent') })
      .radialGradient({ center: ['76%', '50%'], radius: 84,
        colors: [[$r('app.color.glow_accent_soft'), 0], [$r('app.color.glow_accent_faint'), 0.48],
          [Color.Transparent, 1]] })
      .opacity(this.bright ? 0.86 : 0.26)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: 2200, iterations: -1,
          playMode: PlayMode.Alternate, curve: Curve.EaseInOut },
          () => UIUtils.applySync(() => { this.bright = true; }));
      })
  }
}

@ComponentV2
export struct StarwardJourneyCard {
  @Require @Param item: AssignmentSummary;
  @Require @Param rank: number;
  @Require @Param now: number;
  @Require @Param levelLabel: string;
  @Param order: number = 0;
  @Param opensAtText: string = '';
  @Param closesAtText: string = '';
  @Param active: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event open: (id: string) => void = () => {};
  @Local private entered: boolean = false;
  @Local private inView: boolean = false;
  @Local private cardWidth: number = 0;
  @Local private cardHeight: number = 0;

  @Computed
  get kind(): string {
    return assignmentKind(this.item, this.rank, this.now);
  }

  // Motion Prompt #002 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#002
  @Monitor('active', 'reducedMotion')
  private enter(): void {
    if (this.entered || !this.active) { return; }
    const delay: number = CARD_ENTRANCE_DELAYS[Math.min(this.order, CARD_ENTRANCE_DELAYS.length - 1)];
    this.getUIContext().animateTo({
      duration: this.reducedMotion ? 0 : 500,
      delay: this.reducedMotion ? 0 : delay,
      curve: curves.cubicBezierCurve(0.34, 1.38, 0.64, 1)
    }, () => UIUtils.applySync(() => { this.entered = true; }));
  }

  @Computed
  get entrancePending(): boolean {
    return !this.entered && !this.reducedMotion;
  }

  private scheduleLabel(): string {
    const start: string = this.opensAtText.length > 0 ? `开放 ${this.opensAtText}` : '';
    const end: string = this.closesAtText.length > 0 ? `截止 ${this.closesAtText}` : '';
    return start.length > 0 && end.length > 0 ? `${start} · ${end}` : start + end;
  }

  private accessibilityLabel(): string {
    const state: string = assignmentState(this.item, this.rank, this.now);
    const progress: string = this.kind === 'locked' ? '' :
      `，已解开 ${this.item.completedLevels} / ${this.item.totalLevels}`;
    const schedule: string = this.scheduleLabel();
    return `${this.item.title}，${state}，${this.levelLabel}${progress}${schedule.length > 0 ? `，${schedule}` : ''}`;
  }

  @Builder
  private schedule() {
    if (this.opensAtText.length > 0 || this.closesAtText.length > 0) {
      Row({ space: 6 }) {
        Image($r('app.media.icon_clock')).width(14).height(14).fillColor($r('app.color.muted'))
          .margin({ top: 1 })
        Text(this.scheduleLabel()).fontSize(12).lineHeight('16fp').fontFeature("'tnum' 1")
          .fontColor($r('app.color.muted')).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top).margin({ top: 6 })
    }
  }

  @Builder
  private progressRing() {
    Stack() {
      Progress({ value: this.item.completedLevels, total: Math.max(1, this.item.totalLevels), type: ProgressType.Ring })
        .width(RING_SIZE).height(RING_SIZE).color($r('app.color.accent')).backgroundColor($r('app.color.ring_track'))
        .style({ strokeWidth: 3.5, enableScanEffect: false, enableSmoothEffect: !this.reducedMotion,
          shadow: this.kind === 'active' })
      Text() {
        Span(this.item.completedLevels.toString()).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.strong'))
        Span(`/${this.item.totalLevels}`).fontSize(11).fontColor($r('app.color.muted'))
      }.fontFeature("'tnum' 1").maxLines(1)
    }.id(`journey-progress-${this.item.id}`).width(RING_SIZE).height(RING_SIZE)
  }

  @Builder
  private trailing() {
    if (this.kind === 'locked') {
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.lock')).fontSize(17).fontColor([$r('app.color.muted')])
        Text(`Lv.${this.item.minLevel}`).fontSize(14).fontWeight(FontWeight.Medium)
          .fontFeature("'tnum' 1").fontColor($r('app.color.muted')).maxLines(1)
      }.id(`journey-lock-${this.item.id}`)
    } else {
      Row({ space: 12 }) {
        this.progressRing()
        Stack() {
          Image($r('app.media.icon_arrow_right')).width(16).height(16).fillColor($r('app.color.accent_text'))
        }.width(32).height(32).borderRadius(STARWARD_RADIUS_ROUND).backgroundColor($r('app.color.accent_soft'))
      }
    }
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.kind === 'active' && this.active && this.inView && !this.reducedMotion &&
          this.cardWidth > 0 && this.cardHeight > 0) {
          JourneyCardGlow({ cardWidth: this.cardWidth, cardHeight: this.cardHeight }).position({ x: 0, y: 0 })
        }
        Row({ space: 14 }) {
          Column() {
            Text(this.item.title).width('100%').fontSize(19).lineHeight('25.65fp')
              .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong')).wordBreak(WordBreak.BREAK_WORD)
            if (this.kind === 'waiting' || this.kind === 'expired' || this.kind === 'cancelled') {
              Text(assignmentState(this.item, this.rank, this.now)).id(`assignment-state-${this.item.id}`)
                .width('100%').fontSize(12).lineHeight('16fp').fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent_text')).margin({ top: 5 })
            }
            this.schedule()
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          this.trailing()
        }.width('100%').padding({ top: 20, bottom: 20, left: 18, right: 18 })
          .accessibilityLevel('no-hide-descendants')
      }.width('100%')
        .onAreaChange((_previous: Area, current: Area) => {
          this.cardWidth = Number(current.width);
          this.cardHeight = Number(current.height);
        })
    }.id(`assignment-${this.item.id}`).width('100%').padding(0)
      .border({ width: 1, radius: STARWARD_RADIUS_PANEL,
        color: this.kind === 'active' ? $r('app.color.accent_border') : $r('app.color.border') })
      .linearGradient({ angle: 180, colors: [
        [this.kind === 'active' ? $r('app.color.glass_card_active_top') : $r('app.color.glass_card_top'), 0],
        [this.kind === 'active' ? $r('app.color.glass_card_active_bottom') : $r('app.color.glass_card_bottom'), 1]
      ] }).backgroundColor(Color.Transparent)
      .opacity(this.entrancePending ? 0 : this.kind === 'locked' ? 0.72 : 1).clip(true)
      .translate({ y: this.entrancePending ? 18 : 0 })
      .scale({ x: this.entrancePending ? 0.97 : 1, y: this.entrancePending ? 0.97 : 1 })
      .shadow({ radius: this.kind === 'locked' ? 0 : 12, offsetY: 6,
        color: this.kind === 'active' ? $r('app.color.glow_accent_soft') : $r('app.color.shadow') })
      .accessibilityText(this.accessibilityLabel()).accessibilityDescription('查看场次详情')
      .onAppear(() => this.enter())
      .onVisibleAreaChange([0], (_expanding: boolean, ratio: number) => { this.inView = ratio > 0; })
      .onClick(() => this.open(this.item.id))
  }
}

@ComponentV2
export struct StarwardJourneyLoading {
  @Param animated: boolean = false;
  @Local private pulsing: boolean = false;

  @Monitor('animated')
  private updatePulse(): void {
    this.getUIContext().animateTo({
      duration: this.animated ? 1000 : 0,
      iterations: this.animated ? -1 : 1,
      playMode: PlayMode.Alternate,
      curve: curves.cubicBezierCurve(0.2, 0, 0, 1)
    }, () => UIUtils.applySync(() => { this.pulsing = this.animated; }));
  }

  build() {
    Column({ space: 16 }) {
      ForEach([0, 1], () => {
        Row({ space: 16 }) {
          Column().width(70).height(110)
            .backgroundColor($r('app.color.accent_soft')).borderRadius(STARWARD_RADIUS_CONTROL)
          Column({ space: 16 }) {
            Row().height(46).width('100%')
              .backgroundColor($r('app.color.accent_soft')).borderRadius(STARWARD_RADIUS_CONTROL)
            Row().height(46).width('65%')
              .backgroundColor($r('app.color.accent_soft')).borderRadius(STARWARD_RADIUS_CONTROL)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ minHeight: 160 }).padding(24)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
          .accessibilityLevel('no-hide-descendants')
      }, (index: number) => index.toString())
    }.id('journey-loading').width('100%').accessibilityText('正在展开你的旅程…')
      .opacity(this.animated ? (this.pulsing ? 0.85 : 0.4) : 1)
      .onAppear(() => this.updatePulse())
  }
}
