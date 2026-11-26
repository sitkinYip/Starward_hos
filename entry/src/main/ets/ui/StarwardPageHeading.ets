import { STARWARD_RADIUS_ROUND } from './StarwardRadii';

@ComponentV2
export struct StarwardPageHeading {
  @Require @Param title: string;
  @Param nodeId: string = '';
  @Param unreadCount: number | undefined = undefined;
  @Param clearingUnread: boolean = false;
  @Event clearUnread: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.title).id(this.nodeId).fontSize(30).lineHeight('37.5fp')
        .fontWeight(FontWeight.Bold).fontColor($r('app.color.strong'))
        .lineBreakStrategy(LineBreakStrategy.BALANCED).layoutWeight(1)
      if ((this.unreadCount ?? 0) > 0) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 5 }) {
            Image($r('app.media.icon_check_circle')).width(14).height(14)
              .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
            Text(this.clearingUnread ? '正在清空…' : '清空未读').fontSize(12)
              .fontWeight(FontWeight.Medium).fontColor($r('app.color.accent_text'))
          }.constraintSize({ minHeight: 30 }).padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.accent_faint'))
            .border({ width: 1, radius: STARWARD_RADIUS_ROUND, color: $r('app.color.accent_border') })
        }.id(this.nodeId + '-clear-unread').constraintSize({ minHeight: 44 }).padding(0)
          .backgroundColor(Color.Transparent).enabled(!this.clearingUnread)
          .accessibilityText(this.clearingUnread ? '正在清空未读' : '清空未读')
          .accessibilityDescription(`当前 ${this.unreadCount ?? 0} 条未读`).onClick(() => this.clearUnread())
      }
    }.width('100%').constraintSize({ minHeight: this.unreadCount === undefined ? 0 : 44 })
  }
}
