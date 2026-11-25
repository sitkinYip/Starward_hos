import { PromptAction } from '@kit.ArkUI';
import { PushOnboardingViewModel } from './PushOnboardingViewModel';

/** An optional native dialog; the host owns every eligibility and OS-permission decision. */
@ComponentV2
export struct StarwardPushOnboarding {
  @Require @Param model: PushOnboardingViewModel;
  @Param owner: string = '';
  @Param eligible: boolean = false;
  @Param permission: boolean | null = null;
  @Param widthVp: number = 360;
  @Param heightVp: number = 640;
  @Event notificationsConfirmed: () => void = () => {};
  private dialogId: number = -1;
  private serial: number = 0;
  private opening: boolean = false;

  aboutToAppear(): void {
    this.syncOwner();
    this.syncDialog();
  }

  aboutToDisappear(): void {
    this.model.bindOwner('');
    this.closeDialog();
  }

  @Monitor('owner', 'eligible')
  private syncOwner(): void {
    this.model.bindOwner(this.owner);
    this.model.setEligible(this.eligible);
  }

  @Monitor('model.notificationConsentRevision')
  private consentChanged(): void {
    if (this.model.notificationConsentRevision > 0) { this.notificationsConfirmed(); }
  }

  private isHidden(): boolean { return this.model.phase === 'hidden'; }

  @Monitor('model.phase')
  private syncDialog(): void {
    if (this.model.phase === 'hidden') { this.closeDialog(); } else { void this.openDialog(); }
  }

  private closeDialog(): void {
    this.serial++;
    this.opening = false;
    const id: number = this.dialogId;
    this.dialogId = -1;
    if (id >= 0) {
      try { this.getUIContext().getPromptAction().closeCustomDialog(id); } catch { /* Already closed. */ }
    }
  }

  @Builder
  private content() {
    Scroll() {
      Column({ space: 18 }) {
        SymbolGlyph($r('sys.symbol.bell')).fontSize('26vp').fontColor([$r('app.color.accent_text')])
          .accessibilityLevel('no')
        Text(this.model.phase === 'subscription' ? '订阅专属冒险动态？' : '接收专属冒险通知？')
          .id('push-onboarding-title').fontSize(20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.strong')).textAlign(TextAlign.Center).lineHeight('29fp')
        Text(this.model.phase === 'subscription' ?
          '一次订阅之后分配给你的新场次、个人剧情来信与关卡动态，可随时在设置中取消。' :
          '旅途订阅已保存。是否接收这些动态的系统通知？可随时在设置中关闭。')
          .fontSize(14).lineHeight('22fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
        Text(this.model.phase === 'subscription' ? '订阅后会再询问是否接收通知；不影响应用内收信。' :
          this.model.subscriptionApproved ? '应用内来信会照常保留。' :
            '选择会先保存，通知启用后生效。')
          .fontSize(12).lineHeight('19fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
        if (this.model.phase === 'notifications' && this.permission === false) {
          Text('系统通知尚未开启，可稍后前往设置中开启。').id('push-onboarding-system-disabled')
            .fontSize(12).lineHeight('19fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
        }
        if (this.model.error.length > 0) {
          Text(this.model.error).id('push-onboarding-error').fontSize(13).lineHeight('20fp')
            .fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
        }
        Column({ space: 8 }) {
          if (this.model.retryAvailable) {
            Button('重试确认', { type: ButtonType.Capsule }).id('push-onboarding-retry')
              .width('100%').constraintSize({ minHeight: 46 }).fontSize(16)
              .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
              .enabled(!this.model.busy).onClick(() => { void this.model.retry(); })
          } else {
            Button(this.model.busy ? '正在保存…' : this.model.phase === 'subscription' ? '订阅旅途动态' : '接收通知',
              { type: ButtonType.Capsule }).id('push-onboarding-accept')
              .width('100%').constraintSize({ minHeight: 46 }).fontSize(16)
              .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
              .enabled(!this.model.busy).onClick(() => {
                if (this.model.phase === 'subscription') { void this.model.acceptSubscription(); } else {
                  void this.model.confirmNotifications();
                }
              })
          }
          Button(this.model.phase === 'subscription' ? '以后再说' : '暂不接收', { type: ButtonType.Normal })
            .id('push-onboarding-decline').width('100%').constraintSize({ minHeight: 44 }).fontSize(14)
            .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
            .enabled(!this.model.busy).onClick(() => this.model.dismiss())
        }.width('100%')
      }.width('100%').padding(24)
    }.width('100%').constraintSize({ maxHeight: Math.max(200, Math.min(600, this.heightVp - 80)) })
      .scrollBar(BarState.Auto).backgroundColor($r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.border'), radius: 22 }).borderRadius(22)
  }

  private async openDialog(): Promise<void> {
    if (this.dialogId >= 0 || this.opening || this.model.phase === 'hidden') { return; }
    const serial: number = ++this.serial;
    this.opening = true;
    try {
      const action: PromptAction = this.getUIContext().getPromptAction();
      const id: number = await action.openCustomDialog({
        builder: () => { this.content(); }, alignment: DialogAlignment.Center,
        width: Math.min(400, Math.max(240, this.widthVp - 40)), cornerRadius: 22,
        backgroundColor: $r('app.color.raised'), maskColor: $r('app.color.modal_mask'),
        isModal: true, autoCancel: true, showInSubWindow: false,
        onWillDismiss: (event: DismissDialogAction) => {
          if (serial === this.serial) { this.model.dismiss(); }
          event.dismiss();
        },
        onDidDisappear: () => {
          if (serial === this.serial) { this.dialogId = -1; this.opening = false; }
        }
      });
      if (serial !== this.serial || this.isHidden()) { action.closeCustomDialog(id); } else {
        this.dialogId = id;
        this.opening = false;
      }
    } catch {
      if (serial === this.serial) { this.opening = false; this.model.dismiss(); }
    }
  }

  build() { Row() {}.width(0).height(0).accessibilityLevel('no-hide-descendants') }
}
