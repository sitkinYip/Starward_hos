import { autoFillManager, common } from '@kit.AbilityKit';
import { LengthMetrics, window, KeyboardAvoidMode as PageKeyboardAvoidMode } from '@kit.ArkUI';
import { SliceViewModel } from '../features/SliceViewModel';
import { AssignmentBrief } from '../features/AssignmentBrief';
import { GAMEPLAY_MAX_CONTENT_WIDTH, GAMEPLAY_TITLE_MIN_TOP, GAMEPLAY_TITLE_SIDE_GUTTER } from '../features/GameplayChrome';
import { GameplayPage } from '../features/GameplayPage';
import { GameplayViewModel } from '../features/GameplayViewModel';
import { AssignmentAtmosphereState } from '../features/AssignmentAtmosphereState';
import { JourneyNotificationsViewModel } from '../features/JourneyNotificationsViewModel';
import { NarrativePage } from '../features/NarrativePage';
import { NarrativeRoute, NarrativeViewModel } from '../features/NarrativeViewModel';
import { StarLettersPage } from '../features/StarLettersPage';
import { RewardsPage } from '../features/RewardsPage';
import { StarwardJourneyCard, StarwardJourneyLoading } from '../features/StarwardJourneyCard';
import { StarLetterEntry } from '../business/StarLetters';
import { GameNotification } from '../business/GameNotification';
import { GameplayPresentation, GameplaySnapshot } from '../business/GameplayModels';
import { assignmentBgmSource, gameplayBgmSource } from '../business/GameplayBgm';
import { assignmentBackgroundSource, gameplayBackgroundSource } from '../business/GameplayBackground';
import { QUEST_BGM_MARGIN, QUEST_BGM_SIZE, questBgmCoordinate } from '../business/QuestBgmDock';
import { createSliceViewModel } from '../features/createSliceViewModel';
import { AssignmentSummary, AvatarImage, AvatarUpload, GameFailure } from '../business/models';
import { ProfilePage } from '../features/ProfilePage';
import { SettingsPage } from '../features/SettingsPage';
import { AvatarEditor, AvatarSelection } from '../platform/AvatarEditor';
import { assignmentKind } from '../business/assignmentState';
import { AppLifecycle } from '../platform/AppLifecycle';
import { AppEnvironment } from '../platform/AppEnvironment';
import { HostedPrivacy, HostedPrivacyRequestResult, HostedPrivacyState } from '../platform/HostedPrivacy';
import { AppTheme, ThemePreference, ThemeSelection } from '../platform/AppTheme';
import { LaunchRoutes, PushRoute } from '../platform/LaunchRoutes';
import { HarmonyPushDevice } from '../platform/HarmonyPush';
import { PushOnboardingViewModel } from '../features/PushOnboardingViewModel';
import { PushAction, PushPermissionFlow } from '../features/PushPermissionFlow';
import { createPushPermissionFlow } from '../features/createPushPermissionFlow';
import { PushOnboardingPreference } from '../platform/PushOnboardingPreference';
import { StarwardPushOnboarding } from '../features/StarwardPushOnboarding';
import { LabeledInput } from '../ui/LabeledInput';
import { ErrorNotice, InlineError } from '../ui/ErrorMessages';
import { PrimaryAction } from '../ui/PrimaryAction';
import { StarwardStarRingEmblem } from '../ui/StarwardStarRingEmblem';
import { StarwardAssignmentRequest } from '../ui/StarwardAssignmentRequest';
import { StarwardMaterial, StarwardTitleSurface } from '../ui/StarwardMaterial';
import { StarwardBottomTabs, StarwardJourneyTabs, StarwardSyncNote } from '../ui/StarwardTabs';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardAccountSheet } from '../ui/StarwardAccountSheet';
import { STARWARD_LOBBY_TITLE_HEIGHT, StarwardLobbyHeader } from '../ui/StarwardLobbyHeader';
import { STARWARD_SESSION_TITLE_HEIGHT, StarwardSessionTitle } from '../ui/StarwardGlassHeader';
import { StarwardPageHeading } from '../ui/StarwardPageHeading';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardErrorToast } from '../ui/StarwardErrorToast';
import { StarwardJourneyToast } from '../ui/StarwardJourneyToast';
import { StarwardMotion } from '../ui/StarwardMotion';
import { StarwardQuestAvatar } from '../ui/StarwardQuestHeaderMotion';
import { StarwardQuestMessages } from '../ui/StarwardQuestMessages';
import { StarwardAvatarCrop } from '../ui/StarwardAvatarCrop';
import { StarwardPrivacySheet } from '../ui/StarwardPrivacySheet';
import { StarwardKeyboard } from '../ui/StarwardKeyboard';
import { StarwardFinaleBackdrop } from '../ui/StarwardCombinationNotice';
import { StarwardGlassBackdrop, StarwardModalBackdropState } from '../ui/StarwardGlassBackdrop';
import { STARWARD_GLASS_DIALOG_FADE } from '../ui/StarwardGlassDialog';
import { JOURNEY_LAUNCHER_SIZE, StarwardJourneyLauncher } from '../ui/StarwardJourneyLauncher';
import { StarwardJourneyNotificationDialog } from '../ui/StarwardJourneyNotificationDialog';
import { StarwardSyncNotice } from '../ui/StarwardSyncNotice';
import { StarwardSessionStatus } from '../ui/StarwardSessionStatus';
import { StarwardBgmControl } from '../ui/StarwardBgmControl';
import { StarwardQuestBackground } from '../ui/StarwardQuestBackground';
import { StarwardQuestAtmosphere } from '../ui/StarwardQuestAtmosphere';
import { hilog } from '@kit.PerformanceAnalysisKit';

const AUTH_TITLE_HEIGHT: number = 92;

/** Observe the notification model directly instead of a non-observable intermediate owner. */
@ComponentV2
struct JourneyUnreadEvents {
  @Require @Param journey: JourneyNotificationsViewModel;
  @Event arrived: (count: number) => void = () => {};
  @Event allRead: () => void = () => {};

  @Monitor('journey.newUnreadRevision')
  private unreadArrived(): void {
    const count: number = this.journey.newUnreadCount;
    this.journey.dismissNewUnread();
    if (count > 0) { this.arrived(count); }
  }

  @Monitor('journey.unreadClearedRevision')
  private readCompleted(): void {
    if (this.journey.unreadClearedRevision > 0 && this.journey.unreadCount === 0) { this.allRead(); }
  }

  build() {
    Column() {}.width(0).height(0).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}

/** Keep route-scoped reads in sync with both branches of the assignment destination. */
@ComponentV2
struct AssignmentSynchronization {
  @Require @Param journey: JourneyNotificationsViewModel;
  @Require @Param play: GameplayViewModel;
  @Require @Param narrative: NarrativeViewModel;
  @Require @Param atmosphere: AssignmentAtmosphereState;
  @Require @Param atmosphereOwner: string;
  @Require @Param accountId: string;
  @Require @Param briefingPresentation: GameplayPresentation | null;
  @Require @Param assignmentId: string;
  @Require @Param destinationActive: boolean;
  @Require @Param backgroundPlayback: boolean;
  @Require @Param authorized: boolean;
  @Require @Param assigned: boolean;
  @Event briefingPollingChanged: (id: string) => void = () => {};

  aboutToAppear(): void {
    this.update();
    this.updateAtmosphere();
  }

  aboutToDisappear(): void {
    this.journey.setPolling(false);
    this.briefingPollingChanged('');
    this.atmosphere.release();
  }

  @Monitor('assignmentId', 'destinationActive', 'authorized', 'assigned', 'narrative.route', 'play.visible', 'play.snapshot',
    'play.error', 'play.refreshing')
  private update(): void {
    this.briefingPollingChanged(this.destinationActive && this.narrative.route === null && !this.play.visible ?
      this.assignmentId : '');
    this.journey.setPolling(this.destinationActive && this.authorized && this.narrative.route === null &&
      !this.play.refreshing &&
      (this.play.visible ? this.play.snapshot?.detail.id === this.assignmentId &&
        this.play.snapshot?.detail.status !== 'cancelled' && this.play.error.length === 0 : this.assigned));
  }

  @Monitor('assignmentId', 'destinationActive', 'backgroundPlayback', 'authorized', 'assigned', 'accountId', 'atmosphereOwner', 'briefingPresentation',
    'narrative.route', 'play.visible', 'play.snapshot', 'play.error', 'play.activeIndex')
  private updateAtmosphere(): void {
    if (!this.authorized) { this.atmosphere.release(); return; }
    const foreground: boolean = this.destinationActive && this.narrative.route === null;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (this.play.visible) {
      const snapshot: GameplaySnapshot | null = this.play.snapshot;
      if (snapshot === null || snapshot.detail.id !== this.assignmentId || snapshot.detail.player !== this.accountId ||
        (snapshot.detail.status !== 'active' && snapshot.detail.status !== 'completed') || this.play.error.length > 0) {
        this.atmosphere.release();
        return;
      }
      const level = this.play.currentLevel();
      this.atmosphere.update(context, this.atmosphereOwner, this.accountId, gameplayBackgroundSource(snapshot, level),
        gameplayBgmSource(snapshot, level), foreground, this.backgroundPlayback);
    } else if (this.assigned && this.briefingPresentation !== null) {
      this.atmosphere.update(context, this.atmosphereOwner, this.accountId,
        assignmentBackgroundSource(this.briefingPresentation), assignmentBgmSource(this.briefingPresentation), foreground);
    } else {
      this.atmosphere.release();
    }
  }

