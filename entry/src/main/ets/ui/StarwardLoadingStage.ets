import { curves, UIUtils } from '@kit.ArkUI';
import { StarwardStarRingEmblem } from './StarwardStarRingEmblem';

interface LoadingStar {
  left: string;
  top: string;
  delay: number;
}

const LOADING_STARS: LoadingStar[] = [
  { left: '14%', top: '22%', delay: 0 },
  { left: '82%', top: '16%', delay: -1800 },
  { left: '74%', top: '76%', delay: -3400 },
  { left: '10%', top: '66%', delay: -2200 },
  { left: '90%', top: '44%', delay: -4100 },
  { left: '28%', top: '88%', delay: -800 }
];

@ComponentV2
struct StarwardLoadingLight {
  @Require @Param diameter: number;
  @Require @Param color: ResourceColor;
  @Require @Param duration: number;
  @Param delay: number = 0;
  @Local private bright: boolean = false;

  build() {
    Circle().width(this.diameter).height(this.diameter).fill(this.color)
      .opacity(this.bright ? 0.9 : 0.25)
      .scale({ x: this.bright ? 1.2 : 0.8, y: this.bright ? 1.2 : 0.8 })
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: this.duration, delay: this.delay,
          curve: curves.cubicBezierCurve(0.2, 0, 0, 1), iterations: -1, playMode: PlayMode.Alternate }, () => {
          try { UIUtils.applySync(() => { this.bright = true; }); } catch { /* Keep the loading light visible. */ }
        });
      }).accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
  }
}

/** The route supplies real loading text and owns its error, retry, and return states. */
@ComponentV2
export struct StarwardLoadingStage {
  @Require @Param stateId: string;
  @Require @Param title: string;
  @Require @Param status: string;
  @Require @Param hint: string;
  @Param motionEnabled: boolean = false;
  @Param fullScreen: boolean = true;
  @Param showBrand: boolean = true;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Local private widthVp: number = 390;
  @Local private heightVp: number = 640;

  private compact(): boolean { return this.fullScreen && this.heightVp <= 540; }

  private titleSize(): number {
    return this.compact() ? Math.max(19, Math.min(24, this.heightVp * 0.045)) :
      Math.max(22, Math.min(34, this.widthVp * 0.03));
  }

  private emblemDiameter(): number {
    if (!this.fullScreen) { return Math.min(144, this.widthVp * 0.62); }
    if (this.compact()) { return Math.min(this.widthVp * 0.36, this.heightVp * 0.25); }
    return Math.min(this.widthVp * 0.62, Math.max(156, Math.min(260, this.heightVp * 0.30)));
  }

  @Builder
  private brand() {
    Row({ space: 10 }) {
      Image($r('app.media.starward_mark')).width(28).height(28).objectFit(ImageFit.Contain)
        .accessibilityLevel('no')
      Text('赴星之约').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.strong'))
    }.constraintSize({ minHeight: 40 }).padding({ left: 8, right: 14, top: 5, bottom: 5 })
      .linearGradient({ direction: GradientDirection.Bottom,
        colors: [[$r('app.color.glass_card_top'), 0], [$r('app.color.glass_card_bottom'), 1]] })
      .border({ width: 1, radius: 999, color: $r('app.color.border_strong') })
  }

  @Builder
  private light(diameter: number, color: ResourceColor, duration: number, delay: number, dim: number) {
    if (this.motionEnabled) {
      StarwardLoadingLight({ diameter: diameter, color: color, duration: duration, delay: delay })
    } else {
      Circle().width(diameter).height(diameter).fill(color).opacity(dim)
        .accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private backdrop() {
    Stack() {
      Column().width('100%').height('100%')
        .radialGradient({ center: ['50%', '40%'], radius: '58%',
          colors: [[$r('app.color.canvas_ambient'), 0], [Color.Transparent, 0.68]] })
      Stack() {
        ForEach(LOADING_STARS, (star: LoadingStar) => {
          Stack() {
            this.light(3, $r('app.color.star_dot'), 4800, star.delay, 0.45)
          }.position({ x: star.left, y: star.top })
        }, (star: LoadingStar) => star.left)
      }.width('84%').height('80%')
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  private stage() {
    Column({ space: this.compact() ? 8 : 16 }) {
      StarwardStarRingEmblem({ diameter: this.emblemDiameter(), motionEnabled: this.motionEnabled })
      Text(this.title).fontSize(this.titleSize()).lineHeight(`${this.titleSize() * 1.38}fp`).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
      Row({ space: 9 }) {
        this.light(7, $r('app.color.accent'), 1800, 0, 1)
        Text(this.status).fontSize(this.compact() ? 12 : 13).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent_text')).textAlign(TextAlign.Center)
      }.padding({ top: 7, bottom: 7, left: 16, right: 16 })
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [[$r('app.color.glass_card_top'), 0], [$r('app.color.glass_card_bottom'), 1]] })
        .border({ width: 1, radius: 999, color: $r('app.color.border_strong') })
      if (!this.compact()) {
        Text(this.hint).fontSize(13).lineHeight('22.75fp').fontColor($r('app.color.muted'))
          .textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
      }
    }.width('100%').constraintSize({ maxWidth: 440 }).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private footer() {
    Row({ space: 12 }) {
      Divider().width(24).color($r('app.color.border_strong'))
      Text('向着星辰的冒险').fontSize(11).letterSpacing(1.54).fontColor($r('app.color.subtle'))
      Divider().width(24).color($r('app.color.border_strong'))
    }.width('100%').justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.fullScreen) {
        this.backdrop()
        Scroll() {
          Column({ space: this.compact() ? 12 : 20 }) {
            if (this.showBrand) {
              Row() { this.brand() }.width('100%')
            }
            Column() { this.stage() }
              .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
            this.footer()
          }.width('100%').constraintSize({ minHeight: this.heightVp })
            .padding({ left: 20, right: 20, top: Math.max(this.topInset, this.compact() ? 12 : 20),
              bottom: Math.max(this.bottomInset, this.compact() ? 12 : 20) })
        }.width('100%').height('100%').scrollBar(BarState.Off).align(Alignment.Top)
      } else {
        Column() { this.stage() }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 16 })
      }
    }.id(this.stateId).width('100%').height(this.fullScreen ? '100%' : 'auto')
      .backgroundColor(this.fullScreen ? $r('app.color.canvas') : Color.Transparent)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0 && this.widthVp !== width) { this.widthVp = width; }
        if (this.fullScreen && Number.isFinite(height) && height > 0 && this.heightVp !== height) {
          this.heightVp = height;
        }
      })
  }
}
