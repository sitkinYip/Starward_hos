import { curves, uiMaterial, UIUtils } from '@kit.ArkUI';
import { clueTitle } from '../business/GameplayClues';
import { GameplayClue } from '../business/GameplayModels';
import { StarwardMaterial } from './StarwardMaterial';
import { starwardPageReveal } from './StarwardMotion';
import { STARWARD_RADIUS_BADGE, STARWARD_RADIUS_CONTROL } from './StarwardRadii';

export function narrativeAttentionLabel(kind: string): string {
  return kind === 'letter' ? '一封来信等待开启' : '一份祝福正在回响';
}

/** Shared attention lighting. Its overlay takes no space and receives no touch events. */
@ComponentV2
export struct StarwardNarrativeSignal {
  @Param running: boolean = false;
  @Param frameWidth: number = 0;
  @Param frameHeight: number = 0;
  @Local private lit: boolean = false;
  @Local private sweepProgress: number = -0.18;
  @Local private sweepLight: number = 0;
  private mounted: boolean = false;

  @Monitor('running')
  updateMotion(): void {
    if (!this.mounted) { return; }
    const enabled: boolean = this.running;
    const ui = this.getUIContext();
    const ease = curves.cubicBezierCurve(0.32, 0.72, 0, 1);
    ui.animateTo({ duration: enabled ? 1800 : 0, iterations: enabled ? -1 : 1,
      playMode: PlayMode.Alternate, curve: ease }, () => UIUtils.applySync(() => {
      this.lit = enabled;
    }));
    if (!enabled) {
      ui.animateTo({ duration: 0 }, () => UIUtils.applySync(() => this.setSweep(-0.18, 0)));
      return;
    }
    const sweep = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
    ui.keyframeAnimateTo({ iterations: -1 }, [
      { duration: 1428, curve: sweep, event: () => UIUtils.applySync(() => this.setSweep(-0.18, 0)) },
      { duration: 544, curve: sweep, event: () => UIUtils.applySync(() => this.setSweep(0.43, 0.74)) },
      { duration: 816, curve: sweep, event: () => UIUtils.applySync(() => this.setSweep(1.12, 0)) },
      { duration: 612, curve: sweep, event: () => UIUtils.applySync(() => this.setSweep(-0.18, 0)) }
    ]);
  }

  private setSweep(progress: number, light: number): void {
    this.sweepProgress = progress;
    this.sweepLight = light;
  }

  aboutToDisappear(): void { this.mounted = false; }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {}.width(Math.max(0, this.frameWidth - 12)).height(Math.max(0, this.frameHeight - 12))
        .position({ x: 6, y: 6 })
        .border({ width: 1, color: $r('app.color.accent_border'), radius: STARWARD_RADIUS_BADGE })
        .opacity(this.lit ? 1 : 0.34).scale({ x: this.lit ? 1.012 : 0.985, y: this.lit ? 1.012 : 0.985 })
      if (this.running) {
        Column() {}.width(this.frameWidth * 0.18).height(this.frameHeight)
          .linearGradient({ direction: GradientDirection.Right,
            colors: [[Color.Transparent, 0], [$r('app.color.accent_soft'), 0.5], [Color.Transparent, 1]] })
          .translate({ x: this.sweepProgress * this.frameWidth }).opacity(this.sweepLight)
      }
    }.width(this.frameWidth).height(this.frameHeight).position({ x: 0, y: 0 })
      .clip(true).hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no-hide-descendants')
      .onAppear(() => { this.mounted = true; this.updateMotion(); })
  }
}

@ComponentV2
export struct StarwardNarrativeAttention {
  @Require @Param clue: GameplayClue;
  @Param reducedMotion: boolean = true;
  @Param showArrow: boolean = false;
  @Event opened: (id: string) => void = () => {};
  @Local private stageWidth: number = 0;
  @Local private stageHeight: number = 0;
  @Local private emblemAngle: number = 0;
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;
  private mounted: boolean = false;

  @Monitor('reducedMotion')
  private animateEmblem(): void {
    this.material = StarwardMaterial.create(uiMaterial.ImmersiveStyle.THIN,
      !this.reducedMotion, $r('app.color.accent'));
    if (!this.mounted) { return; }
    this.getUIContext().animateTo({ duration: this.reducedMotion ? 0 : 8000,
      iterations: this.reducedMotion ? 1 : -1, curve: Curve.Linear }, () => UIUtils.applySync(() => {
      this.emblemAngle = this.reducedMotion ? 0 : 360;
    }));
  }

  aboutToDisappear(): void { this.mounted = false; }

  @Builder
  signal() {
    if (this.stageWidth > 0 && this.stageHeight > 0) {
      StarwardNarrativeSignal({ running: !this.reducedMotion,
        frameWidth: this.stageWidth, frameHeight: this.stageHeight })
    }
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Row({ space: 12 }) {
          Stack() {
            Circle().width(46).height(46).fill($r('app.color.accent'))
              .shadow({ radius: 20, color: $r('app.color.glow_accent_soft') })
            Circle().width(58).height(58).fill(Color.Transparent).stroke($r('app.color.accent'))
              .strokeWidth(1).strokeDashArray([3, 2]).rotate({ angle: this.emblemAngle })
            Image(this.clue.kind === 'letter' ? $r('app.media.icon_clue_letter') : $r('app.media.icon_clue_bless'))
              .width(23).height(23).fillColor($r('app.color.on_accent'))
          }.width(46).height(46).accessibilityLevel('no-hide-descendants')
          Column({ space: 2 }) {
            Text(narrativeAttentionLabel(this.clue.kind)).width('100%').fontSize(14).fontWeight(600)
              .fontColor($r('app.color.strong')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.clue.content.title || '重要内容已解锁').width('100%').fontSize(11)
              .fontColor($r('app.color.muted')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.showArrow) {
            Image($r('app.media.icon_arrow_up_right')).width(20).height(20)
              .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
          }
        }.width('100%').padding({ top: 12, bottom: 12, left: 11, right: 14 })
          .onAreaChange((_previous: Area, area: Area) => {
            this.stageWidth = Number(area.width);
            this.stageHeight = Number(area.height);
          })
        Stack({ alignContent: Alignment.TopStart }) {
          this.signal()
        }.width(0).height(0).clip(false).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
      }.width('100%')
    }.id('gameplay-narrative-attention').width('100%').padding(0)
      .border({ width: 1, color: $r('app.color.accent'), radius: STARWARD_RADIUS_CONTROL })
      .backgroundColor(this.material ? $r('app.color.glass_floating') : $r('app.color.raised'))
      .systemMaterial(this.material)
      .radialGradient({ center: ['0%', '50%'], radius: '50%',
        colors: [[$r('app.color.glow_accent_soft'), 0], [Color.Transparent, 1]] })
      .shadow({ radius: 24, color: $r('app.color.glow_accent_soft'), offsetY: 6 })
      .clip(true)
      .transition(starwardPageReveal(this.reducedMotion, 8))
      .accessibilityText(`${narrativeAttentionLabel(this.clue.kind)}：${clueTitle(this.clue)}`)
      .onAppear(() => { this.mounted = true; this.animateEmblem(); })
      .onClick(() => this.opened(this.clue.id))
  }
}