  build() {
    Column() {}.width(0).height(0).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }
}

@Entry
@ComponentV2
struct Index {
  @Provider('starwardModalBackdrop') private modalBackdrop: StarwardModalBackdropState = new StarwardModalBackdropState();
  @Env(WritableEnvKey.FONT_SCALE) fontScale: number;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Local vm: SliceViewModel = createSliceViewModel();
  @Local private atmosphere: AssignmentAtmosphereState = new AssignmentAtmosphereState();
  @Local account: string = '';
  @Local password: string = '';
  @Local oldPassword: string = '';
  @Local newPassword: string = '';
  @Local confirmation: string = '';
  @Local history: boolean = false;
  @Local selectedId: string = '';
  @Local private showHelp: boolean = false;
  @Local private authViewportHeight: number = 0;
  @Local mainIndex: number = 0;
  @Local returnAssignmentId: string = '';
  @Local avatarSelection: AvatarSelection | null = null;
  @Local showAvatarCrop: boolean = false;
  @Local avatarPicking: boolean = false;
  @Local theme: ThemePreference = AppTheme.preference;
  @Local themeError: string = '';
  @Local private narrativeFont: string = 'serif';
  @Local private showFinaleBackdrop: boolean = false;
  @Local private foreground: boolean = true;
  @Local private privacyAllowed: boolean = !AppEnvironment.hostedPrivacy;
  @Local private privacyBusy: boolean = false;
  @Local private privacyError: string = '';
  @Local private pushFlow: PushPermissionFlow | null = null;
  @Local private pushInboxRevision: number = 0;
  @Local private pushOnboarding: PushOnboardingViewModel | null = null;
  @Local private navigationDepth: number = 0;
  @Local private lobbyRouteTransitioning: boolean = false;
  @Local private gameplayDestinationShown: boolean = false;
  @Local private gameplayTitleHidden: boolean = false;
  @Local private gameplayTitleCovered: boolean = false;
  @Local private briefViewportWidth: number = 0;
  @Local private briefViewportHeight: number = 0;
  @Local private briefViewportTop: number = 0;
  private motion: StarwardMotion = new StarwardMotion();
  private authToast: StarwardErrorToast = new StarwardErrorToast();
  private authFeedbackEpoch: number = 0;
  private journeyToast: StarwardJourneyToast = new StarwardJourneyToast();
  private journeyToastTimer: number = -1;
  private journeyToastRevision: number = 0;
  private avatarEditor: AvatarEditor = new AvatarEditor();
  private avatarPickRevision: number = 0;
  private starLettersInterrupted: boolean = false;
  private gameplayJourneyBack: (() => boolean) | null = null;
  private briefJourneyBack: (() => boolean) | null = null;
  private paths: NavPathStack = new NavPathStack();
  private readonly lobbyTitlePaths: NavPathStack = new NavPathStack();
  private assignmentDestinationRevision: number = 0;
  private timer: number = -1;
  private privacyOwnerActive: boolean = false;
  private privacyOwnerRevision: number = 0;
  private privacyRestorePending: boolean = true;
  private privacyRevocationHandled: boolean = false;
  private unsubscribePrivacy: (() => void) | null = null;
  private readonly displayFont: string = 'sans-serif';
  private lifecycle: (foreground: boolean) => void = (foreground: boolean) => {
    this.foreground = foreground;
    if (foreground && AppEnvironment.hostedPrivacy) { this.checkHostedPrivacy(); }
    this.lobbyVisibilityChanged();
    if (foreground) {
      this.startClock();
      if (AppEnvironment.pushEnabled && this.privacyAllowed) { this.vm.retryPushRemoval(); }
      if (this.privacyAllowed && this.vm.gate === 'home') {
        this.dispatchPendingRoute();
        this.syncPushOnArrival();
        this.vm.refresh();
        const destinations: string[] = this.paths.getAllPathName();
        if (destinations[destinations.length - 1] === 'assignment' && this.selectedId.length > 0 &&
          !this.vm.play.visible) {
          this.vm.openAssignment(this.selectedId);
        }
        if (this.mainIndex === 2 && this.paths.size() === 0 && !this.vm.securityUnconfirmed) {
          this.vm.starLetters.refresh();
          this.vm.journey.refresh();
        }
      }
    } else {
      this.clearAuthToast();
      this.stopClock();
      this.atmosphere.suspend(true);
      this.vm.rewards.setActive(false);
      this.vm.stopBriefingSync();
      this.vm.starLetters.suspend();
      this.vm.journey.pauseReads();
      if (this.vm.play.starting) { this.vm.play.cancelAutomaticClues(); }
    }
  };

  private routeListener: (id: string) => void = (_id: string) => { this.dispatchPendingRoute(); };

  private dispatchPendingRoute(): void {
    if (!this.privacyAllowed || !this.foreground || this.vm.gate !== 'home' ||
      this.vm.securityUnconfirmed || this.vm.securityBusy) {
      return;
    }
    const push: PushRoute | null = LaunchRoutes.nextPush();
    if (push !== null) {
      void this.dispatchPushRoute(push);
      return;
    }
    const id: string = LaunchRoutes.take();
    if (id.length === 0) {
      return;
    }
    this.vm.narrative.close();
    this.paths.clear(!this.motion.reduced);
    this.openAssignment(id);
  }

  private async dispatchPushRoute(route: PushRoute): Promise<void> {
    const owner: string = this.vm.player.id;
    const matches: boolean = await this.vm.matchesPushProfile(route.profileId);
    if (!this.privacyAllowed || !this.foreground || this.vm.gate !== 'home' || this.vm.player.id !== owner ||
      this.vm.securityUnconfirmed || this.vm.securityBusy || !LaunchRoutes.consumePush(route) || !matches) { return; }
    if (route.kind === 'inbox') {
      this.pushInboxRevision++;
      const alreadyOnInbox: boolean = this.mainIndex === 2;
      this.goMain(2);
      if (alreadyOnInbox) { void this.vm.journey.refresh(); }
    } else {
      this.vm.narrative.close();
      this.paths.clear(!this.motion.reduced);
      void this.openAssignment(route.target);
    }
  }

  private pushAvailable(): boolean {
    return AppEnvironment.pushEnabled && this.privacyAllowed && this.vm.gate === 'home' &&
      !this.vm.securityBusy && !this.vm.securityUnconfirmed && this.foreground;
  }

  private syncPushOnArrival(): void {
    const canPrompt: boolean = this.pushFlow?.promptChecked !== true && !this.privacyBusy &&
      !this.showAvatarCrop && !this.avatarPicking && !this.lobbyRouteTransitioning && this.paths.size() === 0;
    this.syncPush(canPrompt ? 'initial' : 'sync');
  }

  private pushOnboardingOwner(): string {
    return AppEnvironment.pushEnabled && this.privacyAllowed && this.vm.gate === 'home' &&
      !this.vm.securityBusy && !this.vm.securityUnconfirmed ? this.vm.player.id : '';
  }

  private pushOnboardingEligible(): boolean {
    return this.pushOnboardingOwner().length > 0 && this.foreground && this.pushFlow?.promptChecked === true &&
      this.pushFlow?.busy !== true && !this.privacyBusy &&
      !this.showAvatarCrop && !this.avatarPicking && !this.lobbyRouteTransitioning &&
      !this.gameplayDestinationShown && this.navigationDepth === 0 && this.paths.size() === 0 &&
      this.vm.narrative.route === null &&
      this.vm.journey.activeNotificationId.length === 0;
  }

  private syncPush(action: PushAction): void {
    if (this.pushAvailable()) { void this.pushFlow?.sync(action); }
  }

  private checkHostedPrivacy(): boolean {
    if (!this.privacyOwnerActive) { return false; }
    const state: HostedPrivacyState = HostedPrivacy.getState();
    if (state === HostedPrivacyState.ALLOWED) {
      this.privacyAllowed = true;
      this.privacyRevocationHandled = false;
      if (this.foreground && this.privacyRestorePending && this.vm.gate === 'login') {
        this.privacyRestorePending = false;
        void this.vm.restoreSession();
      }
      return true;
    }
    if (state === HostedPrivacyState.CONFIRMED_NOT_ALLOWED) {
      this.privacyAllowed = false;
      this.privacyRestorePending = false;
      if (!this.privacyRevocationHandled || this.vm.gate === 'signout-error') {
        this.privacyRevocationHandled = true;
        this.logout();
      }
    } else if (this.privacyAllowed) {
      this.suspendPrivateSession();
    }
    return false;
  }

  private suspendPrivateSession(): void {
    this.privacyAllowed = false;
    this.pushFlow?.reset();
    // An explicit signout already owns durable deletion; never start restoration behind it.
    this.privacyRestorePending = this.vm.gate !== 'signout' && this.vm.gate !== 'signout-error';
    this.vm.suspendSession();
    this.clearAccountContext();
  }

  private async requestHostedPrivacy(): Promise<void> {
    if (!this.privacyOwnerActive || !this.foreground || this.privacyBusy || this.checkHostedPrivacy()) { return; }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context === undefined) {
      this.privacyError = '暂时无法打开隐私确认，请重试。';
      return;
    }
    const revision: number = this.privacyOwnerRevision;
    this.privacyError = '';
    this.privacyBusy = true;
    const result: HostedPrivacyRequestResult = await HostedPrivacy.requestConsent(context);
    if (!this.privacyOwnerActive || revision !== this.privacyOwnerRevision) { return; }
    this.privacyBusy = false;
    if (!this.checkHostedPrivacy() && result === HostedPrivacyRequestResult.LAUNCH_FAILED) {
      this.privacyError = '暂时无法打开隐私确认，请重试。';
    }
  }

  private async openHostedPrivacyPolicy(): Promise<void> {
    if (!this.privacyOwnerActive || !this.foreground) { return; }
    const revision: number = this.privacyOwnerRevision;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    const opened: boolean = context !== undefined && await HostedPrivacy.openPolicy(context);
    if (!opened && this.privacyOwnerActive && this.foreground && revision === this.privacyOwnerRevision) {
      StarwardFeedback.toast(this.getUIContext(), '暂时无法打开隐私政策，请稍后重试。');
    }
  }

