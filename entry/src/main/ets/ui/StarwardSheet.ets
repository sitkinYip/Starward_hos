import { LengthMetrics } from '@kit.ArkUI';
import { StarwardMaterial } from './StarwardMaterial';
import { STARWARD_RADIUS_PANEL } from './StarwardRadii';

/** Native semi-modal surface shared by the app's bottom drawers. */
export class StarwardSheetStyle {
  private readonly blur: boolean = StarwardMaterial.backgroundBlurAllowed();

  apply(options: SheetOptions): SheetOptions {
    options.radius = LengthMetrics.vp(STARWARD_RADIUS_PANEL);
    options.showClose = false;
    options.dragBar = false;
    options.backgroundColor = this.blur ? Color.Transparent : $r('app.color.raised');
    // The THICK ImmersiveMaterial makes native bottom sheets opaque on the API 26 handset.
    options.blurStyle = this.blur ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE;
    return options;
  }
}

export const STARWARD_SHEET_HEADER_MIN_HEIGHT: number = 52;

@ComponentV2
export struct StarwardSheetHeader {
  @Require @Param title: ResourceStr;
  @Param titleId: string = '';
  @Param closeId: string = '';
  @Param closeLabel: string = '关闭';
  @Param dismissible: boolean = true;
  @Param compact: boolean = false;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Event close: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.title).id(this.titleId).layoutWeight(1).fontSize(this.compact ? 12 : 16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.compact ? $r('app.color.muted') : $r('app.color.strong'))
        .wordBreak(WordBreak.BREAK_WORD)
      if (this.dismissible) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.icon_close_bold')).width(15).height(15)
            .fillColor($r('app.color.muted')).accessibilityLevel('no')
        }.id(this.closeId).width(30).height(30).padding(0)
          .backgroundColor($r('app.color.input'))
          .border({ width: 1, radius: 15, color: $r('app.color.border') })
          .responseRegion({ x: -7, y: -7, width: 44, height: 44 })
          .accessibilityText(this.closeLabel).onClick(() => this.close())
      }
    }.width('100%').constraintSize({ minHeight: STARWARD_SHEET_HEADER_MIN_HEIGHT })
      .padding({ top: 12, right: 14 + this.rightInset, bottom: 10, left: 18 + this.leftInset })
      .borderWidth({ bottom: 1 }).borderColor($r('app.color.border'))
  }
}
