import { common } from '@kit.AbilityKit';
import { window, KeyboardAvoidMode as PageKeyboardAvoidMode } from '@kit.ArkUI';
import { SliceViewModel } from '../features/SliceViewModel';
import { GameplayPage } from '../features/GameplayPage';
import { GameplayViewModel } from '../features/GameplayViewModel';
import { AssignmentAtmosphereState } from '../features/AssignmentAtmosphereState';
import { JourneyNotificationsViewModel } from '../features/JourneyNotificationsViewModel';
import { NarrativePage } from '../features/NarrativePage';
import { NarrativeRoute, NarrativeViewModel } from '../features/NarrativeViewModel';
import { StarLettersPage } from '../features/StarLettersPage';
import { RewardsPage } from '../features/RewardsPage';
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
import { assignmentKind, assignmentState } from '../business/assignmentState';
import { AppLifecycle } from '../platform/AppLifecycle';
import { AppEnvironment } from '../platform/AppEnvironment';
import { HostedPrivacy, HostedPrivacyRequestResult, HostedPrivacyState } from '../platform/HostedPrivacy';
import { AppTheme, ThemePreference, ThemeSelection } from '../platform/AppTheme';
import { LaunchRoutes, PushRoute } from '../platform/LaunchRoutes';
import { HarmonyPush, HarmonyPushDevice } from '../platform/HarmonyPush';
import { PushStatus } from '../business/PushRegistration';
import { LabeledInput } from '../ui/LabeledInput';
import { ErrorNotice, InlineError } from '../ui/ErrorMessages';
import { PrimaryAction } from '../ui/PrimaryAction';
import { DetailFact } from '../ui/DetailFact';
import { StarwardAtlas } from '../ui/StarwardAtlas';
import { StarwardMaterial, StarwardTitleSurface } from '../ui/StarwardMaterial';
import { StarwardBottomTabs, StarwardJourneyTabs, StarwardSyncNote } from '../ui/StarwardTabs';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardAccountSheet } from '../ui/StarwardAccountSheet';
import { StarwardSidePanel } from '../ui/StarwardSidePanel';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardErrorToast } from '../ui/StarwardErrorToast';
import { StarwardJourneyToast } from '../ui/StarwardJourneyToast';
import { StarwardMotion } from '../ui/StarwardMotion';
import { StarwardPlayerAvatar } from '../ui/StarwardPlayerAvatar';
import { StarwardQuestAvatar, StarwardQuestHeaderEntrance, StarwardQuestProgress } from '../ui/StarwardQuestHeaderMotion';
import { StarwardQuestMessages } from '../ui/StarwardQuestMessages';
import { StarwardAvatarCrop } from '../ui/StarwardAvatarCrop';
import { StarwardPassport } from '../ui/StarwardPassport';
import { StarwardPrivacySheet } from '../ui/StarwardPrivacySheet';
import { StarwardKeyboard } from '../ui/StarwardKeyboard';
import { StarwardFinaleBackdrop } from '../ui/StarwardCombinationNotice';
import { JOURNEY_LAUNCHER_SIZE, StarwardJourneyLauncher } from '../ui/StarwardJourneyLauncher';
import { StarwardJourneyNotificationDialog } from '../ui/StarwardJourneyNotificationDialog';
import { StarwardSyncNotice } from '../ui/StarwardSyncNotice';
import { StarwardSessionStatus } from '../ui/StarwardSessionStatus';
import { StarwardBgmControl } from '../ui/StarwardBgmControl';
import { StarwardQuestBackground } from '../ui/StarwardQuestBackground';
import { StarwardQuestAtmosphere } from '../ui/StarwardQuestAtmosphere';
import { hilog } from '@kit.PerformanceAnalysisKit';

