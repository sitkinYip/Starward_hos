import { PromptAction } from '@kit.ArkUI';
import { PushSubscriptionItem } from '../business/PushSubscription';
import { PushSubscriptionsViewModel } from '../features/PushSubscriptionsViewModel';

/** A native scene-specific consent surface; OS permission never implies a subscription. */
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

  @Monitor('model.confirmationId')
  private confirmationChanged(): void {
    if (this.model.confirmationId.length === 0 || !this.active) { this.closeDialog(); return; }
    void this.openConfirmation(this.model.confirmationId);
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
  private confirmation(id: string, title: string) {
    Column({ space: 18 }) {
      SymbolGlyph($r('sys.symbol.bell')).fontSize('26vp').fontColor([$r('app.color.accent_text')])
        .accessibilityLevel('no')
      Text(`接收「${title}」通知？`).id('push-subscription-confirm-title')
        .fontSize(20).fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
        .textAlign(TextAlign.Center).lineHeight('29fp')
      Text('在有新的剧情来信或关卡动态时提醒你。你可以随时在设置中取消订阅。')
        .fontSize(14).lineHeight('22fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
      Column({ space: 8 }) {
        Button('接收通知', { type: ButtonType.Capsule }).id('push-subscription-confirm')
          .width('100%').constraintSize({ minHeight: 46 }).fontSize(16)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .onClick(() => { void this.model.confirmNotifications(id); })
        Button('暂不接收', { type: ButtonType.Normal }).id('push-subscription-decline')
          .width('100%').constraintSize({ minHeight: 44 }).fontSize(14)
          .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
          .onClick(() => this.model.dismissConfirmation())
      }.width('100%')
    }.width('100%').padding(24).backgroundColor($r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.border'), radius: 22 }).borderRadius(22)
  }

  private async openConfirmation(id: string): Promise<void> {
    if (this.dialogId >= 0 || this.opening) { return; }
    const row: PushSubscriptionItem | null = this.model.item(id);
    if (row === null || !row.subscribed || row.pushEnabled) { return; }
    const serial: number = ++this.dialogSerial;
    this.opening = true;
    try {
      const action: PromptAction = this.getUIContext().getPromptAction();
      const nativeId: number = await action.openCustomDialog({
        builder: () => { this.confirmation(id, row.title); },
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
      if (serial !== this.dialogSerial || !this.active || this.model.confirmationId !== id) {
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
  private row(id: string) {
    Row({ space: 10 }) {
      Column({ space: 5 }) {
        Text(this.model.item(id)?.title ?? '').fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text')).lineHeight('23fp')
        Text(!this.model.item(id)?.available ? '场次暂不可用 · 可取消订阅' :
          this.model.item(id)?.pushEnabled ? '已订阅 · 接收来信与关卡通知' :
          this.model.item(id)?.subscribed ? '已订阅 · 暂不接收通知' : '剧情来信与关卡动态')
          .fontSize(12).lineHeight('18fp').fontColor($r('app.color.muted'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 0 }) {
        if (!this.model.item(id)?.subscribed) {
          Button('订阅', { type: ButtonType.Normal })
            .id('push-subscribe-' + id)
            .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .constraintSize({ minHeight: 44, minWidth: 62 }).borderRadius(10)
            .enabled(this.model.pendingId.length === 0 && !this.model.busy &&
              !this.model.needsSync && this.model.error.length === 0)
            .onClick(() => { void this.model.subscribe(id); })
        } else {
          if (this.model.item(id)?.available && !this.model.item(id)?.pushEnabled) {
            Button('接收通知', { type: ButtonType.Normal })
              .id('push-enable-' + id)
              .fontSize(12).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
              .constraintSize({ minHeight: 44 }).padding({ left: 8, right: 8 })
              .enabled(this.model.pendingId.length === 0 && !this.model.busy &&
                !this.model.needsSync && this.model.error.length === 0)
              .onClick(() => this.model.requestNotifications(id))
          }
          Button('取消订阅', { type: ButtonType.Normal })
            .id('push-unsubscribe-' + id)
            .fontSize(12).fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
            .constraintSize({ minHeight: 44 }).padding({ left: 8, right: 8 })
            .enabled(this.model.pendingId.length === 0 && !this.model.busy &&
              !this.model.needsSync && this.model.error.length === 0)
            .onClick(() => { void this.model.unsubscribe(id); })
        }
      }
    }.width('100%').padding(14)
  }

  build() {
    Column({ space: 10 }) {
      Text('场次订阅').fontSize(13).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted'))
        .margin({ left: 2 })
      Text('订阅具体场次的剧情来信与关卡动态，可随时取消。')
        .fontSize(13).lineHeight('20fp').fontColor($r('app.color.muted')).margin({ left: 2, right: 2 })
      Column() {
        if (this.model.loaded) {
          ForEach(this.model.items, (item: PushSubscriptionItem, index: number) => {
            if (index > 0) { Divider().color($r('app.color.border')).margin({ left: 14, right: 14 }) }
            this.row(item.assignmentId)
          }, (item: PushSubscriptionItem) => item.assignmentId)
          if (this.model.items.length === 0) {
            Text('有新的场次后，可以在这里订阅。').fontSize(13).lineHeight('20fp')
              .fontColor($r('app.color.muted')).padding(14)
          }
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
            if (!this.model.saving && this.model.pendingId.length > 0) {
              Button('重试确认', { type: ButtonType.Normal }).id('push-subscription-retry')
                .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
                .constraintSize({ minHeight: 44 }).onClick(() => { void this.model.retry(); })
            }
          }.width('100%').alignItems(HorizontalAlign.Start).padding(14)
        }
      }.width('100%').backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border'), radius: 14 })
      if (this.permission === false && this.model.items.some((item: PushSubscriptionItem) => item.pushEnabled)) {
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
