import { PromptAction, promptAction, uiMaterial, window } from '@kit.ArkUI';
import { AppLifecycle } from '../platform/AppLifecycle';
import { StarwardMaterial } from './StarwardMaterial';

/** One numeric-id native dialog request; no business state or account credentials. */
class SidePanelRequest {
  id: number = -1;
  opening: boolean = true;
  cancelled: boolean = false;
  closing: boolean = false;
  nativeDismissed: boolean = false;
  revision: number;
  ownerKey: string;
  action: PromptAction;

  constructor(revision: number, ownerKey: string, action: PromptAction) {
    this.revision = revision;
    this.ownerKey = ownerKey;
    this.action = action;
  }
}

/** API26 system dialog backplate + official edge transition, owned by this UI host. */
@ComponentV2
export struct StarwardSidePanel {
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Param visible: boolean = false;
  @Event $visible: (visible: boolean) => void = () => {};
  @Param ownerActive: boolean = false;
  @Param ownerKey: string = '';
  @Param anchorWindowX: number = -1;
  @Param reducedMotion: boolean = true;
  @Param title: ResourceStr = '冒险者菜单';
  @Event failed: () => void = () => {};
  @BuilderParam anchor: () => void;
  @BuilderParam content: () => void;
  @Local private renderOwner: string = '';
  @Local private contentAllowed: boolean = false;
  private mounted: boolean = false;
  private desiredOpen: boolean = false;
  private revision: number = 0;
  private request: SidePanelRequest | null = null;
  private readonly lifecycle: (foreground: boolean) => void = (foreground: boolean) => {
    if (!foreground) {
      this.contentAllowed = false;
      this.dismiss();
    }
  };

  aboutToAppear(): void {
    this.mounted = true;
    AppLifecycle.subscribe(this.lifecycle);
    this.desiredOpen = this.visible;
    this.synchronize();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.desiredOpen = false;
    this.contentAllowed = false;
    this.revision++;
    AppLifecycle.unsubscribe(this.lifecycle);
    this.cancelRequest();
  }

  @Monitor('visible')
  visibilityChanged(): void {
    this.revision++;
    this.desiredOpen = this.visible;
    if (!this.visible && this.request?.opening) {
      this.contentAllowed = false;
    }
    this.synchronize();
  }

  @Monitor('ownerActive', 'ownerKey')
  ownerChanged(): void {
    // An owner/gate transition invalidates even an unresolved native open.
    this.revision++;
    this.desiredOpen = false;
    this.contentAllowed = false;
    this.cancelRequest();
    if (this.mounted && this.visible) {
      this.$visible(false);
    }
  }

  private usableWidth(): number {
    const left: number = Math.max(0, this.avoidArea.statusBar.leftRect.width,
      this.avoidArea.cutout.leftRect.width, this.avoidArea.navigationIndicator.leftRect.width);
    const right: number = Math.max(0, this.avoidArea.statusBar.rightRect.width,
      this.avoidArea.cutout.rightRect.width, this.avoidArea.navigationIndicator.rightRect.width);
    // Keep extra space beyond the native16vp margins so Start/End do not
    // collapse to the same centered rectangle on a narrow phone.
    return Math.min(400, this.windowSize.width - left - right - 48);
  }

  private usableHeight(): number {
    const top: number = Math.max(0, this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height);
    const bottom: number = Math.max(0, this.avoidArea.statusBar.bottomRect.height,
      this.avoidArea.cutout.bottomRect.height, this.avoidArea.navigationIndicator.bottomRect.height);
    return Math.max(0, (this.windowSize.height - top - bottom) * 0.9);
  }

  private isCurrent(request: SidePanelRequest): boolean {
    return this.mounted && this.desiredOpen && this.ownerActive && !request.cancelled &&
      this.request === request && request.revision === this.revision && request.ownerKey === this.ownerKey;
  }

  private synchronize(): void {
    if (!this.mounted || !this.desiredOpen || !this.ownerActive || this.ownerKey.length === 0) {
      this.cancelRequest();
      return;
    }
    // At most one unresolved open. A cancelled one must first yield its id so
    // it can be closed; a rapid new tap cannot revive that stale presentation.
    if (this.request !== null) {
      return;
    }
    this.open();
  }

  private release(request: SidePanelRequest): void {
    if (this.request === request) {
      this.request = null;
      this.synchronize();
    }
  }

