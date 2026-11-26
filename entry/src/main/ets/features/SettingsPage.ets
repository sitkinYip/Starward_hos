import { PushStatus } from '../business/PushRegistration';
import { InstalledAppVersion, readInstalledAppVersion } from '../platform/InstalledAppVersion';
import { InlineError } from '../ui/ErrorMessages';
import {
  STARWARD_RADIUS_BADGE, STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_PANEL, STARWARD_RADIUS_ROUND
} from '../ui/StarwardRadii';
import { PushSubscriptionsViewModel } from './PushSubscriptionsViewModel';
import { StarwardPushSubscriptions } from './StarwardPushSubscriptions';

/** Settings content uses the system notification options and the shared appearance controls. */
@ComponentV2
export struct SettingsPage {
  @Param bottomInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param answerHapticsEnabled: boolean = true;
  @Param answerHapticsError: string = '';
  @Param themeError: string = '';
  @Param pushVisible: boolean = false;
  @Param pushAvailable: boolean = false;
  @Param pushBusy: boolean = false;
  @Param pushPermission: boolean | null = null;
  @Param pushStatus: PushStatus = 'unknown';
  @Param pushSettingsError: string = '';
  @Require @Param subscriptions: PushSubscriptionsViewModel;
  @Param active: boolean = false;
  @BuilderParam appearanceControls: () => void;
  @Event openNotificationSettings: () => void = () => {};
  @Event retryNotificationSync: () => void = () => {};
  @Event answerHapticsChanged: (enabled: boolean) => void = () => {};
  @Event openSystemHapticsSettings: () => void = () => {};
  @Local private version: InstalledAppVersion | null = null;

  aboutToAppear(): void {
    this.version = readInstalledAppVersion();
  }

  private notificationState(): string {
    if (this.pushBusy) { return '检查中'; }
    if (this.pushPermission === null) { return '未确认'; }
    return this.pushPermission ? '已开启' : '未开启';
  }

  @Builder
  private rowIcon(icon: Resource) {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(icon).fontSize('19vp').fontColor([$r('app.color.accent_text')])
        .accessibilityLevel('no')
    }.width(36).height(36).borderRadius(STARWARD_RADIUS_BADGE).backgroundColor($r('app.color.accent_faint'))
  }

  @Builder
  private answerFeedback() {
    Column({ space: 10 }) {
      Text('答题').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted'))
        .margin({ left: 2 })
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('答题振动').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
          Text('答对或答错时振动，遵循系统触感反馈设置').fontSize(13)
            .lineHeight('20fp').fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.answerHapticsEnabled })
          .id('settings-answer-haptics').selectedColor($r('app.color.accent'))
          .accessibilityText('答题振动').onChange((enabled: boolean) => this.answerHapticsChanged(enabled))
      }.width('100%').constraintSize({ minHeight: 64 }).padding(14)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
      Button('系统触感设置', { type: ButtonType.Capsule }).id('settings-system-haptics')
        .constraintSize({ minHeight: 44 }).padding({ left: 12, right: 12 })
        .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
        .onClick(() => this.openSystemHapticsSettings())
      InlineError({ message: this.answerHapticsError, fieldId: 'settings-answer-haptics-error' })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private notifications() {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          this.rowIcon($r('sys.symbol.bell'))
          Column({ space: 4 }) {
            Text('旅途通知').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
            Text('接收新场次、来信和公告提醒').fontSize(13)
              .lineHeight('20fp').fontColor($r('app.color.muted'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column({ space: 4 }) {
            Text(this.notificationState()).id('settings-push-status')
              .fontSize(12).fontColor(this.pushPermission === true && !this.pushBusy ?
                $r('app.color.accent_text') : $r('app.color.muted'))
          }
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize('13vp').fontColor([$r('app.color.subtle')])
            .accessibilityLevel('no')
        }.width('100%').padding({ left: 14, right: 14, top: 13, bottom: 13 })
      }.id('settings-push-system').width('100%').padding(0)
        .constraintSize({ minHeight: 64 }).backgroundColor(Color.Transparent).borderRadius(STARWARD_RADIUS_CONTROL)
        .enabled(this.pushAvailable && !this.pushBusy)
        .accessibilityText(`旅途通知，${this.notificationState()}，系统通知设置`)
        .onClick(() => this.openNotificationSettings())
      if (this.pushSettingsError.length > 0 || this.pushStatus === 'retry' || this.pushStatus === 'unavailable') {
        Divider().color($r('app.color.border')).margin({ left: 14, right: 14 })
        Column({ space: 4 }) {
          if (this.pushSettingsError.length === 0 && this.pushStatus === 'unavailable') {
            Text('通知服务暂未就绪，应用内来信仍可查看。').id('settings-push-unavailable')
              .fontSize(13).lineHeight('20fp').fontColor($r('app.color.muted'))
          } else {
            InlineError({ message: this.pushSettingsError.length > 0 ? this.pushSettingsError :
              '暂时无法同步通知，应用内来信仍可查看。', fieldId: 'settings-push-error' })
          }
          if (this.pushStatus === 'retry' || this.pushStatus === 'unavailable') {
            Button(this.pushStatus === 'unavailable' ? '重新检查' : '重新同步', { type: ButtonType.Normal })
              .id(this.pushStatus === 'unavailable' ? 'settings-push-check' : 'settings-push-retry')
              .constraintSize({ minHeight: 44 }).borderRadius(STARWARD_RADIUS_ROUND).padding({ left: 12, right: 12 })
              .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
              .enabled(this.pushAvailable && !this.pushBusy).onClick(() => this.retryNotificationSync())
          }
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 14, right: 14, bottom: 12 })
      }
    }.width('100%').backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
  }

  build() {
    Scroll() {
      Column({ space: 26 }) {
        Column({ space: 10 }) {
          Text('外观').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted'))
            .margin({ left: 2 })
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            Text('旅途光线').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text'))
              .margin({ right: 12, top: 4, bottom: 4 })
            this.appearanceControls()
          }.width('100%').padding(14).backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
          InlineError({ message: this.themeError, fieldId: 'settings-theme-error' })
        }.width('100%').alignItems(HorizontalAlign.Start)
        this.answerFeedback()
        if (this.pushVisible) {
          Column({ space: 10 }) {
            Text('通知').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted'))
              .margin({ left: 2 })
            this.notifications()
            StarwardPushSubscriptions({ model: this.subscriptions, active: this.active,
              permission: this.pushPermission, openSystemSettings: () => this.openNotificationSettings() })
          }.width('100%').alignItems(HorizontalAlign.Start)
        }
        if (this.version !== null) {
          Text(`版本 ${this.version.name}（${this.version.code}）`).id('settings-version')
            .width('100%').textAlign(TextAlign.Center).fontSize(13).fontFeature("'tnum' 1")
            .fontColor($r('app.color.muted'))
        }
      }.width('100%').constraintSize({ maxWidth: 480 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 20 + this.leftInset, right: 20 + this.rightInset, top: 20, bottom: 24 + this.bottomInset })
    }.id('settings-page').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto)
  }
}
