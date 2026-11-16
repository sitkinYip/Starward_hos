import { curves, UIUtils } from '@kit.ArkUI';
import { NarrativeBless, NarrativeBlessLine } from '../business/NarrativeModels';
import { BlessPlayback } from './BlessPlayback';
import { StarwardBlessSky } from './StarwardBlessSky';

const CREDIT_LINE_HEIGHT: number = 76.8;

@ComponentV2
export struct StarwardBlessExperience {
  @Require @Param scene: NarrativeBless;
  @Require @Param title: string;
  @Require @Param ownerKey: string;
  @Require @Param displayFont: string;
  @Param foreground: boolean = true;
  @Param reducedMotion: boolean = true;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Param returnLabel: string = '返回冒险';
  @Event returnToSource: () => void = () => {};
  @Local private playback: BlessPlayback = new BlessPlayback();
  @Local private stageWidth: number = 0;
  @Local private stageHeight: number = 0;
  @Local private launchWidth: number = 0;
  @Local private launchHeight: number = 0;
  @Local private launchPulse: boolean = false;
  @Local private musicPulse: boolean = false;
  private appeared: boolean = false;
  private launchingMotion: boolean = false;
  private playingMotion: boolean = false;

  aboutToAppear(): void { this.playback.setForeground(this.foreground); }

  aboutToDisappear(): void {
    this.appeared = false;
    this.playback.close();
  }

  @Monitor('foreground')
  private syncForeground(): void { this.playback.setForeground(this.foreground); }

  @Monitor('foreground', 'reducedMotion', 'playback.started', 'playback.musicState')
  private syncPulse(): void {
    if (!this.appeared) { return; }
    const launch: boolean = this.foreground && !this.reducedMotion && !this.playback.started;
    const music: boolean = this.foreground && !this.reducedMotion && this.playback.musicState === 'playing';
    if (launch !== this.launchingMotion) {
      this.launchingMotion = launch;
      this.getUIContext().animateTo({ duration: launch ? 1500 : 0, iterations: launch ? -1 : 1,
        curve: Curve.EaseInOut, playMode: PlayMode.Alternate }, () => UIUtils.applySync(() => {
        this.launchPulse = launch;
      }));
    }
    if (music !== this.playingMotion) {
      this.playingMotion = music;
      this.getUIContext().animateTo({ duration: music ? 1100 : 0, iterations: music ? -1 : 1,
        curve: Curve.EaseInOut, playMode: PlayMode.Alternate }, () => UIUtils.applySync(() => {
        this.musicPulse = music;
      }));
    }
  }

  private launchTitle(): string { return this.title || '点此 进入属于你的璀璨星空'; }

  private creditHeight(): number { return Math.max(0, this.stageHeight / 2 - Math.max(this.stageHeight * 0.04, this.bottomInset)); }

  private creditAnchor(): number {
    return Math.min(this.scene.closingLines.length * CREDIT_LINE_HEIGHT, this.creditHeight()) * 0.42;
  }

