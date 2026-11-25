import { PromptAction } from '@kit.ArkUI';
import { StarwardModalBackdropState } from './StarwardGlassBackdrop';

export const STARWARD_GLASS_DIALOG_FADE: number = 180;

class GlassDialogRequest {
  readonly action: PromptAction;
  id: number = -1;

  constructor(action: PromptAction) {
    this.action = action;
  }
}

/** Presents native modal content over the window's shared immersive backdrop. */
@ComponentV2
export struct StarwardGlassDialog {
  @Consumer('starwardModalBackdrop') private backdrop: StarwardModalBackdropState = new StarwardModalBackdropState();
  @Param visible: boolean = false;
  @Param panelWidth: number = 400;
  @Param panelCornerRadius: number = 24;
  @Param dismissOnTapOutside: boolean = false;
  @Param reducedMotion: boolean = true;
  @BuilderParam content: () => void = this.emptyContent;
  @Event back: () => void = () => {};
  @Event failed: () => void = () => {};
  @Event dismissed: () => void = () => {};
  private mounted: boolean = false;
  private request: GlassDialogRequest | null = null;

  aboutToAppear(): void {
    this.mounted = true;
    this.syncVisibility();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.syncVisibility();
  }

  @Monitor('visible')
  private syncVisibility(): void {
    if (this.mounted && this.visible) {
      if (this.request === null) { void this.open(); }
    } else if (this.request !== null) {
      const request: GlassDialogRequest = this.request;
      this.request = null;
      this.backdrop.hide(request);
      this.close(request);
    }
  }

  private async open(): Promise<void> {
    let request: GlassDialogRequest;
    try {
      request = new GlassDialogRequest(this.getUIContext().getPromptAction());
    } catch {
      this.failed();
      return;
    }
    this.request = request;
    this.backdrop.show(request);
    const fade: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.OPACITY.animation({ duration: STARWARD_GLASS_DIALOG_FADE, curve: Curve.Ease });
    try {
      request.id = await request.action.openCustomDialog({
        builder: () => {
          if (this.mounted && this.visible && this.request === request) { this.dialogContent(); }
        },
        alignment: DialogAlignment.Center, width: this.panelWidth, cornerRadius: this.panelCornerRadius,
        showInSubWindow: false, isModal: true, autoCancel: this.dismissOnTapOutside,
        maskColor: Color.Transparent, backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.NONE,
        dialogTransition: fade,
        onWillDismiss: () => { if (this.request === request) { this.back(); } },
        onDidDisappear: () => {
          this.finish(request);
          if (this.mounted && !this.visible) { this.dismissed(); }
        }
      });
      if (this.request !== request) { this.close(request); }
    } catch {
      this.finish(request);
    }
  }

  private close(request: GlassDialogRequest): void {
    if (request.id < 0) { return; }
    try { request.action.closeCustomDialog(request.id); } catch { this.finish(request); }
  }

  private finish(request: GlassDialogRequest): void {
    if (this.request !== request) { return; }
    this.request = null;
    this.backdrop.hide(request);
    if (this.mounted && this.visible) { this.failed(); }
  }

  @Builder
  private emptyContent() {}

  @Builder
  private dialogContent() {
    this.content()
  }

  build() {
    Column() {}.width(0).height(0)
  }
}
