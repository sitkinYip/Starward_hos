import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { curves, PromptAction, promptAction, RectShape } from '@kit.ArkUI';
import { clueImageSources, ClueTextPart, clueTextParts, combinationClues, ordinaryClues } from '../business/GameplayClues';
import { GameplayClue, GameplayContentBlock, GameplayLevel, GameplayOption,
  GameplaySnapshot } from '../business/GameplayModels';
import { gameplayBgmSource } from '../business/GameplayBgm';
import { gameplayBackgroundSource } from '../business/GameplayBackground';
import { QUEST_BGM_MARGIN, QUEST_BGM_SIZE, QuestBgmPosition, questBgmCoordinate } from '../business/QuestBgmDock';
import { AppLifecycle } from '../platform/AppLifecycle';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { openExternalClueLink } from '../platform/ExternalClueLink';
import { isQuestBgmSource, QuestBgmPlayer, QuestBgmState } from '../platform/QuestBgmPlayer';
import { QuestBgmPreference } from '../platform/QuestBgmPreference';
import { QuestAnswerGuidePreference } from '../platform/QuestAnswerGuidePreference';
import { GameplayRankUp, GameplayViewModel } from './GameplayViewModel';
import { ErrorNotice, InlineError } from '../ui/ErrorMessages';
import { StarwardAnswerInput } from '../ui/StarwardAnswerInput';
import { PrimaryAction } from '../ui/PrimaryAction';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardKeyboard } from '../ui/StarwardKeyboard';
import { StarwardQuestionFrame } from '../ui/StarwardQuestionFrame';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardQuestionImages } from '../ui/StarwardQuestionImages';
import { StarwardImageViewer, StarwardImageViewerState } from '../ui/StarwardImageViewer';
import { StarwardVideoViewer, StarwardVideoViewerState } from '../ui/StarwardVideoViewer';
import { StarwardChoiceOption } from '../ui/StarwardChoiceOption';
import { StarwardQuestHint } from '../ui/StarwardQuestHint';
import { StarwardQuestFeedback } from '../ui/StarwardQuestFeedback';
import { StarwardAnswerRecovery } from '../ui/StarwardAnswerRecovery';
import { QuestionNavigationItem, StarwardQuestionNavigation } from '../ui/StarwardQuestionNavigation';
import { StarwardQuestionSwiper } from '../ui/StarwardQuestionSwiper';
import { StarwardClueArchive } from '../ui/StarwardClueArchive';
import { StarwardClueTextDialog } from '../ui/StarwardClueTextDialog';
import { StarwardCombinationDialog } from '../ui/StarwardCombinationDialog';
import { StarwardCombinationLauncher } from '../ui/StarwardCombinationLauncher';
import { StarwardCombinationNotice } from '../ui/StarwardCombinationNotice';
import { StarwardRankUpDialog } from '../ui/StarwardRankUpDialog';
import { StarwardBgmControl } from '../ui/StarwardBgmControl';
import { StarwardSyncNotice } from '../ui/StarwardSyncNotice';
import { StarwardAnswerGuide } from '../ui/StarwardAnswerGuide';
import { StarwardQuestBackground } from '../ui/StarwardQuestBackground';
import { StarwardQuestAtmosphere } from '../ui/StarwardQuestAtmosphere';

class ClueDialogRequest {
  id: number = -1;
  closing: boolean = false;
  nativeDismissed: boolean = false;
  readonly owner: string;
  readonly action: PromptAction;
  readonly combination: boolean;
  readonly sequence: boolean;
  readonly onClosed?: (dismissed: boolean) => void;

  constructor(owner: string, action: PromptAction, combination: boolean, sequence: boolean,
    onClosed?: (dismissed: boolean) => void) {
    this.owner = owner;
    this.action = action;
    this.combination = combination;
    this.sequence = sequence;
    this.onClosed = onClosed;
  }
}

class ClueLinkHandoff {
  timeout: number = -1;
  failed: boolean = false;
  readonly dialog: ClueDialogRequest | null;
  readonly isCurrent: () => boolean;

  constructor(dialog: ClueDialogRequest | null, isCurrent: () => boolean) {
    this.dialog = dialog;
    this.isCurrent = isCurrent;
  }
}

class CompletionNoticeRequest {
  id: number = -1;
  closing: boolean = false;
  acknowledged: boolean = false;
  readonly action: PromptAction;
  readonly owner: string;
  readonly count: number;
  readonly hasResults: boolean;
  readonly revision: number;

  constructor(action: PromptAction, owner: string, count: number, hasResults: boolean, revision: number) {
    this.action = action;
    this.owner = owner;
    this.count = count;
    this.hasResults = hasResults;
    this.revision = revision;
  }
}

class RankDialogRequest {
  id: number = -1;
  closing: boolean = false;
  nativeDismissed: boolean = false;
  readonly action: PromptAction;
  readonly owner: string;
  readonly rank: GameplayRankUp;

  constructor(action: PromptAction, owner: string, rank: GameplayRankUp) {
    this.action = action;
    this.owner = owner;
    this.rank = rank;
  }
}

/** Native presentation only: the account-bound ViewModel owns drafts and writes. */
@ComponentV2
export struct GameplayPage {
  @Require @Param play: GameplayViewModel;
  @Require @Param playerId: string;
  @Param autoNextDelay: number = 0;
  @Param displayFont: string = 'serif';
  @Param bottomClearance: number = 24;
  @Param titleBottom: number = 0;
  @Param statusInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
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
  private readonly imageCache: QuestionImageCache = new QuestionImageCache(() => this.imageCacheOwner());
  @Local private viewer: StarwardImageViewerState = new StarwardImageViewerState(this.imageCache);
  @Local private videoViewer: StarwardVideoViewerState = new StarwardVideoViewerState();
  @Local private textClue: GameplayClue | null = null;
  @Local private combinationSequenceActive: boolean = false;
  @Local private completionNotice: CompletionNoticeRequest | null = null;
  @Local private rankNotice: RankDialogRequest | null = null;
  private clueDialog: ClueDialogRequest | null = null;
  private combinationQueue: GameplayClue[] = [];
  private combinationOwner: string = '';
  private combinationRevision: number = 0;
  @Local private foreground: boolean = true;
  @Local private dismissedSyncEpisode: number = 0;
  @Local private backgroundRetryRevision: number = 0;
  @Local private guideAccount: string = '';
  @Local private guideSeen: boolean = true;
  @Local private guideHeight: number = 132;
  @Local private guideHighlightOwner: string = '';
  private guideHighlightTimer: number = -1;
  @Local private bgmState: QuestBgmState = 'idle';
  @Local private bgmPosition: QuestBgmPosition = new QuestBgmPosition();
  private readonly bgm: QuestBgmPlayer = new QuestBgmPlayer((state: QuestBgmState) => { this.bgmState = state; });
  private bgmMounted: boolean = false;
  private bgmPreferenceOwner: string = '';
  private bgmEnabled: boolean = true;
  private clueLinkHandoff: ClueLinkHandoff | null = null;
  private readonly clueLifecycle: (foreground: boolean) => void = (foreground: boolean) => {
    this.foreground = foreground;
    if (!foreground) {
      this.play.setPollingActive(false);
      this.clearAnswerGuideHighlight();
      this.updateBgm();
    }
    const handoff: ClueLinkHandoff | null = this.clueLinkHandoff;
    const keepHandoff: boolean = handoff !== null && handoff.isCurrent();
    const keepReading: boolean = keepHandoff && handoff?.dialog !== null;
    if (!foreground) {
      if (keepReading) { this.play.cancelRankUpPresentation(); } else { this.play.cancelAutomaticClues(); }
      this.cancelRankNotice();
    }
    this.imageCache.validateOwner();
    this.viewer.validateOwner();
    if (foreground) {
      this.clearClueLinkHandoff();
      if (this.play.visible) {
        if (keepHandoff) {
          this.play.refresh(keepReading ? this.textClue ?? undefined : undefined);
          if (handoff?.failed) { this.showClueLinkFailure(); }
        } else if (this.play.canRefresh()) {
          this.play.refresh();
        } else {
          // Re-enter with the prior recovery path for unresolved writes.
          if (this.play.retryAnswer) { this.play.reload(); }
        }
      }
      this.play.setPollingActive(true);
    } else if (keepHandoff && handoff !== null) {
      // Preserve the current reading state until the system returns to the app.
      clearTimeout(handoff.timeout);
      handoff.timeout = -1;
    } else {
      this.clearClueLinkHandoff();
      this.cancelCompletionNotice();
      this.interruptCombinationSequence();
      this.closeClueDialog(true);
      this.videoViewer.close(this.videoViewer.sessionId, true);
    }
  };
  private readonly questionScroller: Scroller = new Scroller();
  @Local private questionContentWidth: number = 0;
  @Local private explicitQuestionTarget: string = '';
  @Local private explicitQuestionRevision: number = 0;
  private cardContentTop: number = -1;
  private questionRegionHeight: number = 0;
  private titleHidden: boolean = false;
  private positionOwner: string = '';
  private positionPending: boolean = false;
  private positionTimer: number = -1;

