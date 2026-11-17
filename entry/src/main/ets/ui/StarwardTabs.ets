import { CommonModifier, UIUtils } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';

/** Main destinations use a single native floating bar. */
@ComponentV2
export struct StarwardBottomTabs {
  @BuilderParam journeys: () => void;
  @BuilderParam rewards: () => void;
  @BuilderParam letters: () => void;
  @BuilderParam passport: () => void;
  @Param selectedIndex: number = 0;
  @Event canSelect: (index: number) => boolean = () => true;
  @Event selected: (index: number) => void = () => {};
  @Param followHandedness: boolean = false;
  @Param floatingGap: number = 10;
  @Param hideBar: boolean = false;
  @Param materialInteractionEnabled: boolean = false;
  @Local private tabBarModifier: CommonModifier = UIUtils.makeObserved(new CommonModifier());

  private validIndex(index: number): boolean { return Number.isInteger(index) && index >= 0 && index <= 3; }

  aboutToAppear(): void {
    this.tabBarModifier.id('starward-native-tabbar');
    this.barVisibilityChanged();
  }

  @Monitor('hideBar')
  barVisibilityChanged(): void {
    // Keep Tabs and its page drafts mounted; only the native bar leaves layout and hit testing.
    this.tabBarModifier.visibility(this.hideBar ? Visibility.None : Visibility.Visible);
  }

  private tabStyle(index: number, normalIcon: Resource, selectedIcon: Resource, label: string,
    nodeId: string): BottomTabBarStyle {
    const icon: Resource = this.selectedIndex === index ? selectedIcon : normalIcon;
    return BottomTabBarStyle.of(icon, label).id(nodeId)
      .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') })
      .iconStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') });
  }

  build() {
    HdsTabs({ barPosition: BarPosition.End, index: this.selectedIndex, barModifier: this.tabBarModifier }) {
      TabContent() {
        this.journeys()
      }.tabBar(this.tabStyle(0, $r('app.media.icon_nav_compass_regular'),
        $r('app.media.icon_nav_compass_fill'), '启程', 'nav-home'))
      TabContent() {
        this.rewards()
      }.tabBar(this.tabStyle(1, $r('app.media.icon_nav_sparkle_regular'),
        $r('app.media.icon_nav_sparkle_fill'), '收藏', 'nav-rewards'))
      TabContent() {
        this.letters()
      }.tabBar(this.tabStyle(2, $r('app.media.icon_nav_envelope_regular'),
        $r('app.media.icon_nav_envelope_fill'), '来信', 'nav-notifications'))
      TabContent() {
        this.passport()
      }.tabBar(this.tabStyle(3, $r('app.media.icon_nav_passport_regular'),
        $r('app.media.icon_nav_passport_fill'), '护照', 'nav-profile'))
    }.width('100%').height('100%').vertical(false).scrollable(false).barOverlap(true)
      .barFloatingStyle({
        barSideMargin: 20,
        barBottomMargin: this.floatingGap,
        gradientMask: { maskColor: Color.Transparent },
        adaptToHandedness: this.followHandedness,
        lightColor: this.materialInteractionEnabled ? $r('app.color.accent') : Color.Transparent,
        systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }
      })
      .onContentWillChange((current: number, coming: number): boolean => {
        const allowed: boolean = this.validIndex(coming) &&
          (coming === this.selectedIndex || (!this.hideBar && this.canSelect(coming)));
        hilog.info(0x0000, 'StarwardNavigation', 'will current=%{public}d coming=%{public}d allowed=%{public}s',
          current, coming, String(allowed));
        return allowed;
      })
      .onChange((index: number) => {
        hilog.info(0x0000, 'StarwardNavigation', 'change index=%{public}d param=%{public}d', index, this.selectedIndex);
        if (index !== this.selectedIndex && this.validIndex(index) && !this.hideBar && this.canSelect(index)) {
          this.selected(index);
        }
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
