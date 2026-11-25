import { ImmersiveSurfaces } from '../platform/ImmersiveSurfaces';
import { ErrorNotice } from '../ui/ErrorMessages';
import { StarwardBlessExperience } from '../ui/StarwardBlessExperience';
import { StarwardLoadingStage } from '../ui/StarwardLoadingStage';
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
        StarwardLoadingStage({
          stateId: 'narrative-loading',
          title: '故事，正为你展开',
          status: '正在准备这份专属内容…',
          hint: '有些话，正等着被你读到。',
          motionEnabled: this.foreground && !this.reducedMotion,
          showBrand: false,
          bottomInset: this.bottomInset
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