  aboutToAppear(): void {
    this.foreground = AppLifecycle.isForeground();
    if (!this.foreground) { this.play.cancelAutomaticClues(); }
    this.bgmMounted = true;
    // A completed GET or remount is not a new successful answer.
    this.seenCompletionRevision = this.play.completionRevision;
    this.recoveryChanged();
    this.answerGuideAccountChanged();
    this.trackQuestionPosition();
    AppLifecycle.subscribe(this.clueLifecycle);
    this.play.setPollingActive(this.foreground);
    this.updateBgm();
  }

  aboutToDisappear(): void {
    AppLifecycle.unsubscribe(this.clueLifecycle);
    this.foreground = false;
    this.play.setPollingActive(false);
    this.bgmMounted = false;
    this.bgm.release();
    this.bgmPreferenceOwner = '';
    this.bgmEnabled = true;
    this.bgmPosition = new QuestBgmPosition();
    this.clearAnswerGuideHighlight();
    this.play.cancelAutomaticClues();
    this.imageCache.validateOwner();
    this.clearClueLinkHandoff();
    this.cancelCompletionNotice();
    this.cancelRankNotice();
    this.interruptCombinationSequence();
    this.closeClueDialog(true);
    this.viewer.close(this.viewer.sessionId, true);
    this.videoViewer.close(this.videoViewer.sessionId, true);
    clearTimeout(this.positionTimer);
    this.positionTimer = -1;
    this.positionPending = false;
    this.titleVisibilityChanged(false);
  }

  @Monitor('play.visible', 'play.snapshot', 'play.activeIndex', 'play.error')
  imageOwnerChanged(): void {
    if (this.guideHighlightOwner.length > 0 && this.guideHighlightOwner !== this.positionKey()) {
      this.clearAnswerGuideHighlight();
    }
    if (this.clueLinkHandoff !== null && !this.clueLinkHandoff.isCurrent()) { this.clearClueLinkHandoff(); }
    if (this.explicitQuestionTarget.length > 0 && this.explicitQuestionTarget !== this.readableQuestionId()) {
      this.explicitQuestionTarget = '';
    }
    const clue: GameplayClue | null = this.play.automaticClue;
    if (clue !== null && !this.isClueCurrent(this.imageOwner(), clue)) { this.play.cancelAutomaticClues(); }
    this.imageCache.validateOwner();
    this.viewer.validateOwner();
    this.videoViewer.validateOwner();
    if (this.combinationSequenceActive && (this.combinationOwner !== this.play.imageOwnerKey() ||
      this.currentCombinations().length === 0)) { this.interruptCombinationSequence(); }
    if (this.completionNotice !== null && !this.isCompletionNoticeCurrent(this.completionNotice)) {
      this.cancelCompletionNotice();
    }
    if (this.clueDialog !== null && this.textClue !== null &&
      !this.isDialogClueCurrent(this.clueDialog, this.textClue)) { this.closeClueDialog(true); }
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

  private backgroundSource(): string {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    if (this.playerId.length === 0 || snapshot?.detail.player !== this.playerId ||
      this.imageCacheOwner().length === 0) { return ''; }
    return gameplayBackgroundSource(snapshot, this.play.currentLevel());
  }

  private showAtmosphere(): boolean {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    return snapshot !== null && this.playerId.length > 0 && snapshot.detail.player === this.playerId &&
      (snapshot.detail.status === 'active' || snapshot.detail.status === 'completed') &&
      this.imageCacheOwner().length > 0;
  }

  private async refreshQuestion(): Promise<void> {
    if (!this.play.canRefresh()) { return; }
    const owner: string = this.imageCacheOwner();
    await this.play.refresh();
    if (owner.length > 0 && owner === this.imageCacheOwner()) {
      this.backgroundRetryRevision++;
    }
  }

  @Monitor('playerId')
  answerGuideAccountChanged(): void {
    const account: string = this.playerId;
    if (account === this.guideAccount) { return; }
    this.clearAnswerGuideHighlight();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    this.guideSeen = account.length === 0 || (context !== undefined && QuestAnswerGuidePreference.load(context, account));
    this.guideAccount = account;
  }

  private hasPendingAnswerGuide(): boolean {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    return !this.guideSeen && this.guideAccount.length > 0 && this.guideAccount === this.playerId &&
      this.play.visible && this.play.error.length === 0 && snapshot !== null &&
      snapshot.detail.player === this.guideAccount && snapshot.detail.status === 'active' &&
      snapshot.detail.totalLevels > 1 && this.readableQuestionId().length > 0 &&
      this.viewportWidth > 0 && this.viewportWidth < 1100 && this.viewportHeight > 0;
  }

  private showAnswerGuide(): boolean {
    return this.hasPendingAnswerGuide() && this.foreground && this.questionInteractionReady() &&
      this.play.automaticClue === null;
  }

  private consumeAnswerGuide(): void {
    if (!this.hasPendingAnswerGuide()) { return; }
    this.guideSeen = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context) { QuestAnswerGuidePreference.save(context, this.guideAccount); }
  }

