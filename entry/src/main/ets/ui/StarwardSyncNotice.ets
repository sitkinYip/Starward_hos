import { curves } from '@kit.ArkUI';

const NOTICE_TIMEOUT_MS: number = 8000;
const SWIPE_DISTANCE: number = 50;

/** Non-modal sync feedback with an explicit close action and one display per outage. */
@ComponentV2
export struct StarwardSyncNotice {
  @Param reducedMotion: boolean = true;
  @Event dismiss: () => void = () => {};
  @Local private swipeY: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.timer = setTimeout(() => { this.dismiss(); }, NOTICE_TIMEOUT_MS);
  }

  aboutToDisappear(): void { clearTimeout(this.timer); }

  private noticeTransition(): TransitionEffect {
    if (this.reducedMotion) { return TransitionEffect.IDENTITY; }
    return TransitionEffect.asymmetric(
      TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: -18 }))
        .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
        .animation({ duration: 320, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }),
      TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: -10 }))
        .combine(TransitionEffect.scale({ x: 0.98, y: 0.98 }))
        .animation({ duration: 240, curve: curves.cubicBezierCurve(0.4, 0, 0.8, 0.4) }));
  }

  private resetSwipe(): void {
    this.getUIContext().animateTo({ duration: this.reducedMotion ? 0 : 320, curve: Curve.EaseOut }, () => {
      this.swipeY = 0;
    });
  }

  build() {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Text('同步暂时中断').id('gameplay-sync-notice-title').width('100%')
          .fontSize(16).lineHeight('24fp').fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
        Text('当前页面和输入仍保留，连接恢复后会自动同步。').id('gameplay-sync-notice-description')
          .width('100%').fontSize(13).lineHeight('19.5fp').fontColor($r('app.color.muted'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button({ type: ButtonType.Normal }) {
        Image($r('app.media.icon_close')).width(16).height(16).fillColor($r('app.color.subtle'))
          .accessibilityLevel('no')
      }.id('gameplay-sync-notice-dismiss').width(44).height(44).padding(0)
        .backgroundColor(Color.Transparent).borderRadius(0).focusOnTouch(false)
        .accessibilityText('关闭同步暂时中断').onClick(() => this.dismiss())
    }.id('gameplay-sync-notice').width('100%').constraintSize({ maxWidth: 420 })
      .alignItems(VerticalAlign.Center).padding({ left: 16, right: 8, top: 10, bottom: 10 })
      .backgroundColor($r('app.color.raised')).border({ width: 1, color: $r('app.color.accent_border') })
      .shadow({ radius: 26, color: $r('app.color.choice_shadow'), offsetY: 10 })
      .translate({ y: this.reducedMotion ? 0 : this.swipeY }).transition(this.noticeTransition())
      .gesture(PanGesture({ fingers: 1, direction: PanDirection.Up, distance: 8 })
        .onActionUpdate((event: GestureEvent) => { this.swipeY = Math.min(0, event.offsetY); })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetY <= -SWIPE_DISTANCE) { this.dismiss(); } else { this.resetSwipe(); }
        })
        .onActionCancel(() => this.resetSwipe()))
  }
}
