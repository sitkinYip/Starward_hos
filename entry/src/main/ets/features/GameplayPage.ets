import { hilog } from '@kit.PerformanceAnalysisKit';
import { RectShape } from '@kit.ArkUI';
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
import { StarwardQuestHint } from '../ui/StarwardQuestHint';
import { StarwardQuestFeedback } from '../ui/StarwardQuestFeedback';
import { StarwardAnswerRecovery } from '../ui/StarwardAnswerRecovery';
import { QuestionNavigationItem, StarwardQuestionNavigation } from '../ui/StarwardQuestionNavigation';
import { StarwardQuestionSwiper } from '../ui/StarwardQuestionSwiper';

/** Native presentation only: the account-bound ViewModel owns drafts and writes. */
@ComponentV2
export struct GameplayPage {
  @Require @Param play: GameplayViewModel;
  @Param autoNextDelay: number = 0;
  @Param displayFont: string = 'serif';
  @Param bottomClearance: number = 24;
  @Param titleBottom: number = 0;
  @Param statusInset: number = 0;
  @Param keyboardVisible: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event leave: () => void = () => {};
  @Event titleVisibilityChanged: (hidden: boolean) => void = () => {};
  @Local seenCompletionRevision: number = 0;
  @Local private recoveryVisible: boolean = false;
  @Local private recoveryDismissed: boolean = false;
  @Local viewportWidth: number = 0;
  @Local private viewportTop: number = 0;
  @Local private viewportHeight: number = 0;
  @Local private viewer: StarwardImageViewerState = new StarwardImageViewerState();
  private readonly questionScroller: Scroller = new Scroller();
  private cardContentTop: number = -1;
  private questionRegionHeight: number = 0;
  private titleHidden: boolean = false;
  private positionOwner: string = '';
  private positionPending: boolean = false;
  private positionTimer: number = -1;

  aboutToAppear(): void {
    // A completed GET or remount is not a new successful answer.
    this.seenCompletionRevision = this.play.completionRevision;
    this.recoveryChanged();
    this.trackQuestionPosition();
  }

  aboutToDisappear(): void {
    this.viewer.close(this.viewer.sessionId, true);
    clearTimeout(this.positionTimer);
    this.positionTimer = -1;
    this.positionPending = false;
    this.titleVisibilityChanged(false);
  }

  @Monitor('play.visible', 'play.snapshot', 'play.activeIndex')
  imageOwnerChanged(): void {
    this.viewer.validateOwner();
    if (!this.play.currentLevel()?.question) {
      this.cardContentTop = -1;
      this.questionRegionHeight = 0;
      this.setTitleHidden(false, this.scrollOffset(), 0);
    }
    this.trackQuestionPosition();
  }

  private scrollOffset(): number {
    const offset: number = this.questionScroller.offset()?.yOffset ?? 0;
    return Number.isFinite(offset) ? Math.max(0, offset) : 0;
  }

  private setTitleHidden(hidden: boolean, offset: number, threshold: number): void {
    if (this.titleHidden === hidden) { return; }
    this.titleHidden = hidden;
    this.titleVisibilityChanged(hidden);
    hilog.info(0x0000, 'StarwardQuestHeader', 'hidden=%{public}s offset=%{public}s threshold=%{public}s',
      hidden.toString(), offset.toFixed(3), threshold.toFixed(3));
  }

  private syncTitle(): void {
    const offset: number = this.scrollOffset();
    const threshold: number = Math.max(0, this.cardContentTop - this.titleBottom);
    if (offset <= 0.5) {
      this.setTitleHidden(false, offset, threshold);
    } else if (this.titleBottom > 0 && this.cardContentTop >= 0 && offset + 0.25 >= threshold) {
      this.setTitleHidden(true, offset, threshold);
    }
  }

  private measureCard(area: Area): void {
    const top: number = Number(area.globalPosition.y);
    const height: number = Number(area.height);
    if (!Number.isFinite(top) || !Number.isFinite(height) || height <= 0) { return; }
    this.cardContentTop = top + this.scrollOffset();
    this.questionRegionHeight = height;
    this.syncTitle();
    this.scheduleQuestionPosition();
  }

