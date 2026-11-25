import { AvatarImage, Player } from '../business/models';
import { STARWARD_HEADER_CAPSULE_RADIUS, StarwardGlassHeader } from './StarwardGlassHeader';
import { StarwardTitleSurface } from './StarwardMaterial';
import { playerExperiencePercent } from './StarwardPassport';
import { StarwardPlayerAvatar } from './StarwardPlayerAvatar';

const TITLE_HEIGHT: number = 70;
const HORIZONTAL_GUTTER: number = 18;
const TITLE_REVEAL_DURATION: number = 240;

@ComponentV2
export struct StarwardLobbyHeader {
  @Require @Param player: Player;
  @Param avatar: AvatarImage | null = null;
  @Param selected: boolean = true;
  @Param viewportWidth: number = 386;
  @Param topInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param reducedMotion: boolean = true;
  @Event openPassport: () => void = () => {};
  @Event decodeFailed: (avatar: AvatarImage) => void = () => {};

  private levelLabel(): string {
    const name: string = this.player.level.name;
    return name.length > 0 ? `Lv.${this.player.level.order} · ${name}` : `Lv.${this.player.level.order}`;
  }

  @Builder
  private identityRing() {
    Stack() {
      Progress({ value: playerExperiencePercent(this.player), total: 100, type: ProgressType.Ring })
        .width(42).height(42).color($r('app.color.accent'))
        .backgroundColor($r('app.color.ring_track'))
        .style({ strokeWidth: 2.8, enableScanEffect: false, enableSmoothEffect: !this.reducedMotion })
      StarwardPlayerAvatar({ name: this.player.displayName, avatar: this.avatar, avatarSize: 32,
        decodeFailed: (avatar: AvatarImage) => this.decodeFailed(avatar) })
    }.width(42).height(42).accessibilityLevel('no-hide-descendants')
  }

  build() {
    Column() {
      if (this.selected) {
        Column() {
          StarwardTitleSurface({ titleHeight: TITLE_HEIGHT, horizontalGutter: HORIZONTAL_GUTTER,
            topInset: this.topInset, reducedMotion: this.reducedMotion,
            titleContent: () => { this.titleContent() } })
        }.width('100%').transition(this.reducedMotion ? TransitionEffect.IDENTITY :
          TransitionEffect.asymmetric(TransitionEffect.opacity(0)
            .animation({ duration: TITLE_REVEAL_DURATION, curve: Curve.EaseOut }), TransitionEffect.IDENTITY))
      }
    }.width('100%').height(TITLE_HEIGHT + this.topInset)
  }

  @Builder
  private titleContent() {
    StarwardGlassHeader({ insideTitleSurface: true, nodeId: 'lobby-identity-header',
      content: () => { this.identityControls() } }).padding({ left: this.leftInset, right: this.rightInset })
  }

  @Builder
  private identityControls() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 10 }) {
        this.identityRing()
        Column({ space: 2 }) {
          Text(this.player.displayName).fontSize(15).lineHeight('18fp').fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.strong')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.levelLabel()).fontSize(11).lineHeight('13fp').fontWeight(FontWeight.Medium)
            .fontFeature("'tnum' 1").fontColor($r('app.color.accent_text'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.alignItems(HorizontalAlign.Start).constraintSize({ maxWidth: Math.max(52,
          this.viewportWidth - 2 * HORIZONTAL_GUTTER - this.leftInset - this.rightInset - 148) })
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(13).fontColor([$r('app.color.subtle')])
          .accessibilityLevel('no')
      }.padding({ left: 6, right: 12, top: 5, bottom: 5 })
    }.id('lobby-identity').padding(0).constraintSize({ minHeight: 52 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, radius: STARWARD_HEADER_CAPSULE_RADIUS, color: $r('app.color.border_strong') })
      .accessibilityText(`打开护照，${this.player.displayName}，${this.levelLabel()}，经验 ${this.player.totalXp}`)
      .onClick(() => this.openPassport())
    Blank()
    Stack() {
      Image($r('app.media.starward_mark')).width(34).height(34).objectFit(ImageFit.Contain)
    }.id('lobby-brand-mark').width(44).height(44)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, radius: STARWARD_HEADER_CAPSULE_RADIUS, color: $r('app.color.border_strong') })
      .accessibilityText('赴星之约')
  }
}