type PushAction = 'sync' | 'initial' | 'settings' | 'retry';

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

  @Monitor('assignmentId', 'destinationActive', 'authorized', 'assigned', 'accountId', 'atmosphereOwner', 'briefingPresentation',
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
        gameplayBgmSource(snapshot, level), foreground);
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
  @Local showHelp: boolean = false;
  @Local showAccount: boolean = false;
  @Local accountAnchorWindowX: number = -1;
  @Local mainIndex: number = 0;
  @Local returnAssignmentId: string = '';
  @Local avatarSelection: AvatarSelection | null = null;
  @Local showAvatarCrop: boolean = false;
  @Local avatarPicking: boolean = false;
  @Local theme: ThemePreference = AppTheme.preference;
  @Local themeError: string = '';
  @Local displayFont: string = 'serif';
  @Local authAtlasWidth: number = 350;
  @Local authAtlasHeight: number = 204.6;
  @Local lobbyAtlasWidth: number = 350;
  @Local detailAtlasWidth: number = 366;
  @Local private gameplayTitleHidden: boolean = false;
  @Local private showFinaleBackdrop: boolean = false;
  @Local private foreground: boolean = true;
  @Local private privacyAllowed: boolean = !AppEnvironment.hostedPrivacy;
  @Local private privacyBusy: boolean = false;
  @Local private privacyError: string = '';
  @Local private pushStatus: PushStatus = 'unknown';
  @Local private pushBusy: boolean = false;
  @Local private pushPermission: boolean | null = null;
  @Local private pushSettingsError: string = '';
  @Local private pushInboxRevision: number = 0;
  @Local private lobbyRouteTransitioning: boolean = false;
  @Local private gameplayDestinationShown: boolean = false;
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
  private assignmentDestinationRevision: number = 0;
  private timer: number = -1;
  private privacyOwnerActive: boolean = false;
  private privacyOwnerRevision: number = 0;
  private privacyRestorePending: boolean = true;
  private privacyRevocationHandled: boolean = false;
  private unsubscribePrivacy: (() => void) | null = null;
  private pushActionRevision: number = 0;
  private pushPromptChecked: boolean = false;
  private pushTokenDirty: boolean = false;
  private unsubscribePushToken: (() => void) | null = null;
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
      this.atmosphere.suspend();
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
    this.paths.clear();
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
      this.paths.clear();
      void this.openAssignment(route.target);
    }
  }

  private pushAvailable(): boolean {
    return AppEnvironment.pushEnabled && this.privacyAllowed && this.vm.gate === 'home' &&
      !this.vm.securityBusy && !this.vm.securityUnconfirmed && this.foreground;
  }

  private syncPushOnArrival(): void {
    const canPrompt: boolean = !this.pushPromptChecked && !this.privacyBusy && !this.showAccount &&
      !this.lobbyRouteTransitioning && this.paths.size() === 0;
    void this.syncPush(canPrompt ? 'initial' : 'sync');
  }

  private async syncPush(action: PushAction = 'sync'): Promise<void> {
    if (!this.pushAvailable() || this.pushBusy) { return; }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    if (context === undefined) { return; }
    const revision: number = ++this.pushActionRevision;
    const force: boolean = this.pushTokenDirty || action === 'retry';
    this.pushBusy = true;
    if (action === 'settings') { this.pushSettingsError = ''; }
    try {
      if (action === 'initial') {
        this.pushPromptChecked = true;
        if (HarmonyPush.claimInitialPermissionPrompt(context)) {
          try {
            const permitted: boolean = await HarmonyPush.requestPermission(context);
            if (revision === this.pushActionRevision) { this.pushPermission = permitted; }
          } catch {
            // The prompt is optional. Manual system settings remain available.
          }
        }
      } else if (action === 'settings') {
        try {
          const permitted: boolean = await HarmonyPush.openSettings(context);
          if (revision === this.pushActionRevision) { this.pushPermission = permitted; }
        } catch {
          if (revision === this.pushActionRevision) {
            this.pushSettingsError = '暂时无法打开系统通知设置，请重试。';
          }
        }
      }
      if (revision === this.pushActionRevision && this.pushAvailable()) {
        try {
          const permitted: boolean = await HarmonyPush.isPermissionEnabled();
          if (revision === this.pushActionRevision) { this.pushPermission = permitted; }
        } catch {
          if (revision === this.pushActionRevision) { this.pushPermission = null; }
        }
        if (revision !== this.pushActionRevision || !this.pushAvailable()) { return; }
        this.pushTokenDirty = false;
        const status: PushStatus = await this.vm.syncPush(force);
        if (revision === this.pushActionRevision) {
          this.pushStatus = status;
          if (status === 'ready' || status === 'off') { this.pushPermission = status === 'ready'; }
          if (status === 'ready' && this.unsubscribePushToken === null) {
            this.unsubscribePushToken = HarmonyPush.watchTokenUpdates(() => {
              this.pushTokenDirty = true;
              if (this.pushAvailable()) { void this.syncPush(); }
            });
          } else if (status === 'off' || status === 'unavailable') {
            this.stopPushTokenWatch();
          }
        }
      } else if (action !== 'sync' && revision === this.pushActionRevision &&
        this.privacyAllowed && this.vm.gate === 'home') {
        // The system settings promise can settle before the application returns to foreground.
        this.pushTokenDirty = true;
      }
    } catch {
      if (revision === this.pushActionRevision) { this.pushStatus = 'retry'; }
    } finally {
      if (revision === this.pushActionRevision) {
        this.pushBusy = false;
        if (this.pushTokenDirty && this.pushAvailable()) { void this.syncPush(); }
      }
    }
  }

  private stopPushTokenWatch(): void {
    this.unsubscribePushToken?.();
    this.unsubscribePushToken = null;
    this.pushTokenDirty = false;
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
      this.displayFont = 'StarwardSerif';
    } catch (error) {
      this.displayFont = 'serif';
    }
    this.getUIContext().setKeyboardAvoidMode(PageKeyboardAvoidMode.RESIZE);
    this.motion.start();
    AppLifecycle.subscribe(this.lifecycle);
    LaunchRoutes.subscribe(this.routeListener);
    this.paths.setInterception({
      willShow: () => {
        this.clearJourneyToast();
        this.lobbyRouteTransitioning = true;
        this.lobbyVisibilityChanged();
        this.journeyScopeChanged();
      },
      didShow: () => {
        this.lobbyRouteTransitioning = false;
        this.lobbyVisibilityChanged();
        this.journeyScopeChanged();
        if (this.paths.size() === 0) { this.syncPushOnArrival(); }
      }
    });
    this.foreground = AppLifecycle.isForeground();
    if (AppEnvironment.pushEnabled) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (context !== undefined) { this.vm.attachPush(new HarmonyPushDevice(context)); }
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
    this.clearJourneyToast();
    this.clearAuthToast();
    this.stopPushTokenWatch();
    this.pushActionRevision++;
    this.pushBusy = false;
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
    this.showAccount = false;
    this.motion.stop();
    AppLifecycle.unsubscribe(this.lifecycle);
    LaunchRoutes.unsubscribe(this.routeListener);
    this.stopClock();
    this.clearPasswords();
    this.cancelAvatarCrop();
  }

  @Monitor('mainIndex', 'foreground', 'privacyAllowed', 'vm.gate', 'vm.securityUnconfirmed', 'vm.narrative.route')
  rewardsVisibilityChanged(): void {
    this.vm.rewards.setActive(this.rewardsVisible());
  }

  private rewardsVisible(): boolean {
    return this.privacyAllowed && this.foreground && this.mainIndex === 1 && this.paths.size() === 0 &&
      this.vm.narrative.route === null && this.vm.gate === 'home' && !this.vm.securityUnconfirmed;
  }

  @Monitor('mainIndex', 'foreground', 'privacyAllowed', 'vm.gate', 'vm.securityUnconfirmed')
  lobbyVisibilityChanged(): void {
    this.vm.setLobbyPolling(this.lobbyVisible());
  }

  private lobbyVisible(): boolean {
    return this.privacyAllowed && this.foreground && this.mainIndex === 0 && !this.lobbyRouteTransitioning &&
      this.paths.size() === 0 && this.vm.gate === 'home' && !this.vm.securityUnconfirmed;
  }

  private journeySessionReady(): boolean {
    return this.privacyAllowed && this.foreground && this.vm.gate === 'home' &&
      this.vm.player.id.length > 0 && !this.vm.securityBusy && !this.vm.securityUnconfirmed;
  }

  @Monitor('mainIndex', 'foreground', 'privacyAllowed', 'vm.gate', 'vm.securityUnconfirmed', 'vm.securityBusy',
    'showAccount', 'showAvatarCrop', 'gameplayDestinationShown')
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
        this.vm.player.id !== owner || this.showAccount || this.showAvatarCrop) { return; }
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
      !this.showAccount && !this.showAvatarCrop) {
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
    this.clearJourneyToast();
    this.clearPasswords();
    if (this.vm.gate !== 'home') {
      this.stopPushTokenWatch();
      this.pushActionRevision++;
      this.pushBusy = false;
      this.pushStatus = 'unknown';
      this.pushPermission = null;
      this.pushSettingsError = '';
      this.atmosphere.release();
      this.paths.clear();
      this.showAccount = false;
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
    if (this.showAccount) {
      this.showAccount = false;
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
    this.showAccount = false;
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.vm.narrative.close();
    this.vm.play.leave();
    this.vm.journey.setPolling(false);
    this.vm.journey.leaveRoute(this.selectedId);
    this.paths.clear();
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
    this.gameplayTitleHidden = false;
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.vm.journey.setPolling(false);
    this.vm.journey.leaveRoute(this.selectedId);
    this.vm.play.leave();
    if (popPath) {
      this.paths.pop();
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
      this.paths.clear();
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
    this.paths.clear();
    this.clearPasswords();
    this.account = '';
    this.history = false;
    this.selectedId = '';
    this.showAccount = false;
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

  private count(history: boolean): number {
    return this.vm.items.filter((item: AssignmentSummary) => history ?
      item.status === 'completed' || item.status === 'cancelled' :
      item.status === 'assigned' || item.status === 'active').length;
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

  private actionLabel(item: AssignmentSummary): string {
    const state: string = assignmentKind(item, this.vm.player.level.order, this.vm.now);
    if (state === 'ready') {
      return '开启旅程';
    }
    if (state === 'active') {
      return '继续探索';
    }
    return state === 'completed' ? '重温旅程' : '查看详情';
  }

  private detailHint(): string {
    const kind: string = assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now);
    const label: string = assignmentState(this.vm.detail, this.vm.player.level.order, this.vm.now);
    if (kind === 'expired') {
      return `${label}，请联系游戏管理员。`;
    }
    if (kind === 'locked') {
      return `${label}，请确认场次的参与等级。`;
    }
    return `${label}，旅程开放后就能出发。`;
  }

  private async openAssignment(id: string): Promise<void> {
    if (this.vm.gate !== 'home') {
      return;
    }
    if (this.vm.securityUnconfirmed) {
      StarwardFeedback.toast(this.getUIContext(), '请先退出并重新登录，确认密码修改结果。');
      return;
    }
    this.selectMain(0);
    this.atmosphere.release();
    this.vm.stopBriefingSync();
    this.gameplayDestinationShown = false;
    this.selectedId = id;
    this.vm.journey.setPolling(false);
    this.vm.journey.clearRouteArchive();
    this.vm.narrative.close();
    this.vm.play.leave();
    this.paths.pushPath({ name: 'assignment', param: ++this.assignmentDestinationRevision });
    this.lobbyVisibilityChanged();
    await this.vm.openAssignment(id);
  }

  @Builder
  icon(source: Resource, size: number, color: ResourceColor) {
    Image(source).width(size).height(size).fillColor(color).objectFit(ImageFit.Contain).accessibilityLevel('no')
  }

  @Builder
  brand() {
    Row({ space: 12 }) {
      Image($r('app.media.starward_mark')).width(36).height(36).objectFit(ImageFit.Contain).accessibilityLevel('no')
      Column({ space: 0 }) {
        Text('赴星之约').fontFamily(this.displayFont).fontSize(16).lineHeight('24fp')
          .fontColor($r('app.color.accent_text')).letterSpacing(2.08)
        Text('向着星辰的冒险').fontSize(10).lineHeight('16fp').letterSpacing(1.8)
          .fontColor($r('app.color.subtle'))
      }.alignItems(HorizontalAlign.Start)
    }.accessibilityText('赴星之约 · 向着星辰的冒险')
  }

  @Builder
  themeChoice(mode: ThemePreference, label: string, source: Resource, id: string) {
    Button({ type: ButtonType.Normal }) {
      Image(source).width(17).height(17)
        .fillColor(this.theme === mode ? $r('app.color.accent_text') : $r('app.color.subtle'))
        .objectFit(ImageFit.Contain).accessibilityLevel('no')
    }.id(id).height(40).width(37).padding(10).borderRadius(7)
      .backgroundColor(this.theme === mode ? $r('app.color.accent_soft') : Color.Transparent)
      .accessibilityText(label).accessibilitySelected(this.theme === mode).onClick(() => this.setTheme(mode))
  }

  @Builder
  themePicker() {
    Row({ space: 2 }) {
      this.themeChoice(ThemePreference.System, '跟随系统', $r('app.media.icon_desktop'), 'theme-system')
      this.themeChoice(ThemePreference.Light, '浅色', $r('app.media.icon_sun'), 'theme-light')
      this.themeChoice(ThemePreference.Dark, '深色', $r('app.media.icon_moon'), 'theme-dark')
    }.id('theme-picker').padding(3).border({ width: 1, color: $r('app.color.border'), radius: 10 })
      .accessibilityText('主题')
  }

  @Builder
  avatar(quest: boolean = false) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (quest) {
        StarwardQuestAvatar({ name: this.vm.player.displayName, avatar: this.vm.avatarImage,
          motionEnabled: this.foreground && !this.gameplayTitleHidden && !this.motion.reduced,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
      } else {
        StarwardPlayerAvatar({ name: this.vm.player.displayName, avatar: this.vm.avatarImage, avatarSize: 44,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
      }
      Text('≡').fontSize(13).fontColor($r('app.color.accent')).width(21).height(21).textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.raised')).border({ width: 1, color: $r('app.color.accent_border'), radius: 11 })
        .offset({ x: 5, y: 2 })
    }.width(44).height(44).id('account-menu').accessibilityText('打开冒险者菜单')
      .accessibilityRole(AccessibilityRoleType.BUTTON).focusable(true)
      .onClick((event: ClickEvent) => this.openAccount(event))
  }

  private openAccount(event: ClickEvent): void {
    if (this.vm.gate !== 'home') {
      return;
    }
    const area: Area = event.target.area;
    const center: number = Number(area.globalPosition.x) + Number(area.width) / 2;
    this.accountAnchorWindowX = Number.isFinite(center) ? center : event.windowX;
    this.showAccount = true;
  }

  private openSettings(): void {
    if (!this.privacyAllowed || this.vm.gate !== 'home' || this.settingsOnTop()) {
      return;
    }
    this.showAccount = false;
    this.paths.pushPath({ name: 'settings' }, !this.motion.reduced);
  }

  private closeSettings(): boolean {
    if (!this.settingsOnTop()) { return false; }
    this.paths.pop(!this.motion.reduced);
    return true;
  }

  private settingsOnTop(): boolean {
    const destinations: string[] = this.paths.getAllPathName();
    return destinations[destinations.length - 1] === 'settings';
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
  header(auth: boolean) {
    Row() {
      this.brand()
      Blank()
      if (auth) {
        this.themePicker()
      } else {
        this.avatar()
      }
      if (AppEnvironment.showEnvironmentDiagnostics) {
        Text(this.environmentLabel()).id('environment-badge')
          .fontSize(8).lineHeight('10fp').fontColor($r('app.color.subtle')).position({ x: 0, y: 71 })
      }
    }.width('100%').height(84)
      .border({ width: { bottom: auth ? 0 : 1 }, color: $r('app.color.border') })
  }

  private clearAuthToast(): void {
    this.authFeedbackEpoch++;
    this.authToast.dismiss();
  }

  private async submitLogin(): Promise<void> {
    if (this.vm.busy || this.vm.gate !== 'login') { return; }
    this.clearAuthToast();
    const epoch: number = this.authFeedbackEpoch;
    await this.vm.login(this.account, this.password);
    if (epoch === this.authFeedbackEpoch && this.foreground && this.privacyAllowed &&
      this.vm.gate === 'login' && this.vm.loginNetworkError) {
      this.authToast.show(this.getUIContext(), this.vm.error, this.safeBottom());
    }
  }

  @Builder
  loadingCards() {
    Column({ space: 16 }) {
      ForEach([0, 1], (index: number) => {
        Row({ space: 16 }) {
          Column().width(70).height(110).backgroundColor($r('app.color.accent_soft')).borderRadius(10)
          Column({ space: 16 }) {
            Row().height(46).width('100%').backgroundColor($r('app.color.accent_soft')).borderRadius(10)
            Row().height(46).width('65%').backgroundColor($r('app.color.accent_soft')).borderRadius(10)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ minHeight: 160 }).padding(24)
          .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border'), radius: 18 })
          .accessibilityText(`正在读取冒险足迹，加载项${index + 1}`)
      }, (index: number) => index.toString())
    }.width('100%')
  }

  @Builder
  authStory() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        StarwardAtlas({ atlasSize: 420, renderX: this.authAtlasWidth - 270,
          renderY: this.authAtlasHeight / 2 - 210 }).opacity(0.22)
      }.width(0).height(0).clip(false).hitTestBehavior(HitTestMode.None)
      Column() {
        Text('一场属于你的解谜之旅').fontSize(10).fontFamily('monospace').fontWeight(600)
          .lineHeight('12fp').constraintSize({ minHeight: 12 }).letterSpacing(1.4).fontColor($r('app.color.accent_muted')).width('100%')
        Text('答案之外，\n另有天地。').fontFamily(this.displayFont).fontSize(34).fontWeight(FontWeight.Medium)
          .lineHeight('47.6fp').letterSpacing(1.36).fontColor($r('app.color.strong')).width('100%')
          .margin({ top: 16, bottom: 13 })
        Text('循着线索，走进属于你的故事。').fontSize(13).lineHeight('23.4fp').letterSpacing(0.325)
          .fontColor($r('app.color.muted')).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 32, bottom: 13 })
    }.width('100%').clip(false).onAreaChange((_oldArea: Area, area: Area) => {
      const width: number = Number(area.width);
      const height: number = Number(area.height);
      if (Number.isFinite(width) && width > 0 && width !== this.authAtlasWidth) {
        this.authAtlasWidth = width;
      }
      if (Number.isFinite(height) && height > 0 && height !== this.authAtlasHeight) {
        this.authAtlasHeight = height;
      }
    })
  }

  @Builder
  login() {
    Column() {
      Text('以你的名字，开启冒险。').fontFamily(this.displayFont).fontSize(21).fontWeight(FontWeight.Medium)
        .lineHeight('33.6fp').letterSpacing(0.735).fontColor($r('app.color.strong')).width('100%')
        .margin({ bottom: 16 })
      Column({ space: 16 }) {
        LabeledInput({ label: '登录账号', placeholder: '你的冒险者账号', fieldId: 'account',
          value: this.account, disabled: this.vm.busy, changed: (value: string) => {
            if (value !== this.account) { this.vm.clearLoginInputError(); }
            this.account = value;
          } })
        LabeledInput({ label: '密码', placeholder: '输入通行密语', fieldId: 'password', value: this.password,
          secret: true, disabled: this.vm.busy, changed: (value: string) => {
            if (value !== this.password) { this.vm.clearLoginInputError(); }
            this.password = value;
          } })
        if (!this.vm.loginNetworkError) {
          InlineError({ message: this.vm.error, fieldId: 'error-message' })
        }
        PrimaryAction({ label: this.vm.busy ? '正在打开故事…' : '进入冒险', arrow: true,
          actionEnabled: !this.vm.busy && this.vm.mode !== 'unavailable',
          action: () => { void this.submitLogin(); } })
      }.width('100%')
      Button({ type: ButtonType.Normal }) {
        Text(`${this.showHelp ? '▾' : '▸'} 还没有账号，或忘记了密码？`).fontSize(12).lineHeight('21.6fp')
          .fontColor($r('app.color.muted')).width('100%')
      }.width('100%').height(45.6).padding({ top: 12, bottom: 12 }).backgroundColor(Color.Transparent)
        .margin({ top: 12 }).id('login-help').onClick(() => {
          this.getUIContext().animateTo({ duration: this.motion.duration(180), curve: Curve.EaseInOut },
            () => { this.showHelp = !this.showHelp; });
        })
      if (this.showHelp) {
        Text('账号由游戏管理员提供，暂不开放注册。忘记密码时，请联系游戏管理员重置。')
          .fontSize(12).lineHeight('21.6fp').fontColor($r('app.color.muted')).width('100%').margin({ top: 8 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 20, bottom: 12 })
  }

  @Builder
  changePassword() {
    Column() {
      Row({ space: 12 }) {
        this.icon($r('app.media.icon_key'), 24, $r('app.color.accent'))
        Text('首次登录，请先修改密码').fontFamily(this.displayFont).fontSize(24).fontWeight(FontWeight.Medium)
          .lineHeight('36fp').fontColor($r('app.color.strong')).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)
      Text('设置只有你知道的通行密语。使用 10—71 个字符。')
        .fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted')).width('100%')
        .margin({ top: 12, bottom: 24 })
      Column({ space: 16 }) {
        LabeledInput({ label: '当前密码', fieldId: 'old-password', value: this.oldPassword,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.oldPassword = value })
        LabeledInput({ label: '新密码', fieldId: 'new-password', value: this.newPassword,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.newPassword = value })
        LabeledInput({ label: '确认新密码', fieldId: 'confirm-password', value: this.confirmation,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.confirmation = value })
        InlineError({ message: this.vm.error, fieldId: 'error-message' })
        PrimaryAction({ label: this.vm.busy ? '正在保存…' : '保存新密码',
          actionEnabled: !this.vm.busy && this.vm.mode !== 'unavailable',
          action: () => { this.vm.changePassword(this.oldPassword, this.newPassword, this.confirmation); } })
        Button('退出登录', { type: ButtonType.Normal }).id('forced-logout').width('100%').height(44)
          .fontSize(14).fontColor($r('app.color.muted')).backgroundColor(Color.Transparent).onClick(() => this.logout())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 20, bottom: 12 })
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
      StarwardTitleSurface({ topInset: this.safeTop(), titleContent: () => { this.brand() } })
      Column() {
        this.authStory()
      }.width('100%').constraintSize({ maxWidth: 440 })
        .padding({ left: 20 + this.safeLeft(), right: 20 + this.safeRight() })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }

  @Builder
  authPage() {
    Scroll() {
      Column() {
        InlineError({ message: this.themeError, fieldId: 'theme-error-message' })
        this.authStory()
        if (this.vm.gate === 'login') {
          this.login()
        } else {
          this.changePassword()
        }
        Text('每一个问题，都是一扇门。').fontFamily(this.displayFont).fontSize(12).lineHeight('21.6fp')
          .letterSpacing(2.4).fontColor($r('app.color.subtle')).width('100%').textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 24 })
        if (AppEnvironment.hostedPrivacy) {
          this.privacyPolicyLink('login-privacy-policy')
        }
        if (AppEnvironment.showEnvironmentDiagnostics) {
          if (this.vm.mode === 'mock') {
            Text('演示环境 · 数据仅保留在本次运行中').fontSize(10).fontColor($r('app.color.subtle'))
              .margin({ bottom: 8 })
            if (this.vm.gate === 'login') {
              Text('演示账号 alice · 初始密码 Starward1234').fontSize(10).fontColor($r('app.color.subtle'))
                .margin({ bottom: 16 })
            }
          } else {
            Text(this.environmentLabel()).fontSize(10).fontColor($r('app.color.subtle'))
              .margin({ bottom: 16 })
          }
        }
      }.width('100%').constraintSize({ maxWidth: 440 }).padding({ left: 20, right: 20 })
    }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off)
  }

  @Builder
  sessionStatus() {
    StarwardSessionStatus({
      restoring: this.vm.gate === 'restoring' || this.vm.gate === 'restore-error',
      message: this.vm.gate === 'restore-error' || this.vm.gate === 'signout-error' ? this.vm.error : '',
      displayFont: this.displayFont, viewport: Math.max(260, this.windowSize.height - this.safeTop() - 84),
      safeBottom: this.safeBottom(), motionEnabled: this.foreground && !this.motion.reduced,
      retry: () => {
        if (this.vm.gate === 'restore-error') { void this.vm.restoreSession(); }
        else if (this.vm.gate === 'signout-error') { this.logout(); }
      }, useLogin: () => this.logout()
    })
  }

  @Builder
  assignmentCard(item: AssignmentSummary, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Blank().width(58)
        Column() {
          Row({ space: 8 }) {
            Circle().width(6).height(6).fill($r('app.color.accent_text')).accessibilityLevel('no')
            Text(assignmentState(item, this.vm.player.level.order, this.vm.now)).id(`assignment-state-${item.id}`)
              .fontSize(13).lineHeight('19fp')
              .fontColor($r('app.color.accent_text'))
          }.width('100%')
          Text(item.title).fontSize(24).fontWeight(FontWeight.Medium).lineHeight('36fp').fontFamily(this.displayFont)
            .letterSpacing(0.6).fontColor($r('app.color.strong')).width('100%').margin({ top: 12, bottom: 12 })
          Text(item.description || `${item.totalLevels} 道谜题，藏着尚未揭开的故事。`)
            .fontSize(13).lineHeight('24.05fp').fontColor($r('app.color.muted')).width('100%').margin({ bottom: 16 })
          Row({ space: 12 }) {
            Text(`${item.totalLevels} 道谜题`).fontSize(11).lineHeight('16fp').fontColor($r('app.color.subtle'))
            Text(this.levelLabel(item)).fontSize(11).lineHeight('16fp').fontColor($r('app.color.subtle'))
              .padding({ left: 12 }).border({ width: { left: 1 }, color: $r('app.color.border_strong') })
          }.width('100%')
          if (item.startsAt.length > 0 || item.endsAt.length > 0) {
            Row({ space: 8 }) {
              this.icon($r('app.media.icon_clock'), 14, $r('app.color.muted'))
              Column() {
                if (item.startsAt.length > 0) {
                  Text(`开放 ${this.timeLabel(item.startsAt)}`).fontSize(11).lineHeight('19.8fp')
                    .fontColor($r('app.color.muted')).width('100%')
                }
                if (item.endsAt.length > 0) {
                  Text(`截止 ${this.timeLabel(item.endsAt)}`).fontSize(11).lineHeight('19.8fp')
                    .fontColor($r('app.color.muted')).width('100%')
                }
              }.layoutWeight(1)
            }.width('100%').margin({ top: 12 }).alignItems(VerticalAlign.Top)
          }
          Column() {
            Text(`已解开 ${item.completedLevels} / ${item.totalLevels}`).fontSize(11).lineHeight('18fp')
              .fontColor($r('app.color.muted')).width('100%')
            Progress({ value: item.completedLevels, total: Math.max(1, item.totalLevels), type: ProgressType.Linear })
              .width('100%').height(4).style({ strokeWidth: 4 }).color($r('app.color.accent'))
              .backgroundColor($r('app.color.border')).margin({ top: 10 })
              .accessibilityText(`${item.title}探索进度：${item.completedLevels}/${item.totalLevels}`)
          }.width('100%').padding({ bottom: 5 }).margin({ top: 20, bottom: 16 })
          Button({ type: ButtonType.Normal }) {
            Row() {
              Text(this.actionLabel(item)).fontSize(13).fontWeight(600)
              Blank()
              this.icon($r('app.media.icon_arrow_right'), 18, $r('app.color.on_accent'))
            }.width('100%')
          }.id(`assignment-${item.id}`).height(46).width('100%').padding({ left: 20, right: 20 })
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent')).borderRadius(10)
            .onClick(() => this.openAssignment(item.id))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ top: 20, bottom: 20, left: 16, right: 16 })
          .border({ width: { left: 1 }, color: $r('app.color.border'), style: BorderStyle.Dashed })
      }.width('100%')
      Column({ space: 8 }) {
        Text((index + 1).toString().padStart(2, '0')).fontFamily(this.displayFont).fontSize(32).lineHeight('32fp')
          .fontColor($r('app.color.accent_muted')).opacity(0.7)
        Text('CHAPTER').fontFamily('monospace').fontSize(6).letterSpacing(0.6)
          .fontColor($r('app.color.accent_muted'))
      }.width(58).padding({ top: 24 }).accessibilityLevel('no')
      Stack() {
        Circle().width(38).height(38).fill(Color.Transparent).stroke($r('app.color.border')).strokeWidth(1)
        Rect().width(18).height(18).fill(Color.Transparent).stroke($r('app.color.accent_border')).strokeWidth(1)
          .rotate({ angle: 45 })
      }.width(38).height(38).align(Alignment.BottomStart).margin({ left: 10, bottom: 28 }).accessibilityLevel('no')
    }.width('100%').constraintSize({ minHeight: 296 }).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: 18 }).clip(true)
  }

  @Builder
  lobbyIntro() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        StarwardAtlas({ atlasSize: 210, renderX: this.lobbyAtlasWidth - 200, renderY: -40 }).opacity(0.17)
      }.width(0).height(0).clip(false).hitTestBehavior(HitTestMode.None)
      Column() {
        Text('你的冒险，从这里续写').fontFamily('monospace').fontWeight(600).fontSize(10)
          .lineHeight('12fp').constraintSize({ minHeight: 12 }).letterSpacing(1.4).fontColor($r('app.color.accent_muted')).width('100%')
        Text('下一段故事，等你落笔。').fontFamily(this.displayFont).fontWeight(FontWeight.Medium)
          .fontSize(28).lineHeight('40.6fp').letterSpacing(0.42).fontColor($r('app.color.strong')).width('100%')
          .margin({ top: 6, bottom: 6 })
        Text('有些答案，要亲自出发才能找到。').fontSize(14).lineHeight('26.6fp')
          .fontColor($r('app.color.muted')).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 16 })
    }.width('100%').clip(false).onAreaChange((_oldArea: Area, area: Area) => {
      const width: number = Number(area.width);
      if (Number.isFinite(width) && width > 0 && width !== this.lobbyAtlasWidth) {
        this.lobbyAtlasWidth = width;
      }
    })
  }

  @Builder
  emptyState(history: boolean) {
    Column({ space: 16 }) {
      this.icon($r('app.media.icon_compass_thin'), 64, $r('app.color.accent_muted'))
      Text(history ? '故事的第一页，还空着。' : '下一场奇遇，正在酝酿。')
        .fontFamily(this.displayFont).fontSize(21).fontWeight(FontWeight.Medium).lineHeight('31.5fp')
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text(history ? '完成一场冒险，就会在这里留下你的足迹。' :
        '还没有待玩场次。找游戏管理员领取你的旅程，新的邀请会自动出现在这里。')
        .fontSize(13).lineHeight('24.7fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.width('100%').constraintSize({ minHeight: 280 }).padding({ top: 32, bottom: 32, left: 20, right: 20 })
      .justifyContent(FlexAlign.Center).backgroundColor($r('app.color.accent_faint')).borderRadius(18)
  }

  @Builder
  journeyScroll(history: boolean) {
    Scroll() {
      Column({ space: 20 }) {
        if (this.vm.listBusy && !this.vm.lobbyHasList) {
          this.loadingCards()
        }
        if (!this.vm.lobbyHasList) {
          ErrorNotice({ message: this.vm.listError, retryable: !this.vm.listBusy, retry: () => this.vm.refresh() })
        }
        if (this.vm.lobbyHasList && this.visibleItems(history).length === 0) {
          this.emptyState(history)
        }
        // Server projection only: time does not change component identity.
        ForEach(this.visibleItems(history), (item: AssignmentSummary, index: number) => {
          this.assignmentCard(item, index)
        }, (item: AssignmentSummary, index: number) => `${index}:${JSON.stringify(item)}`)
        StarwardSyncNote({ tailClearance: this.bottomContentClearance() })
      }.width('100%').padding({ top: 24, left: 6, right: 6 })
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
    Column() {
      this.lobbyIntro()
      StarwardJourneyTabs({ currentCount: this.count(false), historyCount: this.count(true),
        selectedCategory: this.history ? 1 : 0,
        categoryChanged: (index: number) => { this.history = index === 1; },
        currentJourneys: () => { this.currentJourneys() }, pastJourneys: () => { this.pastJourneys() }
      }).layoutWeight(1)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 16 })
  }

  @Builder
  home() {
    StarwardBottomTabs({ floatingGap: 10 + this.safeBottom(), selectedIndex: this.mainIndex,
      unreadLetters: this.vm.journey.unreadCount,
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
    RewardsPage({ model: this.vm.rewards, playerId: this.vm.player.id, displayFont: this.displayFont,
      bottomClearance: this.bottomContentClearance(), reducedMotion: this.motion.reduced, active: this.rewardsVisible(),
      canReturnToAssignment: this.returnAssignmentId.length > 0,
      returnToAssignment: () => { if (this.returnAssignmentId.length > 0) { void this.openAssignment(this.returnAssignmentId); } },
      returnHome: () => this.goMain(0), openInternalLink: (href: string) => this.openJourneyLink(href) })
  }

  @Builder
  starLetters() {
    StarLettersPage({ model: this.vm.starLetters, journey: this.vm.journey, playerId: this.vm.player.id,
      displayFont: this.displayFont, openInternalLink: (href: string) => this.openJourneyLink(href),
      bottomClearance: this.bottomContentClearance(), reducedMotion: this.motion.reduced,
      inboxRouteRevision: this.pushInboxRevision,
      active: this.foreground && this.mainIndex === 2 && this.vm.narrative.route === null && !this.vm.securityUnconfirmed,
      openLetter: (entry: StarLetterEntry) => this.openStarLetter(entry) })
  }

  @Builder
  profile() {
    ProfilePage({ vm: this.vm, active: this.mainIndex === 3 && this.paths.size() === 0,
      displayFont: this.displayFont, bottomClearance: this.bottomContentClearance(), pickingAvatar: this.avatarPicking,
      chooseAvatar: () => this.pickAvatar(), logout: () => this.logout() })
  }

  @Builder
  sessionHeader(showProgress: boolean = true) {
    Row({ space: 12 }) {
      this.avatar(true)
      Column() {
        Text('QUEST SESSION').fontFamily('monospace').fontSize(12).fontWeight(600).lineHeight('14.4fp')
          .letterSpacing(1.68).fontColor($r('app.color.accent_muted'))
        Text(this.vm.player.displayName).fontFamily(this.displayFont).fontSize(22).lineHeight('30fp')
          .fontColor($r('app.color.strong')).margin({ top: 6 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`RANK ${this.vm.player.level.order} · ${this.vm.player.level.name}`).fontFamily('monospace')
          .fontSize(11).lineHeight('13.2fp').letterSpacing(0.88).fontColor($r('app.color.accent_muted')).margin({ top: 5 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (showProgress && (this.vm.play.visible ? this.vm.play.snapshot !== null && this.vm.play.error.length === 0 :
        this.vm.detail.id.length > 0)) {
        StarwardQuestProgress({
          completed: this.vm.play.visible ? this.vm.play.snapshot?.detail.completedLevels ?? 0 : this.vm.detail.completedLevels,
          total: this.vm.play.visible ? this.vm.play.snapshot?.detail.totalLevels ?? 0 : this.vm.detail.totalLevels,
          motionEnabled: this.foreground && !this.gameplayTitleHidden && !this.motion.reduced
        })
      }
    }.width('100%').constraintSize({ minHeight: this.detailTitleHeight() }).padding({ bottom: 10 })
      .alignItems(VerticalAlign.Center)
  }

  @Builder
  detailCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        StarwardAtlas({ atlasSize: 200, renderX: this.detailAtlasWidth - 141, renderY: -59 }).opacity(0.16)
      }.width(0).height(0).clip(false).hitTestBehavior(HitTestMode.None)
      Column() {
        Text('一段新的旅程').fontFamily('monospace').fontWeight(600).fontSize(12).lineHeight('14.4fp')
          .letterSpacing(1.68).fontColor($r('app.color.accent_muted')).width('100%')
        Text(this.vm.detail.title).fontFamily(this.displayFont).fontSize(30).fontWeight(FontWeight.Medium).lineHeight('45fp')
          .letterSpacing(0.75).fontColor($r('app.color.strong')).width('100%').margin({ top: 16, bottom: 16 })
        Text(this.vm.detail.description || '循着线索，去发现故事另一面的答案。').fontSize(14).lineHeight('26.6fp')
          .fontColor($r('app.color.muted')).width('100%')
        Column({ space: 20 }) {
          Row({ space: 20 }) {
            DetailFact({ label: '谜题', value: `${this.vm.detail.totalLevels} 道等待解开`, source: $r('app.media.icon_puzzle') })
            DetailFact({ label: '参与等级', value: this.levelLabel(this.vm.detail), source: $r('app.media.icon_map') })
          }.width('100%').alignItems(VerticalAlign.Top)
          Row({ space: 20 }) {
            DetailFact({ label: '开放时间', value: this.vm.detail.startsAt.length > 0 ?
              this.timeLabel(this.vm.detail.startsAt) : '现在就能出发', source: $r('app.media.icon_clock') })
            if (this.vm.detail.endsAt.length > 0) {
              DetailFact({ label: '旅程截止', value: this.timeLabel(this.vm.detail.endsAt), source: $r('app.media.icon_clock') })
            } else {
              Blank().layoutWeight(1)
            }
          }.width('100%').alignItems(VerticalAlign.Top)
        }.width('100%').margin({ top: 24, bottom: 24 })
        if (assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now) !== 'ready') {
          Text(this.detailHint()).id('detail-state-hint').fontSize(13).lineHeight('23.4fp')
            .fontColor($r('app.color.muted')).width('100%').margin({ bottom: 12 })
        }
        Button({ type: ButtonType.Normal }) {
          Row({ space: 16 }) {
            Text(this.vm.play.starting ? '正在进入…' : this.vm.play.retryEntry ? '重试入场' : '开始本场冒险')
              .fontSize(16).fontWeight(600).letterSpacing(0.96)
            this.icon($r('app.media.icon_arrow_right'), 20, $r('app.color.on_accent'))
          }.width('100%').justifyContent(FlexAlign.Center)
        }.id('start-assignment').enabled(!this.vm.play.starting && !this.vm.detailBusy && this.briefJourneyNote() === null &&
          assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now) === 'ready')
          .height(52).width('100%').borderRadius(10)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .opacity(assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now) === 'ready' ? 1 : 0.45)
          .accessibilityText(this.vm.play.starting ? '正在进入本场冒险' : '开始本场冒险')
          .onClick(() => this.enterBriefing())
        ErrorNotice({ message: this.vm.play.error, retryable: this.vm.play.retryEntry && !this.vm.play.starting,
          retry: () => this.enterBriefing() })
        if (assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now) === 'expired') {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Image($r('app.media.icon_house')).width(18).height(18).fillColor($r('app.color.on_accent'))
                .objectFit(ImageFit.Contain).accessibilityLevel('no')
              Text('回到首页').fontSize(13).fontWeight(600)
            }.justifyContent(FlexAlign.Center)
          }.id('expired-return-home').width('100%').height(46).padding({ top: 10, bottom: 10, left: 20, right: 20 })
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .border({ width: 1, color: $r('app.color.accent'), radius: 10 }).margin({ top: 12 })
            .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
            .accessibilityText('回到首页，当前场次已过开放时间').onClick(() => this.paths.clear())
        }
        Text('解谜进度会自动保存，随时可以回来继续。').fontSize(11).lineHeight('19.8fp')
          .fontColor($r('app.color.muted')).width('100%').margin({ top: 11 })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(24)
    }.width('100%').backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: 18 }).clip(true)
      .onAreaChange((_oldArea: Area, area: Area) => {
        const width: number = Number(area.width);
        if (Number.isFinite(width) && width > 0 && width !== this.detailAtlasWidth) {
          this.detailAtlasWidth = width;
        }
      })
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
      !this.showAccount && !this.showAvatarCrop &&
      !this.keyboardOccupiesViewport() && this.vm.journey.gameplayReady &&
      this.briefViewportWidth - this.safeLeft() - this.safeRight() >= 160 &&
      this.briefViewportHeight - this.briefJourneyTopInset() >= 120;
  }

  private briefJourneyNote(): GameNotification | null {
    return this.briefJourneyReady() ? this.vm.journey.archivedOnRoute(this.selectedId) ??
      this.vm.journey.automaticUnreadOnRoute(this.selectedId) : null;
  }

  private briefJourneyTopInset(): number {
    return Math.max(0, this.safeTop() - this.briefViewportTop);
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
    return 24 + (reserve > 0 ? reserve + this.safeBottom() : 0);
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
  revokedBriefing() {
    Column({ space: 16 }) {
      Text('本次场次已撤回').id('briefing-cancelled').width('100%').textAlign(TextAlign.Center)
        .fontFamily(this.displayFont).fontSize(21).fontWeight(FontWeight.Medium).lineHeight('31.5fp')
        .fontColor($r('app.color.strong'))
      Text('如需继续，请联系游戏管理员重新安排。').width('100%').textAlign(TextAlign.Center)
        .fontSize(13).lineHeight('24.7fp').fontColor($r('app.color.muted'))
      Button('回到首页', { type: ButtonType.Normal }).id('briefing-cancelled-home')
        .constraintSize({ minHeight: 46 }).padding({ left: 20, right: 20 }).borderRadius(10)
        .fontSize(13).fontWeight(600)
        .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
        .onClick(() => this.leaveGameplay())
    }.width('100%').constraintSize({ minHeight: 280 }).justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 20, top: 32, bottom: 32 })
      .backgroundColor($r('app.color.accent_faint')).borderRadius(18)
  }

  @Builder
  assignmentBrief(owner: string) {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: 16 }) {
          if (this.vm.gate === 'home') {
            if (this.vm.detailBusy && this.vm.detail.id.length === 0) {
              Text('正在准备本场冒险…').id('briefing-loading').fontSize(13)
                .fontColor($r('app.color.muted')).width('100%')
            }
            ErrorNotice({ message: this.vm.detailError, retryable: !this.vm.detailBusy, showReturn: true,
              retry: () => {
                if (this.selectedId.length > 0) { this.vm.openAssignment(this.selectedId); }
              }, returnHome: () => { this.leaveGameplay(); void this.vm.refresh(); } })
            if (this.vm.detail.id.length > 0) {
              if (this.vm.detail.extraDisplay.length > 0) {
                StarwardQuestMessages({ groupId: 'assignment-extra', items: this.vm.detail.extraDisplay })
              }
              if (this.vm.detail.status === 'cancelled') {
                this.revokedBriefing()
              } else {
                this.detailCard()
              }
            }
            // Native return control supplements the frozen Web expired-state action inside the brief.
            if (this.vm.detail.status !== 'cancelled' && this.vm.detailError.length === 0) {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 8 }) {
                  this.icon($r('app.media.icon_arrow_left'), 18, $r('app.color.accent_text'))
                  Text('回到首页').fontSize(13).fontColor($r('app.color.accent_text'))
                }
              }.id('return-home').height(44).backgroundColor(Color.Transparent).onClick(() => this.leaveGameplay())
            }
          }
        }.width('100%').constraintSize({ maxWidth: 720 }).alignItems(HorizontalAlign.Start)
          .padding({ left: 12, right: 12, top: 16, bottom: this.briefScrollClearance(owner) })
      }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off)
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

  @Builder
  destination(name: string, param: Object) {
    if (name === 'assignment') {
      NavDestination() {
        Stack({ alignContent: Alignment.Top }) {
          this.assignmentBackdrop(this.atmosphereOwner(param))
          if (this.vm.play.visible) {
            GameplayPage({ play: this.vm.play, journey: this.vm.journey, autoNextDelay: this.motion.duration(1500),
              openInbox: () => this.openJourneyInbox(),
              atmosphere: this.atmosphere, atmosphereOwner: this.atmosphereOwner(param),
              playerId: this.vm.gate === 'home' ? this.vm.player.id : '',
              displayFont: this.displayFont, bottomClearance: 24 + this.safeBottom(),
              titleBottom: this.detailTitleHeight() + 24 + this.safeTop(), statusInset: this.safeTop(),
              leftInset: this.safeLeft(), rightInset: this.safeRight(),
              keyboardVisible: this.keyboardOccupiesViewport(), reducedMotion: this.motion.reduced,
              narrativeCovered: this.vm.narrative.route !== null, accountCovered: this.showAccount,
              journeyPollingAllowed: this.gameplayDestinationShown && this.vm.gate === 'home' &&
                !this.vm.securityUnconfirmed,
              openJourneyLink: (href: string) => this.openJourneyLink(href),
              journeyBackHandlerChanged: (handler: (() => boolean) | null) => { this.gameplayJourneyBack = handler; },
              profilePollingChanged: (active: boolean) => { this.vm.setGameplayPlayerPolling(active); },
              openNarrative: (assignmentId: string, contentId: string) => this.openFinaleNarrative(assignmentId, contentId),
              openNarrativeClue: (assignmentId: string, clueId: string, contentId: string) =>
                this.openQuestClue(assignmentId, clueId, contentId),
              titleVisibilityChanged: (hidden: boolean) => { this.gameplayTitleHidden = hidden; },
              finaleBackdropChanged: (visible: boolean) => { this.showFinaleBackdrop = visible; },
              leave: () => this.leaveGameplay() })
          } else {
            this.assignmentBrief(this.atmosphereOwner(param))
          }
        }.width('100%').height('100%')
      }.title({ builder: this.detailTitle, height: this.detailTitleHeight() + 24 + this.safeTop() },
        StarwardMaterial.titleOptions(this.vm.play.visible ? BarStyle.STACK : BarStyle.STANDARD))
        .hideTitleBar(this.vm.play.visible && this.gameplayTitleHidden, !this.motion.reduced)
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
    } else if (name === 'settings') {
      NavDestination() {
        if (this.vm.gate === 'home') {
          SettingsPage({
            bottomInset: this.safeBottom(), leftInset: this.safeLeft(), rightInset: this.safeRight(),
            themeError: this.themeError, pushVisible: AppEnvironment.pushEnabled, pushAvailable: this.pushAvailable(),
            pushBusy: this.pushBusy, pushPermission: this.pushPermission, pushStatus: this.pushStatus,
            pushSettingsError: this.pushSettingsError, appearanceControls: () => { this.themePicker() },
            subscriptions: this.vm.pushSubscriptions, active: this.foreground && this.settingsOnTop(),
            openNotificationSettings: () => { void this.syncPush('settings'); },
            retryNotificationSync: () => { void this.syncPush('retry'); }
          })
        }
      }.title({ builder: this.settingsTitle, height: 60 + this.safeTop() }, StarwardMaterial.titleOptions())
        .hideBackButton(true).backgroundColor($r('app.color.canvas'))
        .onBackPressed(() => this.closeSettings())
    } else if (name === 'narrative') {
      NavDestination() {
        if (this.vm.gate === 'home' && this.vm.narrative.route !== null) {
          NarrativePage({ model: this.vm.narrative, displayFont: this.displayFont, foreground: this.foreground,
            reducedMotion: this.motion.reduced, topInset: this.safeTop(), bottomInset: this.safeBottom(),
            returnToQuest: () => { this.closeNarrative(); }, returnHome: () => {
              if (this.vm.narrative.route?.source !== 'quest') {
                this.closeNarrative();
              } else {
                this.goMain(0);
              }
            } })
        }
      }.title({ builder: this.narrativeTitle, height: (this.vm.narrative.route?.source === 'star-letters' ?
        84 : this.detailTitleHeight() + 24) + this.safeTop() },
        StarwardMaterial.titleOptions())
        .hideTitleBar(this.vm.narrative.content !== null).hideBackButton(true)
        .backgroundColor($r('app.color.canvas'))
        .onBackPressed(() => this.closeNarrative())
        .onWillDisappear(() => this.vm.narrative.close())
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
  detailTitle() {
    StarwardTitleSurface({ titleHeight: this.detailTitleHeight(), horizontalGutter: 12,
      topInset: this.safeTop() + 24, titleContent: () => { this.sessionTitleContent() } })
  }

  @Builder
  narrativeTitle() {
    if (this.vm.narrative.route?.source === 'star-letters') {
      this.rootTitle()
    } else {
      StarwardTitleSurface({ titleHeight: this.detailTitleHeight(), horizontalGutter: 12,
        topInset: this.safeTop() + 24, titleContent: () => { this.sessionHeader(false) } })
    }
  }

  @Builder
  sessionTitleContent() {
    StarwardQuestHeaderEntrance({ motionEnabled: this.foreground && !this.gameplayTitleHidden && !this.motion.reduced,
      content: () => { this.sessionHeader() } })
  }

  @Builder
  rootHeader() {
    this.header(!this.privacyAllowed || this.vm.gate !== 'home')
  }

  @Builder
  rootTitle() {
    StarwardTitleSurface({ topInset: this.safeTop(), titleContent: () => { this.rootHeader() } })
  }

  @Builder
  settingsTitle() {
    StarwardTitleSurface({ titleHeight: 60, horizontalGutter: 16, topInset: this.safeTop(),
      titleContent: () => { this.settingsTitleContent() } })
  }

  @Builder
  settingsTitleContent() {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Normal }) {
        this.icon($r('app.media.icon_arrow_left'), 20, $r('app.color.accent_text'))
      }.id('settings-back').width(44).height(44).padding(0).borderRadius(10)
        .backgroundColor($r('app.color.accent_faint')).accessibilityText('返回').onClick(() => this.closeSettings())
      Text('设置').id('settings-heading').fontFamily(this.displayFont).fontSize(23)
        .fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
    }.width('100%').padding({ left: this.safeLeft(), right: this.safeRight() })
  }

  @Builder
  menuDestination(index: number, label: string, description: string, hint: string, normalIcon: Resource,
    selectedIcon: Resource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        this.icon(this.paths.size() === 0 && this.mainIndex === index ? selectedIcon : normalIcon, 23,
          $r('app.color.accent_text'))
        Column({ space: 4 }) {
          Text(description).fontSize(15).fontColor($r('app.color.text'))
          Text(hint).fontSize(11).fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        this.icon($r('app.media.icon_arrow_right'), 17, $r('app.color.subtle'))
      }.width('100%').padding({ top: 12, bottom: 12 })
    }.id(index === 0 ? 'menu-home' : index === 1 ? 'menu-rewards' : index === 2 ? 'menu-notifications' : 'menu-profile')
      .width('100%').constraintSize({ minHeight: 64 }).borderRadius(10).padding({ left: 12, right: 12 })
      .backgroundColor(this.paths.size() === 0 && this.mainIndex === index ? $r('app.color.accent_faint') : Color.Transparent)
      .accessibilitySelected(this.paths.size() === 0 && this.mainIndex === index)
      .accessibilityText(`${label}，${description}，${hint}`)
      .onClick(() => this.goMain(index))
  }

  @Builder
  accountSheet() {
    Scroll() {
      Column({ space: 20 }) {
        StarwardPassport({ player: this.vm.player, avatar: this.vm.avatarImage, displayFont: this.displayFont, menu: true,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
        Column({ space: 4 }) {
          if (this.returnAssignmentId.length > 0 && this.paths.size() === 0) {
            Button('返回答题 · 接着刚才的线索继续', { type: ButtonType.Normal })
              .id('menu-return-assignment').width('100%').constraintSize({ minHeight: 52 })
              .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
              .onClick(() => {
                this.showAccount = false;
                this.openAssignment(this.returnAssignmentId);
              })
          }
          this.menuDestination(0, '启程', '我的场次', '继续未完的冒险', $r('app.media.icon_nav_compass_regular'),
            $r('app.media.icon_nav_compass_fill'))
          this.menuDestination(1, '收藏', '奇遇收藏', '收好线索与战利品', $r('app.media.icon_nav_sparkle_regular'),
            $r('app.media.icon_nav_sparkle_fill'))
          this.menuDestination(2, '来信', '旅途来信', '查收远方的消息', $r('app.media.icon_nav_envelope_regular'),
            $r('app.media.icon_nav_envelope_fill'))
          this.menuDestination(3, '护照', '冒险者护照', '装扮你的冒险名片', $r('app.media.icon_nav_passport_regular'),
            $r('app.media.icon_nav_passport_fill'))
        }.width('100%')
        Column({ space: 8 }) {
          Text('旅途光线').fontSize(12).fontColor($r('app.color.muted'))
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            this.themePicker()
            Button({ type: ButtonType.Normal }) {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.gearshape')).fontSize('17vp').fontColor([$r('app.color.accent_text')])
                  .accessibilityLevel('no')
                Text('设置').fontSize(13).fontColor($r('app.color.accent_text'))
              }
            }.id('account-open-settings').constraintSize({ minHeight: 44 })
              .padding({ left: 10, right: 10 }).borderRadius(10).backgroundColor(Color.Transparent)
              .onClick(() => this.openSettings())
          }.width('100%')
          InlineError({ message: this.themeError, fieldId: 'theme-error-message' })
        }.width('100%').alignItems(HorizontalAlign.Start)
        if (AppEnvironment.hostedPrivacy || AppEnvironment.showEnvironmentDiagnostics) {
          Row() {
            if (AppEnvironment.showEnvironmentDiagnostics) {
              Text(this.vm.mode === 'mock' ? '演示环境 · 数据仅保留在本次运行中' : this.environmentLabel())
                .layoutWeight(1).fontSize(11).fontColor($r('app.color.subtle'))
            } else {
              Blank()
            }
            if (AppEnvironment.hostedPrivacy) {
              this.privacyPolicyLink('account-privacy-policy')
            }
          }.width('100%')
        }
        Button('退出登录', { type: ButtonType.Normal }).id('logout').width('100%').height(44)
          .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent).onClick(() => this.logout())
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 24, right: 24, top: 12, bottom: 24 })
    }.id('account-menu-scroll').width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  accountOverlay() {
    StarwardSidePanel({ visible: this.showAccount!!, title: '冒险者菜单',
      ownerActive: this.privacyAllowed && this.vm.gate === 'home',
      headerTitle: '冒险者护照', displayFont: this.displayFont,
      ownerKey: this.vm.player.id, anchorWindowX: this.accountAnchorWindowX, reducedMotion: this.motion.reduced,
      failed: () => StarwardFeedback.toast(this.getUIContext(), '菜单暂时无法打开，请重试。'),
      anchor: () => { this.rootNavigation() }, content: () => { this.accountSheet() } })
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
      .title({ builder: this.rootTitle, height: 84 + this.safeTop() }, StarwardMaterial.titleOptions()).hideTitleBar(false).hideBackButton(true)
      .width('100%').height('100%').backgroundColor($r('app.color.canvas'))
  }

  @Builder
  appContent() {
    StarwardAccountSheet({ visible: this.showAvatarCrop!!, title: '裁剪头像',
      anchor: () => { this.accountOverlay() }, content: () => { this.avatarCropContent() }
    }).width('100%').height('100%')
    JourneyUnreadEvents({ journey: this.vm.journey, arrived: (count: number) => this.journeyArrived(count),
      allRead: () => this.journeyReadCompleted() })
    AssignmentSynchronization({ journey: this.vm.journey, play: this.vm.play, narrative: this.vm.narrative,
      atmosphere: this.atmosphere, atmosphereOwner: this.atmosphereOwner(this.assignmentDestinationRevision),
      accountId: this.vm.player.id, briefingPresentation: this.vm.briefingPresentation,
      assignmentId: this.selectedId, destinationActive: this.assignmentDestinationActive(),
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
    }.width('100%').height('100%').backgroundColor($r('app.color.canvas'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
