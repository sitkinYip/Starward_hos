import { PromptAction } from '@kit.ArkUI';
import { PushSubscriptionsViewModel } from '../features/PushSubscriptionsViewModel';

/** One personal journey scope with independent native notification consent. */
@ComponentV2
export struct StarwardPushSubscriptions {
  @Require @Param model: PushSubscriptionsViewModel;
  @Param active: boolean = false;
  @Param permission: boolean | null = null;
  @Event openSystemSettings: () => void = () => {};
  @Local private panelWidth: number = 320;
  private dialogId: number = -1;
  private dialogSerial: number = 0;
  private opening: boolean = false;

  aboutToAppear(): void { this.model.setActive(this.active); }

  aboutToDisappear(): void {
    this.model.setActive(false);
    this.closeDialog();
  }

  @Monitor('active')
  private activeChanged(): void {
    this.model.setActive(this.active);
    if (!this.active) { this.closeDialog(); }
  }

  @Monitor('model.confirmationRequested')
  private confirmationChanged(): void {
    if (!this.model.confirmationRequested || !this.active) { this.closeDialog(); return; }
    void this.openConfirmation();
  }

  private closeDialog(): void {
    this.dialogSerial++;
    this.opening = false;
    const id: number = this.dialogId;
    this.dialogId = -1;
    if (id >= 0) {
      try { this.getUIContext().getPromptAction().closeCustomDialog(id); } catch { /* Already gone. */ }
    }
  }

