import { curves, UIUtils } from '@kit.ArkUI';
import { AvatarImage, ExtraDisplay, Player } from '../business/models';
import { StarwardPlayerAvatar } from './StarwardPlayerAvatar';
import { starwardCountUp } from './StarwardMotion';

export function playerExperiencePercent(player: Player): number {
  if (player.nextLevel === null) { return 100; }
  const range: number = player.nextLevel.minTotalXp - player.level.minTotalXp;
  return range <= 0 ? 100 : Math.max(0, Math.min(100, (player.totalXp - player.level.minTotalXp) / range * 100));
}

// Motion Prompt #007 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#007
@ComponentV2
struct PassportExperience {
  @Require @Param player: Player;
  @Param active: boolean = false;
  @Param reducedMotion: boolean = true;
  @Local private displayed: number = 0;
  @Local private landingScale: number = 1;
  private mounted: boolean = false;
  private generation: number = 0;
  private target: number = -1;

  aboutToAppear(): void {
    this.displayed = this.active && !this.reducedMotion ? 0 : this.player.totalXp;
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.generation++;
  }

  @Monitor('player', 'active', 'reducedMotion')
  private update(): void {
    if (!this.mounted) { return; }
    const total: number = this.player.totalXp;
    if (!this.active || this.reducedMotion || total <= 0) {
      this.generation++;
      this.target = this.active ? total : -1;
      this.displayed = total;
      this.landingScale = 1;
      return;
    }
    if (this.target === total) { return; }
    this.target = total;
    this.displayed = 0;
    this.landingScale = 1;
    const generation: number = ++this.generation;
    const context: UIContext = this.getUIContext();
    starwardCountUp(context, total, 720, () => this.mounted && this.generation === generation,
      (value: number, settled: boolean) => {
        this.displayed = value;
        if (!settled) { return; }
        const spring = curves.cubicBezierCurve(0.22, 0.9, 0.24, 1);
        context.keyframeAnimateTo({ iterations: 1 }, [
          { duration: 134, curve: spring, event: () => UIUtils.applySync(() => { this.landingScale = 1.07; }) },
          { duration: 152, curve: spring, event: () => UIUtils.applySync(() => { this.landingScale = 0.99; }) },
          { duration: 134, curve: spring, event: () => UIUtils.applySync(() => { this.landingScale = 1; }) }
        ]);
      });
  }

  private experienceText(): string {
    const next: string = this.player.nextLevel === null ? '' : ' / ' + this.player.nextLevel.minTotalXp.toLocaleString('en-US');
    return 'Lv.' + this.player.level.order + ' · ' + this.displayed.toLocaleString('en-US') + next + ' EXP';
  }

  private accessibilityLabel(): string {
    const next: string = this.player.nextLevel === null ? '已抵达当前最高等级' :
      '再收集 ' + Math.max(0, this.player.nextLevel.minTotalXp - this.player.totalXp) +
      ' 经验，成为「' + this.player.nextLevel.name + '」';
    return this.player.level.name + '，当前经验 ' + this.player.totalXp + '，' + next;
  }

  build() {
    Text(this.experienceText()).id('passport-experience').width('100%').textAlign(TextAlign.Center)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted')).fontFeature("'tnum' 1")
      .scale({ x: this.landingScale, y: this.landingScale }).accessibilityText(this.accessibilityLabel())
      .onAppear(() => { this.mounted = true; this.update(); })
  }
}

@ComponentV2
struct PassportStatistic {
  @Require @Param label: string;
  @Require @Param nodeId: string;
  @Param value: number | null = null;

  build() {
    Column({ space: 4 }) {
      Text(this.value === null ? '—' : this.value.toString()).id(this.nodeId).fontSize(22).lineHeight('26.4fp')
        .fontWeight(FontWeight.Bold).fontFeature("'tnum' 1").fontColor($r('app.color.strong'))
        .textAlign(TextAlign.Center)
      Text(this.label).fontSize(12).fontWeight(FontWeight.Medium).fontColor($r('app.color.muted'))
        .textAlign(TextAlign.Center)
    }.width('100%').accessibilityGroup(true)
  }
}

@ComponentV2
export struct StarwardPassport {
  @Require @Param player: Player;
  @Param avatar: AvatarImage | null = null;
  @Param active: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param solved: number | null = null;
  @Param sessions: number | null = null;
  @Param rewards: number | null = null;
  @Event decodeFailed: (avatar: AvatarImage) => void = () => {};

  build() {
    Column() {
      Stack() {
        Progress({ value: playerExperiencePercent(this.player), total: 100, type: ProgressType.Ring })
          .width(86).height(86).color($r('app.color.accent')).backgroundColor($r('app.color.ring_track'))
          .style({ strokeWidth: 4, shadow: true, enableScanEffect: false,
            enableSmoothEffect: this.active && !this.reducedMotion })
          .accessibilityText('等级经验进度')
        StarwardPlayerAvatar({ name: this.player.displayName, avatar: this.avatar, avatarSize: 64,
          decodeFailed: (avatar: AvatarImage) => this.decodeFailed(avatar) })
      }.id('passport-avatar-ring').width(86).height(86)
      Text(this.player.displayName).id('passport-name').width('100%').textAlign(TextAlign.Center)
        .fontSize(22).lineHeight('27.5fp').fontWeight(FontWeight.Bold).fontColor($r('app.color.strong'))
        .wordBreak(WordBreak.BREAK_WORD).margin({ top: 14, bottom: 6 })
      PassportExperience({ player: this.player, active: this.active, reducedMotion: this.reducedMotion })
      Row() {
        PassportStatistic({ label: '已解开', value: this.solved, nodeId: 'passport-stat-solved' }).layoutWeight(1)
        PassportStatistic({ label: '场次', value: this.sessions, nodeId: 'passport-stat-sessions' }).layoutWeight(1)
        PassportStatistic({ label: '收藏', value: this.rewards, nodeId: 'passport-stat-rewards' }).layoutWeight(1)
      }.width('100%').margin({ top: 22 }).padding({ left: 4, right: 4, top: 12 })
        .accessibilityDescription('探索统计')
      if (this.player.extraDisplay.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.player.extraDisplay, (item: ExtraDisplay) => {
            Column({ space: 4 }) {
              Text(item.label).fontSize(12).fontColor($r('app.color.muted'))
              Text(item.text).fontSize(13).lineHeight('22fp').fontColor($r('app.color.text'))
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (item: ExtraDisplay) => item.key)
        }.width('100%').margin({ top: 16 })
      }
    }.id('profile-passport').width('100%').alignItems(HorizontalAlign.Center)
      .padding({ top: 28, bottom: 22, left: 22, right: 22 })
      .linearGradient({ angle: 180, colors: [[$r('app.color.glass_card_top'), 0], [$r('app.color.glass_card_bottom'), 1]] })
      .border({ width: 1, color: $r('app.color.border_strong'), radius: 24 }).clip(true)
      .shadow({ radius: 14, offsetY: 6, color: $r('app.color.shadow') })
  }
}
