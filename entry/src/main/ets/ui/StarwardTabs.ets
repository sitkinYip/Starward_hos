import { CommonModifier, UIUtils, uiMaterial } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { StarwardMaterial } from './StarwardMaterial';

/** Main destinations use the native floating bar; deferred destinations cannot be entered. */
@ComponentV2
export struct StarwardBottomTabs {
  @BuilderParam journeys: () => void;
  @BuilderParam passport: () => void;
  @Param selectedIndex: number = 0;
  @Event selected: (index: number) => void = () => {};
  @Event unavailableSelected: (index: number) => void = () => {};
  @Param followHandedness: boolean = false;
  @Param floatingGap: number = 10;
  @Param hideBar: boolean = false;
  @Param materialInteractionEnabled: boolean = false;
  @Local private activeIndex: number = 0;
  private pendingIndex: number = -1;
  private selectionTimer: number = -1;
  private mounted: boolean = false;
  private acceptingInput: boolean = false;
  @Local private barInputModifier: CommonModifier = UIUtils.makeObserved(new CommonModifier());
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void {
    this.mounted = true;
    this.activeIndex = this.selectedIndex;
    this.updateMaterial();
    this.barInputModifier.visibility(this.hideBar ? Visibility.None : Visibility.Visible);
    // Attach only to the actual native TabBar. Content controls must never
    // open a tab-selection transaction when native callbacks are emitted.
    this.barInputModifier.id('starward-native-tabbar').onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.beginInput();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.finishInput(event.type === TouchType.Cancel);
      }
    });
    hilog.info(0x0000, 'StarwardNavigation', 'appear selected=%{public}d active=%{public}d', this.selectedIndex, this.activeIndex);
  }

  aboutToDisappear(): void {
    this.mounted = false;
    clearTimeout(this.selectionTimer);
    this.selectionTimer = -1;
    this.pendingIndex = -1;
    this.acceptingInput = false;
  }

  @Monitor('hideBar')
  barVisibilityChanged(): void {
    // Keep Tabs and its page drafts mounted; only the native bar leaves layout and hit testing.
    this.barInputModifier.visibility(this.hideBar ? Visibility.None : Visibility.Visible);
    clearTimeout(this.selectionTimer);
    this.selectionTimer = -1;
    this.pendingIndex = -1;
    this.acceptingInput = false;
  }

  @Monitor('materialInteractionEnabled')
  materialInteractionChanged(): void {
    this.updateMaterial();
  }

  private updateMaterial(): void {
    this.material = StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THIN, this.materialInteractionEnabled);
  }

  private requestSelection(index: number): void {
    if (!this.acceptingInput || this.hideBar) {
      hilog.info(0x0000, 'StarwardNavigation', 'ignore index=%{public}d outside input', index);
      return;
    }
    this.pendingIndex = index;
  }

  private beginInput(): void {
    clearTimeout(this.selectionTimer);
    this.selectionTimer = -1;
    this.pendingIndex = -1;
    this.acceptingInput = !this.hideBar;
  }

  private finishInput(cancelled: boolean = false): void {
    clearTimeout(this.selectionTimer);
    if (cancelled || this.hideBar) {
      this.pendingIndex = -1;
      this.acceptingInput = false;
      return;
    }
    // Only the final native index belonging to this input may become a route.
    // Feedback or delayed native callbacks cannot open an unrelated page.
    this.selectionTimer = setTimeout(() => {
      this.selectionTimer = -1;
      const requested: number = this.pendingIndex;
      this.pendingIndex = -1;
      this.acceptingInput = false;
      if (!this.mounted || this.hideBar) {
        return;
      }
      hilog.info(0x0000, 'StarwardNavigation', 'intent index=%{public}d param=%{public}d', requested, this.selectedIndex);
      if (requested === 0 || requested === 3) {
        this.selected(requested);
      } else if (requested === 1 || requested === 2) {
        this.unavailableSelected(requested);
      }
    }, 0);
  }

  @Monitor('selectedIndex')
  destinationChanged(): void {
    clearTimeout(this.selectionTimer);
    this.selectionTimer = -1;
    this.pendingIndex = -1;
    this.acceptingInput = false;
    hilog.info(0x0000, 'StarwardNavigation', 'param selected=%{public}d active=%{public}d', this.selectedIndex, this.activeIndex);
    if (this.selectedIndex === 0 || this.selectedIndex === 3) {
      this.activeIndex = this.selectedIndex;
    }
  }

  private tabStyle(index: number, normalIcon: Resource, selectedIcon: Resource, label: string,
    nodeId: string): BottomTabBarStyle {
    const icon: Resource = this.selectedIndex === index ? selectedIcon : normalIcon;
    return BottomTabBarStyle.of(icon, label).id(nodeId)
      .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') })
      .iconStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') });
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.activeIndex!!, barModifier: this.barInputModifier }) {
      TabContent() {
        this.journeys()
      }.tabBar(this.tabStyle(0, $r('app.media.icon_nav_compass_regular'),
        $r('app.media.icon_nav_compass_fill'), '启程', 'nav-home'))
      TabContent() {
        Column()
      }.tabBar(this.tabStyle(1, $r('app.media.icon_nav_sparkle_regular'),
        $r('app.media.icon_nav_sparkle_fill'), '收藏', 'nav-rewards'))
        .accessibilityText('收藏，暂未开放')
      TabContent() {
        Column()
      }.tabBar(this.tabStyle(2, $r('app.media.icon_nav_envelope_regular'),
        $r('app.media.icon_nav_envelope_fill'), '来信', 'nav-notifications'))
        .accessibilityText('来信，暂未开放')
      TabContent() {
        this.passport()
      }.tabBar(this.tabStyle(3, $r('app.media.icon_nav_passport_regular'),
        $r('app.media.icon_nav_passport_fill'), '护照', 'nav-profile'))
    }.width('100%').height('100%').vertical(false).scrollable(false).barOverlap(true)
      .barBackgroundColor(this.material ? Color.Transparent : $r('app.color.raised'))
      .barFloatingStyle({
        barSideMargin: 20,
        barBottomMargin: this.floatingGap,
        maskColor: Color.Transparent,
        adaptToHandedness: this.followHandedness,
        systemMaterial: this.material
      })
      .onContentWillChange((current: number, coming: number): boolean => {
        hilog.info(0x0000, 'StarwardNavigation', 'will current=%{public}d coming=%{public}d active=%{public}d param=%{public}d',
          current, coming, this.activeIndex, this.selectedIndex);
        if ((coming === 0 || coming === 3) && coming === this.selectedIndex) {
          return true;
        }
        this.requestSelection(coming);
        return false;
      })
      .onChange((index: number) => {
        hilog.info(0x0000, 'StarwardNavigation', 'change index=%{public}d active=%{public}d param=%{public}d',
          index, this.activeIndex, this.selectedIndex);
        // Native change notifications also include programmatic updates.
        // The parent-approved destination remains the routing authority.
        this.activeIndex = this.selectedIndex;
      })
      .onTabBarClick((index: number) => {
        hilog.info(0x0000, 'StarwardNavigation', 'click index=%{public}d active=%{public}d param=%{public}d',
          index, this.activeIndex, this.selectedIndex);
        this.requestSelection(index);
      })
  }
}