  @Builder
  backdrop() {
    Stack() {
      Column() {}.width('100%').height('100%').radialGradient({ center: ['50%', '116%'],
        radius: this.stageHeight * 0.78, colors: [['#0B1026', 0.1], ['#000005', 0.78], [Color.Black, 1]] })
      Column() {}.width('100%').height('100%').radialGradient({ center: ['80%', '20%'],
        radius: this.stageWidth * 0.72, colors: [['#46141E3C', 0], [Color.Transparent, 1]] })
      Column() {}.width('100%').height('100%').radialGradient({ center: ['20%', '80%'],
        radius: this.stageWidth * 0.72, colors: [['#4228143C', 0], [Color.Transparent, 1]] })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  launch() {
    Stack() {
      Column() {}.width('100%').height('100%').backgroundColor('#66000000').backdropBlur(3)
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Stack() {
        Column() {}.width(this.launchWidth).height(this.launchHeight)
          .border({ width: 1, color: '#51E0B0FF', radius: 40 })
          .scale({ x: this.launchPulse ? 1.24 : 1.02, y: this.launchPulse ? 1.4 : 1.04 })
          .opacity(this.launchPulse ? 0.08 : 0.42).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        Button({ type: ButtonType.Capsule, buttonStyle: ButtonStyleMode.NORMAL }) {
          Row({ space: 8 }) {
            Text('✦').fontSize(14).fontColor('#D1E0D7F2').opacity(this.launchPulse ? 1 : 0.48)
              .accessibilityLevel('no')
            Text(this.launchTitle()).fontFamily(this.displayFont).fontSize(15).fontWeight(600).letterSpacing(1.6)
              .fontColor('#F3E4FF').textAlign(TextAlign.Center).lineBreakStrategy(LineBreakStrategy.BALANCED)
              .constraintSize({ maxWidth: Math.max(80, Math.min(560, this.stageWidth * 0.88) - 90) })
            Text('✦').fontSize(14).fontColor('#D1E0D7F2').opacity(this.launchPulse ? 0.48 : 1)
              .accessibilityLevel('no')
          }.padding({ left: 20, right: 20, top: 13, bottom: 13 }).justifyContent(FlexAlign.Center)
        }.id('bless-launch').constraintSize({ minHeight: 48 }).padding(0)
          .backgroundColor('#B814141E').border({ width: 1, color: '#24FFFFFF', radius: 40 }).backdropBlur(20)
          .shadow({ radius: this.launchPulse ? 34 : 23, color: '#55DAB3FA', offsetX: 0, offsetY: 0 })
          .accessibilityText(this.launchTitle()).onClick(() => this.playback.start(this.scene, this.ownerKey))
          .onAreaChange((_old: Area, area: Area) => {
            this.launchWidth = Number(area.width);
            this.launchHeight = Number(area.height);
          })
      }
    }.width('100%').height('100%').transition(this.reducedMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.asymmetric(TransitionEffect.opacity(0).animation({ duration: 1000, curve: Curve.Ease }),
        TransitionEffect.IDENTITY))
  }

  @Builder
  creditTrack() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        ForEach(this.scene.closingLines, (line: NarrativeBlessLine, index: number) => {
          Text(line.text.replace(/\\n/g, '\n'))
            .width('100%').height(CREDIT_LINE_HEIGHT).padding({ left: 20, right: 20, top: 12, bottom: 12 })
            .fontFamily(this.displayFont).fontSize(index === this.playback.creditIndex ? 20 : 16)
            .fontWeight(index === this.playback.creditIndex ? 500 : 400)
            .fontColor(index === this.playback.creditIndex ? '#FFFFFF' : '#69FFFFFF').textAlign(TextAlign.Center)
            .textShadow({ radius: index === this.playback.creditIndex ? 15 : 0, color: '#66FFFFFF' })
            .animation({ duration: this.reducedMotion ? 0 : 800,
              curve: curves.cubicBezierCurve(0.22, 0.61, 0.36, 1) })
        }, (_line: NarrativeBlessLine, index: number): string => `${index}`)
      }.width('100%').height(this.scene.closingLines.length * CREDIT_LINE_HEIGHT)
        .position({ x: 0, y: 0 })
        .translate({ y: this.creditAnchor() - Math.max(0, this.playback.creditIndex) * CREDIT_LINE_HEIGHT })
        .animation({ duration: this.reducedMotion ? 0 : 800, curve: curves.cubicBezierCurve(0.22, 0.61, 0.36, 1) })
      Column() {}.width('100%').height('100%').linearGradient({ direction: GradientDirection.Bottom,
        colors: [[Color.Transparent, 0], [Color.Black, 0.15], [Color.Black, 0.85], [Color.Transparent, 1]] })
        .blendMode(BlendMode.DST_IN)
    }.width('100%').height('100%').clip(true).blendMode(BlendMode.SRC_OVER, BlendApplyType.OFFSCREEN)
      .opacity(this.playback.creditIndex < 0 ? 0.25 : 1)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  credits() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.creditTrack()
      if (this.playback.creditIndex < 0) {
        Button({ type: ButtonType.Normal, buttonStyle: ButtonStyleMode.NORMAL }) {
          Row({ space: 10 }) {
            Stack() {
              SymbolGlyph($r('sys.symbol.play_fill')).fontSize('12vp').fontColor([Color.White])
            }.width(44).height(44).border({ width: 1, color: '#4DFFFFFF', radius: 22 }).accessibilityLevel('no')
            Text('开始播放').fontSize(15).fontColor(Color.White)
          }
        }.id('bless-credits-start').width('100%').height('100%').padding(0)
          .backgroundColor(Color.Transparent)
          .accessibilityText('开始播放').onClick(() => this.playback.startCredits())
      } else {
        // Keep the readable line anchored for assistive technology while the clipped track moves.
        Text(this.scene.closingLines[this.playback.creditIndex].text.replace(/\\n/g, '\n'))
          .id('bless-credit-line').width('100%').height(CREDIT_LINE_HEIGHT)
          .position({ x: 0, y: this.creditAnchor() }).fontColor(Color.Transparent)
          .accessibilityLevel('yes').hitTestBehavior(HitTestMode.None)
      }
    }.id('bless-credits').width('100%').height(this.creditHeight()).clip(true)
      .position({ x: 0, y: this.stageHeight / 2 })
      .transition(this.reducedMotion ? TransitionEffect.IDENTITY : TransitionEffect.opacity(0)
        .combine(TransitionEffect.translate({ y: 48 })).animation({ duration: 2000,
          curve: curves.cubicBezierCurve(0.22, 0.61, 0.36, 1) }))
  }

  @Builder
  returnButton() {
    Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
      Text('‹').fontSize(29).fontColor('#D8FFFFFF').margin({ bottom: 4 }).accessibilityLevel('no')
    }.id('bless-return').width(40).height(40).padding(0)
      .backgroundColor('#4D000000').border({ width: 1, color: '#33FFFFFF', radius: 20 }).backdropBlur(10)
      .responseRegion({ x: -4, y: -4, width: 48, height: 48 })
      .position({ x: 20, y: Math.max(20, this.topInset) }).accessibilityText(this.returnLabel)
      .onClick(() => { this.playback.close(); this.returnToSource(); })
  }

  @Builder
  musicButton() {
    Button({ type: ButtonType.Circle, buttonStyle: ButtonStyleMode.NORMAL }) {
      Text(this.playback.musicState === 'playing' || this.playback.musicState === 'loading' ? 'Ⅱ' : '♪')
        .fontSize(16).fontColor(this.playback.musicState === 'playing' ? '#E0B0FF' : '#D8FFFFFF')
        .accessibilityLevel('no')
    }.id('bless-music').width(48).height(48).padding(0).backgroundColor('#4D000000').backdropBlur(10)
      .border({ width: 1, color: this.playback.musicState === 'playing' ? '#7AE0B0FF' : '#33FFFFFF', radius: 24 })
      .shadow({ radius: this.playback.musicState === 'playing' ? (this.musicPulse ? 35 : 19) : 0,
        color: '#44B4E4FF', offsetX: 0, offsetY: 0 })
      .position({ x: Math.max(0, this.stageWidth - 68), y: Math.max(0, this.stageHeight - Math.max(this.bottomInset, 20) - 48) })
      .accessibilityText(this.playback.musicState === 'playing' || this.playback.musicState === 'loading' ? '暂停' : '播放')
      .onClick(() => this.playback.toggleMusic())
  }

  build() {
    Stack() {
      this.backdrop()
      StarwardBlessSky({ phrase: this.playback.phrase, foreground: this.foreground, reducedMotion: this.reducedMotion })
      Column() {}.width('100%').height('100%').radialGradient({ center: ['50%', '50%'],
        radius: Math.hypot(this.stageWidth, this.stageHeight) / 2,
        colors: [[Color.Transparent, 0.10], ['#99000000', 1]] })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      if (this.playback.phrase.length > 0) {
        Text(this.playback.phrase.replace(/\\n/g, '\n')).id('bless-active-line').fontColor(Color.Transparent)
          .maxLines(2).accessibilityLevel('yes').hitTestBehavior(HitTestMode.None)
      }
      if (!this.playback.started) { this.launch(); }
      if (this.playback.creditsVisible) { this.credits(); }
      this.returnButton();
      if (this.playback.started && this.scene.mainAudioUrl.length > 0) { this.musicButton(); }
    }.id('bless-experience').width('100%').height('100%').clip(true).backgroundColor(Color.Black)
      .onAreaChange((_old: Area, area: Area) => { this.stageWidth = Number(area.width); this.stageHeight = Number(area.height); })
      .onAppear(() => { this.appeared = true; this.syncPulse(); })
  }
}
