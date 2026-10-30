import { AvatarImage, ExtraDisplay, Player } from '../business/models';
import { StarwardPlayerAvatar } from './StarwardPlayerAvatar';
import { StarwardAtlas } from './StarwardAtlas';

/** Shared identity facts; the official Progress owns its platform presentation. */
@ComponentV2
export struct StarwardExperienceMeter {
  @Require @Param player: Player;
  @Param compact: boolean = false;

  private remaining(): number {
    return this.player.nextLevel === null ? 0 : Math.max(0, this.player.nextLevel.minTotalXp - this.player.totalXp);
  }

  private progress(): number {
    if (this.player.nextLevel === null) {
      return 100;
    }
    const range: number = this.player.nextLevel.minTotalXp - this.player.level.minTotalXp;
    return range <= 0 ? 100 : Math.max(0, Math.min(100,
      (this.player.totalXp - this.player.level.minTotalXp) / range * 100));
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(`${this.player.totalXp} EXP`).fontSize(12).fontColor($r('app.color.muted'))
        Blank()
        Text(this.compact ? (this.player.nextLevel === null ? '已满级' : `距下一级 ${this.remaining()} EXP`) :
          `RANK ${this.player.level.order.toString().padStart(2, '0')}`)
          .fontFamily(this.compact ? 'sans-serif' : 'monospace').fontSize(12).fontColor($r('app.color.muted'))
      }.width('100%')
      Progress({ value: this.progress(), total: 100, type: ProgressType.Linear })
        .width('100%').color($r('app.color.accent')).backgroundColor($r('app.color.border'))
        .accessibilityText('等级经验进度')
      if (!this.compact) {
        Text(this.player.nextLevel === null ? '已抵达当前最高等级，故事仍在继续。' :
          `再收集 ${this.remaining()} 经验，成为「${this.player.nextLevel.name}」`)
          .fontSize(12).lineHeight('20fp').fontColor($r('app.color.muted'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct StarwardPassport {
  @Require @Param player: Player;
  @Param avatar: AvatarImage | null = null;
  @Param displayFont: string = 'serif';
  @Param menu: boolean = false;
  @Event decodeFailed: (avatar: AvatarImage) => void = () => {};

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('冒险者护照').fontSize(12).fontColor($r('app.color.muted'))
        Blank()
        Image($r('app.media.icon_star_four')).width(18).height(18)
          .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
      }.width('100%')
      Row({ space: 16 }) {
        if (this.menu) {
          Stack() {
            StarwardAtlas({ atlasSize: 88 })
            StarwardPlayerAvatar({ name: this.player.displayName, avatar: this.avatar, avatarSize: 56,
              decodeFailed: (avatar: AvatarImage) => this.decodeFailed(avatar) })
          }.width(88).height(88)
        } else {
          StarwardPlayerAvatar({ name: this.player.displayName, avatar: this.avatar, avatarSize: 64,
            decodeFailed: (avatar: AvatarImage) => this.decodeFailed(avatar) })
        }
        Column({ space: 6 }) {
          Text(this.player.displayName).fontFamily(this.displayFont).fontSize(22)
            .fontColor($r('app.color.strong')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.player.level.name} · Lv.${this.player.level.order}`).fontSize(12)
            .fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      StarwardExperienceMeter({ player: this.player, compact: this.menu })
      if (!this.menu) {
        ForEach(this.player.extraDisplay, (item: ExtraDisplay) => {
          Column({ space: 4 }) {
            Text(item.label).fontSize(12).fontColor($r('app.color.muted'))
            Text(item.text).fontSize(13).lineHeight('22fp').fontColor($r('app.color.text'))
          }.width('100%').alignItems(HorizontalAlign.Start)
        }, (item: ExtraDisplay) => item.key)
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
