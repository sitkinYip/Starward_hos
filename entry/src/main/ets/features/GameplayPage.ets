import { common } from '@kit.AbilityKit';
import { curves, LengthMetrics, PromptAction, promptAction } from '@kit.ArkUI';
import { GameNotification } from '../business/GameNotification';
import { clueImageSources, combinationClues, isNarrativeClue,
  nextNarrativeAttention, ordinaryClues } from '../business/GameplayClues';
import { GameplayClue, GameplayCompletionTarget, GameplayContentBlock, GameplayLevel, GameplayOption,
  GameplaySnapshot } from '../business/GameplayModels';
import { QUEST_BGM_MARGIN, QUEST_BGM_SIZE, questBgmCoordinate } from '../business/QuestBgmDock';
import { AppLifecycle } from '../platform/AppLifecycle';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageResult } from '../platform/QuestionImageLoader';
import { externalClueLinkHref, openExternalClueLink } from '../platform/ExternalClueLink';
import { AssignmentAtmosphereState } from './AssignmentAtmosphereState';
import { QuestNarrativeAttentionPreference } from '../platform/QuestNarrativeAttentionPreference';
import { GameplayAnswerBurst, GameplayRankUp, GameplayViewModel } from './GameplayViewModel';
import { GAMEPLAY_COMPOSER_MIN_HEIGHT, GAMEPLAY_COMPOSER_SIDE_GUTTER, GAMEPLAY_MAX_CONTENT_WIDTH,
  GAMEPLAY_TITLE_CLEARANCE, GAMEPLAY_TITLE_MIN_TOP, GAMEPLAY_TITLE_SIDE_GUTTER, GameplayFloatingTitle,
  GameplayProgress, GameplayProgressItem, GameplayQuestionHeading, GameplaySurface } from './GameplayChrome';
import { GameplayAnswerComposer, GameplayComposerAction, GameplayComposerView } from './GameplayAnswerComposer';
import { GameplayHintSheet } from './GameplayQuestionOverlays';
import { JourneyNotificationsViewModel } from './JourneyNotificationsViewModel';
import { isLegacyInternalLink, LegacyRichBlock, LegacyRichSpan, legacyImageSources,
  legacyRichBlocks } from '../business/LegacyRichContent';