  private close(request: SidePanelRequest): void {
    request.cancelled = true;
    if (request.opening || request.nativeDismissed || request.closing || request.id < 0) {
      return;
    }
    request.closing = true;
    try {
      request.action.closeCustomDialog(request.id);
      // Native onDidDisappear can be omitted when navigation interrupts its
      // animation. Release bookkeeping after the close command, not onFinish.
      this.release(request);
    } catch (error) {
      request.closing = false;
      if (this.mounted && this.ownerActive && request.ownerKey === this.ownerKey) {
        this.failed();
      }
    }
  }

  private cancelRequest(): void {
    if (this.request !== null) {
      this.close(this.request);
    }
  }

  private dismiss(): void {
    this.desiredOpen = false;
    this.revision++;
    this.cancelRequest();
    if (this.mounted) {
      this.$visible(false);
    }
  }

  private nativeDismiss(request: SidePanelRequest, action: DismissDialogAction): void {
    request.cancelled = true;
    request.nativeDismissed = true;
    if (this.request === request) {
      this.desiredOpen = false;
      this.revision++;
      if (this.mounted) {
        this.$visible(false);
      }
    }
    action.dismiss();
    this.release(request);
  }

  private disappeared(request: SidePanelRequest): void {
    request.nativeDismissed = true;
    if (this.request === request) {
      this.desiredOpen = false;
      if (this.mounted) {
        this.$visible(false);
      }
      this.release(request);
    }
  }

  private createRequest(): SidePanelRequest | null {
    try {
      return new SidePanelRequest(this.revision, this.ownerKey, this.getUIContext().getPromptAction());
    } catch (error) {
      this.dismiss();
      this.failed();
      return null;
    }
  }

  private async open(): Promise<void> {
    const width: number = this.usableWidth();
    const height: number = this.usableHeight();
    if (!Number.isFinite(width) || width < 160 || !Number.isFinite(height) || height < 132 ||
      !Number.isFinite(this.anchorWindowX) || this.anchorWindowX < 0 || this.anchorWindowX > this.windowSize.width) {
      this.dismiss();
      this.failed();
      return;
    }
    const right: boolean = this.anchorWindowX >= this.windowSize.width / 2;
    const request: SidePanelRequest | null = this.createRequest();
    if (request === null) {
      return;
    }
    this.request = request;
    this.renderOwner = request.ownerKey;
    this.contentAllowed = true;
    const reduced: boolean = this.reducedMotion;
    const edge: TransitionEdge = right ? TransitionEdge.END : TransitionEdge.START;
    const movement: TransitionEffect = reduced ? TransitionEffect.IDENTITY : TransitionEffect.move(edge);
    const options: promptAction.CustomDialogOptions = {
      builder: () => { this.panelBody(); },
      alignment: right ? DialogAlignment.CenterEnd : DialogAlignment.CenterStart,
      width: width,
      height: height,
      showInSubWindow: false,
      isModal: true,
      autoCancel: true,
      systemMaterial: StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK, reduced ? false : undefined),
      dialogTransition: movement.animation({ duration: reduced ? 0 : 220, curve: Curve.EaseOut }),
      maskTransition: TransitionEffect.OPACITY.animation({ duration: reduced ? 0 : 120 }),
      onWillDismiss: (action: DismissDialogAction) => this.nativeDismiss(request, action),
      onDidDisappear: () => this.disappeared(request)
    };
    try {
      // The options/builder overload retains the native backplate. The
      // ComponentContent overload is customStyle=true and disables this material.
      request.id = await request.action.openCustomDialog(options);
      request.opening = false;
      if (request.nativeDismissed) {
        this.release(request);
      } else if (!this.isCurrent(request)) {
        this.close(request);
      }
    } catch (error) {
      request.opening = false;
      if (this.request === request) {
        const notify: boolean = this.isCurrent(request);
        if (notify) {
          this.request = null;
          this.contentAllowed = false;
          this.dismiss();
          this.failed();
        } else {
          // Rejection of an old open is inert after logout/host teardown and
          // must not discard a newer tap that is waiting for its completion.
          this.release(request);
        }
      }
    }
  }

  @Builder
  private panelBody() {
    Column() {
      if (this.contentAllowed && this.ownerActive && this.renderOwner === this.ownerKey) {
        Row({ space: 12 }) {
          Text(this.title).id('account-panel-title').fontSize(20).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.strong')).layoutWeight(1)
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.icon_close')).width(22).height(22).fillColor($r('app.color.text'))
          }.id('account-close').width(44).height(44).backgroundColor(Color.Transparent)
            .accessibilityText('关闭冒险者菜单').onClick(() => this.dismiss())
        }.width('100%').height(64).padding({ left: 24, right: 12 })
        Column() {
          this.content()
        }.width('100%').layoutWeight(1)
      }
    }.id('account-side-panel').width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      this.anchor()
    }.width('100%').height('100%')
  }
}
