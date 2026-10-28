import { uiMaterial } from '@kit.ArkUI';
import { StarwardMaterial } from './StarwardMaterial';

/** Controlled V2 state around the system sheet. Keep its anchor mounted while open. */
@ComponentV2
export struct StarwardAccountSheet {
  @Param visible: boolean = false;
  @Event $visible: (visible: boolean) => void = () => {};
  @Param title: ResourceStr = '冒险者护照';
  @Param sheetHeight: SheetSize = SheetSize.LARGE;
  @BuilderParam anchor: () => void;
  @BuilderParam content: () => void;
  private material: uiMaterial.ImmersiveMaterial | undefined =
    StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK);

  @Builder
  private sheetBody() {
    this.content()
  }

  build() {
    Stack() {
      this.anchor()
    }.bindSheet(this.visible, this.sheetBody, {
      height: this.sheetHeight,
      dragBar: true,
      showClose: true,
      title: { title: this.title },
      systemMaterial: this.material,
      onDisappear: () => { this.$visible(false); }
    })
  }
}