  @Builder
  private confirmation() {
    Column({ space: 18 }) {
      SymbolGlyph($r('sys.symbol.bell')).fontSize('26vp').fontColor([$r('app.color.accent_text')])
        .accessibilityLevel('no')
      Text('接收专属冒险通知？').id('push-subscription-confirm-title')
        .fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
        .textAlign(TextAlign.Center).lineHeight('29fp')
      Text(this.model.subscription?.subscriptionApproved ?
        '之后分配给你的新场次、剧情来信与关卡动态都可以提醒你。无需逐场开启，可随时在设置中取消订阅。' :
        '通知服务启用后，提醒你之后分配给你的新场次、剧情来信与关卡动态。无需逐场开启，可随时在设置中取消订阅。')
        .fontSize(14).lineHeight('22fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
      Column({ space: 8 }) {
        Button('接收通知', { type: ButtonType.Capsule }).id('push-subscription-confirm')
          .width('100%').constraintSize({ minHeight: 46 }).fontSize(16)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .enabled(!this.model.saving && !this.model.busy && !this.model.pending &&
            !this.model.needsSync && this.model.error.length === 0)
          .onClick(() => { void this.model.confirmNotifications(); })
        Button('暂不接收', { type: ButtonType.Normal }).id('push-subscription-decline')
          .width('100%').constraintSize({ minHeight: 44 }).fontSize(14)
          .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
          .onClick(() => this.model.dismissConfirmation())
      }.width('100%')
    }.width('100%').padding(24).backgroundColor($r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.border'), radius: 22 }).borderRadius(22)
  }

  private async openConfirmation(): Promise<void> {
    if (this.dialogId >= 0 || this.opening) { return; }
    if (!this.model.subscription?.subscribed || this.model.subscription.pushEnabled) { return; }
    const serial: number = ++this.dialogSerial;
    this.opening = true;
    try {
      const action: PromptAction = this.getUIContext().getPromptAction();
      const nativeId: number = await action.openCustomDialog({
        builder: () => { this.confirmation(); },
        alignment: DialogAlignment.Center, width: Math.min(400, this.panelWidth), cornerRadius: 22,
        backgroundColor: $r('app.color.raised'), maskColor: $r('app.color.clue_mask'),
        isModal: true, autoCancel: true, showInSubWindow: false,
        onWillDismiss: (event: DismissDialogAction) => {
          if (serial === this.dialogSerial) { this.model.dismissConfirmation(); }
          event.dismiss();
        },
        onDidDisappear: () => {
          if (serial === this.dialogSerial) {
            this.dialogId = -1;
            this.opening = false;
          }
        }
      });
      if (serial !== this.dialogSerial || !this.active || !this.model.confirmationRequested) {
        action.closeCustomDialog(nativeId);
      } else {
        this.dialogId = nativeId;
        this.opening = false;
      }
    } catch {
      if (serial === this.dialogSerial) {
        this.opening = false;
        this.model.dismissConfirmation();
      }
    }
  }

  @Builder
  private row() {
    Row({ space: 10 }) {
      Column({ space: 5 }) {
        Text('我的专属冒险动态').fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text')).lineHeight('23fp')
        Text(this.model.subscription?.pushEnabled ? this.model.subscription.subscriptionApproved ?
          '已订阅 · 接收冒险动态通知' : '订阅已保存 · 通知能力待启用' :
          this.model.subscription?.subscribed ? '已订阅 · 暂不接收通知' : '尚未订阅')
          .fontSize(12).lineHeight('18fp').fontColor($r('app.color.muted'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 0 }) {
        if (!this.model.subscription?.subscribed) {
          Button('订阅', { type: ButtonType.Normal })
            .id('push-journey-subscribe')
            .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .constraintSize({ minHeight: 44, minWidth: 62 }).borderRadius(10)
            .enabled(!this.model.pending && !this.model.busy && !this.model.saving &&
              !this.model.needsSync && this.model.error.length === 0)
            .onClick(() => { void this.model.subscribe(); })
        } else {
          if (!this.model.subscription?.pushEnabled) {
            Button('接收通知', { type: ButtonType.Normal })
              .id('push-journey-enable')
              .fontSize(12).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
              .constraintSize({ minHeight: 44 }).padding({ left: 8, right: 8 })
              .enabled(!this.model.pending && !this.model.busy && !this.model.saving &&
                !this.model.needsSync && this.model.error.length === 0)
              .onClick(() => this.model.requestNotifications())
          }
          Button('取消订阅', { type: ButtonType.Normal })
            .id('push-journey-unsubscribe')
            .fontSize(12).fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
            .constraintSize({ minHeight: 44 }).padding({ left: 8, right: 8 })
            .enabled(!this.model.pending && !this.model.busy && !this.model.saving &&
              !this.model.needsSync && this.model.error.length === 0)
            .onClick(() => { void this.model.unsubscribe(); })
        }
      }
    }.width('100%').padding(14)
  }

  build() {
    Column({ space: 10 }) {
      Text('旅途订阅').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted'))
        .margin({ left: 2 })
      Text('一次订阅之后分配给你的新场次、剧情来信与关卡动态，可随时取消。')
        .fontSize(13).lineHeight('20fp').fontColor($r('app.color.muted')).margin({ left: 2, right: 2 })
      Column() {
        if (this.model.loaded) {
          if (this.model.subscription !== null) { this.row() }
        } else if (this.model.busy) {
          Text('正在读取订阅…').fontSize(13).fontColor($r('app.color.muted')).padding(14)
        }
        if (this.model.error.length > 0) {
          Column({ space: 4 }) {
            Text(this.model.error).id('push-subscriptions-error').fontSize(13).lineHeight('20fp')
              .fontColor($r('app.color.muted'))
            Button('重新读取', { type: ButtonType.Normal }).id('push-subscriptions-retry')
              .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
              .constraintSize({ minHeight: 44 }).enabled(!this.model.busy)
              .onClick(() => { void this.model.refresh(); })
          }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
        }
        if (this.model.writeError.length > 0 || this.model.saving) {
          Column({ space: 4 }) {
            Text(this.model.saving ? '正在保存订阅…' : this.model.writeError).id('push-subscription-write-state')
              .fontSize(13).lineHeight('20fp').fontColor($r('app.color.muted'))
            if (!this.model.saving && this.model.pending) {
              Button('重试确认', { type: ButtonType.Normal }).id('push-subscription-retry')
                .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
                .constraintSize({ minHeight: 44 }).onClick(() => { void this.model.retry(); })
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
        }
      }.width('100%').backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border'), radius: 14 })
      if (this.permission === false && this.model.subscription?.pushEnabled) {
        Button('系统通知尚未开启，前往设置', { type: ButtonType.Normal }).id('push-subscriptions-system')
          .fontSize(12).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
          .constraintSize({ minHeight: 44 }).onClick(() => this.openSystemSettings())
      }
    }.id('push-subscriptions').width('100%').alignItems(HorizontalAlign.Start)
      .onAreaChange((_old: Area, area: Area) => {
        const width: number = Number(area.width);
        if (Number.isFinite(width) && width > 0) { this.panelWidth = width; }
      })
  }
}