import { InlineError } from '../ui/ErrorMessages';
import { StarwardAssignmentRequest } from '../ui/StarwardAssignmentRequest';
import { PrimaryAction } from '../ui/PrimaryAction';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardKeyboard } from '../ui/StarwardKeyboard';
import { StarwardGlassDialog } from '../ui/StarwardGlassDialog';
import { StarwardModalBackdropState } from '../ui/StarwardGlassBackdrop';
import { starwardMediaCoverOptions } from '../ui/StarwardMediaCover';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardQuestionImages } from '../ui/StarwardQuestionImages';
import { StarwardImageViewer, StarwardImageViewerState } from '../ui/StarwardImageViewer';
import { StarwardVideoViewer, StarwardVideoViewerState } from '../ui/StarwardVideoViewer';
import { StarwardVideoPoster } from '../ui/StarwardVideoPoster';
import { StarwardChoiceOption } from '../ui/StarwardChoiceOption';
import { StarwardRichContent } from '../ui/StarwardRichContent';
import { StarwardQuestFeedback } from '../ui/StarwardQuestFeedback';
import { StarwardAnswerRecovery } from '../ui/StarwardAnswerRecovery';
import { StarwardQuestionSwiper } from '../ui/StarwardQuestionSwiper';
import { StarwardClueArchive } from '../ui/StarwardClueArchive';
import { StarwardQuestMessages } from '../ui/StarwardQuestMessages';
import { StarwardNarrativeAttention } from '../ui/StarwardNarrativeAttention';
import { StarwardClueTextDialog } from '../ui/StarwardClueTextDialog';
import { StarwardCombinationDialog } from '../ui/StarwardCombinationDialog';
import { StarwardCombinationLauncher } from '../ui/StarwardCombinationLauncher';
import { StarwardCombinationNotice } from '../ui/StarwardCombinationNotice';
import { StarwardFinalDestination } from '../ui/StarwardFinalDestination';
import { StarwardRankUpDialog } from '../ui/StarwardRankUpDialog';
import { StarwardStarBurstOverlay } from '../ui/StarwardStarBurstOverlay';
import { StarwardBgmControl } from '../ui/StarwardBgmControl';
import { StarwardSyncNotice } from '../ui/StarwardSyncNotice';
import { JOURNEY_LAUNCHER_SIZE, JourneyDockObstacle, StarwardJourneyLauncher } from '../ui/StarwardJourneyLauncher';
import { StarwardJourneyNotificationDialog } from '../ui/StarwardJourneyNotificationDialog';

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
  readonly finale: boolean;

  constructor(action: PromptAction, owner: string, count: number, hasResults: boolean, revision: number, finale: boolean) {
    this.action = action;
    this.owner = owner;
    this.count = count;
    this.hasResults = hasResults;
    this.revision = revision;
    this.finale = finale;
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

type GameplaySheet = 'hint' | 'choice';

interface GameplayFeedbackPosition {
  revision: number;
  owner: string;
  contentTop: number;
  height: number;
}

/** Native presentation only: the account-bound ViewModel owns drafts and writes. */
@ComponentV2
export struct GameplayPage {
  @Consumer('starwardModalBackdrop') private modalBackdrop: StarwardModalBackdropState =
    new StarwardModalBackdropState();
  @Event journeyBackHandlerChanged: (handler: (() => boolean) | null) => void = () => {};
  @Event profilePollingChanged: (active: boolean) => void = () => {};
  @Require @Param play: GameplayViewModel;
  @Require @Param journey: JourneyNotificationsViewModel;
  @Require @Param atmosphere: AssignmentAtmosphereState;
  @Require @Param atmosphereOwner: string;
  @Require @Param playerId: string;
  @Param autoNextDelay: number = 0;
  @Param displayFont: string = 'serif';
  @Param bottomClearance: number = 24;
  @Param statusInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param keyboardVisible: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param narrativeCovered: boolean = false;
  @Param accountCovered: boolean = false;
  @Param journeyPollingAllowed: boolean = false;
  @Event leave: () => void = () => {};
  @Event openNarrative: (assignmentId: string, contentId: string) => void = () => {};
  @Event openNarrativeClue: (assignmentId: string, clueId: string, contentId: string) => boolean = () => false;
  @Event openJourneyLink: (href: string) => boolean = () => false;
  @Event openInbox: () => void = () => {};
  @Event finaleBackdropChanged: (visible: boolean) => void = () => {};
  @Local seenCompletionRevision: number = 0;
  @Local private recoveryVisible: boolean = false;
  @Local private recoveryDismissed: boolean = false;
  @Local viewportWidth: number = 0;
  @Local private viewportTop: number = 0;
  @Local private viewportHeight: number = 0;
  private readonly imageCache: QuestionImageCache = new QuestionImageCache(() => this.imageCacheOwner());
  @Local private viewer: StarwardImageViewerState = new StarwardImageViewerState(this.imageCache);
  @Local private videoViewer: StarwardVideoViewerState = new StarwardVideoViewerState();
  @Local private inlineVideo: StarwardVideoViewerState = new StarwardVideoViewerState(true);
  @Local private inlineVideoSlot: string = '';
  private inlineVideoRevision: number = 0;
  @Local private textClue: GameplayClue | null = null;
  @Local private combinationSequenceActive: boolean = false;
  @Local private completionNotice: CompletionNoticeRequest | null = null;
  @Local private destinationHeight: number = 0;
  @Local private destinationLaunching: boolean = false;
  @Local private rankNotice: RankDialogRequest | null = null;
  @Local private journeyVideoOpen: boolean = false;
  @Local private combinationDock: JourneyDockObstacle | null = null;
  private clueDialog: ClueDialogRequest | null = null;
  private combinationQueue: GameplayClue[] = [];
  private combinationOwner: string = '';
  private combinationRevision: number = 0;
  @Local private foreground: boolean = true;
  @Local private titleHidden: boolean = false;
  @Local private answerFocused: boolean = false;
  @Local private composerHeight: number = GAMEPLAY_COMPOSER_MIN_HEIGHT;
  @Local private sheet: GameplaySheet | null = null;
  @Local private sheetVisible: boolean = false;
  private sheetOwner: string = '';
  @Local private sheetRevision: number = 0;
  private sheetMounted: boolean = false;
  private journeyBack: (() => boolean) | null = null;
  private lastScrollOffset: number = 0;
  private scrollMomentum: number = 0;
  private consumedFeedbackRevision: number = 0;
  private feedbackPosition: GameplayFeedbackPosition | null = null;
  @Local private openedNarrativeIds: string[] = [];
  @Local private attentionHeight: number = 80;
  @Local private attentionReserveOwner: string = '';
  private attentionAccount: string = '';
  private attentionAssignment: string = '';
  private readonly hintBackdropOwner: Object = new Object();
  private bgmMounted: boolean = false;
  private clueLinkHandoff: ClueLinkHandoff | null = null;
  private readonly clueLifecycle: (foreground: boolean) => void = (foreground: boolean) => {
    this.foreground = foreground;
    if (!foreground) {
      this.play.setPollingActive(false);
      this.closeGameplaySheet(true);
      this.stopInlineVideo();
      this.updateBgm();
    }
    const handoff: ClueLinkHandoff | null = this.clueLinkHandoff;
    const keepHandoff: boolean = handoff !== null && handoff.isCurrent();
    const keepReading: boolean = keepHandoff && handoff?.dialog !== null;
    if (!foreground) {
      if (keepReading) {
        if (this.play.finaleStage === 'idle') { this.play.cancelRankUpPresentation(); }
      } else {
        this.play.cancelAutomaticClues(keepHandoff);
      }
      this.cancelRankNotice();
    }
    this.imageCache.validateOwner();
    this.viewer.validateOwner();
    if (foreground) {
      this.clearClueLinkHandoff();
      if (this.play.visible && !this.narrativeCovered) {
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
      this.play.setPollingActive(!this.narrativeCovered);
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
  private positionOwner: string = '';
  private positionPending: boolean = false;
  private positionTimer: number = -1;

  aboutToAppear(): void {
    this.foreground = AppLifecycle.isForeground();
    if (!this.foreground) { this.play.cancelAutomaticClues(); }
    this.bgmMounted = true;
    // A completed GET or remount is not a new successful answer.
    this.seenCompletionRevision = this.play.completionRevision;
    this.consumedFeedbackRevision = this.play.feedbackVersion;
    this.recoveryChanged();
    this.loadNarrativeAttention();
    this.journeyBackHandlerChanged(() => this.handleBack());
    this.trackQuestionPosition();
    AppLifecycle.subscribe(this.clueLifecycle);
    this.play.setPollingActive(this.foreground && !this.narrativeCovered);
    this.updateProfilePolling();
    this.updateBgm();
  }

  aboutToDisappear(): void {
    AppLifecycle.unsubscribe(this.clueLifecycle);
    this.foreground = false;
    this.closeGameplaySheet(true);
    this.journeyBackHandlerChanged(null);
    this.play.setPollingActive(false);
    this.profilePollingChanged(false);
    this.bgmMounted = false;
    this.stopInlineVideo();
    this.journeyVideoOpen = false;
    this.play.cancelAutomaticClues();
    this.imageCache.validateOwner();
    this.clearClueLinkHandoff();
    this.cancelCompletionNotice();
    this.cancelRankNotice();
    this.interruptCombinationSequence();
    this.closeClueDialog(true);
    this.viewer.close(this.viewer.sessionId, true);
    this.videoViewer.close(this.videoViewer.sessionId, true);
    this.atmosphere.setVideo(this.atmosphereOwner, 'gameplay', false);
    clearTimeout(this.positionTimer);
    this.positionTimer = -1;
    this.positionPending = false;
  }

  @Monitor('play.visible', 'play.snapshot', 'play.activeIndex', 'play.error', 'playerId')
  imageOwnerChanged(): void {
    if (this.attentionReserveOwner !== this.positionKey()) { this.attentionReserveOwner = ''; }
    if (this.clueLinkHandoff !== null && !this.clueLinkHandoff.isCurrent()) { this.clearClueLinkHandoff(); }
    if (this.sheet !== null && !this.gameplaySheetOwnerCurrent()) { this.closeGameplaySheet(true); }
    const clue: GameplayClue | null = this.play.automaticClue;
    if (clue !== null && !this.isClueCurrent(this.imageOwner(), clue)) { this.play.cancelAutomaticClues(); }
    this.imageCache.validateOwner();
    this.viewer.validateOwner();
    this.videoViewer.validateOwner();
    this.inlineVideo.validateOwner();
    if (this.combinationSequenceActive && (this.combinationOwner !== this.play.imageOwnerKey() ||
      this.currentCombinations().length === 0)) { this.interruptCombinationSequence(); }
    if (this.completionNotice !== null && !this.isCompletionNoticeCurrent(this.completionNotice)) {
      this.cancelCompletionNotice();
    }
    if (this.clueDialog !== null && this.textClue !== null &&
      !this.isDialogClueCurrent(this.clueDialog, this.textClue)) { this.closeClueDialog(true); }
    this.trackQuestionPosition();
  }

  private scrollOffset(): number {
    const offset: number = this.questionScroller.currentOffset()?.yOffset ?? 0;
    return Number.isFinite(offset) ? Math.max(0, offset) : 0;
  }

  private async refreshQuestion(): Promise<void> {
    if (!this.play.canRefresh()) { return; }
    this.stopInlineVideo();
    const owner: string = this.imageCacheOwner();
    await this.play.refresh();
    if (owner.length > 0 && owner === this.imageCacheOwner()) {
      this.atmosphere.retryBackground(this.atmosphereOwner);
    }
  }

  private scrollBottomClearance(): number {
    const floatingControl: number = this.hasBgm() ? QUEST_BGM_SIZE :
      this.journey.unreadCount > 0 ? JOURNEY_LAUNCHER_SIZE : 0;
    const baseline: number = this.composerClearance() + floatingControl + 12;
    if (this.finalDestination() !== null) { return baseline + this.destinationHeight + 14; }
    if (this.attentionClue() !== null || (this.attentionReserveOwner.length > 0 &&
      this.attentionReserveOwner === this.positionKey())) {
      return baseline + this.attentionInset() + this.attentionHeight - this.bgmBottomInset();
    }
    return baseline;
  }

  private hasBgm(): boolean {
    return this.atmosphere.owns(this.atmosphereOwner) && this.atmosphere.trackAvailable;
  }

  @Monitor('videoViewer.visible', 'videoViewer.closing', 'inlineVideo.visible')
  bgmInputsChanged(): void { this.updateBgm(); }

  @Monitor('narrativeCovered')
  narrativeCoverChanged(): void {
    this.play.setPollingActive(this.foreground && !this.narrativeCovered);
    this.updateBgm();
    if (!this.narrativeCovered) {
      this.rankChanged();
      this.scheduleQuestionPosition();
    }
  }

  @Monitor('journeyPollingAllowed', 'foreground', 'narrativeCovered', 'play.visible', 'play.refreshing',
    'play.loading', 'play.starting', 'play.error')
  private updateProfilePolling(): void {
    this.profilePollingChanged(this.journeyPollingAllowed && this.foreground && !this.narrativeCovered &&
      this.play.visible && !this.play.refreshing && !this.play.loading && !this.play.starting && this.play.error.length === 0);
  }

  private updateBgm(videoOpening: boolean = false): void {
    if (!this.bgmMounted) { return; }
    this.atmosphere.setVideo(this.atmosphereOwner, 'gameplay',
      videoOpening || this.videoViewer.visible || this.videoViewer.closing || this.inlineVideo.visible ||
      this.journeyVideoOpen);
  }

  private showBgmControl(): boolean {
    const minimum: number = QUEST_BGM_SIZE + 2 * QUEST_BGM_MARGIN;
    return this.foreground && this.sheet === null && !this.keyboardVisible && !this.videoViewer.visible &&
      !this.videoViewer.closing &&
      !this.inlineVideo.visible && !this.viewer.visible && !this.viewer.closing && this.hasBgm() &&
      this.viewportWidth - this.leftInset - this.rightInset >= minimum &&
      this.viewportHeight - this.foregroundTopInset() - this.bgmLayoutBottomInset() >= minimum;
  }

  private safeBottom(): number { return this.keyboardVisible ? 0 : Math.max(0, this.bottomClearance - 24); }

  private showComposer(): boolean {
    return this.play.visible && this.play.error.length === 0 && this.readableQuestionId().length > 0 &&
      this.play.snapshot?.detail.status !== 'cancelled';
  }

  private composerInset(): number { return this.keyboardVisible ? 8 : Math.max(18, this.safeBottom()); }

  private composerClearance(): number {
    return this.showComposer() ? this.composerInset() + this.composerHeight + 10 : this.safeBottom() + 12;
  }

  private bgmBottomInset(): number { return this.composerClearance(); }

  private bgmLayoutBottomInset(): number {
    if (this.finalDestination() !== null) { return this.destinationBottomInset() + this.destinationHeight + 10; }
    if (this.attentionClue() !== null) { return this.attentionInset() + this.attentionHeight + 10; }
    return this.bgmBottomInset();
  }

  private bgmLeft(): number {
    return questBgmCoordinate(this.atmosphere.position.x, this.viewportWidth, this.leftInset, this.rightInset);
  }

  private bgmTop(): number {
    return questBgmCoordinate(this.atmosphere.position.y, this.viewportHeight, this.foregroundTopInset(),
      this.bgmLayoutBottomInset());
  }

  private titlePresent(): boolean {
    return (this.play.snapshot?.detail.title.length ?? 0) > 0 && this.play.error.length === 0;
  }

  private readingTopInset(): number {
    return this.titleTopInset() + (this.titlePresent() ? GAMEPLAY_TITLE_CLEARANCE : 0);
  }

  private titleTopInset(): number {
    return Math.max(0, Math.max(GAMEPLAY_TITLE_MIN_TOP, this.statusInset) - this.viewportTop);
  }

  private readingGutter(): number {
    return this.viewportWidth <= 620 ? 14 : 20;
  }

  @Monitor('answerFocused', 'keyboardVisible')
  revealTitleForInput(): void {
    if (this.answerFocused || this.keyboardVisible) { this.revealTitle(); }
  }

  private revealTitle(): void {
    this.titleHidden = false;
    this.scrollMomentum = 0;
  }

  private syncTitle(): void {
    const offset: number = this.scrollOffset();
    const delta: number = offset - this.lastScrollOffset;
    this.lastScrollOffset = offset;
    if (offset <= 16 || this.answerFocused || this.keyboardVisible || this.positionPending) {
      this.revealTitle();
      return;
    }
    if (Math.abs(delta) < 0.05) { return; }
    this.scrollMomentum = Math.sign(delta) === Math.sign(this.scrollMomentum) ? this.scrollMomentum + delta : delta;
    if (this.scrollMomentum <= -6) {
      this.revealTitle();
    } else if (offset >= 56 && this.scrollMomentum >= 10) {
      this.titleHidden = true;
      this.scrollMomentum = 0;
    }
  }

  private hasLevelMessages(): boolean {
    return this.readableQuestionId().length > 0 && (this.play.currentLevel()?.extraDisplay.length ?? 0) > 0;
  }

  private positionKey(): string {
    return this.play.visible && this.play.snapshot?.detail.status !== 'cancelled' && this.readableQuestionId().length > 0 ?
      this.imageOwner() : '';
  }

  private trackQuestionPosition(force: boolean = false): void {
    const owner: string = this.positionKey();
    if (owner !== this.positionOwner) { this.answerFocused = false; }
    if (owner !== this.positionOwner || force) {
      this.positionOwner = owner;
      this.positionPending = owner.length > 0;
      this.revealTitle();
    }
    this.scheduleQuestionPosition();
  }

  private composerOwnerCurrent(owner: string): boolean {
    return owner.length > 0 && owner === this.positionKey() && this.gameplayOwnerCurrent();
  }

  private foregroundTopInset(): number {
    return Math.max(0, this.statusInset - this.viewportTop);
  }

  @Monitor('keyboardVisible', 'recoveryVisible', 'play.loading', 'play.starting', 'play.submitting',
    'play.refreshing', 'play.advancing', 'viewer.visible', 'viewer.closing', 'videoViewer.visible', 'videoViewer.closing',
    'textClue', 'completionNotice', 'combinationSequenceActive', 'rankNotice', 'journey.entries',
    'journey.gameplayReady', 'journey.routeArchive', 'journey.automaticDismissedRevision', 'accountCovered', 'sheet')
  scheduleQuestionPosition(): void {
    if (this.positionTimer !== -1 || !this.questionPositionReady()) {
      return;
    }
    this.positionTimer = setTimeout(() => {
      this.positionTimer = -1;
      if (!this.questionPositionReady() || this.positionOwner !== this.positionKey()) { return; }
      this.positionPending = false;
      this.lastScrollOffset = 0;
      this.questionScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
    }, 0);
  }

  private questionPositionReady(): boolean {
    return this.positionPending && this.viewportHeight > 0 && this.questionInteractionReady();
  }

  private measureNewFeedback(levelId: string, revision: number, area: Area): void {
    if (levelId !== this.readableQuestionId() || revision !== this.play.feedbackVersion ||
      revision <= this.consumedFeedbackRevision || !this.answerFeedbackDanger()) { return; }
    const top: number = Number(area.globalPosition.y);
    const height: number = Number(area.height);
    if (!Number.isFinite(top) || !Number.isFinite(height) || height <= 0) { return; }
    this.feedbackPosition = { revision: revision, owner: this.positionKey(), contentTop: top + this.scrollOffset(),
      height: height };
    this.revealNewFeedback();
  }

  @Monitor('keyboardVisible', 'play.submitting', 'sheet')
  private revealNewFeedback(): void {
    const feedback: GameplayFeedbackPosition | null = this.feedbackPosition;
    if (feedback === null) { return; }
    if (feedback.owner.length === 0 || feedback.owner !== this.positionKey() ||
      feedback.revision !== this.play.feedbackVersion || !this.hasAnswerFeedback() || !this.answerFeedbackDanger()) {
      this.feedbackPosition = null;
      return;
    }
    if (this.keyboardVisible || this.play.submitting || !this.foreground || this.narrativeCovered ||
      this.accountCovered || this.sheet !== null || !this.showComposer()) { return; }
    const viewportTop: number = this.viewportTop + this.readingTopInset();
    const viewportBottom: number = this.viewportTop + this.viewportHeight - this.composerClearance();
    if (viewportBottom <= viewportTop) { return; }
    const offset: number = this.scrollOffset();
    const top: number = feedback.contentTop - offset;
    const bottom: number = top + feedback.height;
    this.consumedFeedbackRevision = feedback.revision;
    this.feedbackPosition = null;
    if (top >= viewportTop && bottom <= viewportBottom) { return; }
    const alignment: number = top < viewportTop || feedback.height > viewportBottom - viewportTop ?
      viewportTop : viewportBottom - feedback.height;
    this.questionScroller.scrollTo({ xOffset: 0, yOffset: Math.max(0, feedback.contentTop - alignment),
      animation: !this.reducedMotion });
  }

  private hasHints(levelId: string): boolean {
    return this.contentBlocks(levelId).some((block: GameplayContentBlock) => block.hint.trim().length > 0);
  }

  private gameplaySheetOwnerCurrent(): boolean {
    return this.foreground && !this.accountCovered && !this.narrativeCovered && this.gameplayOwnerCurrent() &&
      this.sheetOwner.length > 0 && this.sheetOwner === this.positionKey() && (this.sheet === 'choice' ?
      this.play.currentLevel()?.question?.kind === 'choice' : this.hasHints(this.readableQuestionId()));
  }

  private openGameplaySheet(kind: GameplaySheet): void {
    if (!this.foreground || this.accountCovered || !this.questionInteractionReady(true) ||
      this.play.automaticClue !== null || this.positionKey().length === 0 || (kind === 'hint' &&
      !this.hasHints(this.readableQuestionId()))) { return; }
    this.stopInlineVideo();
    StarwardKeyboard.dismiss(this.getUIContext());
    this.sheetOwner = this.positionKey();
    this.sheetRevision++;
    this.sheet = kind;
    this.sheetVisible = true;
  }

  private closeGameplaySheet(invalidOwner: boolean = false): void {
    if (this.sheet === null || (!invalidOwner && this.closeClueMedia())) { return; }
    if (invalidOwner) {
      this.sheetOwner = '';
      this.viewer.close(this.viewer.sessionId, true);
      this.videoViewer.close(this.videoViewer.sessionId, true);
      if (this.viewer.closing) { this.viewer.disappeared(this.viewer.sessionId); }
      if (this.videoViewer.closing) { this.videoViewer.disappeared(this.videoViewer.sessionId); }
    }
    this.stopInlineVideo();
    this.sheetVisible = false;
    if (invalidOwner || !this.sheetMounted) { this.finishGameplaySheet(this.sheetRevision); }
  }

  private finishGameplaySheet(revision: number): void {
    if (revision !== this.sheetRevision) { return; }
    if (this.sheet === 'hint') { this.modalBackdrop.hide(this.hintBackdropOwner); }
    this.sheetMounted = false;
    this.sheetOwner = '';
    this.sheet = null;
    this.sheetVisible = false;
  }

  @Monitor('accountCovered', 'narrativeCovered', 'recoveryVisible', 'play.answerBurst')
  questionCoversChanged(): void {
    if (this.accountCovered || this.narrativeCovered || this.recoveryVisible) {
      this.closeGameplaySheet(true);
      this.play.discardAnswerBurst();
    }
  }

  private handleBack(): boolean {
    if (this.closeClueMedia()) { return true; }
    if (this.sheet !== null) {
      this.closeGameplaySheet();
      return true;
    }
    const burst: GameplayAnswerBurst | null = this.visibleAnswerBurst();
    if (burst !== null) {
      this.play.finishAnswerBurst(burst, false);
      return true;
    }
    return this.journeyBack?.() ?? false;
  }

  private questionMediaReady(fromSheet: GameplaySheet | null = null): boolean {
    return this.foreground && !this.accountCovered && this.play.automaticClue === null &&
      (fromSheet === null ? this.questionInteractionReady(true) : this.sheet === fromSheet && this.sheetVisible &&
      this.gameplaySheetOwnerCurrent() && this.gameplayOverlayReady(true, true));
  }

  private gameplaySheetOptions(): SheetOptions {
    const revision: number = this.sheetRevision;
    return { height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM, dragBar: true, showClose: false,
      backgroundColor: $r('app.color.gameplay_overlay_tint'), blurStyle: BlurStyle.NONE, maskColor: Color.Transparent,
      onWillAppear: () => {
        if (revision === this.sheetRevision && this.sheet === 'hint' && this.sheetVisible) {
          this.sheetMounted = true;
          this.modalBackdrop.show(this.hintBackdropOwner);
        }
      },
      onWillDismiss: (action: DismissSheetAction) => {
        if (revision !== this.sheetRevision || this.closeClueMedia()) { return; }
        this.closeGameplaySheet();
        action.dismiss();
      },
      onDisappear: () => this.finishGameplaySheet(revision) };
  }

  private dismissChoicePopup(revision: number): boolean {
    if (revision !== this.sheetRevision || this.sheet !== 'choice' || this.closeClueMedia()) { return false; }
    this.closeGameplaySheet();
    return true;
  }

  private choicePopupStateChanged(revision: number, visible: boolean): void {
    if (revision !== this.sheetRevision || this.sheet !== 'choice') { return; }
    if (visible) { this.sheetMounted = true; } else { this.finishGameplaySheet(revision); }
  }

  @Monitor('viewer.visible')
  coverVisibilityChanged(): void {
    if (!this.viewer.visible && !this.viewer.closing) { this.viewer.close(this.viewer.sessionId); }
  }

  private openImages(blockIndex: number, index: number): void {
    const block: GameplayContentBlock | undefined = this.play.currentLevel()?.question?.content[blockIndex];
    if (!this.questionMediaReady() || this.imageCacheOwner().length === 0 || block === undefined ||
      block.videoUrl.trim().length > 0) { return; }
    const sources: string[] = this.blockImages(block);
    const owner: string = this.imageOwner();
    this.stopInlineVideo();
    StarwardKeyboard.dismiss(this.getUIContext());
    this.viewer.open(sources, index, () => {
      const current: GameplayContentBlock | undefined = this.play.currentLevel()?.question?.content[blockIndex];
      if (this.imageCacheOwner().length === 0 || this.accountCovered || this.narrativeCovered ||
        owner !== this.imageOwner() || current === undefined ||
        current.videoUrl.trim().length > 0) { return false; }
      const actual: string[] = this.blockImages(current);
      return actual.length === sources.length && actual.every((source: string, position: number) => source === sources[position]);
    });
  }

  private openQuestionVideo(levelId: string, blockIndex: number): void {
    const block: GameplayContentBlock | undefined = this.play.currentLevel()?.question?.content[blockIndex];
    if (block === undefined || levelId !== this.readableQuestionId()) { return; }
    const source: string = block.videoUrl.trim();
    const poster: string = block.imageUrl;
    const owner: string = this.imageOwner();
    this.openManualVideo(source, poster, () => {
      const current: GameplayContentBlock | undefined = this.play.currentLevel()?.question?.content[blockIndex];
      return current !== undefined && this.imageOwner() === owner && this.readableQuestionId() === levelId &&
        current.videoUrl.trim() === source && current.imageUrl === poster;
    });
  }

  private legacyQuestionText(levelId: string, index: number, hint: boolean): string {
    const block: GameplayContentBlock | undefined = this.contentBlocks(levelId)[index];
    return (hint ? block?.hint : block?.text) ?? '';
  }

  private questionLegacyNodeId(levelId: string, index: number, hint: boolean): string {
    return hint ? `question-hint-content-${index}` : levelId === this.readableQuestionId() ?
      `question-content-text-${index}` : `question-rich-preview-${this.levelById(levelId)?.position || 0}-${index}`;
  }

  private openQuestionLegacyMedia(levelId: string, index: number, hint: boolean, partIndex: number,
    inline: boolean = false): void {
    const fromSheet: GameplaySheet | null = hint ? 'hint' : null;
    if (levelId !== this.readableQuestionId() || !this.questionMediaReady(fromSheet)) { return; }
    const source: string = this.legacyQuestionText(levelId, index, hint);
    const blocks: LegacyRichBlock[] = legacyRichBlocks(source);
    const part: LegacyRichBlock | undefined = blocks[partIndex];
    if (part === undefined) { return; }
    const owner: string = this.imageOwner();
    const current = (): boolean => this.imageCacheOwner().length > 0 && !this.accountCovered && !this.narrativeCovered &&
      (!hint || (this.sheet === 'hint' && this.sheetVisible && this.gameplaySheetOwnerCurrent())) &&
      owner === this.imageOwner() &&
      levelId === this.readableQuestionId() && source === this.legacyQuestionText(levelId, index, hint);
    if (part.kind === 'image' && !inline) {
      this.stopInlineVideo();
      StarwardKeyboard.dismiss(this.getUIContext());
      this.viewer.open(legacyImageSources(blocks), legacyImageSources(blocks.slice(0, partIndex)).length, current);
    } else if (part.kind === 'video') {
      const slot: string = `${this.questionLegacyNodeId(levelId, index, hint)}-video-${partIndex}`;
      this.openManualVideo(part.url, part.poster, current, inline ? slot : '', inline ? '' : slot, fromSheet);
    }
  }

  private openQuestionLegacyLink(levelId: string, index: number, hint: boolean, href: string): void {
    if (levelId !== this.readableQuestionId() || !this.questionMediaReady(hint ? 'hint' : null)) { return; }
    const source: string = this.legacyQuestionText(levelId, index, hint);
    if (!legacyRichBlocks(source).some((part: LegacyRichBlock) =>
      part.spans.some((span: LegacyRichSpan) => span.linkTarget === href))) { return; }
    const owner: string = this.imageOwner();
    StarwardKeyboard.dismiss(this.getUIContext());
    if (isLegacyInternalLink(href)) {
      this.stopInlineVideo();
      if (hint) { this.closeGameplaySheet(); }
      if (!this.openJourneyLink(href)) { this.showClueLinkFailure(); }
    } else {
      this.launchClueLink(href, null, () => this.play.visible && owner === this.imageOwner() &&
        levelId === this.readableQuestionId() && source === this.legacyQuestionText(levelId, index, hint));
    }
  }

  private openManualVideo(source: string, posterSource: string, mediaIsCurrent: () => boolean,
    inlineSlot: string = '', returnSlot: string = '', fromSheet: GameplaySheet | null = null): void {
    if (!this.questionMediaReady(fromSheet) || source.length === 0) { return; }
    const current = (): boolean => this.imageCacheOwner().length > 0 && !this.accountCovered && !this.narrativeCovered &&
      this.play.snapshot?.detail.player === this.playerId &&
      mediaIsCurrent();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (!context || !current()) { return; }
    const position: number = returnSlot.length > 0 && returnSlot === this.inlineVideoSlot ?
      this.inlineVideo.pausePosition() : 0;
    let returnRevision: number = -1;
    const restore: ((ended: boolean) => void) | undefined = position > 0 ? (): void => {
      if (returnRevision !== this.inlineVideoRevision || !current() || !this.questionMediaReady(fromSheet)) { return; }
      const cached: QuestionImageResult | undefined = posterSource.length > 0 ? this.imageCache.acquire(posterSource) : undefined;
      try {
        this.openVideoWithBgmSuspended(source, context.cacheDir, current, undefined, cached, returnSlot, position);
      } finally {
        cached?.release();
      }
    } : undefined;
    const poster: QuestionImageResult | undefined = posterSource.length > 0 ? this.imageCache.acquire(posterSource) : undefined;
    try {
      StarwardKeyboard.dismiss(this.getUIContext());
      if (this.openVideoWithBgmSuspended(source, context.cacheDir, current, restore, poster, inlineSlot)) {
        returnRevision = this.inlineVideoRevision;
      }
    } finally {
      poster?.release();
    }
  }

  private viewerOptions(): ContentCoverOptions {
    const sessionId: number = this.viewer.sessionId;
    return starwardMediaCoverOptions(this.reducedMotion, (action: DismissContentCoverAction) => {
      this.viewer.close(sessionId);
      action.dismiss();
    }, () => this.viewer.disappeared(sessionId));
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
    return starwardMediaCoverOptions(this.reducedMotion, (action: DismissContentCoverAction) => {
      if (!this.videoViewer.exitFullscreen(sessionId)) {
        this.videoViewer.close(sessionId);
        action.dismiss();
      }
    }, () => this.videoViewer.disappeared(sessionId));
  }

  @Builder
  gameplayVideoViewer() {
    StarwardVideoViewer({ model: this.videoViewer, sessionId: this.videoViewer.sessionId,
      motionEnabled: this.foreground && !this.reducedMotion && this.videoViewer.visible && !this.videoViewer.closing,
      reducedMotion: this.reducedMotion })
  }

  private currentClues(): GameplayClue[] {
    return this.play.visible && this.play.error.length === 0 ?
      ordinaryClues(this.play.snapshot, this.play.currentLevel()) : [];
  }

  @Monitor('playerId', 'play.snapshot', 'play.visible')
  private loadNarrativeAttention(): void {
    const assignment = this.play.snapshot?.detail;
    const account: string = this.playerId;
    const id: string = this.play.visible && assignment?.player === account ? assignment.id : '';
    if (this.attentionAccount === account && this.attentionAssignment === id) { return; }
    this.attentionAccount = account;
    this.attentionAssignment = id;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    this.openedNarrativeIds = context && account.length > 0 && id.length > 0 ?
      QuestNarrativeAttentionPreference.load(context, account, id) : [];
  }

  private pendingNarrativeIds(): string[] {
    return this.currentClues().filter((clue: GameplayClue) =>
      isNarrativeClue(clue) && !this.openedNarrativeIds.includes(clue.id)).map((clue: GameplayClue) => clue.id);
  }

  private attentionInset(): number { return Math.max(18, this.bgmBottomInset() + 8); }

  private attentionClue(): GameplayClue | null {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    if (!this.foreground || this.narrativeCovered || this.playerId.length === 0 ||
      snapshot?.detail.player !== this.playerId || !this.play.visible || this.play.error.length > 0 ||
      !this.questionInteractionReady() || this.play.automaticClue !== null || this.play.finaleStage !== 'idle' ||
      this.viewportWidth - this.leftInset - this.rightInset < 250 || this.viewportHeight <= 0) { return null; }
    return nextNarrativeAttention(snapshot, this.play.currentLevel(), this.openedNarrativeIds);
  }

  private openPendingNarrative(id: string): void {
    const pending: GameplayClue | null = this.attentionClue();
    if (pending?.id === id) { this.openGrantedNarrative(pending, true); }
  }

  private openGrantedNarrative(clue: GameplayClue, fromAttention: boolean): void {
    const assignment = this.play.snapshot?.detail;
    const account: string = this.playerId;
    if (!this.foreground || this.narrativeCovered || assignment === undefined || account.length === 0 ||
      assignment.player !== account || !this.openNarrativeClue(assignment.id, clue.id, clue.narrative)) { return; }
    if (fromAttention) { this.attentionReserveOwner = this.positionKey(); }
    this.loadNarrativeAttention();
    if (!this.openedNarrativeIds.includes(clue.id)) {
      this.openedNarrativeIds = this.openedNarrativeIds.concat([clue.id]).slice(-128);
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context) { QuestNarrativeAttentionPreference.save(context, account, assignment.id, this.openedNarrativeIds); }
    }
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
    return this.foreground && this.play.finaleStage !== 'notice' && this.play.finaleStage !== 'combination' &&
      this.play.automaticClue === null && this.questionInteractionReady() &&
      this.clueDialogWidth() >= 160 && this.clueDialogHeight() >= 120 && this.currentCombinations().length > 0;
  }

  private openLatestCombination(): void {
    if (!this.showCombinationLauncher() || this.clueDialog !== null) { return; }
    const clues: GameplayClue[] = this.currentCombinations();
    const clue: GameplayClue | undefined = clues[clues.length - 1];
    if (clue !== undefined) { this.openClueDialog(clue, this.play.imageOwnerKey(), true); }
  }

  private interruptCombinationSequence(): void {
    if (this.play.finaleStage === 'combination') {
      this.play.cancelAutomaticClues();
    } else if (this.combinationRevision > 0) {
      this.play.cancelRankUpPresentation();
    }
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
    } else if (isNarrativeClue(clue)) {
      this.openGrantedNarrative(clue, false);
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
    'videoViewer.visible', 'videoViewer.closing', 'sheet')
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
    finished?: (ended: boolean) => void, poster?: QuestionImageResult, inlineSlot: string = '', pausedAt: number = 0): boolean {
    if (inlineSlot.length > 0 && this.inlineVideo.visible && this.inlineVideoSlot === inlineSlot) { return false; }
    this.updateBgm(true);
    this.stopInlineVideo();
    this.inlineVideoSlot = inlineSlot;
    const model: StarwardVideoViewerState = inlineSlot.length > 0 ? this.inlineVideo : this.videoViewer;
    const opened: boolean = model.open(source, cacheDir, ownerCurrent, finished,
      () => this.atmosphere.whenQuiet(this.atmosphereOwner), poster, pausedAt);
    if (!opened) { this.updateBgm(); }
    return opened;
  }

  private stopInlineVideo(): void {
    this.inlineVideoRevision++;
    this.inlineVideo.close(this.inlineVideo.sessionId, true);
    this.inlineVideoSlot = '';
  }

  @Monitor('accountCovered', 'narrativeCovered', 'recoveryVisible', 'viewer.visible', 'viewer.closing',
    'completionNotice', 'rankNotice', 'journey.entries', 'journey.gameplayReady', 'journey.routeArchive',
    'journey.automaticDismissedRevision')
  inlineVideoOverlayChanged(): void {
    if (this.inlineVideo.visible && (this.accountCovered || this.narrativeCovered || this.recoveryVisible ||
      this.viewer.visible || this.viewer.closing || this.completionNotice !== null || this.rankNotice !== null ||
      this.displayedJourneyNotification() !== null)) { this.stopInlineVideo(); }
  }

  private clueDialogWidth(): number {
    return Math.min(680, this.viewportWidth - this.leftInset - this.rightInset - 40);
  }
  private clueDialogHeight(): number {
    return this.viewportHeight - this.foregroundTopInset() - Math.max(24, this.bottomClearance) - 24;
  }

  private async openClueDialog(clue: GameplayClue, owner: string,
    combination: boolean = false, sequence: boolean = false, onClosed?: (dismissed: boolean) => void): Promise<void> {
    if (this.clueDialogWidth() < 160 || this.clueDialogHeight() < 120 || this.clueDialog !== null) {
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
    this.stopInlineVideo();
    this.clueDialog = request;
    this.textClue = clue;
    this.modalBackdrop.show(request);
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
      alignment: DialogAlignment.Center, width: this.clueDialogWidth(), cornerRadius: 24,
      isModal: true, autoCancel: !combination, showInSubWindow: false,
      backgroundColor: $r('app.color.raised'), backgroundBlurStyle: BlurStyle.NONE,
      maskColor: Color.Transparent, dialogTransition,
      onWillDismiss: (action: DismissDialogAction) => {
        if (combination && action.reason === DismissReason.TOUCH_OUTSIDE) { return; }
        if (this.clueDialog !== request || !this.closeClueMedia()) {
          if (this.clueDialog === request) { this.stopInlineVideo(); }
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
    if (!invalidOwner && this.closeClueMedia()) { return; }
    this.stopInlineVideo();
    const closing: boolean = request.closing;
    request.closing = true;
    if (invalidOwner) {
      if (request.sequence) { this.interruptCombinationSequence(); }
      this.viewer.close(this.viewer.sessionId, true);
      this.viewer.disappeared(this.viewer.sessionId);
      this.videoViewer.close(this.videoViewer.sessionId, true);
      this.videoViewer.disappeared(this.videoViewer.sessionId);
      this.releaseClueDialog(request);
    }
    if (!closing) { this.finishClueDialogClose(request); }
  }

  private closeClueMedia(): boolean {
    if (this.inlineVideo.exitFullscreen(this.inlineVideo.sessionId)) { return true; }
    if (this.videoViewer.visible || this.videoViewer.closing) {
      const sessionId: number = this.videoViewer.sessionId;
      if (this.videoViewer.visible && !this.videoViewer.exitFullscreen(sessionId)) { this.videoViewer.close(sessionId); }
      return true;
    }
    if (!this.viewer.visible && !this.viewer.closing) { return false; }
    if (this.viewer.visible) { this.viewer.close(this.viewer.sessionId); }
    return true;
  }

  private releaseClueDialog(request: ClueDialogRequest, dismissed: boolean = false): void {
    this.modalBackdrop.hide(request);
    if (this.clueDialog === request) {
      this.stopInlineVideo();
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
    this.destinationLaunching = false;
  }

  private openClueLink(request: ClueDialogRequest, href: string): void {
    if (this.viewer.visible || this.viewer.closing || this.videoViewer.visible || this.videoViewer.closing) { return; }
    this.launchClueLink(href, request, () => this.clueDialog === request && this.currentTextClueOwner(request.owner));
  }

  private showClueLinkFailure(): void {
    StarwardFeedback.toast(this.getUIContext(), '暂时无法打开链接，请重试。');
  }

  private async launchClueLink(href: string, dialog: ClueDialogRequest | null,
    isCurrent: () => boolean, destination: boolean = false): Promise<void> {
    if (!this.foreground || this.clueLinkHandoff !== null || !isCurrent()) { return; }
    this.stopInlineVideo();
    const handoff: ClueLinkHandoff = new ClueLinkHandoff(dialog, isCurrent);
    this.clueLinkHandoff = handoff;
    this.destinationLaunching = destination;
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

  private openInlineClueMedia(request: ClueDialogRequest, partIndex: number, inline: boolean = false): void {
    const clue: GameplayClue | null = this.textClue;
    const current = (): boolean => this.foreground && this.clueDialog === request && this.textClue === clue &&
      this.currentTextClueOwner(request.owner);
    if (clue === null || !current() || this.viewer.visible || this.viewer.closing ||
      this.videoViewer.visible || this.videoViewer.closing) { return; }
    const parts: LegacyRichBlock[] = legacyRichBlocks(clue.content.text, 'clueBody');
    const part: LegacyRichBlock | undefined = parts[partIndex];
    if (part?.kind === 'image' && !inline) {
      this.stopInlineVideo();
      this.viewer.open(legacyImageSources(parts), legacyImageSources(parts.slice(0, partIndex)).length, current);
    } else if (part?.kind === 'video') {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (!context) { return; }
      const poster: QuestionImageResult | undefined =
        part.poster.length > 0 ? this.imageCache.acquire(part.poster) : undefined;
      try {
        const slot: string = inline ? `gameplay-${request.combination ? 'combination' : 'clue'}-video-${partIndex}` : '';
        this.openVideoWithBgmSuspended(part.url, context.cacheDir, current, undefined, poster, slot);
      } finally {
        poster?.release();
      }
    }
  }

  @Builder
  clueDialogContent(request: ClueDialogRequest) {
    if (this.clueDialog === request && this.textClue !== null) {
      Stack() {
        if (request.combination) {
          StarwardCombinationDialog({ clue: this.textClue, ownerKey: request.owner,
            ownerIsCurrent: (owner: string) => this.currentTextClueOwner(owner),
            imageCache: this.imageCache, inlineVideo: this.inlineVideo, inlineVideoSlot: this.inlineVideoSlot,
            panelWidth: this.clueDialogWidth(), maxHeight: this.clueDialogHeight(),
            motionEnabled: this.foreground && !this.reducedMotion && !this.viewer.visible && !this.viewer.closing &&
              !this.videoViewer.visible && !this.videoViewer.closing,
            reducedMotion: this.reducedMotion, acknowledge: () => this.closeClueDialog(),
            openImage: (index: number) => this.openInlineClueMedia(request, index),
            openVideo: (index: number) => this.openInlineClueMedia(request, index),
            playVideo: (index: number) => this.openInlineClueMedia(request, index, true),
            openLink: (href: string) => this.openClueLink(request, href) })
        } else {
          StarwardClueTextDialog({ clue: this.textClue, ownerKey: request.owner,
            ownerIsCurrent: (owner: string) => this.currentTextClueOwner(owner),
            imageCache: this.imageCache, inlineVideo: this.inlineVideo, inlineVideoSlot: this.inlineVideoSlot,
            panelWidth: this.clueDialogWidth(), maxHeight: this.clueDialogHeight(),
            motionEnabled: this.foreground && !this.reducedMotion && !this.viewer.visible && !this.viewer.closing &&
              !this.videoViewer.visible && !this.videoViewer.closing,
            reducedMotion: this.reducedMotion, close: () => this.closeClueDialog(),
            openImage: (index: number) => this.openInlineClueMedia(request, index),
            openVideo: (index: number) => this.openInlineClueMedia(request, index),
            playVideo: (index: number) => this.openInlineClueMedia(request, index, true),
            openLink: (href: string) => this.openClueLink(request, href) })
        }
        Column() {}.width(0).height(0).bindContentCover(this.viewer.visible, this.imageViewer(), this.viewerOptions())
        Column() {}.width(0).height(0)
          .bindContentCover(this.videoViewer.visible, this.gameplayVideoViewer(), this.videoViewerOptions())
      }.width(this.clueDialogWidth())
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

  @Builder
  answerRecovery() {
    StarwardAnswerRecovery({ pending: this.play.submitting, displayFont: this.displayFont,
      maxHeight: this.clueDialogHeight(), motionEnabled: this.foreground && !this.reducedMotion && this.recoveryVisible,
      retry: () => this.retryAnswer(), stay: () => this.stayOnQuestion() })
  }

  private isCompletionNoticeCurrent(request: CompletionNoticeRequest): boolean {
    return this.completionNotice === request && this.foreground && this.play.visible && this.play.error.length === 0 &&
      this.play.snapshot?.detail.status === 'completed' && this.play.imageOwnerKey() === request.owner &&
      (request.finale ? this.play.finaleStage === 'notice' : !request.hasResults ||
        this.combinationQueue.some((clue: GameplayClue) => this.isCombinationCurrent(request.owner, clue)));
  }

  @Builder
  combinationNoticeContent(request: CompletionNoticeRequest, width: number, height: number) {
    if (this.completionNotice === request) {
      StarwardCombinationNotice({ completedCount: request.count, hasResults: request.hasResults,
        panelWidth: width, maxHeight: height, viewportWidth: this.viewportWidth, displayFont: this.displayFont,
        finale: request.finale,
        motionEnabled: this.foreground && !this.reducedMotion,
        acknowledge: () => {
          if (request.closing || !this.isCompletionNoticeCurrent(request)) { return; }
          request.acknowledged = request.hasResults || request.finale;
          request.closing = true;
          this.closeCompletionNotice(request);
        } })
    }
  }

  private async openCompletionNotice(owner: string, count: number, hasResults: boolean, revision: number,
    finale: boolean = false): Promise<void> {
    const width: number = Math.min(680, this.viewportWidth - 48);
    const height: number = this.clueDialogHeight();
    if (width < 160 || height < 120) {
      this.interruptCombinationSequence();
      if (finale) { this.play.cancelAutomaticClues(); } else { this.play.cancelRankUpPresentation(); }
      return;
    }
    let request: CompletionNoticeRequest;
    try {
      request = new CompletionNoticeRequest(this.getUIContext().getPromptAction(), owner, count, hasResults, revision, finale);
    } catch {
      this.interruptCombinationSequence();
      if (finale) { this.play.cancelAutomaticClues(); } else { this.play.cancelRankUpPresentation(); }
      return;
    }
    this.completionNotice = request;
    if (finale) { this.finaleBackdropChanged(true); }
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
        maskColor: finale ? Color.Transparent : $r('app.color.modal_mask'), dialogTransition: dialogTransition,
        maskTransition: fade,
        autoCancel: !hasResults && !finale, onWillDismiss: hasResults || finale ? () => {} : undefined,
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
    if (request.finale) {
      this.finaleBackdropChanged(false);
      if (completed && request.acknowledged) { this.play.acknowledgeFinale(request.revision); }
      else { this.play.cancelAutomaticClues(); }
      return;
    }
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

  @Monitor('play.completionRevision', 'viewportWidth', 'viewportHeight', 'play.submitting', 'recoveryVisible',
    'foreground', 'keyboardVisible', 'sheet')
  completionChanged(): void {
    const revision: number = this.play.completionRevision;
    if (revision <= 0 || revision === this.seenCompletionRevision) {
      this.seenCompletionRevision = revision;
      return;
    }
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    if (!this.foreground || !this.play.visible || snapshot === null || snapshot.detail.status !== 'completed' ||
      this.sheet !== null) {
      return;
    }
    if (this.play.finaleStage === 'notice') {
      if (!this.questionInteractionReady() || this.viewportWidth - 48 < 160 || this.clueDialogHeight() < 120) { return; }
      this.seenCompletionRevision = revision;
      this.openCompletionNotice(this.play.imageOwnerKey(), snapshot.detail.completedLevels, false, revision, true);
    } else if (snapshot.presentation.completionStyle === 'finale') {
      this.seenCompletionRevision = revision;
    } else if (snapshot.detail.totalLevels > 1) {
      this.seenCompletionRevision = revision;
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

  @Monitor('play.finaleStage', 'play.snapshot', 'foreground')
  finaleAdvanced(): void {
    if (!this.foreground || !this.play.visible || this.play.error.length > 0 ||
      this.play.snapshot?.detail.status !== 'completed') { return; }
    const revision: number = this.play.completionRevision;
    if (this.play.finaleStage === 'destination' && this.finalDestination() === null) {
      this.play.dismissFinaleDestination(revision);
    }
    if (this.play.finaleStage !== 'combination' || this.combinationSequenceActive) { return; }
    this.combinationOwner = this.play.imageOwnerKey();
    this.combinationRevision = revision;
    this.combinationQueue = this.play.completionClues.filter((clue: GameplayClue) =>
      this.isCombinationCurrent(this.combinationOwner, clue));
    this.combinationSequenceActive = true;
    this.showNextCombination();
  }

  private destinationBottomInset(): number { return 14 + this.bgmBottomInset(); }

  private finalDestination(): GameplayCompletionTarget | null {
    if (this.play.finaleStage !== 'destination' || !this.play.visible || this.play.error.length > 0) { return null; }
    const target: GameplayCompletionTarget | null = this.play.currentFinaleTarget();
    return target?.kind === 'narrative' || (target?.kind === 'link' && externalClueLinkHref(target.url).length > 0) ?
      target : null;
  }

  private openFinalDestination(): void {
    const target: GameplayCompletionTarget | null = this.finalDestination();
    if (target === null) { return; }
    if (target.kind === 'narrative') {
      const assignmentId: string = this.play.snapshot?.detail.id ?? '';
      this.openNarrative(assignmentId, target.id);
      return;
    }
    const href: string = externalClueLinkHref(target.url);
    const revision: number = this.play.completionRevision;
    const owner: string = this.play.imageOwnerKey();
    this.launchClueLink(href, null, () => this.play.completionRevision === revision &&
      this.play.imageOwnerKey() === owner && externalClueLinkHref(this.finalDestination()?.url ?? '') === href, true);
  }

  @Monitor('play.rankUp', 'play.visible', 'play.error', 'play.snapshot', 'play.automaticClue',
    'play.loading', 'play.starting', 'play.submitting', 'play.refreshing', 'seenCompletionRevision',
    'completionNotice', 'combinationSequenceActive', 'keyboardVisible', 'foreground', 'recoveryVisible',
    'textClue', 'viewer.visible', 'viewer.closing', 'videoViewer.visible', 'videoViewer.closing',
    'viewportWidth', 'viewportHeight', 'sheet', 'play.answerBurst', 'accountCovered', 'narrativeCovered')
  rankChanged(): void {
    if (this.rankNotice !== null) {
      if (!this.isRankNoticeCurrent(this.rankNotice)) { this.cancelRankNotice(); }
      return;
    }
    const rank: GameplayRankUp | null = this.play.rankUp;
    const width: number = Math.min(680, this.viewportWidth - (this.viewportWidth <= 620 ? 28 : 48));
    const height: number = this.clueDialogHeight();
    if (rank === null || !this.foreground || this.accountCovered || !this.play.visible || this.play.error.length > 0 ||
      this.play.imageOwnerKey().length === 0 || this.play.automaticClue !== null ||
      this.seenCompletionRevision !== this.play.completionRevision || !this.questionInteractionReady() ||
      width < 160 || height < 120) { return; }
    this.openRankNotice(rank, width, height);
  }

  private isRankNoticeCurrent(request: RankDialogRequest): boolean {
    return this.rankNotice === request && this.play.rankUp === request.rank && this.foreground && !this.accountCovered &&
      !this.narrativeCovered && this.gameplayOwnerCurrent() && this.play.imageOwnerKey() === request.owner;
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
        alignment: DialogAlignment.Center, width, cornerRadius: 24, isModal: true, showInSubWindow: false,
        backgroundColor: Color.Transparent, backgroundBlurStyle: BlurStyle.NONE,
        maskColor: $r('app.color.modal_mask'), dialogTransition, maskTransition, autoCancel: false,
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

  private questionNavigationItems(): GameplayProgressItem[] {
    return (this.play.snapshot?.levels || []).map((level: GameplayLevel, index: number): GameplayProgressItem => ({
      id: level.id,
      completed: level.completedAt.length > 0,
      enabled: this.questionInteractionReady(true) && this.play.canMoveTo(index),
      locked: level.question === null
    }));
  }

  private selectQuestion(index: number): void {
    if (!this.questionInteractionReady(true) || !this.play.canMoveTo(index) || index === this.play.activeIndex) {
      return;
    }
    this.stopInlineVideo();
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

  private currentOption(key: string): GameplayOption | undefined {
    return this.play.currentLevel()?.question?.options.find((item: GameplayOption) => item.key === key);
  }

  private optionImage(key: string): string {
    return this.currentOption(key)?.imageUrl || '';
  }

  private optionVideo(key: string): string {
    return this.currentOption(key)?.videoUrl.trim() || '';
  }

  private optionOwner(key: string): string { return `${this.imageOwner()}:option:${key}`; }

  private choiceMediaCurrent(owner: string, key: string): boolean {
    return this.sheet === 'choice' && this.sheetVisible && this.gameplaySheetOwnerCurrent() &&
      this.optionOwner(key) === owner && this.currentOption(key) !== undefined;
  }

  private openOptionImage(key: string): void {
    const source: string = this.optionImage(key);
    const owner: string = this.optionOwner(key);
    if (!this.questionMediaReady('choice') || source.length === 0 ||
      this.optionVideo(key).length > 0) { return; }
    this.stopInlineVideo();
    StarwardKeyboard.dismiss(this.getUIContext());
    this.viewer.open([source], 0, () => this.choiceMediaCurrent(owner, key) && this.optionImage(key) === source &&
      this.optionVideo(key).length === 0);
  }

  private openOptionVideo(key: string): void {
    const owner: string = this.optionOwner(key);
    const source: string = this.optionVideo(key);
    const poster: string = this.optionImage(key);
    this.openManualVideo(source, poster, () => this.choiceMediaCurrent(owner, key) &&
      this.optionVideo(key) === source && this.optionImage(key) === poster, '', '', 'choice');
  }

  private currentCompleted(): boolean {
    return (this.play.currentLevel()?.completedAt || '').length > 0;
  }

  private interactionReady(): boolean {
    return !this.play.loading && !this.play.starting && !this.play.submitting && !this.play.refreshing;
  }

  private gameplayOverlayReady(allowsKeyboard: boolean = false, allowsSheet: boolean = false): boolean {
    return !this.narrativeCovered && this.interactionReady() && (allowsKeyboard || !this.keyboardVisible) &&
      !this.recoveryVisible && this.play.answerBurst === null && (allowsSheet || this.sheet === null) &&
      this.textClue === null && !this.viewer.visible && !this.viewer.closing &&
      !this.videoViewer.visible && !this.videoViewer.closing &&
      !this.combinationSequenceActive && this.completionNotice === null && this.rankNotice === null;
  }

  private questionInteractionReady(allowsKeyboard: boolean = false): boolean {
    return this.gameplayOverlayReady(allowsKeyboard) && this.displayedJourneyNotification() === null;
  }

  private gameplayOwnerCurrent(): boolean {
    const snapshot: GameplaySnapshot | null = this.play.snapshot;
    return this.playerId.length > 0 && this.play.visible && this.play.error.length === 0 &&
      snapshot !== null && snapshot.detail.player === this.playerId && snapshot.detail.status !== 'cancelled';
  }

  private visibleAnswerBurst(): GameplayAnswerBurst | null {
    const burst: GameplayAnswerBurst | null = this.play.answerBurst;
    if (burst === null || !this.foreground || this.accountCovered || this.narrativeCovered ||
      this.keyboardVisible || this.recoveryVisible || this.sheet !== null || !this.interactionReady() ||
      this.textClue !== null || this.viewer.visible || this.viewer.closing || this.videoViewer.visible ||
      this.videoViewer.closing || this.completionNotice !== null || this.rankNotice !== null ||
      !this.gameplayOwnerCurrent() || !this.play.answerBurstCurrent(burst)) { return null; }
    return burst;
  }

  private visibleAnswerBursts(): GameplayAnswerBurst[] {
    const burst: GameplayAnswerBurst | null = this.visibleAnswerBurst();
    return burst === null ? [] : [burst];
  }

  private finishAnswerBurst(burst: GameplayAnswerBurst, advance: boolean): void {
    if (this.visibleAnswerBurst() === burst) { this.play.finishAnswerBurst(burst, advance); }
  }

  private journeyPresentationReady(): boolean {
    return this.journeyPollingAllowed && this.foreground && !this.accountCovered && this.journey.gameplayReady &&
      this.gameplayOwnerCurrent() &&
      this.gameplayOverlayReady() && !this.play.advancing && this.play.automaticClue === null &&
      this.play.finaleStage === 'idle' &&
      this.play.rankUp === null && this.seenCompletionRevision === this.play.completionRevision &&
      this.viewportWidth - this.leftInset - this.rightInset >= 160 &&
      this.viewportHeight - this.foregroundTopInset() >= 120;
  }

  private manualJourneyNotification(): GameNotification | null {
    return this.journey.archivedOnRoute(this.play.snapshot?.detail.id ?? '');
  }

  private displayedJourneyNotification(): GameNotification | null {
    return this.journeyPresentationReady() ? this.manualJourneyNotification() ??
      this.journey.automaticUnreadOnRoute(this.play.snapshot?.detail.id ?? '') : null;
  }

  private showJourneyLauncher(): boolean {
    return this.journeyPresentationReady() && this.journey.unreadCount > 0 &&
      this.displayedJourneyNotification() === null &&
      this.viewportHeight - this.foregroundTopInset() - this.bgmLayoutBottomInset() >= JOURNEY_LAUNCHER_SIZE + 24;
  }

  private measureCombinationDock(area: Area | null): void {
    if (area === null) {
      this.combinationDock = null;
      return;
    }
    const left: number = Number(area.position.x);
    const top: number = Number(area.position.y);
    const width: number = Number(area.width);
    const height: number = Number(area.height);
    if (!Number.isFinite(left) || !Number.isFinite(top) ||
      !Number.isFinite(width) || width <= 0 || !Number.isFinite(height) || height <= 0) { return; }
    const previous: JourneyDockObstacle | null = this.combinationDock;
    if (previous === null || previous.left !== left || previous.top !== top ||
      previous.width !== width || previous.height !== height) {
      this.combinationDock = new JourneyDockObstacle(left, top, width, height);
    }
  }

  private openManualJourney(id: string): void {
    if (this.showJourneyLauncher()) {
      this.stopInlineVideo();
      this.journey.openRouteArchive(this.play.snapshot?.detail.id ?? '', id);
    }
  }

  private async closeJourneyNotification(id: string, retry: boolean): Promise<void> {
    if (this.displayedJourneyNotification()?.id !== id) { return; }
    await this.journey.closeRouteNote(this.play.snapshot?.detail.id ?? '', id, retry);
  }

  private openGameplayJourneyLink(href: string): boolean {
    if (this.displayedJourneyNotification() === null || !this.openJourneyLink(href)) { return false; }
    this.journey.clearRouteArchive();
    return true;
  }

  private journeyReadError(): string {
    const id: string = this.displayedJourneyNotification()?.id ?? '';
    return id.length > 0 && this.journey.readErrorId === id ? this.journey.readErrorMessage : '';
  }

  private setJourneyVideo(open: boolean): void {
    this.journeyVideoOpen = open;
    this.updateBgm(open);
  }

  private answerMotionEnabled(): boolean {
    return this.foreground && !this.reducedMotion && !this.recoveryVisible && this.textClue === null &&
      !this.viewer.visible && !this.viewer.closing && !this.videoViewer.visible && !this.videoViewer.closing &&
      !this.combinationSequenceActive && this.completionNotice === null && this.rankNotice === null &&
      this.displayedJourneyNotification() === null;
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
    if (this.viewportWidth <= 620) { return Math.max(20, Math.min(24, this.viewportWidth * 0.054)); }
    return Math.max(21, Math.min(26, this.viewportWidth * 0.05));
  }

  private questionMediaHeight(): number { return this.viewportWidth <= 620 ? 300 : 420; }

  private shownAnswer(): string {
    return this.currentCompleted() ? this.play.currentLevel()?.lastAnswer || '' : this.play.draftAnswer;
  }

  @Computed
  get composerView(): GameplayComposerView {
    const answer: string = this.shownAnswer();
    const option: GameplayOption | undefined = this.currentOption(answer);
    const interactionReady: boolean = this.questionInteractionReady(true);
    const completed: boolean = this.currentCompleted();
    const action: GameplayComposerAction = completed ?
      this.play.canMoveTo(this.play.activeIndex + 1) ? 'next' : 'none' :
      this.play.retryAnswer && !this.play.submitting ? 'retry' : 'submit';
    return {
      choice: this.play.currentLevel()?.question?.kind === 'choice', choiceKey: option?.key ?? '',
      choiceLabel: option ? option.text || `选项 ${option.key}` : '', answer: answer,
      placeholder: this.play.currentLevel()?.question?.placeholder || '输入你的答案',
      editable: this.play.answerEditable(), completed: completed, interactionReady: interactionReady,
      action: action, actionEnabled: interactionReady && (action !== 'submit' || this.play.answerAllowed()),
      submitting: this.play.submitting, advancing: this.play.advancing
    };
  }

  private performComposerAction(action: GameplayComposerAction): void {
    if (!this.questionInteractionReady(true) || action !== this.composerView.action) { return; }
    if (action === 'submit' && this.play.answerAllowed()) {
      this.submit();
    } else if (action === 'retry') {
      this.showRecovery();
    } else if (action === 'next') {
      this.play.nextQuestion();
    }
  }

  private submit(): void {
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.submitAnswer(this.autoNextDelay);
  }

  private retryAnswer(): void {
    StarwardKeyboard.dismiss(this.getUIContext());
    this.play.retrySubmission(this.autoNextDelay);
  }

  @Builder
  questionNavigation() {
    GameplayProgress({ items: this.questionNavigationItems(), activeIndex: this.play.activeIndex,
      reducedMotion: this.reducedMotion,
      select: (index: number) => this.selectQuestion(index) })
  }

  @Builder
  choiceOptions() {
    Column({ space: 10 }) {
      ForEach(this.optionKeys(), (key: string, index: number) => {
        StarwardChoiceOption({ optionKey: key, text: this.currentOption(key)?.text || `选项 ${key}`,
          group: `gameplay-${this.play.currentLevel()?.id || ''}`, radioId: `gameplay-option-${index}`,
          cardId: `gameplay-choice-${index}`, imageId: `gameplay-option-image-${index}`,
          selected: this.shownAnswer() === key, editable: this.play.answerEditable(),
          imageSource: this.optionImage(key), ownerKey: this.optionOwner(key),
          videoSource: this.optionVideo(key), videoId: `gameplay-option-video-${index}`,
          mediaEnabled: this.questionMediaReady('choice'), videoPlayable: this.questionMediaReady('choice'),
          ownerIsCurrent: (owner: string) => this.choiceMediaCurrent(owner, key),
          imageCache: this.imageCache,
          reducedMotion: this.reducedMotion, chosen: () => {
            if (this.questionMediaReady('choice') && this.play.answerEditable() && this.currentOption(key)) {
              this.play.editAnswer(key);
              this.closeGameplaySheet();
            }
          },
          opened: () => this.openOptionImage(key), videoOpened: () => this.openOptionVideo(key) })
      }, (key: string) => key)
    }.id('gameplay-choice-options').width('100%')
  }

  @Builder
  answerFeedback(levelId: string) {
    Column({ space: 8 }) {
      if (!this.currentCompleted() && this.play.blockedReason().length > 0) {
        Text(this.play.blockedReason()).id('gameplay-penalty').width('100%')
          .fontSize(16).lineHeight('25.6fp').fontColor($r('app.color.accent_text'))
          .padding({ top: 6, bottom: 6, left: 12, right: 12 }).borderRadius(12)
          .backgroundColor($r('app.color.accent_faint'))
      }
      if (this.hasAnswerFeedback()) {
        ForEach([this.play.feedbackVersion], (version: number) => {
          Column() {
            StarwardQuestFeedback({
              message: this.play.answerError.length > 0 ? this.play.answerError : this.play.feedback,
              messageId: this.play.answerError.length > 0 ? 'gameplay-answer-error' : 'gameplay-feedback-message',
              danger: this.answerFeedbackDanger(),
              transient: this.play.feedbackTransient, motionEnabled: this.answerMotionEnabled()
            })
          }.width('100%').onAreaChange((_previous: Area, area: Area) => this.measureNewFeedback(levelId, version, area))
        }, (version: number) => version.toString())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private choicePopupStatus(): string {
    if (this.currentCompleted()) { return '已作答 · 仅查看选项'; }
    if (!this.play.answerEditable()) { return '当前仅可查看选项'; }
    const selection: GameplayOption | undefined = this.currentOption(this.shownAnswer());
    return selection ? `已选 ${selection.key} · 点击选项可更换` : '请选择一个选项';
  }

  @Builder
  private gameplaySheetMediaCovers() {
    Column() {}.width(0).height(0).bindContentCover(this.viewer.visible, this.imageViewer(), this.viewerOptions())
    Column() {}.width(0).height(0)
      .bindContentCover(this.videoViewer.visible, this.gameplayVideoViewer(), this.videoViewerOptions())
  }

  @Builder
  private choicePopupContent() {
    if (this.sheet === 'choice' && this.gameplaySheetOwnerCurrent()) {
      this.choiceOptions()
      this.gameplaySheetMediaCovers()
    }
  }

  @Builder
  private hintSheet() {
    GameplayHintSheet({ maxHeight: this.viewportHeight * 0.88,
      leftInset: this.leftInset, rightInset: this.rightInset, close: () => this.closeGameplaySheet(),
      content: () => { this.hintSheetContent() } })
  }

  @Builder
  private hintSheetContent() {
    if (this.sheet === 'hint' && this.gameplaySheetOwnerCurrent()) {
      ForEach(this.contentBlocks(this.readableQuestionId()), (block: GameplayContentBlock, index: number) => {
        if (block.hint.trim().length > 0) {
          Column() {
            this.questionLegacyBody(this.readableQuestionId(), index, true)
          }.width('100%').padding({ top: 15, bottom: 15, left: 17, right: 17 })
            .border({ width: 1, radius: 16, color: $r('app.color.border') })
            .backgroundColor($r('app.color.input'))
        }
      }, (block: GameplayContentBlock, index: number) => `${index}:${block.hint}`)
      this.gameplaySheetMediaCovers()
    }
  }

  @Builder
  questionLegacyBody(levelId: string, index: number, hint: boolean) {
    StarwardRichContent({ content: this.legacyQuestionText(levelId, index, hint),
      nodeId: this.questionLegacyNodeId(levelId, index, hint),
      ownerKey: this.questionImageOwner(levelId), ownerIsCurrent: (key: string) =>
        this.imageCacheOwner().length > 0 && this.showsQuestionImages(levelId) && key === this.questionImageOwner(levelId),
      imageCache: this.imageCache, inlineVideo: this.inlineVideo, inlineVideoSlot: this.inlineVideoSlot,
      color: hint ? $r('app.color.text') : $r('app.color.strong'),
      textSize: hint ? 15 : this.viewportWidth <= 620 ? 19 : 20, textWeight: hint ? 400 : 600,
      lineHeight: hint ? '26.25fp' : this.viewportWidth <= 620 ? '29.45fp' : '31.2fp',
      active: levelId === this.readableQuestionId(),
      interactive: this.questionMediaReady(hint ? 'hint' : null),
      showMedia: this.showsQuestionImages(levelId), availableWidth: hint ? 0 : this.questionContentWidth,
      maxMediaHeight: hint && this.viewportWidth <= 620 ? 340 : this.questionMediaHeight(), reducedMotion: this.reducedMotion,
      openImage: (partIndex: number) => this.openQuestionLegacyMedia(levelId, index, hint, partIndex),
      openVideo: (partIndex: number) => this.openQuestionLegacyMedia(levelId, index, hint, partIndex),
      playVideo: (partIndex: number) => this.openQuestionLegacyMedia(levelId, index, hint, partIndex, true),
      openLink: (href: string) => this.openQuestionLegacyLink(levelId, index, hint, href) })
  }

  @Builder
  questionCard(levelId: string) {
    GameplaySurface({ lightweight: true, interactive: false, reducedMotion: this.reducedMotion }) {
      Column() {
        GameplayQuestionHeading({ questionNumber: this.levelById(levelId)?.position || 0,
          active: levelId === this.readableQuestionId(), hasHint: this.hasHints(levelId),
          hintExpanded: levelId === this.readableQuestionId() && this.sheet === 'hint' && this.sheetVisible,
          hintEnabled: this.questionMediaReady(), openHint: () => this.openGameplaySheet('hint') })
        if (this.titleVisible(levelId) && (this.levelById(levelId)?.question?.title || '').length > 0) {
          Text(this.levelById(levelId)?.question?.title || '')
            .id(levelId === this.readableQuestionId() ? 'question-title' : '').width('100%')
            .fontSize(this.questionTitleSize()).fontWeight(FontWeight.Bold)
            .lineHeight(`${this.questionTitleSize() * 1.4}fp`)
            .letterSpacing(`${-0.02 * this.questionTitleSize()}fp`)
            .lineBreakStrategy(LineBreakStrategy.BALANCED)
            .fontColor($r('app.color.strong')).margin({ top: this.viewportWidth <= 620 ? 10 : 12 })
        }
        Column({ space: this.viewportWidth <= 620 ? 14 : 16 }) {
          if (this.contentBlocks(levelId).some((block: GameplayContentBlock) => block.text.length > 0)) {
            Column({ space: this.viewportWidth <= 620 ? 14 : 16 }) {
              ForEach(this.contentBlocks(levelId), (block: GameplayContentBlock, index: number) => {
                if (block.text.length > 0) { this.questionLegacyBody(levelId, index, false); }
              }, (block: GameplayContentBlock, index: number) => `${index}:${block.text}`)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
          if (this.showsQuestionImages(levelId) && this.contentBlocks(levelId).some((block: GameplayContentBlock) =>
            block.videoUrl.trim().length > 0 || this.blockImages(block).length > 0)) {
            Column({ space: this.viewportWidth <= 620 ? 14 : 16 }) {
              ForEach(this.contentBlocks(levelId), (block: GameplayContentBlock, index: number) => {
                if (block.videoUrl.trim().length > 0) {
                  StarwardVideoPoster({ source: block.imageUrl, ownerKey: this.questionImageOwner(levelId),
                    ownerIsCurrent: (key: string) => this.imageCacheOwner().length > 0 &&
                      this.showsQuestionImages(levelId) && key === this.questionImageOwner(levelId),
                    imageCache: this.imageCache, active: levelId === this.readableQuestionId(),
                    nodeId: levelId === this.readableQuestionId() ? `gameplay-question-video-${index}` :
                      `question-video-preview-${this.levelById(levelId)?.position || 0}-${index}`,
                    playLabel: `播放题目视频 ${index + 1}`, maxHeight: this.questionMediaHeight(),
                    playable: this.questionMediaReady(),
                    play: () => this.openQuestionVideo(levelId, index) }).borderRadius(16).clip(true)
                } else if (this.blockImages(block).length > 0) {
                  StarwardQuestionImages({ sources: this.blockImages(block), ownerKey: this.questionImageOwner(levelId),
                    ownerIsCurrent: (key: string) => this.play.visible && this.play.snapshot !== null &&
                      this.showsQuestionImages(levelId) && key === this.questionImageOwner(levelId),
                    imageCache: this.imageCache, active: levelId === this.readableQuestionId(),
                    availableWidth: this.questionContentWidth,
                    groupId: levelId === this.readableQuestionId() ? `question-images-${index}` :
                      `question-preview-${this.levelById(levelId)?.position || 0}-${index}`,
                    maxHeight: this.questionMediaHeight(), reducedMotion: this.reducedMotion,
                    opened: (imageIndex: number) => {
                      if (levelId === this.readableQuestionId()) { this.openImages(index, imageIndex); }
                    } }).borderRadius(16).clip(true)
                }
              }, (block: GameplayContentBlock, index: number) =>
                `${index}:${JSON.stringify([block.videoUrl, block.imageUrl, block.imageUrls])}`)
            }.width('100%').alignItems(HorizontalAlign.Start)
          }
        }.id(levelId === this.readableQuestionId() ? 'question-content' : '')
          .width('100%').alignItems(HorizontalAlign.Start).margin({ top: 14 })
          .onAreaChange((_previous: Area, current: Area) => {
            const width: number = Number(current.width);
            if (levelId === this.readableQuestionId() && Number.isFinite(width) && width > 2 &&
              width !== this.questionContentWidth) { this.questionContentWidth = width; }
          })
        if (levelId === this.readableQuestionId()) {
          if ((!this.currentCompleted() && this.play.blockedReason().length > 0) || this.hasAnswerFeedback()) {
            Column() {
              this.answerFeedback(levelId)
            }.width('100%').margin({ top: 16 })
          }
          if (this.currentClues().length > 0) {
            StarwardClueArchive({ clues: this.currentClues(), reducedMotion: this.reducedMotion,
              pendingNarrativeIds: this.pendingNarrativeIds(), opened: (id: string) => this.openClue(id) })
          }
        }
      }.id(levelId === this.readableQuestionId() ? 'gameplay-question-card' : '')
        .width('100%').alignItems(HorizontalAlign.Start)
        .padding(this.viewportWidth <= 620 ? { top: 20, left: 18, right: 18, bottom: 20 } :
          { top: 22, left: 20, right: 20, bottom: 22 })
    }
  }

  @Builder
  questionBody() {
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
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  questionRegion() {
    Column({ space: 16 }) {
      if (this.hasLevelMessages()) {
        StarwardQuestMessages({ groupId: 'gameplay-level-extra', items: this.play.currentLevel()?.extraDisplay ?? [] })
      }
      this.questionBody()
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  gameplayScroll() {
    Scroll(this.questionScroller) {
      Column({ space: this.viewportWidth <= 620 ? 14 : 16 }) {
        if (this.play.error.length === 0 && this.play.snapshot !== null &&
          this.play.snapshot.detail.extraDisplay.length > 0) {
          StarwardQuestMessages({ groupId: 'assignment-extra', items: this.play.snapshot.detail.extraDisplay })
        }
        if (this.play.error.length > 0) {
          StarwardAssignmentRequest({ loadingId: 'gameplay-loading', loadingLabel: '正在展开你的旅程…',
            displayFont: this.displayFont, message: this.play.loading ? '' : this.play.error,
            motionEnabled: this.foreground && !this.reducedMotion && !this.narrativeCovered && !this.accountCovered,
            retryable: this.interactionReady(),
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
        .constraintSize({ maxWidth: GAMEPLAY_MAX_CONTENT_WIDTH + Math.max(this.readingGutter(), this.leftInset) +
          Math.max(this.readingGutter(), this.rightInset) })
        .padding({ left: Math.max(this.readingGutter(), this.leftInset), right: Math.max(this.readingGutter(), this.rightInset),
          top: this.readingTopInset(),
          bottom: this.scrollBottomClearance() })
    }.id('gameplay-page').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .clipContent(ContentClipMode.BOUNDARY)
      .fadingEdge(this.statusInset > 0, { fadingEdgeLength: LengthMetrics.vp(this.statusInset + 6) })
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
        this.revealNewFeedback();
      })
      .bindContentCover(this.textClue === null && this.sheet === null && this.videoViewer.visible,
        this.gameplayVideoViewer(), this.videoViewerOptions())
  }

  @Builder
  gameplayForeground() {
    Stack() {
      StarwardRefresh({ refreshEnabled: this.play.canRefresh(),
        request: () => this.refreshQuestion(),
        content: () => { this.gameplayScroll() } })
        .bindContentCover(this.textClue === null && this.sheet === null && this.viewer.visible,
          this.imageViewer(), this.viewerOptions())
      if (this.showCombinationLauncher()) {
        StarwardCombinationLauncher({ viewportWidth: this.viewportWidth, viewportHeight: this.viewportHeight,
          topInset: this.foregroundTopInset(), bottomInset: this.bgmLayoutBottomInset(),
          bgmLeft: this.showBgmControl() ? this.bgmLeft() : -1,
          bgmTop: this.showBgmControl() ? this.bgmTop() : -1,
          reducedMotion: this.reducedMotion, open: () => this.openLatestCombination(),
          dockChanged: (area: Area | null) => this.measureCombinationDock(area) })
      }
      if (this.showBgmControl()) {
        StarwardBgmControl({ state: this.atmosphere.state, reducedMotion: this.reducedMotion,
          viewportWidth: this.viewportWidth, viewportHeight: this.viewportHeight,
          topInset: this.foregroundTopInset(), leftInset: this.leftInset, rightInset: this.rightInset,
          bottomInset: this.bgmLayoutBottomInset(), savedX: this.atmosphere.position.x, savedY: this.atmosphere.position.y,
          ownerKey: this.atmosphereOwner, positionCommitted: (owner: string, x: number, y: number) => {
            if (this.showBgmControl()) { this.atmosphere.rememberPosition(owner, x, y); }
          }, toggle: () => {
            if (this.showBgmControl()) { this.atmosphere.toggle(this.atmosphereOwner); }
          } })
      }
      if (this.showJourneyLauncher()) {
        StarwardJourneyLauncher({ entries: this.journey.unreadEntries, unreadCount: this.journey.unreadCount,
          viewportWidth: this.viewportWidth, viewportHeight: this.viewportHeight,
          topInset: this.foregroundTopInset(), bottomInset: this.bgmLayoutBottomInset(),
          leftInset: this.leftInset, rightInset: this.rightInset, displayFont: this.displayFont,
          bgmLeft: this.showBgmControl() ? this.bgmLeft() : -1, bgmTop: this.showBgmControl() ? this.bgmTop() : -1,
          combinationDock: this.showCombinationLauncher() ? this.combinationDock : null,
          reducedMotion: this.reducedMotion, select: (id: string) => this.openManualJourney(id),
          openInbox: () => this.openInbox() })
      }
      if (this.attentionClue() !== null) {
        Column() {
          StarwardNarrativeAttention({ clue: this.attentionClue() as GameplayClue,
            showArrow: this.viewportWidth > 420, reducedMotion: this.reducedMotion,
            opened: (id: string) => this.openPendingNarrative(id) })
            .constraintSize({ maxWidth: 430 })
            .onAreaChange((_previous: Area, area: Area) => {
              const height: number = Number(area.height);
              if (Number.isFinite(height) && height > 0 && this.attentionHeight !== height) {
                this.attentionHeight = height;
              }
            })
        }.width('100%').height('100%').alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.End)
          .padding({ bottom: this.attentionInset(), left: Math.max(16, this.leftInset), right: Math.max(16, this.rightInset) })
          .hitTestBehavior(HitTestMode.None)
      }
      if (this.foreground && this.finalDestination() !== null && this.viewportWidth - this.leftInset - this.rightInset > 28) {
        Column() {
          StarwardFinalDestination({ panelWidth: Math.min(760, this.viewportWidth - 28 - this.leftInset - this.rightInset),
            displayFont: this.displayFont, launching: this.destinationLaunching,
            later: () => {
              this.clearClueLinkHandoff();
              this.play.dismissFinaleDestination(this.play.completionRevision);
            }, proceed: () => this.openFinalDestination() })
            .onAreaChange((_previous: Area, area: Area) => {
              const height: number = Number(area.height);
              if (height > 0 && Number.isFinite(height) && this.destinationHeight !== height) {
                this.destinationHeight = height;
              }
            })
        }.width('100%').height('100%').justifyContent(FlexAlign.End)
          .padding({ bottom: this.destinationBottomInset(), left: this.leftInset, right: this.rightInset })
          .hitTestBehavior(HitTestMode.None)
      }
      if (this.foreground && this.play.syncEpisode > 0 && this.play.syncEpisode !== this.play.dismissedSyncEpisode &&
        this.play.error.length === 0) {
        Column() {
          StarwardSyncNotice({ reducedMotion: this.reducedMotion, dismiss: () => this.play.dismissSyncNotice() })
        }.width('100%').align(Alignment.Top).alignItems(HorizontalAlign.Center)
          .padding({ top: this.readingTopInset(),
            left: 16 + this.leftInset, right: 16 + this.rightInset })
          .hitTestBehavior(HitTestMode.Transparent)
      }
      if (this.showComposer()) {
        Column() {
          ForEach([this.positionKey()], (owner: string) => {
            GameplayAnswerComposer({ view: this.composerView, reducedMotion: this.reducedMotion,
              choicesOpen: this.sheet === 'choice' && this.sheetVisible,
              choiceRevision: this.sheetRevision, choiceStatus: this.choicePopupStatus(),
              choiceMaxHeight: Math.max(112, Math.min(620, this.viewportHeight - this.foregroundTopInset() -
                this.composerInset() - this.composerHeight - 20)),
              choicesContent: () => { this.choicePopupContent() }, openChoices: () => {
                if (!this.composerOwnerCurrent(owner)) { return; }
                if (this.sheet === 'choice' && this.sheetVisible) { this.dismissChoicePopup(this.sheetRevision); }
                else { this.openGameplaySheet('choice'); }
              }, closeChoices: (revision: number) => this.dismissChoicePopup(revision),
              choiceStateChanged: (revision: number, visible: boolean) => this.choicePopupStateChanged(revision, visible),
              changeAnswer: (value: string) => {
                if (this.composerOwnerCurrent(owner)) { this.play.editAnswer(value); }
              }, focusChanged: (focused: boolean) => {
                if (this.composerOwnerCurrent(owner)) { this.answerFocused = focused; }
              }, primaryAction: (action: GameplayComposerAction) => {
                if (this.composerOwnerCurrent(owner)) { this.performComposerAction(action); }
              }, heightChanged: (height: number) => {
                if (this.composerOwnerCurrent(owner) && height !== this.composerHeight) { this.composerHeight = height; }
              } })
          }, (owner: string) => owner)
        }.width('100%').height('100%').justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Center)
          .padding({ bottom: this.composerInset(), left: Math.max(GAMEPLAY_COMPOSER_SIDE_GUTTER, this.leftInset),
            right: Math.max(GAMEPLAY_COMPOSER_SIDE_GUTTER, this.rightInset) }).hitTestBehavior(HitTestMode.None)
      }
      if (this.titlePresent()) {
        Column() {
          GameplayFloatingTitle({ title: this.play.snapshot?.detail.title ?? '', hidden: this.titleHidden,
            reducedMotion: this.reducedMotion, back: () => { if (!this.handleBack()) { this.leave(); } } })
            .constraintSize({ maxWidth: GAMEPLAY_MAX_CONTENT_WIDTH })
        }.width('100%').alignItems(HorizontalAlign.Center)
          .padding({ top: this.titleTopInset(), left: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.leftInset),
            right: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.rightInset) })
          .hitTestBehavior(HitTestMode.None)
      }
    }.width('100%').height(LayoutPolicy.matchParent).alignContent(Alignment.Top)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
      .accessibilityLevel(this.visibleAnswerBurst() === null ? 'auto' : 'no-hide-descendants')
      .bindSheet(this.sheet === 'hint' && this.sheetVisible, this.hintSheet, this.gameplaySheetOptions())
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.play.loading && this.play.snapshot === null && this.play.error.length === 0) {
        StarwardAssignmentRequest({ loadingId: 'gameplay-loading', loadingLabel: '正在展开你的旅程…',
          motionEnabled: this.foreground &&
          !this.reducedMotion && !this.narrativeCovered && !this.accountCovered, fullScreen: true,
          topInset: this.statusInset, bottomInset: this.safeBottom() })
      } else {
        this.gameplayForeground()
      }
      StarwardGlassDialog({ visible: this.recoveryVisible && this.clueDialogHeight() > 0 && this.viewportWidth > 40,
        panelWidth: Math.min(460, this.viewportWidth - 40), panelCornerRadius: 18, reducedMotion: this.reducedMotion,
        content: () => { this.answerRecovery() }, back: () => this.stayOnQuestion(),
        failed: () => this.stayOnQuestion() })
      StarwardJourneyNotificationDialog({ note: this.displayedJourneyNotification(), playerId: this.playerId,
        active: this.journeyPresentationReady(), displayFont: this.displayFont, reducedMotion: this.reducedMotion,
        queuedCount: this.manualJourneyNotification() === null ? this.journey.unreadCount : 1,
        pending: this.journey.readingId.length > 0, error: this.journeyReadError(),
        close: (id: string) => { this.closeJourneyNotification(id, false); },
        acknowledge: (id: string) => { this.closeJourneyNotification(id, true); },
        openInternalLink: (href: string) => this.openGameplayJourneyLink(href),
        backHandlerChanged: (handler: (() => boolean) | null) => { this.journeyBack = handler; },
        playingChanged: (open: boolean) => this.setJourneyVideo(open),
        playbackReady: () => this.atmosphere.whenQuiet(this.atmosphereOwner) })
      if (this.visibleAnswerBurst() !== null) {
        Stack() {
          ForEach(this.visibleAnswerBursts(), (burst: GameplayAnswerBurst) => {
            StarwardStarBurstOverlay({ title: burst.completed ? '全部完成' : '回答正确', xpDelta: burst.xpDelta,
              actionLabel: burst.nextIndex >= 0 ? '下一题' : '继续', autoAdvance: burst.autoAdvance,
              reducedMotion: this.reducedMotion,
              proceed: () => this.finishAnswerBurst(burst, true), dismiss: () => this.finishAnswerBurst(burst, false) })
          }, (burst: GameplayAnswerBurst) => burst.id.toString())
        }.width('100%').height('100%')
      }
    }.width('100%').height('100%')
  }
}
