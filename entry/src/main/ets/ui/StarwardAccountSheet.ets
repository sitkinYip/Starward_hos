import { StarwardModalBackdropState } from './StarwardGlassBackdrop';
import { StarwardSheetHeader, StarwardSheetStyle } from './StarwardSheet';

/** Controlled V2 state around the system sheet. Keep its anchor mounted while open. */
@ComponentV2
export struct StarwardAccountSheet {
  @Consumer('starwardModalBackdrop') private modalBackdrop: StarwardModalBackdropState =
    new StarwardModalBackdropState();
  @Param visible: boolean = false;
  @Event $visible: (visible: boolean) => void = () => {};
  @Param title: ResourceStr = '冒险者护照';
  @Param closeId: string = '';
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param sheetHeight: SheetSize = SheetSize.LARGE;
  @Param preferType: SheetType | undefined = undefined;
  @BuilderParam anchor: () => void;
  @BuilderParam content: () => void;
  private readonly sheetStyle: StarwardSheetStyle = new StarwardSheetStyle();
  private readonly backdropOwner: Object = new Object();
  private active: boolean = false;

  aboutToAppear(): void { this.active = true; }

  aboutToDisappear(): void {
    this.active = false;
    this.modalBackdrop.hide(this.backdropOwner);
  }

  @Builder
  private sheetBody() {
    Column() {
      StarwardSheetHeader({ title: this.title, closeId: this.closeId, leftInset: this.leftInset,
        rightInset: this.rightInset, close: () => { this.$visible(false); } })
      Column() {
        this.content()
      }.width('100%').layoutWeight(this.sheetHeight === SheetSize.FIT_CONTENT ? 0 : 1)
    }.width('100%').height(this.sheetHeight === SheetSize.FIT_CONTENT ?
      LayoutPolicy.wrapContent : LayoutPolicy.matchParent)
  }

  build() {
    Stack() {
      this.anchor()
    }.bindSheet(this.visible, this.sheetBody, this.sheetStyle.apply({
      height: this.sheetHeight,
      preferType: this.preferType,
      maskColor: Color.Transparent,
      onWillAppear: () => {
        if (this.active && this.visible) { this.modalBackdrop.show(this.backdropOwner); }
      },
      onDisappear: () => {
        this.modalBackdrop.hide(this.backdropOwner);
        if (this.visible) { this.$visible(false); }
      }
    }))
  }
}
