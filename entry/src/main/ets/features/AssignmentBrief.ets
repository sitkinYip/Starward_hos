import { LengthMetrics } from '@kit.ArkUI';
import { assignmentKind, assignmentState } from '../business/assignmentState';
import { AssignmentDetail } from '../business/models';
import { DetailFact } from '../ui/DetailFact';
import { ErrorNotice } from '../ui/ErrorMessages';
import { GameplaySurface } from './GameplayChrome';

/** Read-only presentation of the authorized detail and the entry actions it offers. */
@ComponentV2
export struct AssignmentBrief {
  @Require @Param detail: AssignmentDetail;
  @Require @Param rank: number;
  @Require @Param now: number;
  @Require @Param rankLabel: string;
  @Require @Param opensAt: string;
  @Param closesAt: string = '';
  @Param viewportWidth: number = 0;
  @Param entryAvailable: boolean = false;
  @Param starting: boolean = false;
  @Param retryEntry: boolean = false;
  @Param error: string = '';
  @Event start: () => void = () => {};
  @Event returnHome: () => void = () => {};

  @Computed
  get kind(): string {
    return assignmentKind(this.detail, this.rank, this.now);
  }

  @Computed
  get titleSize(): number {
    return Math.max(28, Math.min(38, this.viewportWidth * 0.036));
  }

  private stateHint(): string {
    const state: string = assignmentState(this.detail, this.rank, this.now);
    if (this.kind === 'expired') { return `${state}，请联系游戏管理员。`; }
    if (this.kind === 'locked') { return `${state}，请确认场次的参与等级。`; }
    return `${state}，旅程开放后就能出发。`;
  }

  @Builder
  private facts() {
    Column({ space: 12 }) {
      DetailFact({ label: '谜题', value: `${this.detail.totalLevels} 道等待解开`,
        source: $r('app.media.icon_puzzle') })
      DetailFact({ label: '参与等级', value: this.rankLabel, source: $r('app.media.icon_map') })
      DetailFact({ label: '开放时间', value: this.opensAt, source: $r('app.media.icon_clock') })
      if (this.closesAt.length > 0) {
        DetailFact({ label: '旅程截止', value: this.closesAt })
      }
    }.id('briefing-facts').width('100%').margin({ top: 20, bottom: 20 })
  }

  @Builder
  private actions() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(12), cross: LengthMetrics.vp(12) } }) {
      Button({ type: ButtonType.Capsule }) {
        Row({ space: 12 }) {
          Text(this.starting ? '正在进入…' : this.retryEntry ? '重试入场' : '开始本场冒险')
            .fontSize(16).fontWeight(600).letterSpacing(0.6).fontColor($r('app.color.on_accent'))
          Image($r('app.media.icon_arrow_right')).width(18).height(18)
            .fillColor($r('app.color.on_accent')).accessibilityLevel('no')
        }
      }.id('start-assignment').constraintSize({ minHeight: 44 }).padding({ left: 20, right: 20 })
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[$r('app.color.accent_strong'), 0], [$r('app.color.accent'), 1]] })
        .shadow({ radius: 14, offsetY: 5, color: $r('app.color.glow_accent_faint') })
        .enabled(this.entryAvailable && this.kind === 'ready')
        .opacity(this.kind === 'ready' ? 1 : 0.45)
        .onClick(() => this.start())
      if (this.kind === 'expired') {
        Button({ type: ButtonType.Capsule }) {
          Row({ space: 8 }) {
            Image($r('app.media.icon_house')).width(16).height(16)
              .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
            Text('回到首页').fontSize(14).fontWeight(600).fontColor($r('app.color.accent_text'))
          }
        }.id('expired-return-home').constraintSize({ minHeight: 44 }).padding({ left: 18, right: 18 })
          .backgroundColor($r('app.color.accent_faint'))
          .accessibilityText('回到首页，当前场次已过开放时间').onClick(() => this.returnHome())
      }
    }.width('100%')
  }

  @Builder
  private cancelled() {
    Column({ space: 14 }) {
      Text('本次场次已撤回').id('briefing-cancelled').fontSize(21).fontWeight(600)
        .fontColor($r('app.color.strong'))
      Text('如需继续，请联系游戏管理员重新安排。').textAlign(TextAlign.Center)
        .fontSize(14).lineHeight('24.5fp').fontColor($r('app.color.muted'))
      Button('回到首页', { type: ButtonType.Capsule }).id('briefing-cancelled-home')
        .constraintSize({ minHeight: 44 }).padding({ left: 18, right: 18 })
        .fontSize(14).fontWeight(600).fontColor($r('app.color.accent_text'))
        .backgroundColor($r('app.color.accent_faint')).onClick(() => this.returnHome())
    }.width('100%').constraintSize({ minHeight: 240 }).justifyContent(FlexAlign.Center).padding(24)
  }

  @Builder
  private content() {
    Column() {
      Text('一段新的旅程').fontSize(12).fontWeight(600)
        .fontColor($r('app.color.accent_text')).letterSpacing(0.8).lineHeight('14.4fp')
      Text(this.detail.title).id('briefing-title')
        .fontSize(this.titleSize).lineHeight(`${this.titleSize * 1.3}fp`)
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.strong'))
        .lineBreakStrategy(LineBreakStrategy.BALANCED).margin({ bottom: 12 })
      Text(this.detail.description || '循着线索，去发现故事另一面的答案。').id('briefing-description')
        .fontSize(15).lineHeight('26.25fp').fontColor($r('app.color.muted'))
      this.facts()
      if (this.kind !== 'ready') {
        Text(this.stateHint()).id('detail-state-hint').fontSize(13).lineHeight('23.4fp')
          .fontColor($r('app.color.muted')).margin({ bottom: 12 })
      }
      ErrorNotice({ message: this.error, retryable: this.retryEntry && !this.starting, retry: () => this.start() })
      this.actions()
      Text('解谜进度会自动保存，随时可以回来继续。')
        .fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted')).margin({ top: 12, bottom: 13 })
    }.width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: this.viewportWidth > 760 ? 32 : 20, right: this.viewportWidth > 760 ? 32 : 20,
        top: this.viewportWidth > 760 ? 32 : 24, bottom: this.viewportWidth > 760 ? 32 : 24 })
  }

  build() {
    Column() {
      GameplaySurface({ lightweight: true, radius: 24 }) {
        if (this.detail.status === 'cancelled') {
          this.cancelled()
        } else {
          this.content()
        }
      }
    }.id('assignment-brief-card').width('100%')
  }
}
