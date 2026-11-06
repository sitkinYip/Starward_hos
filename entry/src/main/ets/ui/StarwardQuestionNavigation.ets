import { Binding, curves, UIUtils } from '@kit.ArkUI';

const QUESTION_WIDTH = 94;
const QUESTION_HEIGHT = 63;
const QUESTION_GAP = 6;

export interface QuestionNavigationItem {
  id: string;
  completed: boolean;
  enabled: boolean;
  locked: boolean;
}

/** The session owns selection. This native strip only presents and reveals it. */
@ComponentV2
export struct StarwardQuestionNavigation {
  @Require @Param items: QuestionNavigationItem[];
  @Param activeIndex: number = 0;
  @Param reducedMotion: boolean = true;
  @Event select: (index: number) => void = () => {};
  @Env(WritableEnvKey.FONT_SCALE) fontScale: number;
  private readonly scroller: Scroller = new Scroller();
  private viewportWidth: number = 0;

  @Monitor('activeIndex')
  activeQuestionChanged(): void {
    this.revealActive(!this.reducedMotion);
  }

  private trackWidth(): number {
    return this.items.length * QUESTION_WIDTH + Math.max(0, this.items.length - 1) * QUESTION_GAP;
  }

  private revealActive(animated: boolean): void {
    if (this.viewportWidth <= 0 || this.activeIndex < 0 || this.activeIndex >= this.items.length) {
      return;
    }
    const center: number = this.activeIndex * (QUESTION_WIDTH + QUESTION_GAP) + QUESTION_WIDTH / 2;
    const maxOffset: number = Math.max(0, this.trackWidth() - this.viewportWidth);
    const offset: number = Math.min(maxOffset, Math.max(0, center - this.viewportWidth / 2));
    this.scroller.scrollTo({ xOffset: offset, yOffset: 0, animation: animated });
  }

  private buttonHeight(): number {
    // Keep both lines in the native font scale. The default layout is 63vp.
    return QUESTION_HEIGHT + 34 * Math.max(0, (this.fontScale || 1) - 1);
  }

  private canSelect(index: number): boolean {
    return this.items[index]?.enabled === true && this.items[index]?.locked === false;
  }

  private status(index: number): string {
    return this.items[index]?.completed ? '已完成' : `第 ${index + 1} 题`;
  }

  private accessibilityLabel(index: number): string {
    return `第 ${index + 1} 题${index === this.activeIndex ? '，当前题目' : ''}${
      this.items[index]?.completed ? '，已完成' : ''}${this.items[index]?.locked ? '，未解锁' : ''}`;
  }

  @Builder
  question(position: Binding<number>) {
    Button({ type: ButtonType.Normal }) {
      Stack({ alignContent: Alignment.Bottom }) {
        if (position.value === this.activeIndex) {
          Column() {}.width('100%').height('100%')
            .radialGradient({ center: ['50%', '110%'], radius: 54,
              colors: [[$r('app.color.accent'), 0], [Color.Transparent, 1]] })
            .opacity(0.28).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
          Column() {}.width(64).height(1)
            .linearGradient({ direction: GradientDirection.Right,
              colors: [[Color.Transparent, 0], [$r('app.color.accent'), 0.5], [Color.Transparent, 1]] })
            .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
        Column({ space: 5 }) {
          Text((position.value + 1).toString().padStart(2, '0')).fontFamily('monospace').fontSize(18).lineHeight('18fp')
            .maxLines(1).fontColor(position.value === this.activeIndex ? $r('app.color.strong') : $r('app.color.muted'))
          Text(this.status(position.value)).fontSize(11).lineHeight('16fp')
            .maxLines(1).fontColor(position.value === this.activeIndex ? $r('app.color.strong') : $r('app.color.muted'))
        }.width('100%').height('100%').padding({ top: 11, left: 12, right: 12, bottom: 11 })
          .alignItems(HorizontalAlign.Start)
      }.width('100%').height('100%')
    }.id(`gameplay-level-${position.value}`).width(QUESTION_WIDTH).height(this.buttonHeight()).padding(0).borderRadius(0)
      .backgroundColor(position.value === this.activeIndex ? $r('app.color.surface') : Color.Transparent)
      .border({ width: 1, radius: 0,
        color: position.value === this.activeIndex ? $r('app.color.accent') : $r('app.color.border') })
      .translate({ y: position.value === this.activeIndex ? -2 : 0 })
      .animation({ duration: this.reducedMotion ? 0 : 420, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) })
      .enabled(this.canSelect(position.value))
      .accessibilityText(this.accessibilityLabel(position.value)).accessibilitySelected(position.value === this.activeIndex)
      .onClick(() => {
        const index: number = position.value;
        if (this.canSelect(index)) { this.select(index); }
      })
  }

  build() {
    Scroll(this.scroller) {
      Row({ space: QUESTION_GAP }) {
        // Reused cells read the current position even if a snapshot changes the order.
        ForEach(this.items, (item: QuestionNavigationItem) => {
          this.question(UIUtils.makeBinding<number>(() =>
            this.items.findIndex((candidate: QuestionNavigationItem) => candidate.id === item.id)))
        }, (item: QuestionNavigationItem) => item.id)
      }.width(this.trackWidth()).padding({ top: 2, bottom: 2 })
        .onAreaChange((previous: Area, current: Area) => {
          if (previous.width !== current.width) { this.revealActive(false); }
        })
    }.id('gameplay-level-navigation').width('100%').align(Alignment.TopStart)
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      .accessibilityText('题目导航')
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 0 && width !== this.viewportWidth) {
          this.viewportWidth = width;
          this.revealActive(false);
        }
      })
  }
}
