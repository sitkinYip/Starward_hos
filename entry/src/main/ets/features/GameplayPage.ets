import { GameplayContentBlock, GameplayLevel, GameplayOption,
  GameplaySnapshot } from '../business/GameplayModels';
import { GameplayViewModel } from './GameplayViewModel';
import { ErrorNotice, InlineError } from '../ui/ErrorMessages';
import { StarwardAnswerInput } from '../ui/StarwardAnswerInput';
import { PrimaryAction } from '../ui/PrimaryAction';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardKeyboard } from '../ui/StarwardKeyboard';
import { StarwardQuestionFrame } from '../ui/StarwardQuestionFrame';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardQuestionImages } from '../ui/StarwardQuestionImages';
import { StarwardImageViewer, StarwardImageViewerState } from '../ui/StarwardImageViewer';
import { StarwardChoiceOption } from '../ui/StarwardChoiceOption';

/** A hint is disclosed by the player, like the formal Web question details. */
@ComponentV2
struct GameplayHint {
  @Param text: string = '';
  @Param contentIndex: number = 0;
  @Local expanded: boolean = false;

  build() {
    Column({ space: 10 }) {
      Button(this.expanded ? '收起提示' : '查看提示', { type: ButtonType.Normal })
        .id(`question-hint-${this.contentIndex}`).constraintSize({ minHeight: 44 })
        .padding({ left: 12, right: 12 }).fontSize(13)
        .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
        .borderRadius(10).onClick(() => { this.expanded = !this.expanded; })
      if (this.expanded) {
        Text(this.text).id(`question-hint-content-${this.contentIndex}`).width('100%')
          .fontSize(14).lineHeight('25.9fp').fontColor($r('app.color.muted'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

/** Native presentation only: the account-bound ViewModel owns drafts and writes. */
@ComponentV2
export struct GameplayPage {
  @Require @Param play: GameplayViewModel;
  @Param autoNextDelay: number = 0;
  @Param displayFont: string = 'serif';
  @Param bottomClearance: number = 24;
  @Param reducedMotion: boolean = true;
  @Event leave: () => void = () => {};
  @Local seenCompletionRevision: number = 0;
  @Local reconnecting: boolean = false;
  @Local viewportWidth: number = 0;
  @Local private viewer: StarwardImageViewerState = new StarwardImageViewerState();

  aboutToAppear(): void {
    // A completed GET or remount is not a new successful answer.
    this.seenCompletionRevision = this.play.completionRevision;
  }

  aboutToDisappear(): void { this.viewer.close(this.viewer.sessionId, true); }

  @Monitor('play.visible', 'play.snapshot', 'play.activeIndex')
  imageOwnerChanged(): void { this.viewer.validateOwner(); }

  @Monitor('viewer.visible')
  coverVisibilityChanged(): void {
    if (!this.viewer.visible && !this.viewer.closing) { this.viewer.close(this.viewer.sessionId); }
  }

  private openImages(blockIndex: number, index: number): void {
    const block: GameplayContentBlock | undefined = this.play.currentLevel()?.question?.content[blockIndex];
    if (!this.play.visible || this.play.snapshot === null || block === undefined || block.videoUrl.length > 0) { return; }
    const sources: string[] = this.blockImages(block);
    const owner: string = this.imageOwner();
    StarwardKeyboard.dismiss(this.getUIContext());
    this.viewer.open(sources, index, () => {
      const current: GameplayContentBlock | undefined = this.play.currentLevel()?.question?.content[blockIndex];
      if (!this.play.visible || this.play.snapshot === null || owner !== this.imageOwner() || current === undefined ||
        current.videoUrl.length > 0) { return false; }
      const actual: string[] = this.blockImages(current);
      return actual.length === sources.length && actual.every((source: string, position: number) => source === sources[position]);
    });
  }

  private viewerOptions(): ContentCoverOptions {
    const sessionId: number = this.viewer.sessionId;
    return { backgroundColor: '#050605', enableSafeArea: false,
      modalTransition: this.reducedMotion ? ModalTransition.NONE : ModalTransition.ALPHA,
      onWillDismiss: (action: DismissContentCoverAction) => { this.viewer.close(sessionId); action.dismiss(); },
      onDisappear: () => this.viewer.disappeared(sessionId) };
  }

  private viewerCloseAction(): () => void {
    const sessionId: number = this.viewer.sessionId;
    return () => this.viewer.close(sessionId);
  }

  @Builder
  imageViewer() {
    StarwardImageViewer({ model: this.viewer, sessionId: this.viewer.sessionId, reducedMotion: this.reducedMotion,
      close: this.viewerCloseAction() })
  }

  @Monitor('play.retryAnswer')
  retryChanged(): void {
    if (!this.play.retryAnswer) {
      this.reconnecting = false;
    }
  }

  @Monitor('play.completionRevision')
  completionChanged(): void {
    const revision: number = this.play.completionRevision;
    if (revision <= 0 || revision === this.seenCompletionRevision) {
      this.seenCompletionRevision = revision;
      return;
    }
    this.seenCompletionRevision = revision;
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    if (!this.play.visible || snapshot === null || snapshot.detail.status !== 'completed') {
      return;
    }
    if (snapshot.presentation.completionStyle === 'finale') {
      StarwardFeedback.notice(this.getUIContext(), '本次场次已完成', '全部题目已经完成。终章内容尚未迁移。');
    } else if (snapshot.detail.totalLevels > 1) {
      StarwardFeedback.notice(this.getUIContext(), '组合谜题全部破解',
        `你已完成本次组合中的 ${snapshot.detail.completedLevels} 道谜题。`);
    }
  }

  private displayedLevelIds(): string[] {
    const level: GameplayLevel | null = this.play.currentLevel();
    return level !== null && level.question !== null ? [level.id] : [];
  }

  private navigationLevelIds(): string[] {
    return this.play.snapshot === null ? [] : this.play.snapshot.levels.map((level: GameplayLevel) => level.id);
  }

  private navigationCompleted(index: number): boolean {
    return (this.play.snapshot?.levels[index]?.completedAt || '').length > 0;
  }

  private contentBlocks(): GameplayContentBlock[] {
    return this.play.currentLevel()?.question?.content || [];
  }

  private blockImages(block: GameplayContentBlock): string[] {
    const sources: string[] = [];
    if (block.imageUrl.length > 0) { sources.push(block.imageUrl); }
    for (const source of block.imageUrls) {
      if (source.length > 0 && !sources.includes(source)) { sources.push(source); }
    }
    return sources;
  }

  private imageOwner(): string {
    return `${this.play.imageOwnerKey()}:${this.play.currentLevel()?.id || ''}`;
  }

  private optionKeys(): string[] {
    return this.play.currentLevel()?.question?.options.map((option: GameplayOption) => option.key) || [];
  }

  private optionText(key: string): string {
    const option: GameplayOption | undefined = this.play.currentLevel()?.question?.options.find(
      (item: GameplayOption) => item.key === key);
    return option?.text || `选项 ${key}`;
  }

  private optionImage(key: string): string {
    const option: GameplayOption | undefined = this.play.currentLevel()?.question?.options.find(
      (item: GameplayOption) => item.key === key);
    // A video poster must not become a fake image-only playback path.
    return option !== undefined && option.videoUrl.length === 0 ? option.imageUrl : '';
  }

  private optionOwner(key: string): string { return `${this.imageOwner()}:option:${key}`; }

  private openOptionImage(key: string): void {
    const source: string = this.optionImage(key);
    const owner: string = this.optionOwner(key);
    if (!this.play.visible || this.play.snapshot === null || !this.play.answerEditable() || source.length === 0) { return; }
    StarwardKeyboard.dismiss(this.getUIContext());
    this.viewer.open([source], 0, () => this.play.visible && this.play.snapshot !== null && this.play.answerEditable() &&
      this.optionOwner(key) === owner && this.optionImage(key) === source);
  }

  private currentCompleted(): boolean {
    return (this.play.currentLevel()?.completedAt || '').length > 0;
  }

  private interactionReady(): boolean {
    return !this.play.loading && !this.play.starting && !this.play.submitting && !this.play.refreshing;
  }

  private titleVisible(): boolean {
    const hidden: boolean | undefined = this.play.currentLevel()?.presentationOverride.hideTitle;
    return hidden === undefined ? this.play.snapshot?.presentation.hideTitle !== true : !hidden;
  }

  private questionTitleSize(): number {
    return Math.max(32, Math.min(48, this.viewportWidth * 0.1));
  }

  private shownAnswer(): string {
    return this.currentCompleted() ? this.play.currentLevel()?.lastAnswer || '' : this.play.draftAnswer;
  }

  private submit(): void {
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.submitAnswer(this.autoNextDelay);
  }

  private retryAnswer(): void {
    this.reconnecting = true;
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.retrySubmission(this.autoNextDelay);
  }

  // Private builders read the V2 owner directly. Passing plain snapshot/level
  // objects by value would freeze their first render across a settlement.
  @Builder
  questionNavigation() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.navigationLevelIds(), (_levelId: string, index: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 4 }) {
              Text((index + 1).toString().padStart(2, '0')).fontFamily('monospace').fontSize(15)
              Text(this.navigationCompleted(index) ? '已完成' : `第 ${index + 1} 题`).fontSize(11)
            }.padding({ left: 16, right: 16, top: 10, bottom: 10 })
          }.id(`gameplay-level-${index}`).constraintSize({ minHeight: 60, minWidth: 72 })
            .borderRadius(12)
            .fontColor(index === this.play.activeIndex ? $r('app.color.accent_text') : $r('app.color.muted'))
            .backgroundColor(index === this.play.activeIndex ? $r('app.color.accent_faint') : $r('app.color.surface'))
            .border({ width: 1,
              color: index === this.play.activeIndex ? $r('app.color.accent_border') : $r('app.color.border') })
            .enabled(this.interactionReady() && this.play.canMoveTo(index))
            .accessibilityText(`第 ${index + 1} 题${this.navigationCompleted(index) ? '，已完成' : ''}${
              index === this.play.activeIndex ? '，当前题目' : ''}`)
            .onClick(() => {
              StarwardKeyboard.dismiss(this.getUIContext());
              this.play.moveTo(index);
            })
        }, (levelId: string) => levelId)
      }
    }.id('gameplay-level-navigation').width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
  }

  @Builder
  choiceAnswer() {
    Column({ space: 10 }) {
      ForEach(this.optionKeys(), (key: string, index: number) => {
        StarwardChoiceOption({ optionKey: key, text: this.optionText(key),
          group: `gameplay-${this.play.currentLevel()?.id || ''}`, radioId: `gameplay-option-${index}`,
          cardId: `gameplay-choice-${index}`, imageId: `gameplay-option-image-${index}`,
          selected: this.shownAnswer() === key, editable: this.play.answerEditable(),
          imageSource: this.optionImage(key), ownerKey: this.optionOwner(key),
          ownerIsCurrent: (owner: string) => this.play.visible && this.play.snapshot !== null && owner === this.optionOwner(key),
          reducedMotion: this.reducedMotion, chosen: () => this.play.editAnswer(key), opened: () => this.openOptionImage(key) })
      }, (key: string) => key)
    }.id('gameplay-choice-options').width('100%')
  }

  @Builder
  answerForm() {
    Column({ space: 16 }) {
      if (this.play.currentLevel()?.question?.kind === 'choice') {
        this.choiceAnswer()
      } else {
        StarwardAnswerInput({ value: this.shownAnswer(),
          placeholder: this.play.currentLevel()?.question?.placeholder || '输入你的答案',
          editable: this.play.answerEditable(), reducedMotion: this.reducedMotion,
          changed: (value: string) => this.play.editAnswer(value) })
      }
      if (this.currentCompleted()) {
        Text('当前题目已完成。').id('gameplay-answer-completed').width('100%').fontSize(13).lineHeight('22.1fp')
          .fontColor($r('app.color.accent_text'))
      } else if (this.play.blockedReason().length > 0) {
        Text(this.play.blockedReason()).id('gameplay-penalty').width('100%').fontSize(13).lineHeight('22.1fp')
          .fontColor($r('app.color.danger')).accessibilityText(this.play.blockedReason())
      }
      if (this.play.retryAnswer && (!this.play.submitting || this.reconnecting)) {
        Column({ space: 12 }) {
          Text('答案还在，等待回音').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
          Text('暂时未能确认提交结果。你的输入仍在，重试会确认同一次提交，不会重复计次。')
            .fontSize(13).lineHeight('22.1fp').fontColor($r('app.color.muted')).width('100%')
          InlineError({ message: this.play.answerError, fieldId: 'gameplay-answer-error' })
          Button(this.play.submitting ? '正在重新连接…' : '重新连接', { type: ButtonType.Normal })
            .id('gameplay-answer-retry').height(48).width('100%').borderRadius(10).fontSize(15)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .enabled(this.interactionReady()).onClick(() => this.retryAnswer())
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
          .backgroundColor($r('app.color.accent_faint')).borderRadius(12)
      } else {
        InlineError({ message: this.play.answerError, fieldId: 'gameplay-answer-error' })
        if (!this.currentCompleted()) {
          Button(this.play.submitting ? '正在提交…' : '提交答案', { type: ButtonType.Normal })
            .id('gameplay-submit').height(52).width('100%').borderRadius(10).fontSize(16).fontWeight(600)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .enabled(this.play.answerAllowed()).onClick(() => this.submit())
        }
      }
      if (this.play.feedback.length > 0) {
        Text(this.play.feedback).id('gameplay-feedback').width('100%').fontSize(14).lineHeight('23.8fp')
          .fontColor(this.play.feedbackDanger ? $r('app.color.danger') : $r('app.color.accent_text'))
          .accessibilityText(this.play.feedback)
      }
      if (this.currentCompleted() && this.play.canMoveTo(this.play.activeIndex + 1)) {
        Button(this.play.advancing ? '即将前往下一题…' : '前往下一题', { type: ButtonType.Normal })
          .id('gameplay-next').height(48).width('100%').borderRadius(10).fontSize(15)
          .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
          .border({ width: 1, color: $r('app.color.accent_border') })
          .enabled(this.interactionReady()).onClick(() => this.play.nextQuestion())
      }
    }.id('gameplay-answer-form').width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  questionCard() {
    StarwardQuestionFrame({ frameId: 'gameplay-question-card' }) {
      Column() {
        Row() {
          Text(`第 ${this.play.currentLevel()?.position || 0} 题`).id('question-number')
            .fontFamily('monospace').fontSize(12).lineHeight('14.4fp').fontColor($r('app.color.subtle'))
          Blank()
          Text(this.play.currentLevel()?.question?.kind === 'choice' ? '选择题' : '填空题').id('question-kind')
            .fontFamily('monospace').fontSize(12).lineHeight('14.4fp').fontColor($r('app.color.subtle'))
        }.width('100%')
        if (this.titleVisible() && (this.play.currentLevel()?.question?.title || '').length > 0) {
          Text(this.play.currentLevel()?.question?.title || '').id('question-title').width('100%')
            .fontFamily(this.displayFont).fontSize(this.questionTitleSize()).fontWeight(FontWeight.Medium)
            .lineHeight(`${this.questionTitleSize() * 0.98}fp`).letterSpacing(`${this.questionTitleSize() * -0.055}fp`)
            .lineBreakStrategy(LineBreakStrategy.BALANCED)
            .fontColor($r('app.color.strong')).margin({ top: 18 })
        }
        Column({ space: 20 }) {
          ForEach(this.contentBlocks(), (block: GameplayContentBlock, index: number) => {
            Column({ space: 13 }) {
              if (this.blockImages(block).length > 0 && block.videoUrl.length === 0) {
                StarwardQuestionImages({ sources: this.blockImages(block), ownerKey: this.imageOwner(),
                  ownerIsCurrent: (key: string) => this.play.visible && this.play.snapshot !== null && key === this.imageOwner(),
                  groupId: `question-images-${index}`, maxHeight: this.viewportWidth <= 620 ? 340 : 420,
                  reducedMotion: this.reducedMotion, opened: (imageIndex: number) => this.openImages(index, imageIndex) })
              }
              if (block.text.length > 0) {
                Text(block.text).id(`question-content-text-${index}`).width('100%')
                  .fontSize(16).lineHeight('27.52fp').fontColor($r('app.color.text'))
              }
              if (block.hint.length > 0) {
                GameplayHint({ text: block.hint, contentIndex: index })
              }
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (block: GameplayContentBlock, index: number) => `${index}:${JSON.stringify(block)}`)
        }.id('question-content').width('100%').alignItems(HorizontalAlign.Start).margin({ top: 20 })
        Column() {
          this.answerForm()
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 24 })
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ top: 22, left: 18, right: 18, bottom: 26 })
    }
  }

  @Builder
  gameplayScroll() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.play.loading) {
          Text('正在展开你的旅程…').id('gameplay-loading').width('100%')
            .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.muted'))
        } else if (this.play.error.length > 0) {
          ErrorNotice({ message: this.play.error, retryable: this.interactionReady(),
            retry: () => this.play.reload(), returnHome: () => this.leave() })
        } else if (this.play.snapshot !== null && this.play.snapshot.detail.status === 'cancelled') {
          Text('本次场次已撤回').id('gameplay-cancelled').width('100%').fontFamily(this.displayFont)
            .fontSize(26).lineHeight('37.7fp').fontColor($r('app.color.strong'))
          Text('如需继续，请联系游戏管理员重新安排。').width('100%').fontSize(14).lineHeight('25.2fp')
            .fontColor($r('app.color.muted'))
          Button('回到首页', { type: ButtonType.Normal }).id('gameplay-leave').height(44)
            .fontSize(14).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
            .onClick(() => this.leave())
        } else if (this.play.snapshot !== null && this.play.snapshot.detail.id.length > 0) {
          if (this.play.refreshError.length > 0) {
            Column({ space: 6 }) {
              InlineError({ message: this.play.refreshError, fieldId: 'gameplay-refresh-error' })
              Button('重新同步', { type: ButtonType.Normal }).id('gameplay-refresh-retry').height(44)
                .fontSize(13).fontColor($r('app.color.accent_text')).backgroundColor(Color.Transparent)
                .enabled(this.play.canRefresh()).onClick(() => { this.play.refresh(); })
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
          if (this.play.snapshot.detail.totalLevels > 1) {
            this.questionNavigation()
          }
          ForEach(this.displayedLevelIds(), (_levelId: string) => {
            this.questionCard()
          }, (levelId: string) => levelId)
          if (this.displayedLevelIds().length === 0) {
            Text('题目尚未解锁，请同步进度后重试。').id('gameplay-question-unavailable').width('100%')
              .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.muted'))
          }
          if (this.play.snapshot.clues.length > 0) {
            Text('本场线索内容尚未迁移。').id('gameplay-clue-notice').width('100%')
              .fontSize(13).lineHeight('22.1fp').fontColor($r('app.color.muted'))
          }
          if (this.play.snapshot.detail.status === 'completed') {
            Text('本次场次已完成。').id('gameplay-completed-state').width('100%')
              .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.accent_text'))
            if (this.play.snapshot.presentation.completionStyle === 'finale' ||
              this.play.snapshot.completionTarget !== null) {
              Text('终章与旅程出口尚未迁移。').id('gameplay-completion-pending').width('100%')
                .fontSize(13).lineHeight('22.1fp').fontColor($r('app.color.muted'))
            }
          }
        } else {
          Text('尚未读取题目，请重新尝试。').id('gameplay-empty').width('100%')
            .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.muted'))
          PrimaryAction({ label: '重新尝试', actionEnabled: this.interactionReady(), action: () => this.play.reload() })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: 16, bottom: this.bottomClearance })
    }.id('gameplay-page').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 0 && width !== this.viewportWidth) {
          this.viewportWidth = width;
        }
      })
  }

  build() {
    StarwardRefresh({ refreshEnabled: this.play.canRefresh(),
      request: async () => { await this.play.refresh(); },
      content: () => { this.gameplayScroll() } })
      .bindContentCover(!!this.viewer.visible, this.imageViewer(), this.viewerOptions())
  }
}
