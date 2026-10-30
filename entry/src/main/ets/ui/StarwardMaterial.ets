import { uiMaterial } from '@kit.ArkUI';

/** API 26 ArkUI system material; no blur/shadow imitation or HDS enums. */
export class StarwardMaterial {
  static create(style: uiMaterial.ImmersiveStyle,
    interactionEnabled: boolean | undefined = undefined): uiMaterial.ImmersiveMaterial | undefined {
    try {
      if (!uiMaterial.isImmersiveMaterialSupported() ||
        uiMaterial.getMaterialInfo().state === uiMaterial.MaterialState.DISABLE) {
        return undefined;
      }
      const options: uiMaterial.ImmersiveOptions = { style: style };
      if (interactionEnabled !== undefined) {
        options.interactive = interactionEnabled;
        if (interactionEnabled) {
          options.lightEffect = {};
        } else {
          options.lightEffect = null;
        }
      }
      return new uiMaterial.ImmersiveMaterial(options);
    } catch {
      // Capability queries must not prevent the ordinary surface from rendering.
      return undefined;
    }
  }

  static titleOptions(): NavigationTitleOptions {
    return {
      barStyle: BarStyle.STANDARD,
      systemMaterial: StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THIN),
      scrollEffectOptions: { scrollEffectType: ScrollEffectType.COMMON_BLUR }
    };
  }
}

/** Custom title content keeps its geometry; native title options affect only native bar controls. */
@ComponentV2
export struct StarwardTitleSurface {
  @Param titleHeight: number = 84;
  @Param horizontalGutter: number = 20;
  @Param topInset: number = 0;
  @BuilderParam titleContent: () => void;
  private material: uiMaterial.ImmersiveMaterial | undefined =
    StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THIN);

  build() {
    Column() {
      Row() {
        this.titleContent()
      }.width('100%').height(this.titleHeight).padding({ left: this.horizontalGutter, right: this.horizontalGutter })
    }.width('100%').padding({ top: this.topInset }).backgroundColor(this.material ? Color.Transparent : $r('app.color.canvas'))
      .systemMaterial(this.material)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