  private positionKey(): string {
    return this.play.visible && this.play.snapshot?.detail.status !== 'cancelled' && this.readableQuestionId().length > 0 ?
      this.imageOwner() : '';
  }

  private trackQuestionPosition(force: boolean = false): void {
    const owner: string = this.positionKey();
    if (owner !== this.positionOwner || force) {
      this.positionOwner = owner;
      this.positionPending = owner.length > 0;
    }
    this.scheduleQuestionPosition();
  }

  private foregroundTopInset(): number {
    return Math.max(0, this.statusInset - this.viewportTop);
  }

  private minimumQuestionRegionHeight(): number {
    return Math.max(0, this.viewportHeight - this.foregroundTopInset());
  }

  @Monitor('keyboardVisible', 'recoveryVisible', 'play.loading', 'play.starting', 'play.submitting',
    'play.refreshing', 'viewer.visible', 'viewer.closing')
  scheduleQuestionPosition(): void {
    if (this.positionTimer !== -1 || !this.questionPositionReady()) {
      return;
    }
    this.positionTimer = setTimeout(() => {
      this.positionTimer = -1;
      if (!this.questionPositionReady() || this.positionOwner !== this.positionKey()) { return; }
      const y: number = Math.max(0, this.cardContentTop - Math.max(this.viewportTop, this.statusInset));
      this.positionPending = false;
      this.questionScroller.scrollTo({ xOffset: 0, yOffset: y,
        animation: this.reducedMotion ? false : { duration: 240, curve: Curve.EaseOut } });
    }, 0);
  }

  private questionPositionReady(): boolean {
    return this.positionPending && this.viewportHeight > 0 && this.cardContentTop >= 0 &&
      this.questionRegionHeight + 0.5 >= this.minimumQuestionRegionHeight() && this.questionInteractionReady();
  }

  private foregroundClip(): RectShape | undefined {
    if (this.viewportHeight <= 0) { return undefined; }
    const top: number = this.foregroundTopInset();
    return new RectShape({ width: '100%', height: Math.max(0, this.viewportHeight - top) }).offset({ x: 0, y: top });
  }

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

  @Monitor('play.retryAnswer', 'play.submitting', 'play.loading', 'play.visible', 'play.snapshot',
    'viewer.visible', 'viewer.closing')
  recoveryChanged(): void {
    if (!this.play.retryAnswer || !this.play.visible || this.play.snapshot === null) {
      this.recoveryVisible = false;
      this.recoveryDismissed = false;
    } else if (!this.recoveryDismissed && !this.play.submitting && !this.play.loading &&
      !this.viewer.visible && !this.viewer.closing) {
      this.recoveryVisible = true;
    }
  }

  private showRecovery(): void {
    if (this.play.retryAnswer && this.interactionReady() && !this.viewer.visible && !this.viewer.closing) {
      this.recoveryDismissed = false;
      this.recoveryVisible = true;
    }
  }

  private stayOnQuestion(): void {
    if (!this.play.submitting) {
      this.recoveryDismissed = true;
      this.recoveryVisible = false;
    }
  }

  private recoveryOptions(): ContentCoverOptions {
    return {
      backgroundColor: $r('app.color.answer_recovery_mask'),
      enableSafeArea: true,
      modalTransition: this.reducedMotion ? ModalTransition.NONE : ModalTransition.ALPHA,
      onWillDismiss: (action: DismissContentCoverAction) => {
        if (!this.play.submitting && action.reason === DismissReason.PRESS_BACK) {
          this.stayOnQuestion();
          action.dismiss();
        }
      }
    };
  }

