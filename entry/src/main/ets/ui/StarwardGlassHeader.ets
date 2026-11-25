import { uiMaterial } from '@kit.ArkUI';
import { StarwardMaterial } from './StarwardMaterial';

export const STARWARD_SESSION_TITLE_HEIGHT: number = 52;
export const STARWARD_HEADER_CAPSULE_RADIUS: number = 999;

/** A native header row can own its glass or sit inside an existing title surface. */
@ComponentV2
export struct StarwardGlassHeader {
  @Param insideTitleSurface: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param nodeId: string = '';
  @BuilderParam content: () => void;
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void { this.updateMaterial(); }

  @Monitor('insideTitleSurface', 'reducedMotion')
  private updateMaterial(): void {
    this.material = this.insideTitleSurface ? undefined : StarwardMaterial.create(uiMaterial.ImmersiveStyle.THIN,
      !this.reducedMotion, $r('app.color.accent'));
  }

  build() {
    if (this.insideTitleSurface) {
      Row({ space: 12 }) { this.content() }.id(this.nodeId).width('100%')
    } else {
      Column() {
        Row({ space: 8 }) { this.content() }.width('100%').height(STARWARD_SESSION_TITLE_HEIGHT)
          .padding({ left: 10, right: 10 })
      }.id(this.nodeId).width('100%')
        .backgroundColor(this.material ? Color.Transparent : $r('app.color.raised'))
        .systemMaterial(this.material)
        .border({ width: 1, radius: STARWARD_HEADER_CAPSULE_RADIUS, color: $r('app.color.border_strong') })
    }
  }
}

/** Briefing and active questions share the session title, including the symmetric trailing space. */
@ComponentV2
export struct StarwardSessionTitle {
  @Require @Param title: string;
  @Param backId: string = '';
  @Param titleId: string = '';
  @Param backLabel: string = '返回';
  @Param reducedMotion: boolean = true;
  @Event back: () => void = () => {};

  build() {
    StarwardGlassHeader({ reducedMotion: this.reducedMotion, content: () => { this.sessionControls() } })
  }

  @Builder
  private sessionControls() {
    Button({ type: ButtonType.Circle }) {
      Image($r('app.media.icon_arrow_left')).width(18).height(18)
        .fillColor($r('app.color.strong')).accessibilityLevel('no')
    }.id(this.backId).width(44).height(44).padding(0)
      .backgroundColor(Color.Transparent).accessibilityText(this.backLabel).onClick(() => this.back())
    Text(this.title).id(this.titleId).layoutWeight(1).maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
      .fontSize(17).fontWeight(600).lineHeight('22.1fp').letterSpacing('-0.17fp')
      .fontColor($r('app.color.strong'))
    Blank().width(44).height(44)
  }
}
