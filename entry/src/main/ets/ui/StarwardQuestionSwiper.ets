/** Native horizontal paging. The gameplay owner supplies readable pages and owns selection. */
@ComponentV2
export struct StarwardQuestionSwiper {
  @Require @Param pages: string[];
  @Require @Param currentId: string;
  @Param swipeEnabled: boolean = false;
  @Param reducedMotion: boolean = true;
  @BuilderParam content: (id: string) => void;
  @Event select: (id: string) => boolean = () => false;
  private readonly controller: SwiperController = new SwiperController();
  private gestureFrom: string = '';
  private gestureTo: string = '';

  @Monitor('currentId', 'pages', 'swipeEnabled')
  selectionChanged(): void {
    if (!this.swipeEnabled || this.gestureFrom !== this.currentId || !this.pages.includes(this.gestureTo)) {
      this.clearGesture();
    }
  }

  private clearGesture(): void {
    this.gestureFrom = '';
    this.gestureTo = '';
  }

  private mayScroll(event: SwiperContentWillScrollResult): boolean {
    const from: string | undefined = this.pages[event.currentIndex];
    const to: string | undefined = this.pages[event.comingIndex];
    if (!this.swipeEnabled || !from || !to || from !== this.currentId ||
      Math.abs(event.currentIndex - event.comingIndex) !== 1) {
      return false;
    }
    // This callback follows the finger. Business selection only occurs after settlement.
    this.gestureFrom = from;
    this.gestureTo = to;
    return true;
  }

  private settled(index: number): void {
    const destination: string | undefined = this.pages[index];
    const currentIndex: number = this.pages.indexOf(this.currentId);
    const fromGesture: boolean = this.swipeEnabled && this.gestureFrom === this.currentId &&
      destination !== undefined && destination === this.gestureTo && Math.abs(currentIndex - index) === 1;
    this.clearGesture();
    if (destination === this.currentId || currentIndex < 0) { return; }
    if (!fromGesture || !destination || !this.select(destination)) {
      this.controller.changeIndex(currentIndex, false);
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
      .index(Math.max(0, this.pages.indexOf(this.currentId))).displayCount(1)
      .loop(false).autoPlay(false).indicator(false).effectMode(EdgeEffect.None)
      .curve(Curve.EaseOut).duration(this.reducedMotion ? 0 : 260)
      .disableSwipe(!this.swipeEnabled || this.pages.length < 2)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) { this.clearGesture(); }
      })
      .onContentWillScroll((event: SwiperContentWillScrollResult) => this.mayScroll(event))
      .onChange((index: number) => this.settled(index))
  }
}