  @Builder
  answerRecovery() {
    StarwardAnswerRecovery({ pending: this.play.submitting, displayFont: this.displayFont,
      retry: () => this.retryAnswer(), stay: () => this.stayOnQuestion() })
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

  private readableQuestionId(): string {
    const level: GameplayLevel | null = this.play.currentLevel();
    return level?.question ? level.id : '';
  }

  private levelById(id: string): GameplayLevel | undefined {
    return this.play.snapshot?.levels.find((level: GameplayLevel) => level.id === id);
  }

  private swipeableQuestionIds(): string[] {
    const levels: GameplayLevel[] = this.play.snapshot?.levels || [];
    const current: number = this.play.activeIndex;
    if (!levels[current]?.question) { return []; }
    let first: number = current;
    let last: number = current;
    while (first > 0 && levels[first - 1].question !== null) { first--; }
    while (last + 1 < levels.length && levels[last + 1].question !== null) { last++; }
    return levels.slice(first, last + 1).map((level: GameplayLevel) => level.id);
  }

  private questionNavigationItems(): QuestionNavigationItem[] {
    return (this.play.snapshot?.levels || []).map((level: GameplayLevel, index: number): QuestionNavigationItem => ({
      id: level.id,
      completed: level.completedAt.length > 0,
      enabled: this.interactionReady() && this.play.canMoveTo(index),
      locked: level.question === null
    }));
  }

  private selectQuestion(index: number): void {
    if (!this.interactionReady() || this.recoveryVisible || !this.play.canMoveTo(index)) {
      return;
    }
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.moveTo(index);
    this.trackQuestionPosition(true);
  }

  private selectSwipedQuestion(id: string): boolean {
    const index: number = this.play.snapshot?.levels.findIndex((level: GameplayLevel) => level.id === id) ?? -1;
    if (!this.questionInteractionReady() || Math.abs(index - this.play.activeIndex) !== 1 || !this.play.canMoveTo(index)) {
      return false;
    }
    this.selectQuestion(index);
    return this.readableQuestionId() === id;
  }

  private contentBlocks(id: string): GameplayContentBlock[] {
    return this.levelById(id)?.question?.content || [];
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

  private questionInteractionReady(): boolean {
    return this.interactionReady() && !this.keyboardVisible && !this.recoveryVisible &&
      !this.viewer.visible && !this.viewer.closing;
  }

  private titleVisible(id: string): boolean {
    const hidden: boolean | undefined = this.levelById(id)?.presentationOverride.hideTitle;
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
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.retrySubmission(this.autoNextDelay);
  }

  // Private builders read the V2 owner directly. Passing plain snapshot/level
  // objects by value would freeze their first render across a settlement.
  @Builder
  questionNavigation() {
    StarwardQuestionNavigation({ items: this.questionNavigationItems(), activeIndex: this.play.activeIndex,
      reducedMotion: this.reducedMotion, select: (index: number) => this.selectQuestion(index) })
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
    Column() {
      if (this.play.currentLevel()?.question?.kind === 'choice') {
        this.choiceAnswer()
      } else {
        StarwardAnswerInput({ value: this.shownAnswer(),
          placeholder: this.play.currentLevel()?.question?.placeholder || '输入你的答案',
          editable: this.play.answerEditable(), reducedMotion: this.reducedMotion,
          changed: (value: string) => this.play.editAnswer(value) })
      }
      if (!this.currentCompleted() && this.play.blockedReason().length > 0) {
        Text(this.play.blockedReason()).id('gameplay-penalty').width('100%')
          .fontSize(16).lineHeight('25.6fp').fontColor($r('app.color.accent_text'))
          .padding({ top: 13, bottom: 13, left: 15, right: 15 }).margin({ top: 16 })
          .backgroundColor($r('app.color.accent_faint')).border({ width: 1, color: $r('app.color.accent_border') })
      }
      if (!this.currentCompleted()) {
        if (this.play.retryAnswer && !this.play.submitting) {
          Button('重新连接', { type: ButtonType.Capsule }).id('gameplay-answer-retry-inline')
            .constraintSize({ minHeight: 46 }).padding({ left: 20, right: 20 }).margin({ top: 18 })
            .fontSize(16).fontWeight(600).fontColor($r('app.color.on_accent'))
            .backgroundColor($r('app.color.accent')).enabled(this.interactionReady())
            .onClick(() => this.showRecovery())
        } else {
          Button('提交答案', { type: ButtonType.Capsule }).id('gameplay-submit')
            .constraintSize({ minHeight: 46 }).padding({ left: 20, right: 20 }).margin({ top: 18 })
            .fontSize(16).fontWeight(600).fontColor($r('app.color.on_accent'))
            .backgroundColor($r('app.color.accent')).enabled(this.play.answerAllowed()).onClick(() => this.submit())
        }
      }
      if (this.currentCompleted() && this.play.canMoveTo(this.play.activeIndex + 1)) {
        Button(this.play.advancing ? '即将前往下一题…' : '前往下一题', { type: ButtonType.Capsule })
          .id('gameplay-next').constraintSize({ minHeight: 46 }).padding({ left: 20, right: 20 }).margin({ top: 18 })
          .fontSize(16).fontWeight(600)
          .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
          .border({ width: 1, color: $r('app.color.accent_border') })
          .enabled(this.interactionReady()).onClick(() => this.play.nextQuestion())
      }
      if (!this.play.retryAnswer && (this.play.answerError.length > 0 || this.play.feedback.length > 0)) {
        ForEach([this.play.feedbackVersion], (_version: number) => {
          StarwardQuestFeedback({
            message: this.play.answerError.length > 0 ? this.play.answerError : this.play.feedback,
            messageId: this.play.answerError.length > 0 ? 'gameplay-answer-error' : 'gameplay-feedback-message',
            danger: this.play.answerError.length > 0 || this.play.feedbackDanger,
            transient: this.play.feedbackTransient, reducedMotion: this.reducedMotion
          })
        }, (version: number) => version.toString())
      }
    }.id('gameplay-answer-form').width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  questionCard(levelId: string) {
    StarwardQuestionFrame({ frameId: levelId === this.readableQuestionId() ? 'gameplay-question-card' : '' }) {
      Column() {
        Row() {
          Text(`第 ${this.levelById(levelId)?.position || 0} 题`)
            .id(levelId === this.readableQuestionId() ? 'question-number' : '')
            .fontFamily('monospace').fontSize(12).lineHeight('14.4fp').fontColor($r('app.color.subtle'))
          Blank()
          Text(this.levelById(levelId)?.question?.kind === 'choice' ? '选择题' : '填空题')
            .id(levelId === this.readableQuestionId() ? 'question-kind' : '')
            .fontFamily('monospace').fontSize(12).lineHeight('14.4fp').fontColor($r('app.color.subtle'))
        }.width('100%')
        if (this.titleVisible(levelId) && (this.levelById(levelId)?.question?.title || '').length > 0) {
          Text(this.levelById(levelId)?.question?.title || '')
            .id(levelId === this.readableQuestionId() ? 'question-title' : '').width('100%')
            .fontFamily(this.displayFont).fontSize(this.questionTitleSize()).fontWeight(FontWeight.Medium)
            .lineHeight(`${this.questionTitleSize() * 0.98}fp`).letterSpacing(`${this.questionTitleSize() * -0.055}fp`)
            .lineBreakStrategy(LineBreakStrategy.BALANCED)
            .fontColor($r('app.color.strong')).margin({ top: 18 })
        }
        Column({ space: 20 }) {
          ForEach(this.contentBlocks(levelId), (block: GameplayContentBlock, index: number) => {
            Column({ space: 13 }) {
              if (levelId === this.readableQuestionId() && this.blockImages(block).length > 0 && block.videoUrl.length === 0) {
                StarwardQuestionImages({ sources: this.blockImages(block), ownerKey: this.imageOwner(),
                  ownerIsCurrent: (key: string) => this.play.visible && this.play.snapshot !== null && key === this.imageOwner(),
                  groupId: `question-images-${index}`, maxHeight: this.viewportWidth <= 620 ? 340 : 420,
                  reducedMotion: this.reducedMotion, opened: (imageIndex: number) => this.openImages(index, imageIndex) })
              }
              if (block.text.length > 0) {
                Text(block.text).id(levelId === this.readableQuestionId() ? `question-content-text-${index}` : '').width('100%')
                  .fontSize(16).lineHeight('27.52fp').fontColor($r('app.color.text'))
              }
              if (levelId === this.readableQuestionId() && block.hint.length > 0) {
                StarwardQuestHint({ text: block.hint, contentIndex: index, reducedMotion: this.reducedMotion })
              }
            }.width('100%').alignItems(HorizontalAlign.Start)
          }, (block: GameplayContentBlock, index: number) => `${index}:${JSON.stringify(block)}`)
        }.id(levelId === this.readableQuestionId() ? 'question-content' : '')
          .width('100%').alignItems(HorizontalAlign.Start).margin({ top: 20 })
        if (levelId === this.readableQuestionId()) {
          Column() {
            this.answerForm()
          }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 24 })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ top: 22, left: 18, right: 18, bottom: 26 })
    }
  }

  @Builder
  questionRegion() {
    Column({ space: 16 }) {
      if (this.readableQuestionId().length > 0) {
        if ((this.play.snapshot?.detail.totalLevels || 0) > 1) {
          StarwardQuestionSwiper({ pages: this.swipeableQuestionIds(), currentId: this.readableQuestionId(),
            swipeEnabled: this.questionInteractionReady() && this.play.canMoveTo(this.play.activeIndex),
            reducedMotion: this.reducedMotion,
            content: (id: string) => { this.questionCard(id) },
            select: (id: string) => this.selectSwipedQuestion(id) })
        } else {
          this.questionCard(this.readableQuestionId())
        }
      } else {
        Text('题目尚未解锁，请同步进度后重试。').id('gameplay-question-unavailable').width('100%')
          .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.muted'))
      }
      if ((this.play.snapshot?.clues.length || 0) > 0) {
        Text('本场线索内容尚未迁移。').id('gameplay-clue-notice').width('100%')
          .fontSize(13).lineHeight('22.1fp').fontColor($r('app.color.muted'))
      }
      if (this.play.snapshot?.detail.status === 'completed') {
        Text('本次场次已完成。').id('gameplay-completed-state').width('100%')
          .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.accent_text'))
        if (this.play.snapshot?.presentation.completionStyle === 'finale' ||
          this.play.snapshot?.completionTarget !== null) {
          Text('终章与旅程出口尚未迁移。').id('gameplay-completion-pending').width('100%')
            .fontSize(13).lineHeight('22.1fp').fontColor($r('app.color.muted'))
        }
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
      // Short cards still need enough scroll range to reach the safe reading position.
      .constraintSize({ minHeight: this.readableQuestionId().length > 0 ?
        this.minimumQuestionRegionHeight() : 0 })
      .onAreaChange((_previous: Area, current: Area) => {
        if (this.readableQuestionId().length > 0) { this.measureCard(current); }
      })
  }

  @Builder
  gameplayScroll() {
    Scroll(this.questionScroller) {
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
          this.questionRegion()
        } else {
          Text('尚未读取题目，请重新尝试。').id('gameplay-empty').width('100%')
            .fontSize(14).lineHeight('25.2fp').fontColor($r('app.color.muted'))
          PrimaryAction({ label: '重新尝试', actionEnabled: this.interactionReady(), action: () => this.play.reload() })
        }
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: 16 + Math.max(0, this.titleBottom - this.viewportTop),
          bottom: this.bottomClearance })
    }.id('gameplay-page').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .onDidScroll(() => this.syncTitle())
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        const top: number = Number(current.globalPosition.y);
        const height: number = Number(current.height);
        if (Number.isFinite(width) && width > 0 && width !== this.viewportWidth) {
          this.viewportWidth = width;
        }
        if (Number.isFinite(top) && top >= 0 && top !== this.viewportTop) {
          this.viewportTop = top;
        }
        if (Number.isFinite(height) && height > 0 && height !== this.viewportHeight) {
          this.viewportHeight = height;
        }
        this.scheduleQuestionPosition();
      })
  }

  build() {
    Stack() {
      StarwardRefresh({ refreshEnabled: this.play.canRefresh(),
        request: async () => { await this.play.refresh(); },
        content: () => { this.gameplayScroll() } })
        .bindContentCover(!!this.viewer.visible, this.imageViewer(), this.viewerOptions())
    }.width('100%').height('100%')
      // Keep the immersive page background outside the scrolling foreground's clip.
      .clipShape(this.foregroundClip())
      .bindContentCover(!!this.recoveryVisible, this.answerRecovery(), this.recoveryOptions())
  }
}
