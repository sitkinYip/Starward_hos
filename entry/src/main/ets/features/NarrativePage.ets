import { ImmersiveSurfaces } from '../platform/ImmersiveSurfaces';
import { ErrorNotice } from '../ui/ErrorMessages';
import { StarwardAtlas } from '../ui/StarwardAtlas';
import { StarwardBlessExperience } from '../ui/StarwardBlessExperience';
import { StarwardNarrativeLetter } from '../ui/StarwardNarrativeLetter';
import { NarrativeViewModel } from './NarrativeViewModel';

@ComponentV2
export struct NarrativePage {
  @Require @Param model: NarrativeViewModel;
  @Require @Param displayFont: string;
  @Param foreground: boolean = true;
  @Param reducedMotion: boolean = true;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Event returnToQuest: () => void = () => {};
  @Event returnHome: () => void = () => {};
  @Local private loadingWidth: number = 0;
  @Local private loadingHeight: number = 0;
  private darkLease: number = 0;

  aboutToAppear(): void { this.applySystemBarContrast(); }

  aboutToDisappear(): void { this.releaseSystemBarContrast(); }

  @Monitor('model.content', 'foreground')
  applySystemBarContrast(): void {
    if (this.foreground && this.model.content !== null) {
      if (this.darkLease === 0) {
        try { this.darkLease = ImmersiveSurfaces.acquireDark(); } catch { this.darkLease = 0; }
      }
    } else {
      this.releaseSystemBarContrast();
    }
  }

  private releaseSystemBarContrast(): void {
    if (this.darkLease > 0) {
      ImmersiveSurfaces.releaseDark(this.darkLease);
      this.darkLease = 0;
    }
  }

  @Builder
  loading() {
    Column({ space: 18 }) {
      StarwardAtlas({ atlasSize: Math.max(90, Math.min(this.loadingWidth * 0.64, this.loadingHeight * 0.36, 320)) })
        .margin({ bottom: 14 })
      Column({ space: 12 }) {
        Text('星图正在显现').fontSize(10).letterSpacing(2.4).fontColor($r('app.color.accent_muted'))
        Text('故事，正为你展开').fontFamily(this.displayFont).fontSize(24).lineHeight('34.8fp').letterSpacing('0.96fp')
          .fontWeight(500).fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
          .lineBreakStrategy(LineBreakStrategy.BALANCED)
        Row({ space: 10 }) {
          if (!this.reducedMotion && this.foreground) {
            LoadingProgress().width(12).height(12).color($r('app.color.accent')).accessibilityLevel('no')
          } else {
            Circle({ width: 5, height: 5 }).fill($r('app.color.accent')).accessibilityLevel('no')
          }
          Text('正在准备这份专属内容…').fontSize(13).fontColor($r('app.color.muted'))
        }
      }
      Row({ space: 14 }) {
        Divider().layoutWeight(1).color($r('app.color.border_strong'))
        Text('✦').fontSize(12).fontColor($r('app.color.accent_muted'))
        Divider().layoutWeight(1).color($r('app.color.border_strong'))
      }.width('60%').accessibilityLevel('no-hide-descendants')
      Text('有些话，正等着被你读到。').fontSize(12).fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.id('narrative-loading').width('100%').padding(20).alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      if (this.model.content?.letter) {
        StarwardNarrativeLetter({ letter: this.model.content.letter, title: this.model.content.title,
          ownerKey: `narrative:${this.model.revision}`, displayFont: this.displayFont,
          reducedMotion: this.reducedMotion, foreground: this.foreground,
          topInset: this.topInset, bottomInset: this.bottomInset, returnToQuest: () => this.returnToQuest() })
      } else if (this.model.content?.bless) {
        StarwardBlessExperience({ scene: this.model.content.bless, title: this.model.content.title,
          ownerKey: `narrative:${this.model.revision}`, displayFont: this.displayFont,
          reducedMotion: this.reducedMotion, foreground: this.foreground,
          topInset: this.topInset, bottomInset: this.bottomInset,
          returnLabel: this.model.route?.source === 'star-letters' ? '返回星海信笺' : '返回冒险',
          returnToSource: () => this.returnToQuest() })
      } else if (this.model.loading) {
        Column() {
          Scroll() {
            this.loading()
          }.width('100%').layoutWeight(1).align(Alignment.Center).scrollBar(BarState.Off)
          Row({ space: 16 }) {
            Divider().width(24).color($r('app.color.border_strong'))
            Text('向着星辰的冒险').fontSize(10).letterSpacing('1.2fp').fontColor($r('app.color.subtle'))
            Divider().width(24).color($r('app.color.border_strong'))
          }.padding({ bottom: this.bottomInset + 22 })
        }.width('100%').height('100%').onAreaChange((_previous: Area, current: Area) => {
          this.loadingWidth = Number(current.width);
          this.loadingHeight = Number(current.height);
        })
      } else if (this.model.error.length > 0) {
        Scroll() {
          ErrorNotice({ message: this.model.error, retryable: this.model.retryable, topMargin: 8, showReturn: true,
            returnLabel: this.model.route?.source === 'star-letters' ? '返回星海信笺' :
              this.model.route?.source === 'quest-clue' ? '返回答题' : '回到首页',
            retry: () => this.model.retry(), returnHome: () => this.returnHome() })
            .id('narrative-error')
        }.width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      }
    }.id('narrative-page').width('100%').height('100%').backgroundColor($r('app.color.canvas'))
  }
}
