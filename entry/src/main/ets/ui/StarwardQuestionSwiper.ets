import { QuestionSwiperSelection } from './QuestionSwiperSelection';
import { STARWARD_PAGE_TRANSITION_MS } from './StarwardMotion';

const ANIMATION_COMPLETION_GRACE_MS: number = 200;

/** Native horizontal paging. The owner supplies readable pages and owns selection. */
@ComponentV2
export struct StarwardQuestionSwiper {
  @Require @Param pages: string[];
  @Require @Param currentId: string;
  @Param swipeEnabled: boolean = false;
  @Param reducedMotion: boolean = true;
  @BuilderParam content: (id: string) => void;
  @Event select: (id: string) => boolean = () => false;
  @Event settled: (id: string) => void = () => {};
  private readonly controller: SwiperController = new SwiperController();
  private readonly selection: QuestionSwiperSelection = new QuestionSwiperSelection();
  @Local private moving: boolean = false;
  @Local private presented: boolean = false;
  private mounted: boolean = false;
  private laidOut: boolean = false;
  private syncTimer: number = -1;
  private animationRecoveryTimer: number = -1;
  private gestureSource: string = '';
  private gestureDestination: string = '';

  aboutToAppear(): void {
    // Swiper starts at zero. A reactive .index() modifier can reapply a stale index during a gesture.
    this.selection.reset(this.pages, this.pages[0] ?? '');
    this.presented = this.selection.displayedId() === this.currentId;
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.laidOut = false;
    clearTimeout(this.syncTimer);
    this.syncTimer = -1;
    this.clearAnimationRecovery();
  }

  @Monitor('currentId', 'pages', 'swipeEnabled', 'reducedMotion')
  private selectionChanged(): void {
    this.selection.updatePages(this.pages);
    if (!this.swipeEnabled) { this.selection.clearGesture(); }
    this.scheduleSync();
  }

  /** Apply owner changes outside native callbacks, once Swiper has a measured viewport. */
  private scheduleSync(): void {
    if (!this.mounted || !this.laidOut || this.syncTimer !== -1) { return; }
    this.syncTimer = setTimeout(() => {
      this.syncTimer = -1;
      if (this.mounted) { this.syncSelection(); }
    }, 0);
  }

  private nativeIndexChanged(index: number): void {
    this.selection.updatePages(this.pages);
    const candidate: string = this.selection.observe(index, this.currentId, this.swipeEnabled);
    if (candidate.length > 0) {
      this.gestureSource = this.currentId;
      this.gestureDestination = candidate;
    }
    this.scheduleSync();
  }

  private clearAnimationRecovery(): void {
    clearTimeout(this.animationRecoveryTimer);
    this.animationRecoveryTimer = -1;
  }

  private recoverInterruptedAnimation(index: number): void {
    this.clearAnimationRecovery();
    this.animationRecoveryTimer = setTimeout(() => {
      this.animationRecoveryTimer = -1;
      if (this.mounted && this.selection.awaits(index)) {
        this.controller.changeIndex(index, SwiperAnimationMode.NO_ANIMATION);
      }
    }, STARWARD_PAGE_TRANSITION_MS + ANIMATION_COMPLETION_GRACE_MS);
  }

  private syncSelection(): void {
    this.selection.updatePages(this.pages);
    const candidate: string = this.gestureDestination;
    const from: string = this.gestureSource;
    this.gestureDestination = '';
    this.gestureSource = '';
    if (candidate.length > 0 && this.swipeEnabled && from === this.currentId &&
      this.selection.displayedId() === candidate && this.select(candidate)) {
      this.settled(candidate);
      return;
    }
    const target: number = this.selection.request(this.currentId);
    if (target >= 0) {
      const animate: boolean = this.presented && !this.reducedMotion && this.selection.isAdjacent(target) &&
        candidate.length === 0;
      this.moving = true;
      if (animate) { this.recoverInterruptedAnimation(target); } else { this.clearAnimationRecovery(); }
      this.controller.changeIndex(target, animate ? SwiperAnimationMode.DEFAULT_ANIMATION : SwiperAnimationMode.NO_ANIMATION);
    }
    this.moving = this.selection.isMoving();
    if (!this.moving) {
      this.clearAnimationRecovery();
      if (this.currentId === this.selection.displayedId()) {
        this.presented = true;
        this.settled(this.currentId);
      }
    }
  }

  build() {
    Swiper(this.controller) {
      ForEach(this.pages, (id: string) => {
        Column() {
          this.content(id)
        }.width('100%')
          .hitTestBehavior(id === this.currentId ? HitTestMode.Default : HitTestMode.BLOCK_DESCENDANTS)
          .accessibilityLevel(id === this.currentId ? 'auto' : 'no-hide-descendants')
      }, (id: string) => id)
    }.id('gameplay-question-swiper').width('100%').align(Alignment.Top)
      .displayCount(1).opacity(this.presented ? 1 : 0)
      .accessibilityLevel(this.presented ? 'auto' : 'no-hide-descendants')
      .loop(false).autoPlay(false).indicator(false).effectMode(EdgeEffect.None)
      .curve(Curve.EaseOut).duration(this.reducedMotion ? 0 : STARWARD_PAGE_TRANSITION_MS)
      .disableSwipe(!this.presented || !this.swipeEnabled || this.moving || this.pages.length < 2)
      .onAppear(() => { this.mounted = true; this.scheduleSync(); })
      .onAreaChange((_previous: Area, current: Area) => {
        if (!this.laidOut && Number(current.width) > 0 && Number(current.height) > 0) {
          this.laidOut = true;
          this.scheduleSync();
        }
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) { this.selection.clearGesture(); }
      })
      .onContentWillScroll((event: SwiperContentWillScrollResult) => this.swipeEnabled &&
        this.selection.followGesture(event.currentIndex, event.comingIndex, this.currentId))
      .onChange((index: number) => this.nativeIndexChanged(index))
      .onAnimationStart((from: number, to: number) => this.selection.animationStarted(from, to))
      .onAnimationEnd((index: number) => {
        if (this.selection.animationEnded(index)) { this.scheduleSync(); }
      })
  }
}
