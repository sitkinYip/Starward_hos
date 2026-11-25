import { uiMaterial } from '@kit.ArkUI';

const BLUR_RADIUS: number = 9;

@ObservedV2
export class StarwardModalBackdropState {
  @Trace visible: boolean = false;
  private readonly owners: Set<Object> = new Set<Object>();

  show(owner: Object): void {
    this.owners.add(owner);
    this.visible = true;
  }

  hide(owner: Object): void {
    this.owners.delete(owner);
    this.visible = this.owners.size > 0;
  }
}

/** Shades and blurs the live page across the system and cutout safe areas. */
@ComponentV2
export struct StarwardGlassBackdrop {
  @Param nodeId: string = '';
  @Param dismissible: boolean = false;
  @Event dismiss: () => void = () => {};
  private blurRadius: number = 0;

  aboutToAppear(): void {
    try {
      this.blurRadius = uiMaterial.getMaterialInfo().state === uiMaterial.MaterialState.DISABLE ? 0 : BLUR_RADIUS;
    } catch {
      this.blurRadius = 0;
    }
  }

  build() {
    Column() {}.id(this.nodeId).width('100%').height('100%')
      .backdropBlur(this.blurRadius, undefined, { disableSystemAdaptation: false })
      .backgroundColor($r('app.color.modal_mask'))
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT],
        [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
      .hitTestBehavior(this.dismissible ? HitTestMode.Default : HitTestMode.None)
      .accessibilityLevel('no')
      .onClick(() => { if (this.dismissible) { this.dismiss(); } })
  }
}