  private editAnswer(value: string): void {
    const previous: string = this.play.draftAnswer;
    this.play.editAnswer(value);
    if (this.play.draftAnswer !== previous) { this.consumeAnswerGuide(); }
  }

  private locateAnswerForm(): void {
    if (!this.showAnswerGuide()) { return; }
    const ui: UIContext = this.getUIContext();
    let formHeight: number;
    let formTop: number;
    try {
      const geometry = ui.getComponentUtils();
      const form = geometry.getRectangleById('gameplay-answer-form');
      const viewport = geometry.getRectangleById('gameplay-page');
      formHeight = ui.px2vp(form.size.height);
      formTop = ui.px2vp(form.windowOffset.y - viewport.windowOffset.y);
    } catch {
      // A relayout can temporarily remove the form. Keep the guide available for another tap.
      return;
    }
    if (!Number.isFinite(formHeight) || formHeight <= 0 || !Number.isFinite(formTop)) { return; }
    const safeTop: number = this.foregroundTopInset();
    const safeBottom: number = Math.max(safeTop, this.viewportHeight - this.bgmBottomInset());
    const available: number = safeBottom - safeTop;
    const alignment: number = safeTop + Math.max(0, (available - formHeight) / 2);
    const target: number = Math.max(0, this.scrollOffset() + formTop - alignment);
    clearTimeout(this.positionTimer);
    this.positionTimer = -1;
    this.positionPending = false;
    this.consumeAnswerGuide();
    this.guideHighlightOwner = this.positionKey();
    this.guideHighlightTimer = setTimeout(() => this.clearAnswerGuideHighlight(), 2400);
    this.questionScroller.scrollTo({ xOffset: 0, yOffset: target,
      animation: this.reducedMotion ? false : { duration: 420, curve: Curve.EaseOut } });
  }

  private clearAnswerGuideHighlight(): void {
    clearTimeout(this.guideHighlightTimer);
    this.guideHighlightTimer = -1;
    this.guideHighlightOwner = '';
  }

  private answerGuideHighlighted(): boolean {
    return this.guideHighlightOwner.length > 0 && this.guideHighlightOwner === this.positionKey();
  }

  private guideBottomInset(): number { return Math.max(12, this.bgmBottomInset()); }

  private scrollBottomClearance(): number {
    const baseline: number = this.bottomClearance + (this.bgmSource().length > 0 ? QUEST_BGM_SIZE : 0);
    return this.showAnswerGuide() ? Math.max(baseline, this.guideBottomInset() + this.guideHeight + 12) : baseline;
  }

  private bgmSource(): string {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    if (!this.play.visible || this.play.error.length > 0 || this.playerId.length === 0 ||
      snapshot === null || snapshot.detail.player !== this.playerId) { return ''; }
    const source: string = gameplayBgmSource(snapshot, this.play.currentLevel());
    return source.length > 0 && isQuestBgmSource(source) ? source : '';
  }

  @Monitor('play.visible', 'play.snapshot', 'play.error', 'play.activeIndex', 'playerId', 'foreground',
    'videoViewer.visible', 'videoViewer.closing')
  bgmInputsChanged(): void { this.updateBgm(); }

  private updateBgm(videoOpening: boolean = false): void {
    if (!this.bgmMounted) { return; }
    const account: string = this.playerId;
    if (this.bgmPreferenceOwner !== account) {
      this.bgmPreferenceOwner = account;
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      this.bgmEnabled = context && account.length > 0 ? QuestBgmPreference.load(context, account) : true;
      this.bgmPosition = context && account.length > 0 ? QuestBgmPreference.loadPosition(context, account) :
        new QuestBgmPosition();
    }
    const source: string = this.bgmSource();
    const owner: string = source.length > 0 ? this.play.imageOwnerKey() : '';
    this.bgm.update(owner, source, this.foreground,
      videoOpening || this.videoViewer.visible || this.videoViewer.closing, this.bgmEnabled);
  }

  private showBgmControl(): boolean {
    const minimum: number = QUEST_BGM_SIZE + 2 * QUEST_BGM_MARGIN;
    return this.foreground && !this.keyboardVisible && !this.videoViewer.visible && !this.videoViewer.closing &&
      !this.viewer.visible && !this.viewer.closing && this.bgmSource().length > 0 &&
      this.viewportWidth - this.leftInset - this.rightInset >= minimum &&
      this.viewportHeight - this.foregroundTopInset() - this.bgmLayoutBottomInset() >= minimum;
  }

  private bgmBottomInset(): number { return Math.max(0, this.bottomClearance - 24); }

  private bgmLayoutBottomInset(): number {
    return this.showAnswerGuide() ? this.guideBottomInset() + this.guideHeight : this.bgmBottomInset();
  }

  private bgmLeft(): number {
    return questBgmCoordinate(this.bgmPosition.x, this.viewportWidth, this.leftInset, this.rightInset);
  }

  private bgmTop(): number {
    return questBgmCoordinate(this.bgmPosition.y, this.viewportHeight, this.foregroundTopInset(),
      this.bgmLayoutBottomInset());
  }