  aboutToAppear(): void {
    try {
      this.getUIContext().getFont().registerFont({
        familyName: 'StarwardSerif', familySrc: $rawfile('fonts/NotoSerifSC.ttf')
      });
      this.narrativeFont = 'StarwardSerif';
    } catch (error) {
      this.narrativeFont = 'serif';
    }
    this.getUIContext().setKeyboardAvoidMode(PageKeyboardAvoidMode.RESIZE);
    this.motion.start();
    AppLifecycle.subscribe(this.lifecycle);
    LaunchRoutes.subscribe(this.routeListener);
    this.paths.setInterception({
      willShow: () => {
        this.navigationDepth = this.paths.size();
        this.clearJourneyToast();
        this.lobbyRouteTransitioning = true;
        this.lobbyVisibilityChanged();
        this.journeyScopeChanged();
      },
      didShow: () => {
        this.navigationDepth = this.paths.size();
        this.lobbyRouteTransitioning = false;
        this.lobbyVisibilityChanged();
        this.journeyScopeChanged();
        if (this.paths.size() === 0) { this.syncPushOnArrival(); }
      }
    });
    this.foreground = AppLifecycle.isForeground();
    if (AppEnvironment.pushEnabled) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context !== undefined) {
        this.vm.attachPush(new HarmonyPushDevice(context));
        this.pushFlow = createPushPermissionFlow(context, () => this.privacyAllowed ? this.vm.pushSyncOwner() : '',
          () => this.foreground, (force: boolean) => this.vm.syncPush(force));
        this.pushOnboarding = new PushOnboardingViewModel(this.vm.onboardingSubscriptions,
          new PushOnboardingPreference(context));
      }
    }
    if (AppEnvironment.hostedPrivacy) {
      this.privacyOwnerActive = true;
      this.unsubscribePrivacy = HostedPrivacy.subscribe(() => { this.checkHostedPrivacy(); });
      this.checkHostedPrivacy();
    }
    this.lobbyVisibilityChanged();
    this.startClock();
    if (!AppEnvironment.hostedPrivacy) { void this.vm.restoreSession(); }
  }

  aboutToDisappear(): void {
    this.pushOnboarding?.bindOwner('');
    this.clearJourneyToast();
    this.clearAuthToast();
    this.pushFlow?.reset();
    this.pushFlow = null;
    this.privacyOwnerActive = false;
    this.privacyOwnerRevision++;
    this.privacyBusy = false;
    this.privacyError = '';
    this.unsubscribePrivacy?.();
    this.unsubscribePrivacy = null;
    if (AppEnvironment.hostedPrivacy && this.privacyAllowed) { this.suspendPrivateSession(); }
    this.paths.setInterception({});
    this.vm.setLobbyPolling(false);
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.vm.narrative.close();
    this.vm.starLetters.suspend();
    this.vm.rewards.setActive(false);
    this.vm.journey.suspend();
    this.vm.play.leave();
    this.motion.stop();
    AppLifecycle.unsubscribe(this.lifecycle);
    LaunchRoutes.unsubscribe(this.routeListener);
    this.stopClock();
    this.clearPasswords();
    this.cancelAvatarCrop();
  }

  @Monitor('mainIndex', 'navigationDepth', 'foreground', 'privacyAllowed', 'vm.gate', 'vm.player',
    'vm.securityBusy', 'vm.securityUnconfirmed', 'vm.narrative.route')
  rewardsVisibilityChanged(): void {
    this.vm.rewards.setActive(this.rewardsVisible(), this.profileStatsVisible());
  }

  private rewardsVisible(): boolean {
    return this.privacyAllowed && this.foreground && this.mainIndex === 1 && this.paths.size() === 0 &&
      this.vm.narrative.route === null && this.vm.gate === 'home' && !this.vm.securityUnconfirmed;
  }

  @Monitor('mainIndex', 'navigationDepth', 'foreground', 'privacyAllowed', 'vm.gate', 'vm.securityUnconfirmed')
  lobbyVisibilityChanged(): void {
    this.vm.setLobbyPolling(this.lobbyVisible() || this.profileStatsVisible());
  }

  private lobbyVisible(): boolean {
    return this.privacyAllowed && this.foreground && this.mainIndex === 0 && !this.lobbyRouteTransitioning &&
      this.paths.size() === 0 && this.vm.gate === 'home' && !this.vm.securityUnconfirmed;
  }

  private profileActive(): boolean {
    return this.mainIndex === 3 && this.navigationDepth === 0 && this.privacyAllowed && this.vm.gate === 'home';
  }

  private profileStatsVisible(): boolean {
    return this.profileActive() && this.foreground && !this.vm.securityBusy && !this.vm.securityUnconfirmed;
  }

  private journeySessionReady(): boolean {
    return this.privacyAllowed && this.foreground && this.vm.gate === 'home' &&
      this.vm.player.id.length > 0 && !this.vm.securityBusy && !this.vm.securityUnconfirmed;
  }

  @Monitor('mainIndex', 'foreground', 'privacyAllowed', 'vm.gate', 'vm.securityUnconfirmed', 'vm.securityBusy',
    'showAvatarCrop', 'gameplayDestinationShown')
  private journeyScopeChanged(): void {
    this.clearJourneyToast();
    // AssignmentSynchronization owns quest reads and pauses them around its refresh.
    this.vm.journey.setInboxPolling(this.journeySessionReady() && !this.gameplayDestinationShown);
  }

  private clearJourneyToast(): void {
    this.journeyToastRevision++;
    clearTimeout(this.journeyToastTimer);
    this.journeyToastTimer = -1;
    this.journeyToast.dismiss();
  }

  private showJourneyToast(message: string): void {
    this.clearJourneyToast();
    const owner: string = this.vm.player.id;
    const revision: number = this.journeyToastRevision;
    this.journeyToastTimer = setTimeout(() => {
      this.journeyToastTimer = -1;
      if (revision !== this.journeyToastRevision || !this.journeySessionReady() ||
        this.vm.player.id !== owner || this.showAvatarCrop) { return; }
      this.journeyToast.show(this.getUIContext(), message,
        this.paths.size() === 0 ? this.bottomContentClearance() : this.safeBottom() + 12, () => {
          if (revision === this.journeyToastRevision && this.vm.player.id === owner && this.journeySessionReady()) {
            this.openJourneyInbox();
          }
        });
    }, 320);
  }

  private journeyArrived(count: number): void {
    if (count > 0 && this.journeySessionReady() && !this.gameplayDestinationShown &&
      this.vm.narrative.route === null && !(this.mainIndex === 2 && this.paths.size() === 0) &&
      !this.showAvatarCrop) {
      this.showJourneyToast(`收到 ${count} 封新来信`);
    }
  }

  private journeyReadCompleted(): void {
    if (this.vm.journey.unreadClearedRevision > 0 && this.vm.journey.unreadCount === 0 &&
      this.assignmentDestinationActive()) {
      this.showJourneyToast('已阅读的来信可在「来信」中查看。');
    }
  }

  private openJourneyInbox(): void {
    if (!this.journeySessionReady()) { return; }
    this.clearJourneyToast();
    this.pushInboxRevision++;
    this.goMain(2);
    this.vm.journey.clearRouteArchive();
    void this.vm.journey.refresh();
    this.journeyScopeChanged();
  }

  @Monitor('vm.gate')
  gateChanged(): void {
    this.clearAuthToast();
    this.showHelp = false;
    this.clearJourneyToast();
    this.clearPasswords();
    if (this.vm.gate !== 'home') {
      this.pushFlow?.reset();
      this.atmosphere.release();
      this.paths.clear(false);
      this.mainIndex = 0;
      this.returnAssignmentId = '';
      this.cancelAvatarCrop();
    } else {
      this.dispatchPendingRoute();
      this.syncPushOnArrival();
    }
  }

  @Monitor('vm.securityUnconfirmed', 'vm.securityBusy', 'privacyAllowed')
  secureRoutesAvailable(): void {
    if (this.pushAvailable()) { this.syncPushOnArrival(); }
    this.dispatchPendingRoute();
  }

  @Monitor('showAvatarCrop')
  cropVisibilityChanged(): void {
    if (!this.showAvatarCrop) {
      this.avatarSelection?.dispose();
      this.avatarSelection = null;
      this.avatarEditor.dispose();
    }
  }

  private assignmentDestinationActive(): boolean {
    return this.privacyAllowed && this.foreground && this.gameplayDestinationShown && this.vm.gate === 'home' &&
      !this.vm.securityUnconfirmed && this.selectedId.length > 0;
  }

  private assignmentAuthorized(): boolean {
    return this.privacyAllowed && this.vm.gate === 'home' && !this.vm.securityUnconfirmed &&
      this.selectedId.length > 0 && (this.gameplayDestinationShown || this.vm.narrative.route !== null) &&
      this.vm.detail.id === this.selectedId && this.vm.detail.player === this.vm.player.id &&
      this.vm.detail.status !== 'cancelled';
  }

  private atmosphereOwner(revision: Object): string {
    return `${this.vm.player.id}:${revision}`;
  }

  private handleAssignmentJourneyBack(): boolean {
    if (!this.gameplayDestinationShown) { return false; }
    return (this.vm.play.visible ? this.gameplayJourneyBack?.() : this.briefJourneyBack?.()) ?? false;
  }

  onBackPress(): boolean {
    if (!this.privacyAllowed) { return false; }
    const keyboardHeight: number = Math.max(this.avoidArea.keyboard.bottomRect.height,
      this.avoidArea.keyboard.topRect.height, this.avoidArea.keyboard.leftRect.height, this.avoidArea.keyboard.rightRect.height);
    hilog.info(0x0000, 'StarwardBack', 'keyboard=%{public}s height=%{public}d main=%{public}d depth=%{public}d',
      this.avoidArea.keyboard.visible.toString(), Math.round(keyboardHeight), this.mainIndex, this.paths.size());
    if (this.vm.gate === 'signout') { return true; }
    if (this.avoidArea.keyboard.visible && keyboardHeight > 0) {
      StarwardKeyboard.dismiss(this.getUIContext());
      return true;
    }
    if (this.showAvatarCrop) {
      this.cancelAvatarCrop();
      return true;
    }
    if (this.closeSettings()) { return true; }
    if (this.closeNarrative()) { return true; }
    if (this.handleAssignmentJourneyBack()) { return true; }
    if (this.vm.rewards.selected !== null && this.mainIndex === 1) {
      this.vm.rewards.close();
      return true;
    }
    if (this.vm.gate === 'home' && this.paths.size() === 0 && this.mainIndex !== 0) {
      this.goMain(0);
      return true;
    }
    if (this.paths.size() > 0) {
      this.leaveGameplay(false);
    }
    return false;
  }

  private cancelAvatarCrop(): void {
    this.avatarPickRevision++;
    this.avatarPicking = false;
    this.showAvatarCrop = false;
    this.avatarSelection?.dispose();
    this.avatarSelection = null;
    this.avatarEditor.dispose();
  }

  private async pickAvatar(): Promise<void> {
    if (this.vm.gate !== 'home' || this.vm.profileBusy || this.vm.securityBusy || this.avatarPicking ||
      this.vm.securityUnconfirmed) {
      return;
    }
    const revision: number = ++this.avatarPickRevision;
    const playerId: string = this.vm.player.id;
    this.avatarPicking = true;
    try {
      const selected: AvatarSelection | null = await this.avatarEditor.pick();
      if (revision !== this.avatarPickRevision || this.vm.gate !== 'home' || this.vm.player.id !== playerId) {
        selected?.dispose();
        return;
      }
      if (selected !== null) {
        this.avatarSelection = selected;
        this.showAvatarCrop = true;
      }
    } catch (error) {
      if (revision === this.avatarPickRevision && this.vm.gate === 'home' && this.vm.player.id === playerId) {
        this.vm.reportProfileError(error instanceof GameFailure ? error.message :
          '图片处理失败，请重新选择 JPG、PNG 或 WebP 图片。');
      }
    } finally {
      if (revision === this.avatarPickRevision) {
        this.avatarPicking = false;
      }
    }
  }

  private goMain(index: number): void {
    if (this.vm.gate !== 'home') {
      return;
    }
    const gameplayVisible: boolean = this.vm.play.visible;
    if ((index === 1 || index === 2) && this.vm.securityUnconfirmed) {
      StarwardFeedback.toast(this.getUIContext(), '请先退出并重新登录，确认密码修改结果。');
      return;
    }
    if (this.paths.size() > 0 && this.selectedId.length > 0) {
      this.returnAssignmentId = this.selectedId;
    }
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.vm.narrative.close();
    this.vm.play.leave();
    this.vm.journey.setPolling(false);
    this.vm.journey.leaveRoute(this.selectedId);
    this.paths.clear(!this.motion.reduced);
    this.selectMain(index);
    if (gameplayVisible) {
      this.vm.refresh();
    }
  }

  private selectMain(index: number): void {
    if ((index === 1 || index === 2) && this.vm.securityUnconfirmed) {
      StarwardFeedback.toast(this.getUIContext(), '请先退出并重新登录，确认密码修改结果。');
      return;
    }
    if (this.mainIndex !== index) {
      if (this.mainIndex === 2) {
        this.vm.starLetters.suspend();
        this.vm.journey.suspend();
      }
      this.mainIndex = index;
      this.lobbyVisibilityChanged();
      this.journeyScopeChanged();
      if (index === 2 && this.foreground) {
        this.vm.starLetters.refresh();
        this.vm.journey.refresh();
      }
    }
    if (index === 3) { this.vm.openProfile(); }
  }

  private leaveGameplay(popPath: boolean = true): void {
    const gameplayVisible: boolean = this.vm.play.visible;
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.vm.journey.setPolling(false);
    this.vm.journey.leaveRoute(this.selectedId);
    this.vm.play.leave();
    if (popPath) {
      this.paths.pop(!this.motion.reduced);
    }
    if (gameplayVisible) {
      this.vm.refresh();
    }
  }

  private openFinaleNarrative(assignmentId: string, contentId: string): void {
    if (this.vm.gate !== 'home' || this.vm.securityUnconfirmed ||
      !this.vm.play.canOpenFinaleNarrative(assignmentId, contentId)) { return; }
    const route: NarrativeRoute = new NarrativeRoute(assignmentId, contentId);
    if (!this.vm.narrative.open(route)) { return; }
    this.vm.play.cancelAutomaticClues();
    this.paths.pushPath({ name: 'narrative', param: route }, !this.motion.reduced);
  }

  private openStarLetter(entry: StarLetterEntry): void {
    if (!this.foreground || this.vm.gate !== 'home' || this.vm.securityUnconfirmed || this.mainIndex !== 2 ||
      this.paths.size() !== 0 || !this.vm.starLetters.canOpen(entry.assignmentId, entry.contentId)) { return; }
    const route: NarrativeRoute = new NarrativeRoute(entry.assignmentId, entry.contentId, 'star-letters');
    if (!this.vm.narrative.open(route)) { return; }
    this.starLettersInterrupted = this.vm.starLetters.loading;
    this.vm.starLetters.suspend();
    this.paths.pushPath({ name: 'narrative', param: route }, !this.motion.reduced);
  }

  private openQuestClue(assignmentId: string, clueId: string, contentId: string): boolean {
    const names: string[] = this.paths.getAllPathName();
    if (!this.foreground || this.vm.gate !== 'home' || this.vm.securityUnconfirmed ||
      names[names.length - 1] !== 'assignment' ||
      !this.vm.play.canOpenNarrativeClue(assignmentId, clueId, contentId)) { return false; }
    const route: NarrativeRoute = new NarrativeRoute(assignmentId, contentId, 'quest-clue');
    if (!this.vm.narrative.open(route)) { return false; }
    this.vm.play.cancelAutoAdvance();
    this.paths.pushPath({ name: 'narrative', param: route }, !this.motion.reduced);
    return true;
  }

  private openJourneyLink(href: string): boolean {
    if (!this.foreground || this.vm.gate !== 'home' || this.vm.securityUnconfirmed ||
      this.vm.narrative.route !== null) { return false; }
    const path: string = href.split(/[?#]/)[0];
    if (path === '/' || path === '/rewards' || path === '/notifications' || path === '/profile') {
      this.vm.journey.close();
      this.goMain(path === '/' ? 0 : path === '/rewards' ? 1 : path === '/notifications' ? 2 : 3);
      return true;
    }
    const story: RegExpMatchArray | null = path.match(/^\/play\/([A-Za-z0-9_-]{1,100})\/content\/([A-Za-z0-9_-]{1,100})\/?$/);
    if (story !== null) {
      const route: NarrativeRoute = new NarrativeRoute(story[1], story[2], 'journey');
      if (!this.vm.narrative.open(route)) { return false; }
      this.vm.journey.pauseReads();
      this.vm.journey.close();
      this.vm.journey.clearRouteArchive();
      this.vm.play.cancelAutoAdvance();
      this.paths.pushPath({ name: 'narrative', param: route }, !this.motion.reduced);
      return true;
    }
    const assignment: RegExpMatchArray | null = path.match(/^\/play\/([A-Za-z0-9_-]{1,100})\/?$/);
    if (assignment === null) { return false; }
    this.vm.journey.close();
    if (!this.vm.play.visible || assignment[1] !== this.selectedId) {
      this.paths.clear(!this.motion.reduced);
      this.openAssignment(assignment[1]);
    }
    return true;
  }

  private closeNarrative(): boolean {
    const names: string[] = this.paths.getAllPathName();
    if (names[names.length - 1] !== 'narrative') { return false; }
    const route: NarrativeRoute | null = this.vm.narrative.route;
    const lost: boolean = this.vm.narrative.accessLost;
    const interrupted: boolean = this.starLettersInterrupted;
    this.starLettersInterrupted = false;
    this.vm.narrative.close();
    this.paths.pop(!this.motion.reduced);
    if (route?.source === 'star-letters') {
      if (lost) { this.vm.starLetters.hideEntry(route.assignmentId, route.contentId); }
      if (this.foreground && this.vm.gate === 'home') {
        if (interrupted) {
          this.vm.starLetters.refresh();
        } else if (lost) {
          this.vm.starLetters.retryAssignment(route.assignmentId);
        }
      }
    } else if (route?.source === 'quest-clue' && lost && this.foreground && this.vm.gate === 'home') {
      this.vm.play.refresh();
    }
    return true;
  }

  private startClock(): void {
    this.stopClock();
    this.vm.tick();
    this.timer = setInterval(() => this.vm.tick(), 1000);
  }

  private stopClock(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private clearPasswords(): void {
    this.password = '';
    this.oldPassword = '';
    this.newPassword = '';
    this.confirmation = '';
  }

  private logout(): void {
    this.vm.logout();
    this.clearAccountContext();
  }

  private clearAccountContext(): void {
    LaunchRoutes.clear();
    this.atmosphere.release();
    this.showFinaleBackdrop = false;
    this.paths.clear(false);
    this.clearPasswords();
    this.account = '';
    this.history = false;
    this.selectedId = '';
    this.mainIndex = 0;
    this.returnAssignmentId = '';
    this.cancelAvatarCrop();
  }

  private setTheme(mode: ThemePreference): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context === undefined) {
      this.themeError = '主题切换失败，请重试。';
      return;
    }
    const result = AppTheme.select(context, mode);
    if (result === ThemeSelection.ApplyFailed) {
      this.themeError = '主题切换失败，请重试。';
      return;
    }
    this.theme = AppTheme.preference;
    this.themeError = result === ThemeSelection.SaveFailed ? '主题已切换，保存失败，请重试。' : '';
  }

  private visibleItems(history: boolean): AssignmentSummary[] {
    return this.vm.items.filter((item: AssignmentSummary) => history ?
      item.status === 'completed' || item.status === 'cancelled' :
      item.status === 'assigned' || item.status === 'active');
  }

  private timeLabel(value: string): string {
    if (value.length === 0) {
      return '时间待确认';
    }
    const date: Date = new Date(value);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  private levelLabel(item: AssignmentSummary): string {
    return item.maxLevel === null ? `等级 ${item.minLevel} 及以上` : `等级 ${item.minLevel}—${item.maxLevel}`;
  }

  private async openAssignment(id: string): Promise<void> {
    if (this.vm.gate !== 'home') {
      return;
    }
    if (this.vm.securityUnconfirmed) {
      StarwardFeedback.toast(this.getUIContext(), '请先退出并重新登录，确认密码修改结果。');
      return;
    }
    this.lobbyRouteTransitioning = true;
    this.pushOnboarding?.setEligible(false);
    this.selectMain(0);
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.gameplayDestinationShown = false;
    this.gameplayTitleHidden = false;
    this.gameplayTitleCovered = false;
    this.selectedId = id;
    this.vm.journey.setPolling(false);
    this.vm.journey.clearRouteArchive();
    this.vm.narrative.close();
    this.vm.play.leave();
    this.paths.pushPath({ name: 'assignment', param: ++this.assignmentDestinationRevision }, !this.motion.reduced);
    this.lobbyVisibilityChanged();
    await this.vm.openAssignment(id);
  }

  @Builder
  icon(source: Resource, size: number, color: ResourceColor) {
    Image(source).width(size).height(size).fillColor(color).objectFit(ImageFit.Contain).accessibilityLevel('no')
  }

  @Builder
  brand() {
    Row({ space: 8 }) {
      Image($r('app.media.starward_mark')).width(34).height(34).objectFit(ImageFit.Contain).accessibilityLevel('no')
      Text('赴星之约').fontSize(16).lineHeight('24fp').fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.strong')).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.accessibilityText('赴星之约')
  }

  @Builder
  themeChoice(mode: ThemePreference, label: string, source: Resource, id: string) {
    Button({ type: ButtonType.Normal }) {
      Image(source).width(17).height(17)
        .fillColor(this.theme === mode ? $r('app.color.accent_text') : $r('app.color.subtle'))
        .objectFit(ImageFit.Contain).accessibilityLevel('no')
    }.id(id).height(40).width(40).padding(10).borderRadius(999)
      .backgroundColor(this.theme === mode ? $r('app.color.accent_soft') : Color.Transparent)
      .accessibilityText(label).accessibilitySelected(this.theme === mode).onClick(() => this.setTheme(mode))
  }

  @Builder
  themePicker() {
    Row({ space: 2 }) {
      this.themeChoice(ThemePreference.System, '跟随系统', $r('app.media.icon_desktop'), 'theme-system')
      this.themeChoice(ThemePreference.Light, '浅色', $r('app.media.icon_sun'), 'theme-light')
      this.themeChoice(ThemePreference.Dark, '深色', $r('app.media.icon_moon'), 'theme-dark')
    }.id('theme-picker').padding(3).backgroundColor($r('app.color.glass_floating'))
      .border({ width: 1, color: $r('app.color.border'), radius: 999 })
      .accessibilityText('主题')
  }

  private themeLabel(): string {
    if (this.theme === ThemePreference.Light) { return '浅色'; }
    return this.theme === ThemePreference.Dark ? '深色' : '跟随系统';
  }

  @Builder
  private passportThemeChoice(mode: ThemePreference, label: string, source: Resource, nodeId: string) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 4 }) {
        Image(source).width(16).height(16).objectFit(ImageFit.Contain)
          .fillColor(this.theme === mode ? $r('app.color.on_accent') : $r('app.color.muted'))
          .accessibilityLevel('no')
        Text(label).fontSize(13).fontWeight(FontWeight.Medium)
          .fontColor(this.theme === mode ? $r('app.color.on_accent') : $r('app.color.muted'))
      }.justifyContent(FlexAlign.Center)
    }.id(nodeId).layoutWeight(1).constraintSize({ minHeight: 44 }).padding(4).borderRadius(999)
      .backgroundColor(this.theme === mode ? $r('app.color.accent') : Color.Transparent)
      .accessibilityText(label).accessibilitySelected(this.theme === mode).onClick(() => this.setTheme(mode))
  }

  @Builder
  private passportThemePicker() {
    Row({ space: 2 }) {
      this.passportThemeChoice(ThemePreference.System, '跟随系统', $r('app.media.icon_desktop'), 'theme-system')
      this.passportThemeChoice(ThemePreference.Light, '浅色', $r('app.media.icon_sun'), 'theme-light')
      this.passportThemeChoice(ThemePreference.Dark, '深色', $r('app.media.icon_moon'), 'theme-dark')
    }.id('theme-picker').width('100%').padding(4).backgroundColor($r('app.color.inset'))
      .border({ width: 1, color: $r('app.color.border'), radius: 999 }).accessibilityText('主题')
  }

  private openSettings(notificationsOnly: boolean = false): void {
    if (!this.privacyAllowed || this.vm.gate !== 'home' || this.settingsOnTop() ||
      (notificationsOnly && !AppEnvironment.pushEnabled)) {
      return;
    }
    this.lobbyRouteTransitioning = true;
    this.pushOnboarding?.setEligible(false);
    this.paths.pushPath({ name: notificationsOnly ? 'notification-settings' : 'settings' }, !this.motion.reduced);
  }

  private closeSettings(): boolean {
    if (!this.settingsOnTop()) { return false; }
    this.paths.pop(!this.motion.reduced);
    return true;
  }

  private topDestination(): string {
    const destinations: string[] = this.paths.getAllPathName();
    return destinations[destinations.length - 1] ?? '';
  }

  private settingsOnTop(): boolean {
    const name: string = this.topDestination();
    return name === 'settings' || name === 'notification-settings';
  }

  private environmentLabel(): string {
    if (this.vm.mode === 'mock') { return '演示环境'; }
    if (this.vm.mode !== 'https') { return '环境配置无效'; }
    if (AppEnvironment.production) {
      if (AppEnvironment.hostedPrivacy) { return '邀请测试'; }
      return AppEnvironment.productionReadOnly ? '生产联调 · 只读' : '生产测试候选';
    }
    return '隔离测试环境';
  }

  @Builder
  authHeader() {
    Row() {
      this.brand()
      Blank()
      this.themePicker()
      if (AppEnvironment.showEnvironmentDiagnostics) {
        Text(this.environmentLabel()).id('environment-badge')
          .fontSize(8).lineHeight('10fp').fontColor($r('app.color.subtle')).position({ x: 0, y: 77 })
      }
    }.width('100%').height(92).padding({ left: this.safeLeft(), right: this.safeRight() })
  }

  private clearAuthToast(): void {
    this.authFeedbackEpoch++;
    this.authToast.dismiss();
  }

  private async submitLogin(): Promise<void> {
    if (this.vm.busy || this.vm.gate !== 'login') { return; }
    this.clearAuthToast();
    const epoch: number = this.authFeedbackEpoch;
    await this.vm.login(this.account, this.password, () => {
      if (AppEnvironment.production && this.foreground && this.privacyAllowed) {
        // The system reads the input nodes before the login form is removed.
        autoFillManager.requestAutoSave(this.getUIContext());
      }
    });
    if (epoch === this.authFeedbackEpoch && this.foreground && this.privacyAllowed &&
      this.vm.gate === 'login' && this.vm.loginNetworkError) {
      this.authToast.show(this.getUIContext(), this.vm.error, this.safeBottom());
    }
  }

  @Builder
  authStory() {
    Column({ space: 12 }) {
      StarwardStarRingEmblem({ diameter: this.authEmblemDiameter(), motionEnabled: this.foreground && !this.motion.reduced,
        slowOrbit: true })
      Text('赴星之约').fontSize(30).lineHeight('36fp').fontWeight(FontWeight.Bold).letterSpacing(2.4)
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
    }.id('auth-star-ring-hero').width('100%')
  }

  private authEmblemDiameter(): number {
    // Use the window before keyboard avoidance so opening the IME does not resize the mark.
    const contentHeight = this.windowSize.height - this.safeTop() - this.safeBottom() - AUTH_TITLE_HEIGHT;
    return Math.min(140, Math.max(56, contentHeight * 0.22));
  }

  @Builder
  login() {
    Column() {
      Column({ space: 16 }) {
        LabeledInput({ label: '登录账号', placeholder: '你的冒险者账号', fieldId: 'account',
          inputType: AppEnvironment.production ? InputType.USER_NAME : InputType.Normal,
          enableAutoFill: AppEnvironment.production && this.foreground,
          value: this.account, disabled: this.vm.busy, changed: (value: string) => {
            if (value !== this.account) { this.vm.clearLoginInputError(); }
            this.account = value;
          } })
        LabeledInput({ label: '密码', placeholder: '输入通行密语', fieldId: 'password', value: this.password,
          inputType: InputType.Password, enableAutoFill: AppEnvironment.production && this.foreground,
          disabled: this.vm.busy, changed: (value: string) => {
            if (value !== this.password) { this.vm.clearLoginInputError(); }
            this.password = value;
          } })
        if (!this.vm.loginNetworkError) {
          InlineError({ message: this.vm.error, fieldId: 'error-message' })
        }
        PrimaryAction({ label: this.vm.busy ? '正在打开故事…' : '进入冒险', arrow: true, pill: true,
          actionEnabled: !this.vm.busy && this.vm.mode !== 'unavailable',
          action: () => { void this.submitLogin(); } })
      }.width('100%')
      StarwardAccountSheet({ visible: this.showHelp!!,
        title: '还没有账号，或忘记了密码？', sheetHeight: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM,
        anchor: () => { this.loginHelpLink() }, content: () => { this.loginHelpContent() }
      }).width('100%').margin({ top: 12 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private loginHelpLink() {
    Button({ type: ButtonType.Normal }) {
      Text('还没有账号，或忘记了密码？').fontSize(12).lineHeight('20.4fp')
        .fontColor($r('app.color.muted')).width('100%').textAlign(TextAlign.Center)
    }.id('login-help').width('100%').constraintSize({ minHeight: 44 }).backgroundColor(Color.Transparent)
      .onClick(() => { this.showHelp = true; })
  }

  @Builder
  private loginHelpContent() {
    Column() {
      Text('账号由游戏管理员提供，暂不开放注册。忘记密码时，请联系游戏管理员重置。')
        .fontSize(15).lineHeight('24fp').fontColor($r('app.color.text')).width('100%')
    }.id('login-help-sheet').width('100%').padding({ top: 8, left: 24 + this.safeLeft(),
      right: 24 + this.safeRight(), bottom: 24 })
  }

  @Builder
  changePassword() {
    Column() {
      Row({ space: 12 }) {
        this.icon($r('app.media.icon_key'), 24, $r('app.color.accent'))
        Text('首次登录，请先修改密码').fontSize(24).fontWeight(FontWeight.Medium)
          .lineHeight('36fp').fontColor($r('app.color.strong')).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)
      Text('使用 10—71 个字符。')
        .fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted')).width('100%')
        .margin({ top: 12, bottom: 24 })
      Column({ space: 16 }) {
        LabeledInput({ label: '当前密码', fieldId: 'old-password', value: this.oldPassword,
          inputType: InputType.Password, disabled: this.vm.busy, changed: (value: string) => this.oldPassword = value })
        LabeledInput({ label: '新密码', fieldId: 'new-password', value: this.newPassword,
          inputType: InputType.Password, disabled: this.vm.busy, changed: (value: string) => this.newPassword = value })
        LabeledInput({ label: '确认新密码', fieldId: 'confirm-password', value: this.confirmation,
          inputType: InputType.Password, disabled: this.vm.busy, changed: (value: string) => this.confirmation = value })
        InlineError({ message: this.vm.error, fieldId: 'error-message' })
        PrimaryAction({ label: this.vm.busy ? '正在保存…' : '保存新密码', pill: true,
          actionEnabled: !this.vm.busy && this.vm.mode !== 'unavailable',
          action: () => { this.vm.changePassword(this.oldPassword, this.newPassword, this.confirmation); } })
        Button('退出登录', { type: ButtonType.Normal }).id('forced-logout').width('100%').height(44)
          .fontSize(14).fontColor($r('app.color.muted')).backgroundColor(Color.Transparent).onClick(() => this.logout())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  privacyPolicyLink(nodeId: string) {
    Button('隐私政策', { type: ButtonType.Normal }).id(nodeId).constraintSize({ minHeight: 44 })
      .padding({ left: 10, right: 10 }).fontSize(13).fontColor($r('app.color.accent_text'))
      .backgroundColor(Color.Transparent).onClick(() => { void this.openHostedPrivacyPolicy(); })
  }

  @Builder
  privacyGatedContent() {
    if (this.privacyAllowed) {
      this.appContent()
    } else {
      this.privacyBackdrop()
    }
  }

  @Builder
  privacyBackdrop() {
    Column() {
      StarwardTitleSurface({ titleHeight: 92, topInset: this.safeTop(), reducedMotion: this.motion.reduced,
        titleContent: () => { this.brand() } })
      Column() {
        this.authStory()
      }.width('100%').constraintSize({ maxWidth: 440 })
        .padding({ left: 20 + this.safeLeft(), right: 20 + this.safeRight() })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private authEntry() {
    Column() {
      Column() {
        InlineError({ message: this.themeError, fieldId: 'theme-error-message' })
        if (this.vm.gate === 'login') {
          this.login()
        } else {
          this.changePassword()
        }
      }.id('auth-form-card').width('100%').padding({ left: 20, right: 20, top: 24, bottom: 24 })
        .border({ width: 1, color: $r('app.color.border_strong'), radius: 24 })
        .linearGradient({ angle: 180,
          colors: [[$r('app.color.glass_card_top'), 0], [$r('app.color.glass_card_bottom'), 1]] })
      if (AppEnvironment.hostedPrivacy) {
        this.privacyPolicyLink('login-privacy-policy')
      }
      if (AppEnvironment.showEnvironmentDiagnostics) {
        Text(this.vm.mode === 'mock' ? '演示环境 · 数据仅保留在本次运行中' : this.environmentLabel())
          .id('auth-environment-note').fontSize(10).fontColor($r('app.color.subtle')).margin({ top: 12 })
      }
    }.id('auth-entry').width('100%')
  }

  @Builder
  authPage() {
    Scroll() {
      Column({ space: 16 }) {
        this.authStory()
        this.authEntry()
      }.width('100%').constraintSize({ maxWidth: 446, minHeight: this.authViewportHeight > 0 ?
        this.authViewportHeight : Math.max(0, this.windowSize.height - this.safeTop() - AUTH_TITLE_HEIGHT) })
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 18 + this.safeLeft(), right: 18 + this.safeRight(),
          top: 16, bottom: 16 + (this.keyboardOccupiesViewport() ? 0 : this.safeBottom()) })
    }.id('auth-scroll').height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off)
      .onAreaChange((_old: Area, current: Area) => {
        const height = Number(current.height);
        if (Number.isFinite(height) && height > 0 && height !== this.authViewportHeight) {
          this.authViewportHeight = height;
        }
      })
  }

  @Builder
  sessionStatus() {
    StarwardSessionStatus({
      restoring: this.vm.gate === 'restoring' || this.vm.gate === 'restore-error',
      message: this.vm.gate === 'restore-error' || this.vm.gate === 'signout-error' ? this.vm.error : '',
      displayFont: this.displayFont, viewport: this.windowSize.height, safeTop: this.safeTop(),
      safeBottom: this.safeBottom(), motionEnabled: this.foreground && !this.motion.reduced,
      retry: () => {
        if (this.vm.gate === 'restore-error') { void this.vm.restoreSession(); }
        else if (this.vm.gate === 'signout-error') { this.logout(); }
      }, useLogin: () => this.logout()
    })
  }

  @Builder
  emptyState(history: boolean) {
    Column({ space: 16 }) {
      this.icon($r('app.media.icon_compass_thin'), 64, $r('app.color.accent_muted'))
      Text(history ? '故事的第一页，还空着。' : '下一场奇遇，正在酝酿。')
        .fontSize(21).fontWeight(FontWeight.Medium).lineHeight('31.5fp')
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text(history ? '完成一场冒险，就会在这里留下你的足迹。' :
        '还没有待玩场次。找游戏管理员领取你的旅程，新的邀请会自动出现在这里。')
        .fontSize(13).lineHeight('24.7fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.id(history ? 'journey-history-empty' : 'journey-current-empty').width('100%')
      .constraintSize({ minHeight: 280 }).padding({ top: 32, bottom: 32, left: 20, right: 20 })
      .justifyContent(FlexAlign.Center).backgroundColor($r('app.color.accent_faint')).borderRadius(24)
  }

  @Builder
  journeyScroll(history: boolean) {
    Scroll() {
      Column({ space: 14 }) {
        if (this.vm.listBusy && !this.vm.lobbyHasList) {
          StarwardJourneyLoading({ animated: history === this.history && this.lobbyVisible() && !this.motion.reduced })
        } else if (!this.vm.lobbyHasList) {
          ErrorNotice({ message: this.vm.listError, retryable: !this.vm.listBusy, retry: () => this.vm.refresh() })
        }
        if (this.vm.lobbyHasList && this.visibleItems(history).length === 0) {
          this.emptyState(history)
        }
        // Server projection only: time does not change component identity.
        ForEach(this.visibleItems(history), (item: AssignmentSummary, index: number) => {
          StarwardJourneyCard({ item, rank: this.vm.player.level.order, now: this.vm.now,
            levelLabel: this.levelLabel(item), order: index,
            opensAtText: item.startsAt.length > 0 ? this.timeLabel(item.startsAt) : '',
            closesAtText: item.endsAt.length > 0 ? this.timeLabel(item.endsAt) : '',
            active: history === this.history && this.lobbyVisible(), reducedMotion: this.motion.reduced,
            open: (id: string) => { void this.openAssignment(id); } })
        }, (item: AssignmentSummary, index: number) => `${index}:${JSON.stringify(item)}`)
        StarwardSyncNote({ tailClearance: this.bottomContentClearance() })
      }.width('100%').padding({ left: 6, right: 6 })
    }.id(history ? 'history-scroll' : 'current-scroll').width('100%').height('100%')
      .scrollBar(BarState.Off).align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  journeyList(history: boolean) {
    StarwardRefresh({ refreshEnabled: this.vm.gate === 'home' && !this.vm.listBusy,
      request: async () => { await this.vm.refresh(); },
      content: () => { this.journeyScroll(history) }
    })
  }

  @Builder
  currentJourneys() {
    this.journeyList(false)
  }

  @Builder
  pastJourneys() {
    this.journeyList(true)
  }

  @Builder
  journeys() {
    Navigation(this.lobbyTitlePaths) {
      Column() {
        StarwardPageHeading({ title: '启程', nodeId: 'journey-heading' }).margin({ bottom: 14 })
        StarwardJourneyTabs({ selectedCategory: this.history ? 1 : 0, reducedMotion: this.motion.reduced,
          categoryChanged: (index: number) => { this.history = index === 1; },
          currentJourneys: () => { this.currentJourneys() }, pastJourneys: () => { this.pastJourneys() }
        }).layoutWeight(1)
      }.width('100%').height('100%')
        .padding({ left: 18, right: 18, top: 16 + STARWARD_LOBBY_TITLE_HEIGHT + this.safeTop() })
    }.mode(NavigationMode.Stack).hideBackButton(true)
      .title({ builder: this.lobbyTitle, height: STARWARD_LOBBY_TITLE_HEIGHT + this.safeTop() },
        StarwardMaterial.overlayTitleOptions())
      .width('100%').height('100%').backgroundColor(Color.Transparent)
  }

  @Builder
  lobbyTitle() {
    StarwardLobbyHeader({ player: this.vm.player, avatar: this.vm.avatarImage, reducedMotion: this.motion.reduced,
      selected: this.mainIndex === 0, viewportWidth: this.windowSize.width,
      topInset: this.safeTop(), leftInset: this.safeLeft(), rightInset: this.safeRight(),
      openPassport: () => {
        if (this.vm.gate === 'home' && this.mainIndex === 0 && this.paths.size() === 0) { this.selectMain(3); }
      }, decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar)
    })
  }

  @Builder
  home() {
    StarwardBottomTabs({ floatingGap: 10 + this.safeBottom(), selectedIndex: this.mainIndex,
      unreadLetters: this.vm.journey.unreadCount,
      reducedMotion: this.motion.reduced,
      hideBar: this.keyboardOccupiesViewport(), materialInteractionEnabled: !this.motion.reduced,
      canSelect: (index: number): boolean => {
        if (this.vm.gate !== 'home' || this.paths.size() > 0) { return false; }
        if ((index === 1 || index === 2) && this.vm.securityUnconfirmed) {
          StarwardFeedback.toast(this.getUIContext(), '请先退出并重新登录，确认密码修改结果。');
          return false;
        }
        return true;
      }, selected: (index: number) => { this.selectMain(index); },
      journeys: () => { this.journeys() }, rewards: () => { this.rewards() }, letters: () => { this.starLetters() },
      passport: () => { this.profile() }
    })
  }

  @Builder
  rewards() {
    Column() {
      RewardsPage({ model: this.vm.rewards, playerId: this.vm.player.id,
        bottomClearance: this.bottomContentClearance(), reducedMotion: this.motion.reduced, active: this.rewardsVisible(),
        canReturnToAssignment: this.returnAssignmentId.length > 0,
        returnToAssignment: () => { if (this.returnAssignmentId.length > 0) { void this.openAssignment(this.returnAssignmentId); } },
        returnHome: () => this.goMain(0), openInternalLink: (href: string) => this.openJourneyLink(href) })
    }.width('100%').height('100%').padding({ top: this.safeTop(), left: this.safeLeft(), right: this.safeRight() })
  }

  @Builder
  starLetters() {
    Column() {
      StarLettersPage({ model: this.vm.starLetters, journey: this.vm.journey, playerId: this.vm.player.id,
        displayFont: this.displayFont, openInternalLink: (href: string) => this.openJourneyLink(href),
        bottomClearance: this.bottomContentClearance(), reducedMotion: this.motion.reduced,
        inboxRouteRevision: this.pushInboxRevision,
        active: this.foreground && this.mainIndex === 2 && this.vm.narrative.route === null && !this.vm.securityUnconfirmed,
        openLetter: (entry: StarLetterEntry) => this.openStarLetter(entry) })
    }.width('100%').height('100%').padding({ top: this.safeTop(), left: this.safeLeft(), right: this.safeRight() })
  }

  @Builder
  profile() {
    Column() {
      ProfilePage({ vm: this.vm, active: this.profileActive(),
        motionEnabled: this.foreground && !this.motion.reduced,
        bottomClearance: this.bottomContentClearance(), pickingAvatar: this.avatarPicking,
        showPrivacyPolicy: AppEnvironment.hostedPrivacy, showNotifications: AppEnvironment.pushEnabled,
        themeLabel: this.themeLabel(), themeError: this.themeError,
        environmentLabel: AppEnvironment.showEnvironmentDiagnostics ? this.environmentLabel() : '',
        appearanceControls: () => { this.passportThemePicker() },
        chooseAvatar: () => this.pickAvatar(), openSettings: () => this.openSettings(),
        openNotifications: () => this.openSettings(true),
        openPrivacyPolicy: () => { void this.openHostedPrivacyPolicy(); }, logout: () => this.logout() })
    }.width('100%').height('100%').padding({ top: this.safeTop(), left: this.safeLeft(), right: this.safeRight() })
  }

  @Builder
  sessionHeader() {
    Row({ space: 12 }) {
      StarwardQuestAvatar({ name: this.vm.player.displayName, avatar: this.vm.avatarImage,
        motionEnabled: this.foreground && !this.motion.reduced,
        decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
      Column() {
        Text(this.vm.player.displayName).fontFamily(this.displayFont).fontSize(22).lineHeight('30fp')
          .fontColor($r('app.color.strong')).margin({ top: 6 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`Lv.${this.vm.player.level.order} · ${this.vm.player.level.name}`).fontFeature("'tnum' 1")
          .fontSize(11).lineHeight('13.2fp').fontColor($r('app.color.accent_muted')).margin({ top: 5 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').constraintSize({ minHeight: this.detailTitleHeight() }).padding({ bottom: 10 })
      .alignItems(VerticalAlign.Center)
  }

  private enterBriefing(): void {
    if (this.briefJourneyNote() === null && this.vm.detail.id === this.selectedId) {
      void this.vm.enterAssignment(this.selectedId);
    }
  }

  private briefJourneyReady(): boolean {
    return !this.vm.play.visible && this.assignmentDestinationActive() && this.assignmentAuthorized() &&
      this.vm.detail.status === 'assigned' &&
      this.vm.narrative.route === null && !this.vm.detailBusy && !this.vm.play.starting && !this.vm.play.retryEntry &&
      !this.showAvatarCrop &&
      !this.keyboardOccupiesViewport() && this.vm.journey.gameplayReady &&
      this.briefViewportWidth - this.safeLeft() - this.safeRight() >= 160 &&
      this.briefViewportHeight - this.briefJourneyTopInset() >= 120;
  }

  private briefJourneyNote(): GameNotification | null {
    return this.briefJourneyReady() ? this.vm.journey.archivedOnRoute(this.selectedId) ??
      this.vm.journey.automaticUnreadOnRoute(this.selectedId) : null;
  }

  private briefHeaderTop(): number {
    return Math.max(0, Math.max(GAMEPLAY_TITLE_MIN_TOP, this.safeTop()) - this.briefViewportTop);
  }

  private briefJourneyTopInset(): number {
    return this.briefHeaderTop() + STARWARD_SESSION_TITLE_HEIGHT + 8;
  }

  private showBriefJourneyLauncher(): boolean {
    return this.briefJourneyReady() && this.vm.journey.unreadCount > 0 && this.briefJourneyNote() === null &&
      this.briefViewportHeight - this.briefJourneyTopInset() - this.safeBottom() >= JOURNEY_LAUNCHER_SIZE + 24;
  }

  private showBriefBgm(owner: string): boolean {
    const minimum: number = QUEST_BGM_SIZE + 2 * QUEST_BGM_MARGIN;
    return this.foreground && this.atmosphere.owns(owner) && this.atmosphere.trackAvailable &&
      !this.keyboardOccupiesViewport() &&
      this.briefViewportWidth - this.safeLeft() - this.safeRight() >= minimum &&
      this.briefViewportHeight - this.briefJourneyTopInset() - this.safeBottom() >= minimum;
  }

  private briefBgmLeft(): number {
    return questBgmCoordinate(this.atmosphere.position.x, this.briefViewportWidth, this.safeLeft(), this.safeRight());
  }

  private briefBgmTop(): number {
    return questBgmCoordinate(this.atmosphere.position.y, this.briefViewportHeight, this.briefJourneyTopInset(),
      this.safeBottom());
  }

  private briefScrollClearance(owner: string): number {
    const reserve: number = this.showBriefBgm(owner) ? QUEST_BGM_SIZE :
      this.showBriefJourneyLauncher() ? JOURNEY_LAUNCHER_SIZE : 0;
    return 24 + this.safeBottom() + reserve;
  }

  private async closeBriefJourneyNote(id: string, retry: boolean): Promise<void> {
    if (this.briefJourneyNote()?.id === id) { await this.vm.journey.closeRouteNote(this.selectedId, id, retry); }
  }

  private measureBriefViewport(area: Area): void {
    const width: number = Number(area.width);
    const height: number = Number(area.height);
    const top: number = Number(area.globalPosition.y);
    if (Number.isFinite(width) && width > 0) { this.briefViewportWidth = width; }
    if (Number.isFinite(height) && height > 0) { this.briefViewportHeight = height; }
    if (Number.isFinite(top) && top >= 0) { this.briefViewportTop = top; }
  }

  @Builder
  assignmentBrief(owner: string) {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: 16 }) {
          if (this.vm.gate === 'home') {
            if (this.vm.detailError.length > 0) {
              StarwardAssignmentRequest({ loadingId: 'briefing-loading', loadingLabel: '正在准备本场冒险…',
                displayFont: this.displayFont, message: this.vm.detailError, retryable: !this.vm.detailBusy,
                motionEnabled: this.assignmentDestinationActive() && !this.showAvatarCrop && !this.motion.reduced,
                retry: () => {
                  if (this.selectedId.length > 0) { this.vm.openAssignment(this.selectedId); }
                }, returnHome: () => { this.leaveGameplay(); void this.vm.refresh(); } })
            }
            if (this.vm.detail.id.length > 0) {
              if (this.vm.detail.extraDisplay.length > 0) {
                StarwardQuestMessages({ groupId: 'assignment-extra', items: this.vm.detail.extraDisplay })
              }
              AssignmentBrief({ detail: this.vm.detail, rank: this.vm.player.level.order, now: this.vm.now,
                rankLabel: this.levelLabel(this.vm.detail),
                opensAt: this.vm.detail.startsAt.length > 0 ? this.timeLabel(this.vm.detail.startsAt) : '现在就能出发',
                closesAt: this.vm.detail.endsAt.length > 0 ? this.timeLabel(this.vm.detail.endsAt) : '',
                viewportWidth: this.briefViewportWidth, reducedMotion: this.motion.reduced,
                entryAvailable: !this.vm.play.starting && !this.vm.detailBusy && this.briefJourneyNote() === null,
                starting: this.vm.play.starting, retryEntry: this.vm.play.retryEntry, error: this.vm.play.error,
                start: () => this.enterBriefing(), returnHome: () => this.leaveGameplay() })
            }
          }
        }.width('100%').constraintSize({ maxWidth: 720 + 2 * GAMEPLAY_TITLE_SIDE_GUTTER })
          .alignItems(HorizontalAlign.Center)
          .padding({ left: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.safeLeft()),
            right: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.safeRight()),
            top: this.briefHeaderTop() + STARWARD_SESSION_TITLE_HEIGHT + 14,
            bottom: this.briefScrollClearance(owner) })
      }.id('assignment-brief-scroll').height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off)
        .clipContent(ContentClipMode.BOUNDARY)
        .fadingEdge(this.safeTop() > 0, { fadingEdgeLength: LengthMetrics.vp(this.safeTop() + 6) })
      if (this.showBriefBgm(owner)) {
        StarwardBgmControl({ state: this.atmosphere.state, reducedMotion: this.motion.reduced,
          viewportWidth: this.briefViewportWidth, viewportHeight: this.briefViewportHeight,
          topInset: this.briefJourneyTopInset(), leftInset: this.safeLeft(), rightInset: this.safeRight(),
          bottomInset: this.safeBottom(), savedX: this.atmosphere.position.x, savedY: this.atmosphere.position.y,
          ownerKey: owner, positionCommitted: (key: string, x: number, y: number) => {
            if (this.showBriefBgm(owner)) { this.atmosphere.rememberPosition(key, x, y); }
          }, toggle: () => { if (this.showBriefBgm(owner)) { this.atmosphere.toggle(owner); } } })
      }
      if (this.showBriefJourneyLauncher()) {
        StarwardJourneyLauncher({ entries: this.vm.journey.unreadEntries, unreadCount: this.vm.journey.unreadCount,
          viewportWidth: this.briefViewportWidth, viewportHeight: this.briefViewportHeight,
          topInset: this.briefJourneyTopInset(), bottomInset: 24 + this.safeBottom(),
          leftInset: this.safeLeft(), rightInset: this.safeRight(), displayFont: this.displayFont,
          bgmLeft: this.showBriefBgm(owner) ? this.briefBgmLeft() : -1,
          bgmTop: this.showBriefBgm(owner) ? this.briefBgmTop() : -1,
          reducedMotion: this.motion.reduced, openInbox: () => this.openJourneyInbox(), select: (id: string) => {
            if (this.showBriefJourneyLauncher()) { this.vm.journey.openRouteArchive(this.selectedId, id); }
          } })
      }
      Column() {
        StarwardSessionTitle({ title: this.vm.detail.title || '场次详情',
          titleId: 'briefing-session-title', backId: 'return-home', backLabel: '返回启程',
          reducedMotion: this.motion.reduced, back: () => {
            if (!this.handleAssignmentJourneyBack()) { this.leaveGameplay(); }
          } }).constraintSize({ maxWidth: GAMEPLAY_MAX_CONTENT_WIDTH })
      }.id('assignment-brief-header').width('100%').alignItems(HorizontalAlign.Center)
        .padding({ left: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.safeLeft()),
          right: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.safeRight()), top: this.briefHeaderTop() })
        .hitTestBehavior(HitTestMode.None)
      StarwardJourneyNotificationDialog({ note: this.briefJourneyNote(), playerId: this.vm.player.id,
        active: this.briefJourneyReady(), displayFont: this.displayFont, reducedMotion: this.motion.reduced,
        queuedCount: this.vm.journey.archivedOnRoute(this.selectedId) === null ? this.vm.journey.unreadCount : 1,
        pending: this.vm.journey.readingId.length > 0,
        error: this.briefJourneyNote()?.id === this.vm.journey.readErrorId ? this.vm.journey.readErrorMessage : '',
        close: (id: string) => { this.closeBriefJourneyNote(id, false); },
        acknowledge: (id: string) => { this.closeBriefJourneyNote(id, true); },
        openInternalLink: (href: string) => {
          if (this.briefJourneyNote() === null || !this.openJourneyLink(href)) { return false; }
          this.vm.journey.clearRouteArchive();
          return true;
        },
        backHandlerChanged: (handler: (() => boolean) | null) => { this.briefJourneyBack = handler; },
        playingChanged: (open: boolean) => this.atmosphere.setVideo(owner, 'briefing', open),
        playbackReady: () => this.atmosphere.whenQuiet(owner) })
    }.width('100%').height('100%')
      .onAreaChange((_oldArea: Area, area: Area) => this.measureBriefViewport(area))
  }

  @Builder
  assignmentBackdrop(owner: string) {
    if (this.foreground && this.vm.narrative.route === null && this.atmosphere.owns(owner)) {
      if (this.atmosphere.background.length > 0) {
        StarwardQuestBackground({ source: this.atmosphere.background, ownerKey: owner,
          sourceIsCurrent: (key: string, source: string) => this.atmosphere.owns(key) &&
            source === this.atmosphere.background,
          imageCache: this.atmosphere.imageCache, retryRevision: this.atmosphere.backgroundRetryRevision })
      }
      StarwardQuestAtmosphere({ reducedMotion: this.motion.reduced })
    }
  }

  private assignmentFirstLoading(): boolean {
    return this.vm.gate === 'home' && !this.vm.play.visible && this.vm.detailBusy &&
      this.vm.detail.id.length === 0 && this.vm.detailError.length === 0;
  }

  private gameplayTitleText(): string {
    return this.vm.play.visible && this.vm.play.error.length === 0 ? this.vm.play.snapshot?.detail.title ?? '' : '';
  }

  private gameplayTitleTop(): number { return Math.max(GAMEPLAY_TITLE_MIN_TOP, this.safeTop()); }

  @Builder
  private gameplayTitle() {
    Column() {
      StarwardSessionTitle({ title: this.gameplayTitleText(), backId: 'gameplay-title-back',
        titleId: 'gameplay-session-title', inNavigationTitle: true, reducedMotion: this.motion.reduced, back: () => {
          if (!this.handleAssignmentJourneyBack()) { this.leaveGameplay(); }
        } }).constraintSize({ maxWidth: GAMEPLAY_MAX_CONTENT_WIDTH })
    }.id('gameplay-floating-title').width('100%').alignItems(HorizontalAlign.Center)
      .padding({ top: this.gameplayTitleTop(), left: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.safeLeft()),
        right: Math.max(GAMEPLAY_TITLE_SIDE_GUTTER, this.safeRight()) })
  }

  @Builder
  destination(name: string, param: Object) {
    if (name === 'assignment') {
      NavDestination() {
        Stack({ alignContent: Alignment.Top }) {
          if (!this.assignmentFirstLoading()) {
            this.assignmentBackdrop(this.atmosphereOwner(param))
          }
          if (this.assignmentFirstLoading()) {
            StarwardAssignmentRequest({ loadingId: 'briefing-loading', loadingLabel: '正在准备本场冒险…', fullScreen: true,
              topInset: this.safeTop(), bottomInset: this.safeBottom(),
              motionEnabled: this.foreground && !this.showAvatarCrop && !this.motion.reduced })
          } else if (this.vm.play.visible) {
            GameplayPage({ play: this.vm.play, journey: this.vm.journey, autoNextDelay: 1500,
              openInbox: () => this.openJourneyInbox(),
              atmosphere: this.atmosphere, atmosphereOwner: this.atmosphereOwner(param),
              playerId: this.vm.gate === 'home' ? this.vm.player.id : '',
              displayFont: this.displayFont, bottomClearance: 24 + this.safeBottom(),
              statusInset: this.safeTop(),
              leftInset: this.safeLeft(), rightInset: this.safeRight(),
              keyboardVisible: this.keyboardOccupiesViewport(), reducedMotion: this.motion.reduced,
              narrativeCovered: this.vm.narrative.route !== null, accountCovered: this.showAvatarCrop,
              journeyPollingAllowed: this.gameplayDestinationShown && this.vm.gate === 'home' &&
                !this.vm.securityUnconfirmed,
              openJourneyLink: (href: string) => this.openJourneyLink(href),
              journeyBackHandlerChanged: (handler: (() => boolean) | null) => { this.gameplayJourneyBack = handler; },
              titleVisibilityChanged: (hidden: boolean, covered: boolean) => {
                if (param === this.assignmentDestinationRevision) {
                  this.gameplayTitleHidden = hidden;
                  this.gameplayTitleCovered = covered;
                }
              },
              profilePollingChanged: (active: boolean) => { this.vm.setGameplayPlayerPolling(active); },
              openNarrative: (assignmentId: string, contentId: string) => this.openFinaleNarrative(assignmentId, contentId),
              openNarrativeClue: (assignmentId: string, clueId: string, contentId: string) =>
                this.openQuestClue(assignmentId, clueId, contentId),
              finaleBackdropChanged: (visible: boolean) => { this.showFinaleBackdrop = visible; },
              leave: () => this.leaveGameplay() })
          } else {
            this.assignmentBrief(this.atmosphereOwner(param))
          }
        }.width('100%').height('100%')
      }.systemTransition(this.motion.reduced ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.FADE)
        .title({ builder: this.gameplayTitle, height: this.gameplayTitleTop() + STARWARD_SESSION_TITLE_HEIGHT },
          StarwardMaterial.overlayTitleOptions())
        .hideTitleBar(this.gameplayTitleHidden || this.gameplayTitleCovered || this.gameplayTitleText().length === 0,
          !this.gameplayTitleCovered && !this.motion.reduced)
        .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
        .hideBackButton(true).backgroundColor($r('app.color.canvas'))
        .onBackPressed(() => param === this.assignmentDestinationRevision && this.handleAssignmentJourneyBack())
        .onShown((reason: VisibilityChangeReason) => {
          if (param === this.assignmentDestinationRevision && reason === VisibilityChangeReason.TRANSITION) {
            this.gameplayDestinationShown = true;
          }
        })
        .onHidden((reason: VisibilityChangeReason) => {
          // A full-screen clue or letter cover does not leave the answer destination.
          if (param !== this.assignmentDestinationRevision || reason !== VisibilityChangeReason.TRANSITION) { return; }
          this.gameplayDestinationShown = false;
          if (this.vm.narrative.route === null) { this.atmosphere.release(); } else { this.atmosphere.suspend(); }
          this.vm.stopBriefingSync();
          this.vm.journey.setPolling(false);
          this.vm.journey.clearRouteArchive();
        })
    } else if (name === 'settings' || name === 'notification-settings') {
      NavDestination() {
        if (this.vm.gate === 'home') {
          SettingsPage({
            bottomInset: this.safeBottom(), leftInset: this.safeLeft(), rightInset: this.safeRight(),
            notificationsOnly: name === 'notification-settings',
            themeError: this.themeError, pushVisible: AppEnvironment.pushEnabled, pushAvailable: this.pushAvailable(),
            pushBusy: this.pushFlow?.busy ?? false, pushPermission: this.pushFlow?.permission ?? null,
            pushStatus: this.pushFlow?.status ?? 'unknown',
            pushSettingsError: this.pushFlow?.settingsError ?? '', appearanceControls: () => { this.themePicker() },
            subscriptions: this.vm.pushSubscriptions, active: this.foreground && this.settingsOnTop(),
            openNotificationSettings: () => this.syncPush('settings'),
            retryNotificationSync: () => this.syncPush('retry')
          })
        }
      }.systemTransition(this.motion.reduced ? NavigationSystemTransitionType.NONE :
        NavigationSystemTransitionType.SLIDE_RIGHT)
        .title({ builder: this.settingsTitle, height: 60 + this.safeTop() }, StarwardMaterial.titleOptions())
        .hideBackButton(true).backgroundColor($r('app.color.canvas'))
        .onBackPressed(() => this.closeSettings())
    } else if (name === 'narrative') {
      NavDestination() {
        if (this.vm.gate === 'home' && this.vm.narrative.route !== null) {
          NarrativePage({ model: this.vm.narrative, displayFont: this.narrativeFont, foreground: this.foreground,
            reducedMotion: this.motion.reduced, topInset: this.safeTop(), bottomInset: this.safeBottom(),
            returnToQuest: () => { this.closeNarrative(); }, returnHome: () => {
              if (this.vm.narrative.route?.source !== 'quest') {
                this.closeNarrative();
              } else {
                this.goMain(0);
              }
            } })
        }
      }.systemTransition(this.motion.reduced ? NavigationSystemTransitionType.NONE : NavigationSystemTransitionType.FADE)
        .title({ builder: this.narrativeTitle, height: (this.vm.narrative.route?.source === 'star-letters' ?
        84 : this.detailTitleHeight() + 24) + this.safeTop() },
        StarwardMaterial.titleOptions())
        .hideTitleBar(this.vm.narrative.content !== null).hideBackButton(true)
        .backgroundColor($r('app.color.canvas'))
        .onBackPressed(() => this.closeNarrative())
        .onWillDisappear(() => {
          if (this.vm.narrative.route === param) { this.vm.narrative.close(); }
        })
    }
  }

  private keyboardOccupiesViewport(): boolean {
    const area: window.UIEnvAvoidAreaVP = this.avoidArea.keyboard;
    return area.visible && Math.max(area.bottomRect.height, area.topRect.height,
      area.leftRect.height, area.rightRect.height) > 0;
  }

  private bottomContentClearance(): number {
    return this.keyboardOccupiesViewport() ? 20 : 84 + this.safeBottom();
  }

  private safeTop(): number {
    return Math.max(0, this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height);
  }

  private safeBottom(): number {
    return Math.max(0, this.avoidArea.statusBar.bottomRect.height, this.avoidArea.cutout.bottomRect.height,
      this.avoidArea.navigationIndicator.bottomRect.height);
  }

  private safeLeft(): number {
    return Math.max(0, this.avoidArea.cutout.leftRect.width, this.avoidArea.statusBar.leftRect.width,
      this.avoidArea.navigationIndicator.leftRect.width);
  }

  private safeRight(): number {
    return Math.max(0, this.avoidArea.cutout.rightRect.width, this.avoidArea.statusBar.rightRect.width,
      this.avoidArea.navigationIndicator.rightRect.width);
  }

  private detailTitleHeight(): number {
    // Track the actual window font environment, including runtime changes.
    if (!Number.isFinite(this.fontScale) || this.fontScale <= 0) {
      return 78.6;
    }
    const context = this.getUIContext();
    // The rank's real bottom padding is part of both the content and native title budget.
    return Math.max(68.6, context.px2vp(context.fp2px(57.6)) + 11) + 10;
  }

  @Builder
  narrativeTitle() {
    if (this.vm.narrative.route?.source === 'star-letters') {
      StarwardTitleSurface({ titleHeight: 84, topInset: this.safeTop(), reducedMotion: this.motion.reduced,
        titleContent: () => { this.brand() } })
    } else {
      StarwardTitleSurface({ titleHeight: this.detailTitleHeight(), horizontalGutter: 12,
        topInset: this.safeTop() + 24, titleContent: () => { this.sessionHeader() } })
    }
  }

  private authTitleVisible(): boolean {
    return this.vm.gate === 'login' || this.vm.gate === 'password';
  }

  @Builder
  authTitle() {
    if (this.authTitleVisible()) {
      StarwardTitleSurface({ titleHeight: AUTH_TITLE_HEIGHT, horizontalGutter: 18, topInset: this.safeTop(),
        reducedMotion: this.motion.reduced, titleContent: () => { this.authHeader() } })
    }
  }

  @Builder
  settingsTitle() {
    StarwardTitleSurface({ titleHeight: 60, horizontalGutter: 16, topInset: this.safeTop(), reducedMotion: this.motion.reduced,
      titleContent: () => { this.settingsTitleContent() } })
  }

  @Builder
  settingsTitleContent() {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        this.icon($r('app.media.icon_arrow_left'), 20, $r('app.color.accent_text'))
      }.id('settings-back').width(44).height(44).padding(0).borderRadius(10)
        .backgroundColor($r('app.color.accent_faint')).accessibilityText('返回').onClick(() => this.closeSettings())
      Text(this.topDestination() === 'notification-settings' ? '旅途通知与订阅设置' : '设置')
        .id('settings-heading').fontSize(23)
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
    }.width('100%').padding({ left: this.safeLeft(), right: this.safeRight() })
  }

  @Builder
  avatarCropContent() {
    StarwardAvatarCrop({ selection: this.avatarSelection,
      confirmed: (upload: AvatarUpload) => {
        if (this.vm.gate === 'home') {
          this.vm.selectProfileAvatar(upload);
        }
        this.cancelAvatarCrop();
      }, cancelled: () => this.cancelAvatarCrop(), reselect: () => this.pickAvatar() })
  }

  @Builder
  rootNavigation() {
    Navigation(this.paths) {
      if (this.vm.gate === 'home') {
        this.home()
      } else if (this.vm.gate === 'login' || this.vm.gate === 'password') {
        this.authPage()
      } else {
        this.sessionStatus()
      }
    }.navDestination(this.destination)
      .mode(this.vm.gate === 'home' ? NavigationMode.Auto : NavigationMode.Stack)
      .navBarWidth('40%').navBarWidthRange([320, 440]).minContentWidth(360)
      .title({ builder: this.authTitle, height: AUTH_TITLE_HEIGHT + this.safeTop() }, StarwardMaterial.titleOptions())
      .hideTitleBar(!this.authTitleVisible()).hideBackButton(true)
      .width('100%').height('100%').backgroundColor($r('app.color.canvas'))
  }

  @Builder
  appContent() {
    StarwardAccountSheet({ visible: this.showAvatarCrop!!, title: '裁剪头像',
      anchor: () => { this.rootNavigation() }, content: () => { this.avatarCropContent() }
    }).width('100%').height('100%')
    if (this.pushOnboarding !== null) {
      StarwardPushOnboarding({ model: this.pushOnboarding, permission: this.pushFlow?.permission ?? null,
        owner: this.pushOnboardingOwner(), eligible: this.pushOnboardingEligible(),
        widthVp: this.windowSize.width, heightVp: this.windowSize.height,
        notificationsConfirmed: () => this.syncPush('sync') })
    }
    JourneyUnreadEvents({ journey: this.vm.journey, arrived: (count: number) => this.journeyArrived(count),
      allRead: () => this.journeyReadCompleted() })
    AssignmentSynchronization({ journey: this.vm.journey, play: this.vm.play, narrative: this.vm.narrative,
      atmosphere: this.atmosphere, atmosphereOwner: this.atmosphereOwner(this.assignmentDestinationRevision),
      accountId: this.vm.player.id, briefingPresentation: this.vm.briefingPresentation,
      assignmentId: this.selectedId, destinationActive: this.assignmentDestinationActive(),
      backgroundPlayback: this.gameplayDestinationShown && this.vm.play.visible && this.vm.narrative.route === null,
      authorized: this.assignmentAuthorized(), assigned: this.vm.detail.status === 'assigned',
      briefingPollingChanged: (id: string) => { this.vm.setBriefingPolling(id); } })
    if (this.assignmentDestinationActive() && !this.vm.play.visible && this.vm.detail.status === 'assigned' &&
      this.vm.detail.id === this.selectedId && this.vm.play.syncEpisode > 0 &&
      this.vm.play.syncEpisode !== this.vm.play.dismissedSyncEpisode) {
      Column() {
        StarwardSyncNotice({ reducedMotion: this.motion.reduced, dismiss: () => this.vm.play.dismissSyncNotice() })
      }.width('100%').alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: this.safeTop() + 16 })
        .padding({ left: 16 + this.safeLeft(), right: 16 + this.safeRight() })
        .hitTestBehavior(HitTestMode.Transparent).zIndex(2)
    }
    if (this.lobbyVisible() && this.vm.showLobbySyncNotice) {
      Column() {
        StarwardSyncNotice({ nodePrefix: 'lobby-sync-notice', reducedMotion: this.motion.reduced,
          dismiss: () => this.vm.dismissLobbySyncNotice() })
      }.width('100%').alignItems(HorizontalAlign.Center)
        .position({ x: 0, y: this.safeTop() + 16 })
        .padding({ left: 16 + this.safeLeft(), right: 16 + this.safeRight() })
        .hitTestBehavior(HitTestMode.Transparent).zIndex(2)
    }
    if (this.showFinaleBackdrop && this.foreground && this.vm.gate === 'home') {
      StarwardFinaleBackdrop({ reducedMotion: this.motion.reduced }).zIndex(1)
    }
  }

  build() {
    Stack() {
      StarwardPrivacySheet({
        visible: !this.privacyAllowed, busy: this.privacyBusy, error: this.privacyError, displayFont: this.displayFont,
        viewportHeight: this.windowSize.height, leftInset: this.safeLeft(), rightInset: this.safeRight(),
        bottomInset: this.safeBottom(), continueConsent: () => { void this.requestHostedPrivacy(); },
        openPolicy: () => { void this.openHostedPrivacyPolicy(); }, anchor: () => { this.privacyGatedContent() }
      })
      if (this.modalBackdrop.visible) {
        StarwardGlassBackdrop({ nodeId: 'starward-window-modal-backdrop' })
          .transition(TransitionEffect.OPACITY.animation({
            duration: this.motion.reduced ? 0 : STARWARD_GLASS_DIALOG_FADE, curve: Curve.Ease
          }))
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.canvas'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
