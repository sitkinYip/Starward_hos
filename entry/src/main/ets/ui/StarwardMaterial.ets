import { uiMaterial } from '@kit.ArkUI';

/** API 26 ArkUI system material; no blur/shadow imitation or HDS enums. */
export class StarwardMaterial {
  static backgroundBlurAllowed(): boolean {
    try {
      return uiMaterial.getMaterialInfo().state !== uiMaterial.MaterialState.DISABLE;
    } catch {
      return false;
    }
  }

  static immersiveAvailable(): boolean {
    try {
      return uiMaterial.isImmersiveMaterialSupported() && StarwardMaterial.backgroundBlurAllowed();
    } catch {
      return false;
    }
  }

  static create(style: uiMaterial.ImmersiveStyle,
    interactionEnabled: boolean | undefined = undefined,
    lightEffectColor: ResourceColor | undefined = undefined,
    applyShadow: boolean = true): uiMaterial.ImmersiveMaterial | undefined {
    try {
      if (!StarwardMaterial.immersiveAvailable()) {
        return undefined;
      }
      const options: uiMaterial.ImmersiveOptions = { style: style, applyShadow: applyShadow };
      if (interactionEnabled !== undefined) {
        options.interactive = interactionEnabled;
        if (interactionEnabled) {
          options.lightEffect = lightEffectColor === undefined ? {} : { color: lightEffectColor };
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

  static titleOptions(barStyle: BarStyle = BarStyle.STANDARD): NavigationTitleOptions {
    return {
      barStyle: barStyle,
      systemMaterial: StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THIN),
      scrollEffectOptions: { scrollEffectType: ScrollEffectType.COMMON_BLUR }
    };
  }

  /** Lets the title content own rounded materials over the full-width navigation host. */
  static overlayTitleOptions(): NavigationTitleOptions {
    return { barStyle: BarStyle.STACK, backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.NONE,
      systemMaterial: uiMaterial.Material.empty };
  }

  static titleCapsule(interactionEnabled: boolean): uiMaterial.ImmersiveMaterial | undefined {
    return StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK, interactionEnabled, $r('app.color.accent'), false);
  }
}

/** Custom title content keeps its geometry; native title options affect only native bar controls. */
@ComponentV2
export struct StarwardTitleSurface {
  @Param titleHeight: number = 84;
  @Param horizontalGutter: number = 20;
  @Param topInset: number = 0;
  @Param reducedMotion: boolean = true;
  @BuilderParam titleContent: () => void;
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void {
    this.updateMaterial();
  }

  @Monitor('reducedMotion')
  private updateMaterial(): void {
    this.material = StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THIN,
      !this.reducedMotion, $r('app.color.accent'));
  }

  build() {
    Column() {
      Row() {
        this.titleContent()
      }.width('100%').height(this.titleHeight).padding({ left: this.horizontalGutter, right: this.horizontalGutter })
    }.width('100%').padding({ top: this.topInset })
      .backgroundColor(this.material ? Color.Transparent : $r('app.color.raised'))
      .systemMaterial(this.material)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