  private rememberBgmPosition(owner: string, x: number, y: number): void {
    if (!this.bgmMounted || !this.showBgmControl() || this.playerId !== owner || this.bgmPreferenceOwner !== owner) {
      return;
    }
    const position: QuestBgmPosition = new QuestBgmPosition(x, y);
    this.bgmPosition = position;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context) { QuestBgmPreference.savePosition(context, owner, position); }
  }

  private toggleBgm(): void {
    if (!this.showBgmControl()) { return; }
    if (this.bgmPreferenceOwner !== this.playerId) { this.updateBgm(); }
    this.bgmEnabled = this.bgmState !== 'playing' && this.bgmState !== 'loading';
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context) { QuestBgmPreference.save(context, this.playerId, this.bgmEnabled); }
    this.updateBgm();
    if (this.bgmEnabled) { this.bgm.retry(); }
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
    'play.refreshing', 'viewer.visible', 'viewer.closing', 'videoViewer.visible', 'videoViewer.closing',
    'textClue', 'completionNotice', 'combinationSequenceActive', 'rankNotice')
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
      motionEnabled: this.foreground && !this.reducedMotion && this.viewer.visible && !this.viewer.closing,
      close: this.viewerCloseAction() })
  }

  private videoViewerOptions(): ContentCoverOptions {
    const sessionId: number = this.videoViewer.sessionId;
    return { backgroundColor: '#050605', enableSafeArea: false,
      modalTransition: this.reducedMotion ? ModalTransition.NONE : ModalTransition.ALPHA,
      onWillDismiss: (action: DismissContentCoverAction) => {
        if (!this.videoViewer.exitFullscreen(sessionId)) {
          this.videoViewer.close(sessionId);
          action.dismiss();
        }
      },
      onDisappear: () => this.videoViewer.disappeared(sessionId) };
  }

  @Builder
  clueVideoViewer() {
    StarwardVideoViewer({ model: this.videoViewer, sessionId: this.videoViewer.sessionId,
      motionEnabled: this.foreground && !this.reducedMotion && this.videoViewer.visible && !this.videoViewer.closing,
      reducedMotion: this.reducedMotion })
  }

  private currentClues(): GameplayClue[] {
    return this.play.visible && this.play.error.length === 0 ?
      ordinaryClues(this.play.snapshot, this.play.currentLevel()) : [];
  }

  private isClueCurrent(owner: string, clue: GameplayClue): boolean {
    if (this.imageOwner() !== owner || !this.play.visible || this.play.error.length > 0) { return false; }
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    if (snapshot === null || snapshot.detail.player !== this.playerId) { return false; }
    const canUseSessionGrants: boolean = snapshot.detail.status === 'completed' ||
      (snapshot.detail.status === 'active' && this.play.isEntryClue(clue));
    const grants: GameplayClue[] = this.play.automaticClue === clue && canUseSessionGrants ?
      snapshot.clues : this.currentClues();
    return grants.some((actual: GameplayClue) =>
      actual.id === clue.id && JSON.stringify(actual) === JSON.stringify(clue));
  }

  private currentCombinations(): GameplayClue[] {
    return this.play.visible && this.play.error.length === 0 ? combinationClues(this.play.snapshot) : [];
  }

  private isCombinationCurrent(owner: string, clue: GameplayClue): boolean {
    return this.play.imageOwnerKey() === owner && this.currentCombinations().some((actual: GameplayClue) =>
      actual.id === clue.id && JSON.stringify(actual) === JSON.stringify(clue));
  }

  private isDialogClueCurrent(request: ClueDialogRequest, clue: GameplayClue): boolean {
    return request.combination ? this.isCombinationCurrent(request.owner, clue) : this.isClueCurrent(request.owner, clue);
  }

  private showCombinationLauncher(): boolean {
    return this.foreground && this.play.automaticClue === null && this.questionInteractionReady() &&
      this.clueDialogWidth(true) >= 160 && this.clueDialogHeight() >= 120 && this.currentCombinations().length > 0;
  }

  private openLatestCombination(): void {
    if (!this.showCombinationLauncher() || this.clueDialog !== null) { return; }
    const clues: GameplayClue[] = this.currentCombinations();
    const clue: GameplayClue | undefined = clues[clues.length - 1];
    if (clue !== undefined) { this.openClueDialog(clue, this.play.imageOwnerKey(), true); }
  }

  private interruptCombinationSequence(): void {
    if (this.combinationRevision > 0) { this.play.cancelRankUpPresentation(); }
    this.clearCombinationSequence();
  }

  private clearCombinationSequence(): void {
    this.combinationQueue = [];
    this.combinationOwner = '';
    this.combinationRevision = 0;
    this.combinationSequenceActive = false;
  }

  private showNextCombination(): void {
    if (!this.combinationSequenceActive) { return; }
    if (!this.foreground) {
      this.interruptCombinationSequence();
      return;
    }
    while (this.combinationQueue.length > 0) {
      const clue: GameplayClue | undefined = this.combinationQueue.shift();
      if (clue !== undefined && this.isCombinationCurrent(this.combinationOwner, clue)) {
        this.openClueDialog(clue, this.combinationOwner, true, true);
        return;
      }
    }
    const revision: number = this.combinationRevision;
    this.clearCombinationSequence();
    this.play.finishCompletionPresentation(revision);
  }

  private openClue(id: string): void {
    if (!this.questionInteractionReady() || this.clueDialog !== null || this.play.automaticClue !== null) { return; }
    const clue: GameplayClue | undefined = this.currentClues().find((item: GameplayClue) => item.id === id);
    if (clue === undefined) { return; }
    const owner: string = this.imageOwner();
    if (clue.kind === 'text') {
      this.openClueDialog(clue, owner);
    } else if (clue.kind === 'image') {
      this.viewer.open(clueImageSources(clue), 0, () => this.isClueCurrent(owner, clue));
    } else if (clue.kind === 'link') {
      this.launchClueLink(clue.content.url, null, () => this.isClueCurrent(owner, clue));
    } else if (clue.kind === 'video' && this.foreground) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context && this.openVideoWithBgmSuspended(clue.content.url.trim(), context.cacheDir,
        () => this.foreground && this.isClueCurrent(owner, clue))) {
        this.play.cancelAutoAdvance();
      }
    }
  }

  @Monitor('play.automaticClue', 'play.starting', 'play.submitting', 'play.refreshing', 'keyboardVisible', 'recoveryVisible',
    'foreground', 'viewportWidth', 'viewportHeight', 'textClue', 'viewer.visible', 'viewer.closing',
    'videoViewer.visible', 'videoViewer.closing')
  automaticClueChanged(): void {
    const clue: GameplayClue | null = this.play.automaticClue;
    if (clue === null || !this.foreground || this.viewportWidth <= 0 || this.viewportHeight <= 0) { return; }
    const owner: string = this.imageOwner();
    const current = (): boolean => this.foreground && this.play.automaticClue === clue &&
      this.isClueCurrent(owner, clue);
    if (!current()) {
      this.play.cancelAutomaticClues();
      return;
    }
    if (!this.questionInteractionReady()) { return; }
    const finish = (allowAdvance: boolean): void => {
      if (current()) { this.play.finishAutomaticClue(clue, allowAdvance); }
    };
    if (clue.kind === 'text') {
      this.openClueDialog(clue, owner, false, false, (dismissed: boolean) => {
        if (!current()) { return; }
        if (dismissed) { finish(true); } else { this.play.cancelAutomaticClues(); }
      });
      return;
    }
    if (clue.kind === 'image') {
      if (!this.viewer.open(clueImageSources(clue), 0, current, () => finish(true))) {
        this.play.cancelAutomaticClues();
      }
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!context || !this.openVideoWithBgmSuspended(clue.content.url.trim(), context.cacheDir, current, finish)) {
      this.play.cancelAutomaticClues();
    }
  }

  private openVideoWithBgmSuspended(source: string, cacheDir: string, ownerCurrent: () => boolean,
    finished?: (ended: boolean) => void): boolean {
    this.updateBgm(true);
    const opened: boolean = this.videoViewer.open(source, cacheDir, ownerCurrent, finished, () => this.bgm.whenQuiet());
    if (!opened) { this.updateBgm(); }
    return opened;
  }

  private clueDialogWidth(combination: boolean = false): number {
    return Math.min(combination ? 760 : 720, this.viewportWidth - 48);
  }
  private clueDialogHeight(): number {
    return this.viewportHeight - this.foregroundTopInset() - Math.max(24, this.bottomClearance) - 24;
  }

  private async openClueDialog(clue: GameplayClue, owner: string,
    combination: boolean = false, sequence: boolean = false, onClosed?: (dismissed: boolean) => void): Promise<void> {
    if (this.clueDialogWidth(combination) < 160 || this.clueDialogHeight() < 120 || this.clueDialog !== null) {
      if (sequence) { this.interruptCombinationSequence(); }
      onClosed?.(false);
      return;
    }
    let request: ClueDialogRequest;
    try {
      request = new ClueDialogRequest(owner, this.getUIContext().getPromptAction(), combination, sequence, onClosed);
    } catch {
      if (sequence) { this.interruptCombinationSequence(); }
      onClosed?.(false);
      return;
    }
    this.clueDialog = request;
    this.textClue = clue;
    const fade: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY : TransitionEffect.asymmetric(
      TransitionEffect.opacity(0).animation({ duration: 320, curve: Curve.EaseOut }),
      TransitionEffect.opacity(0).animation({ duration: 240, curve: Curve.EaseIn }));
    const dialogTransition: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.asymmetric(
        TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 14 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 320, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }),
        TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 14 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 240, curve: curves.cubicBezierCurve(0.4, 0, 0.8, 0.4) }));
    const options: promptAction.CustomDialogOptions = {
      builder: () => { this.clueDialogContent(request); },
      alignment: DialogAlignment.Center, width: this.clueDialogWidth(combination), cornerRadius: 0,
      isModal: true, autoCancel: !combination, showInSubWindow: false,
      backgroundColor: combination ? $r('app.color.combination_surface') : $r('app.color.raised'),
      maskColor: combination ? $r('app.color.combination_mask') : $r('app.color.clue_mask'),
      dialogTransition, maskTransition: fade,
      onWillDismiss: (action: DismissDialogAction) => {
        if (combination && action.reason === DismissReason.TOUCH_OUTSIDE) { return; }
        if (this.clueDialog === request && (this.viewer.visible || this.viewer.closing)) {
          if (this.viewer.visible) { this.viewer.close(this.viewer.sessionId); }
        } else {
          request.closing = true;
          request.nativeDismissed = true;
          action.dismiss();
        }
      },
      onDidDisappear: () => this.releaseClueDialog(request, true)
    };
    try {
      request.id = await request.action.openCustomDialog(options);
      if (!request.nativeDismissed &&
        (request.closing || this.clueDialog !== request || !this.isDialogClueCurrent(request, clue))) {
        this.finishClueDialogClose(request);
      }
    } catch {
      if (sequence && this.clueDialog === request) { this.interruptCombinationSequence(); }
      this.releaseClueDialog(request);
    }
  }

  private finishClueDialogClose(request: ClueDialogRequest): void {
    if (request.id < 0 || request.nativeDismissed) { return; }
    try { request.action.closeCustomDialog(request.id); } catch {
      if (request.sequence && this.clueDialog === request) { this.interruptCombinationSequence(); }
      this.releaseClueDialog(request);
    }
  }

  private closeClueDialog(invalidOwner: boolean = false): void {
    const request: ClueDialogRequest | null = this.clueDialog;
    if (request === null) { return; }
    if (!invalidOwner && (this.viewer.visible || this.viewer.closing)) {
      if (this.viewer.visible) { this.viewer.close(this.viewer.sessionId); }
      return;
    }
    const closing: boolean = request.closing;
    request.closing = true;
    if (invalidOwner) {
      if (request.sequence) { this.interruptCombinationSequence(); }
      this.viewer.close(this.viewer.sessionId, true);
      this.viewer.disappeared(this.viewer.sessionId);
      this.releaseClueDialog(request);
    }
    if (!closing) { this.finishClueDialogClose(request); }
  }

  private releaseClueDialog(request: ClueDialogRequest, dismissed: boolean = false): void {
    if (this.clueDialog === request) {
      if (this.clueLinkHandoff?.dialog === request) { this.clearClueLinkHandoff(); }
      this.clueDialog = null;
      this.textClue = null;
      if (dismissed && request.sequence) { this.showNextCombination(); }
      request.onClosed?.(dismissed);
    }
  }

  private currentTextClueOwner(owner: string): boolean {
    return this.clueDialog?.owner === owner && !this.clueDialog.closing && this.textClue !== null &&
      this.isDialogClueCurrent(this.clueDialog, this.textClue);
  }

  private clearClueLinkHandoff(): void {
    if (this.clueLinkHandoff !== null) { clearTimeout(this.clueLinkHandoff.timeout); }
    this.clueLinkHandoff = null;
  }

  private openClueLink(request: ClueDialogRequest, href: string): void {
    if (this.viewer.visible || this.viewer.closing) { return; }
    this.launchClueLink(href, request, () => this.clueDialog === request && this.currentTextClueOwner(request.owner));
  }

  private showClueLinkFailure(): void {
    StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。');
  }

  private async launchClueLink(href: string, dialog: ClueDialogRequest | null,
    isCurrent: () => boolean): Promise<void> {
    if (!this.foreground || this.clueLinkHandoff !== null || !isCurrent()) { return; }
    const handoff: ClueLinkHandoff = new ClueLinkHandoff(dialog, isCurrent);
    this.clueLinkHandoff = handoff;
    this.play.cancelAutoAdvance();
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      const opened: boolean = await openExternalClueLink(context, href);
      if (this.foreground && this.clueLinkHandoff === handoff) {
        if (!opened) {
          this.clearClueLinkHandoff();
        } else {
          // The system may open the target without moving this window to the background.
          handoff.timeout = setTimeout(() => {
            if (this.clueLinkHandoff === handoff) { this.clearClueLinkHandoff(); }
          }, 8000);
        }
      }
    } catch {
      if (this.clueLinkHandoff !== handoff) { return; }
      if (!this.foreground) { handoff.failed = true; return; }
      this.clearClueLinkHandoff();
      if (isCurrent()) { this.showClueLinkFailure(); }
    }
  }

  private openInlineClueImage(partIndex: number): void {
    const clue: GameplayClue | null = this.textClue;
    const owner: string = this.clueDialog?.owner || '';
    if (clue === null || !this.currentTextClueOwner(owner)) { return; }
    const parts: ClueTextPart[] = clueTextParts(clue.content.text);
    if ((parts[partIndex]?.image || '').length === 0) { return; }
    const sources: string[] = parts.filter((part: ClueTextPart) => part.image.length > 0)
      .map((part: ClueTextPart) => part.image);
    const index: number = parts.slice(0, partIndex).filter((part: ClueTextPart) => part.image.length > 0).length;
    this.viewer.open(sources, index, () => this.textClue === clue && this.currentTextClueOwner(owner));
  }

  @Builder
  clueDialogContent(request: ClueDialogRequest) {
    if (this.clueDialog === request && this.textClue !== null) {
      if (request.combination) {
        StarwardCombinationDialog({ clue: this.textClue, ownerKey: request.owner,
          ownerIsCurrent: (owner: string) => this.currentTextClueOwner(owner),
          imageCache: this.imageCache,
          panelWidth: this.clueDialogWidth(true), maxHeight: this.clueDialogHeight(), displayFont: this.displayFont,
          motionEnabled: this.foreground && !this.reducedMotion && !this.viewer.visible && !this.viewer.closing,
          reducedMotion: this.reducedMotion, acknowledge: () => this.closeClueDialog(),
          openImage: (index: number) => this.openInlineClueImage(index),
          openLink: (href: string) => this.openClueLink(request, href) })
          .bindContentCover(!!this.viewer.visible, this.imageViewer(), this.viewerOptions())
      } else {
        StarwardClueTextDialog({ clue: this.textClue, ownerKey: request.owner,
          ownerIsCurrent: (owner: string) => this.currentTextClueOwner(owner),
          imageCache: this.imageCache,
          panelWidth: this.clueDialogWidth(), maxHeight: this.clueDialogHeight(), displayFont: this.displayFont,
          motionEnabled: this.foreground && !this.reducedMotion && !this.viewer.visible && !this.viewer.closing,
          reducedMotion: this.reducedMotion, close: () => this.closeClueDialog(),
          openImage: (index: number) => this.openInlineClueImage(index),
          openLink: (href: string) => this.openClueLink(request, href) })
          .bindContentCover(!!this.viewer.visible, this.imageViewer(), this.viewerOptions())
      }
    }
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
      motionEnabled: this.foreground && !this.reducedMotion && this.recoveryVisible,
      retry: () => this.retryAnswer(), stay: () => this.stayOnQuestion() })
  }

  private isCompletionNoticeCurrent(request: CompletionNoticeRequest): boolean {
    return this.completionNotice === request && this.foreground && this.play.visible && this.play.error.length === 0 &&
      this.play.snapshot?.detail.status === 'completed' && this.play.imageOwnerKey() === request.owner &&
      (!request.hasResults || this.combinationQueue.some((clue: GameplayClue) =>
        this.isCombinationCurrent(request.owner, clue)));
  }

  @Builder
  combinationNoticeContent(request: CompletionNoticeRequest, width: number, height: number) {
    if (this.completionNotice === request) {
      StarwardCombinationNotice({ completedCount: request.count, hasResults: request.hasResults,
        panelWidth: width, maxHeight: height, viewportWidth: this.viewportWidth, displayFont: this.displayFont,
        motionEnabled: this.foreground && !this.reducedMotion,
        acknowledge: () => {
          if (request.closing || !this.isCompletionNoticeCurrent(request)) { return; }
          request.acknowledged = request.hasResults;
          request.closing = true;
          this.closeCompletionNotice(request);
        } })
    }
  }

  private async openCompletionNotice(owner: string, count: number, hasResults: boolean, revision: number): Promise<void> {
    const width: number = Math.min(680, this.viewportWidth - 48);
    const height: number = this.clueDialogHeight();
    if (width < 160 || height < 120) {
      this.interruptCombinationSequence();
      this.play.cancelRankUpPresentation();
      return;
    }
    let request: CompletionNoticeRequest;
    try {
      request = new CompletionNoticeRequest(this.getUIContext().getPromptAction(), owner, count, hasResults, revision);
    } catch {
      this.interruptCombinationSequence();
      this.play.cancelRankUpPresentation();
      return;
    }
    this.completionNotice = request;
    const fade: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY : TransitionEffect.asymmetric(
      TransitionEffect.opacity(0).animation({ duration: 320, curve: Curve.EaseOut }),
      TransitionEffect.opacity(0).animation({ duration: 240, curve: Curve.EaseIn }));
    const dialogTransition: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.asymmetric(
        TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 14 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 320, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }),
        TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 14 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 240, curve: curves.cubicBezierCurve(0.4, 0, 0.8, 0.4) }));
    try {
      request.id = await request.action.openCustomDialog({
        builder: () => { this.combinationNoticeContent(request, width, height); },
        alignment: DialogAlignment.Center, width: width, cornerRadius: 0, isModal: true, showInSubWindow: false,
        backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.NONE,
        maskColor: $r('app.color.completion_mask'), dialogTransition: dialogTransition, maskTransition: fade,
        autoCancel: !hasResults, onWillDismiss: hasResults ? () => {} : undefined,
        onDidDisappear: () => this.releaseCompletionNotice(request, true)
      });
      if (request.closing || !this.isCompletionNoticeCurrent(request)) { this.closeCompletionNotice(request); }
    } catch {
      this.releaseCompletionNotice(request);
    }
  }

  private closeCompletionNotice(request: CompletionNoticeRequest): void {
    if (request.id < 0) { return; }
    try { request.action.closeCustomDialog(request.id); } catch { this.releaseCompletionNotice(request); }
  }

  private cancelCompletionNotice(): void {
    const request: CompletionNoticeRequest | null = this.completionNotice;
    if (request === null) { return; }
    const closing: boolean = request.closing;
    request.closing = true;
    this.releaseCompletionNotice(request);
    if (!closing) { this.closeCompletionNotice(request); }
  }

  private releaseCompletionNotice(request: CompletionNoticeRequest, dismissed: boolean = false): void {
    if (this.completionNotice !== request) { return; }
    const completed: boolean = dismissed && this.isCompletionNoticeCurrent(request);
    this.completionNotice = null;
    if (completed && request.acknowledged) {
      this.showNextCombination();
    } else {
      this.interruptCombinationSequence();
      if (completed && !request.hasResults) {
        this.play.finishCompletionPresentation(request.revision);
      } else {
        this.play.cancelRankUpPresentation();
      }
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
    if (!this.foreground || !this.play.visible || snapshot === null || snapshot.detail.status !== 'completed') {
      return;
    }
    if (snapshot.presentation.completionStyle === 'finale') {
      StarwardFeedback.notice(this.getUIContext(), '本次场次已完成', '全部题目已经完成。终章内容尚未迁移。');
    } else if (snapshot.detail.totalLevels > 1) {
      this.cancelCompletionNotice();
      const owner: string = this.play.imageOwnerKey();
      this.combinationQueue = this.play.completionClues.filter((clue: GameplayClue) =>
        this.isCombinationCurrent(owner, clue));
      const hasResults: boolean = this.combinationQueue.length > 0;
      if (hasResults) {
        this.combinationOwner = owner;
        this.combinationRevision = revision;
        this.combinationSequenceActive = true;
      }
      this.openCompletionNotice(owner, snapshot.detail.completedLevels, hasResults, revision);
    }
  }

  @Monitor('play.rankUp', 'play.visible', 'play.error', 'play.snapshot', 'play.automaticClue',
    'play.loading', 'play.starting', 'play.submitting', 'play.refreshing', 'seenCompletionRevision',
    'completionNotice', 'combinationSequenceActive', 'keyboardVisible', 'foreground', 'recoveryVisible',
    'textClue', 'viewer.visible', 'viewer.closing', 'videoViewer.visible', 'videoViewer.closing',
    'viewportWidth', 'viewportHeight')
  rankChanged(): void {
    if (this.rankNotice !== null) {
      if (!this.isRankNoticeCurrent(this.rankNotice)) { this.cancelRankNotice(); }
      return;
    }
    const rank: GameplayRankUp | null = this.play.rankUp;
    const width: number = Math.min(680, this.viewportWidth - (this.viewportWidth <= 620 ? 28 : 48));
    const height: number = this.clueDialogHeight();
    if (rank === null || !this.foreground || !this.play.visible || this.play.error.length > 0 ||
      this.play.imageOwnerKey().length === 0 || this.play.automaticClue !== null ||
      this.seenCompletionRevision !== this.play.completionRevision || !this.questionInteractionReady() ||
      width < 160 || height < 120) { return; }
    this.openRankNotice(rank, width, height);
  }

  private isRankNoticeCurrent(request: RankDialogRequest): boolean {
    return this.rankNotice === request && this.play.rankUp === request.rank && this.foreground && this.play.visible &&
      this.play.error.length === 0 && this.play.imageOwnerKey() === request.owner;
  }

  @Builder
  rankNoticeContent(request: RankDialogRequest, width: number, height: number) {
    if (this.rankNotice === request) {
      StarwardRankUpDialog({ rankOrder: request.rank.order, rankName: request.rank.name,
        panelWidth: width, maxHeight: height, viewportWidth: this.viewportWidth, displayFont: this.displayFont,
        motionEnabled: this.foreground && !this.reducedMotion,
        acknowledge: () => {
          if (request.closing || !this.isRankNoticeCurrent(request)) { return; }
          request.closing = true;
          this.closeRankNotice(request);
        } })
    }
  }

  private async openRankNotice(rank: GameplayRankUp, width: number, height: number): Promise<void> {
    let request: RankDialogRequest;
    try {
      request = new RankDialogRequest(this.getUIContext().getPromptAction(), this.play.imageOwnerKey(), rank);
    } catch {
      this.play.dismissRankUp(rank);
      return;
    }
    this.rankNotice = request;
    const maskTransition: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.asymmetric(
        TransitionEffect.opacity(0).animation({ duration: 320, curve: Curve.EaseOut }),
        TransitionEffect.opacity(0).animation({ duration: 240, curve: Curve.EaseIn }));
    const dialogTransition: TransitionEffect = this.reducedMotion ? TransitionEffect.IDENTITY :
      TransitionEffect.asymmetric(
        TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 14 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 320, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }),
        TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 14 }))
          .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
          .animation({ duration: 240, curve: curves.cubicBezierCurve(0.4, 0, 0.8, 0.4) }));
    try {
      request.id = await request.action.openCustomDialog({
        builder: () => { this.rankNoticeContent(request, width, height); },
        alignment: DialogAlignment.Center, width, cornerRadius: 0, isModal: true, showInSubWindow: false,
        backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.NONE,
        maskColor: $r('app.color.rank_up_mask'), dialogTransition, maskTransition, autoCancel: false,
        onWillDismiss: (action: DismissDialogAction) => {
          if (action.reason === DismissReason.TOUCH_OUTSIDE) { return; }
          request.closing = true;
          request.nativeDismissed = true;
          action.dismiss();
        },
        onDidDisappear: () => this.releaseRankNotice(request)
      });
      if (request.closing || !this.isRankNoticeCurrent(request)) { this.closeRankNotice(request); }
    } catch {
      this.releaseRankNotice(request);
    }
  }

  private closeRankNotice(request: RankDialogRequest): void {
    if (request.id < 0 || request.nativeDismissed) { return; }
    try { request.action.closeCustomDialog(request.id); } catch { this.releaseRankNotice(request); }
  }

  private cancelRankNotice(): void {
    const request: RankDialogRequest | null = this.rankNotice;
    if (request === null) { return; }
    const wasClosing: boolean = request.closing;
    request.closing = true;
    this.releaseRankNotice(request);
    if (!wasClosing) { this.closeRankNotice(request); }
  }

  private releaseRankNotice(request: RankDialogRequest): void {
    if (this.rankNotice !== request) { return; }
    this.rankNotice = null;
    this.play.dismissRankUp(request.rank);
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

  private requestQuestionSettle(index: number): void {
    const target: string = this.play.snapshot?.levels[index]?.id ?? '';
    if (target.length > 0 && target !== this.readableQuestionId() && this.answerMotionEnabled()) {
      this.explicitQuestionTarget = target;
      this.explicitQuestionRevision++;
    }
  }

  private selectQuestion(index: number, directAction: boolean = true): void {
    if (!this.interactionReady() || this.recoveryVisible || !this.play.canMoveTo(index)) {
      return;
    }
    if (directAction) { this.requestQuestionSettle(index); }
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.moveTo(index);
    this.trackQuestionPosition(true);
  }

  private selectSwipedQuestion(id: string): boolean {
    const index: number = this.play.snapshot?.levels.findIndex((level: GameplayLevel) => level.id === id) ?? -1;
    if (!this.questionInteractionReady() || Math.abs(index - this.play.activeIndex) !== 1 || !this.play.canMoveTo(index)) {
      return false;
    }
    this.selectQuestion(index, false);
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

  private showsQuestionImages(id: string): boolean {
    if (id === this.readableQuestionId()) { return true; }
    if (!this.foreground) { return false; }
    const levels: GameplayLevel[] = this.play.snapshot?.levels || [];
    const previous: GameplayLevel | undefined = levels[this.play.activeIndex - 1];
    const next: GameplayLevel | undefined = levels[this.play.activeIndex + 1];
    return (previous?.id === id && previous.question !== null) || (next?.id === id && next.question !== null);
  }

  private questionImageOwner(id: string): string { return `${this.play.imageOwnerKey()}:${id}`; }

  private imageOwner(): string { return this.questionImageOwner(this.play.currentLevel()?.id || ''); }

  private imageCacheOwner(): string {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    return this.foreground && this.play.visible && this.play.error.length === 0 && snapshot !== null &&
      snapshot.detail.status !== 'cancelled' ? this.play.imageOwnerKey() : '';
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
      this.textClue === null && !this.viewer.visible && !this.viewer.closing &&
      !this.videoViewer.visible && !this.videoViewer.closing &&
      !this.combinationSequenceActive && this.completionNotice === null && this.rankNotice === null;
  }

  private answerMotionEnabled(): boolean {
    return this.foreground && !this.reducedMotion && !this.recoveryVisible && this.textClue === null &&
      !this.viewer.visible && !this.viewer.closing && !this.videoViewer.visible && !this.videoViewer.closing &&
      !this.combinationSequenceActive && this.completionNotice === null && this.rankNotice === null;
  }

  private hasAnswerFeedback(): boolean {
    return !this.play.retryAnswer && (this.play.answerError.length > 0 || this.play.feedback.length > 0);
  }

  private answerFeedbackDanger(): boolean { return this.play.answerError.length > 0 || this.play.feedbackDanger; }

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
      reducedMotion: this.reducedMotion, motionEnabled: this.answerMotionEnabled(),
      select: (index: number) => this.selectQuestion(index) })
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
          imageCache: this.imageCache,
          reducedMotion: !this.answerMotionEnabled(), chosen: () => this.editAnswer(key),
          opened: () => this.openOptionImage(key) })
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
          changed: (value: string) => this.editAnswer(value) })
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
          .enabled(this.interactionReady()).onClick(() => {
            this.requestQuestionSettle(this.play.activeIndex + 1);
            this.play.nextQuestion();
          })
      }
      if (this.hasAnswerFeedback()) {
        ForEach([this.play.feedbackVersion], (_version: number) => {
          StarwardQuestFeedback({
            message: this.play.answerError.length > 0 ? this.play.answerError : this.play.feedback,
            messageId: this.play.answerError.length > 0 ? 'gameplay-answer-error' : 'gameplay-feedback-message',
            danger: this.answerFeedbackDanger(),
            transient: this.play.feedbackTransient, motionEnabled: this.answerMotionEnabled()
          })
        }, (version: number) => version.toString())
      }
    }.id('gameplay-answer-form').width('100%').alignItems(HorizontalAlign.Start)
      .outlineWidth(1).outlineRadius(2)
      .outlineColor(this.answerGuideHighlighted() ? $r('app.color.accent') : Color.Transparent)
      .backgroundColor(this.answerGuideHighlighted() ? $r('app.color.accent_faint') : Color.Transparent)
      .animation({ duration: this.reducedMotion ? 0 : 480, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) })
      .shadow({ radius: this.getUIContext().vp2px(52),
        color: this.answerGuideHighlighted() ? $r('app.color.quest_avatar_glow') : Color.Transparent })
      .animation({ duration: this.reducedMotion ? 0 : 620, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) })
      .accessibilityDescription(this.answerGuideHighlighted() ? '已定位到当前答题区' : '')
  }

  @Builder
  questionCard(levelId: string) {
    StarwardQuestionFrame({
      frameId: levelId === this.readableQuestionId() ? 'gameplay-question-card' : '',
      motionEnabled: levelId === this.readableQuestionId() && this.answerMotionEnabled(),
      selectionRevision: levelId === this.explicitQuestionTarget ? this.explicitQuestionRevision : 0,
      feedbackVersion: levelId === this.readableQuestionId() && this.hasAnswerFeedback() ? this.play.feedbackVersion : 0,
      feedbackDanger: this.answerFeedbackDanger(),
      feedbackSuccess: !this.answerFeedbackDanger() && this.currentCompleted()
    }) {
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
              if (this.showsQuestionImages(levelId) && this.blockImages(block).length > 0 && block.videoUrl.length === 0) {
                StarwardQuestionImages({ sources: this.blockImages(block), ownerKey: this.questionImageOwner(levelId),
                  ownerIsCurrent: (key: string) => this.play.visible && this.play.snapshot !== null &&
                    this.showsQuestionImages(levelId) && key === this.questionImageOwner(levelId),
                  imageCache: this.imageCache, active: levelId === this.readableQuestionId(),
                  availableWidth: this.questionContentWidth,
                  groupId: levelId === this.readableQuestionId() ? `question-images-${index}` :
                    `question-preview-${this.levelById(levelId)?.position || 0}-${index}`,
                  maxHeight: this.viewportWidth <= 620 ? 340 : 420, reducedMotion: this.reducedMotion,
                  opened: (imageIndex: number) => {
                    if (levelId === this.readableQuestionId()) { this.openImages(index, imageIndex); }
                  } })
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
          .onAreaChange((_previous: Area, current: Area) => {
            const width: number = Number(current.width);
            if (levelId === this.readableQuestionId() && Number.isFinite(width) && width > 2 &&
              width !== this.questionContentWidth) { this.questionContentWidth = width; }
          })
        if (levelId === this.readableQuestionId()) {
          Column() {
            this.answerForm()
          }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 24 })
          if (this.currentClues().length > 0) {
            StarwardClueArchive({ clues: this.currentClues(), displayFont: this.displayFont,
              motionEnabled: this.foreground && !this.reducedMotion && this.questionInteractionReady(),
              reducedMotion: this.reducedMotion,
              opened: (id: string) => this.openClue(id) })
          }
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
                .enabled(this.play.canRefresh()).onClick(() => { this.refreshQuestion(); })
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
          bottom: this.scrollBottomClearance() })
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
      .bindContentCover(this.videoViewer.visible, this.clueVideoViewer(), this.videoViewerOptions())
  }

  @Builder
  gameplayForeground() {
    Stack() {
      StarwardRefresh({ refreshEnabled: this.play.canRefresh(),
        request: () => this.refreshQuestion(),
        content: () => { this.gameplayScroll() } })
        .bindContentCover(this.textClue === null && this.viewer.visible, this.imageViewer(), this.viewerOptions())
      if (this.showCombinationLauncher()) {
        StarwardCombinationLauncher({ viewportWidth: this.viewportWidth, viewportHeight: this.viewportHeight,
          topInset: this.foregroundTopInset(), bottomInset: this.bgmBottomInset(),
          bgmLeft: this.showBgmControl() ? this.bgmLeft() : -1,
          bgmTop: this.showBgmControl() ? this.bgmTop() : -1,
          reducedMotion: this.reducedMotion, open: () => this.openLatestCombination() })
      }
      if (this.showBgmControl()) {
        StarwardBgmControl({ state: this.bgmState, reducedMotion: this.reducedMotion,
          viewportWidth: this.viewportWidth, viewportHeight: this.viewportHeight,
          topInset: this.foregroundTopInset(), leftInset: this.leftInset, rightInset: this.rightInset,
          bottomInset: this.bgmLayoutBottomInset(), savedX: this.bgmPosition.x, savedY: this.bgmPosition.y,
          ownerKey: this.playerId, positionCommitted: (owner: string, x: number, y: number) => {
            this.rememberBgmPosition(owner, x, y);
          }, toggle: () => this.toggleBgm() })
      }
      if (this.showAnswerGuide()) {
        Column() {
          StarwardAnswerGuide({ reducedMotion: this.reducedMotion,
            dismiss: () => { if (this.showAnswerGuide()) { this.consumeAnswerGuide(); } },
            locate: () => this.locateAnswerForm(),
            measured: (height: number) => {
              if (Number.isFinite(height) && height > 0 && this.guideHeight !== height) { this.guideHeight = height; }
            } })
        }.width('100%').height('100%').justifyContent(FlexAlign.End)
          .padding({ bottom: this.guideBottomInset(), left: Math.max(12, this.leftInset),
            right: Math.max(12, this.rightInset) })
          .hitTestBehavior(HitTestMode.None)
      }
      if (this.foreground && this.play.syncEpisode > 0 && this.play.syncEpisode !== this.dismissedSyncEpisode &&
        this.play.error.length === 0) {
        Column() {
          StarwardSyncNotice({ reducedMotion: this.reducedMotion,
            dismiss: () => { this.dismissedSyncEpisode = this.play.syncEpisode; } })
        }.width('100%').align(Alignment.Top).alignItems(HorizontalAlign.Center)
          .padding({ top: Math.max(16, this.foregroundTopInset()),
            left: 16 + this.leftInset, right: 16 + this.rightInset })
          .hitTestBehavior(HitTestMode.Transparent)
      }
    }.width('100%').height('100%').alignContent(Alignment.Top)
      .clipShape(this.foregroundClip())
      .bindContentCover(!!this.recoveryVisible, this.answerRecovery(), this.recoveryOptions())
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.backgroundSource().length > 0) {
        StarwardQuestBackground({ source: this.backgroundSource(), ownerKey: this.imageCacheOwner(),
          sourceIsCurrent: (owner: string, source: string) => owner === this.imageCacheOwner() &&
            source === this.backgroundSource(),
          imageCache: this.imageCache, retryRevision: this.backgroundRetryRevision })
      }
      if (this.showAtmosphere()) {
        StarwardQuestAtmosphere({ reducedMotion: this.reducedMotion })
      }
      this.gameplayForeground()
    }.width('100%').height('100%')
  }
}
