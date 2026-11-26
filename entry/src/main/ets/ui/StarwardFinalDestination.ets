import { LengthMetrics } from '@kit.ArkUI';
import { starwardPageReveal } from './StarwardMotion';
import { STARWARD_RADIUS_PANEL } from './StarwardRadii';

/** The nonmodal passage prompt uses the same inset and actions as the mobile Web. */
@ComponentV2
export struct StarwardFinalDestination {
  @Require @Param panelWidth: number;
  @Param displayFont: string = 'serif';
  @Param launching: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event later: () => void = () => {};
  @Event proceed: () => void = () => {};

  build() {
    Column({ space: 24 }) {
      Column({ space: 6 }) {
        Text('最终旅程入口已经开启').id('gameplay-final-destination-title').fontFamily(this.displayFont)
          .fontWeight(700).fontSize(18).lineHeight('26fp').fontColor($r('app.color.strong'))
      }.width('100%').alignItems(HorizontalAlign.Start)
      Flex({ justifyContent: FlexAlign.End, alignItems: ItemAlign.Center, wrap: FlexWrap.Wrap,
        space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(4) } }) {
        Button('稍后前往', { type: ButtonType.Capsule }).id('gameplay-final-destination-later')
          .constraintSize({ minHeight: 46 }).padding({ left: 20, right: 20, top: 7, bottom: 7 })
          .fontSize(16).fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
          .onClick(() => this.later())
        Button('继续旅程', { type: ButtonType.Capsule }).id('gameplay-final-destination-continue')
          .constraintSize({ minHeight: 46 }).padding({ left: 20, right: 20, top: 7, bottom: 7 })
          .fontSize(16).fontWeight(600).fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .enabled(!this.launching).onClick(() => this.proceed())
      }.width('100%')
    }.id('gameplay-final-destination').width(this.panelWidth).padding({ top: 18, bottom: 18, left: 20, right: 20 })
      .alignItems(HorizontalAlign.Start).backgroundColor($r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: STARWARD_RADIUS_PANEL })
      .shadow({ radius: 36, offsetY: 12, color: $r('app.color.choice_shadow') })
      .transition(starwardPageReveal(this.reducedMotion, 8))
  }
}