/** Category switching and its transition are owned by native Tabs/SubTabBarStyle. */
@ComponentV2
export struct StarwardJourneyTabs {
  @Param currentCount: number = 0;
  @Param historyCount: number = 0;
  @Param selectedCategory: number = 0;
  @Event categoryChanged: (index: number) => void = () => {};
  @BuilderParam currentJourneys: () => void;
  @BuilderParam pastJourneys: () => void;

  build() {
    Tabs({ barPosition: BarPosition.Start, index: this.selectedCategory }) {
      TabContent() {
        this.currentJourneys()
      }.tabBar(SubTabBarStyle.of(`待赴之约 ${this.currentCount}`).id('current-tab')
        .indicator({ color: $r('app.color.accent'), height: 2 })
        .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'),
          font: { size: 15, weight: FontWeight.Medium } }))
      TabContent() {
        this.pastJourneys()
      }.tabBar(SubTabBarStyle.of(`旅途回响 ${this.historyCount}`).id('history-tab')
        .indicator({ color: $r('app.color.accent'), height: 2 })
        .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'),
          font: { size: 15, weight: FontWeight.Medium } }))
    }.width('100%').height('100%').barMode(BarMode.Scrollable).barHeight(53)
      .onChange((index: number) => this.categoryChanged(index))
  }
}

/** Place this as the final item INSIDE the scrollable list; it reserves no fixed footer. */
@ComponentV2
export struct StarwardSyncNote {
  @Param tailClearance: number = 112;

  build() {
    Column() {
      Text('场次与进度会自动同步，放心去探索。').id('assignment-sync-note-text')
        .fontSize(11).lineHeight('16fp').fontColor($r('app.color.subtle')).textAlign(TextAlign.Center).width('100%')
    }.id('assignment-sync-note').width('100%').padding({ top: 24, bottom: this.tailClearance })
  }
}
