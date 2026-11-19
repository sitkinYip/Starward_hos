import { CommonModifier, FrameCallback, FrameNode, UIUtils } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';

class TabBadgeMeasure extends FrameCallback {
  private readonly measure: () => void;
  constructor(measure: () => void) { super(); this.measure = measure; }
  onIdle(_remaining: number): void { this.measure(); }
}

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
  @Param unreadLetters: number = 0;
  @Local private tabBarModifier: CommonModifier = UIUtils.makeObserved(new CommonModifier());
  @Local private badgeX: number = 0;
  @Local private badgeY: number = 0;
  @Local private badgeMeasured: boolean = false;
  private mounted: boolean = false;

  private validIndex(index: number): boolean { return Number.isInteger(index) && index >= 0 && index <= 3; }

  aboutToAppear(): void {
    this.mounted = true;
    this.tabBarModifier.id('starward-native-tabbar');
    this.tabBarModifier.onAreaChange(() => this.scheduleBadge());
    this.barVisibilityChanged();
  }

  aboutToDisappear(): void { this.mounted = false; }

  @Monitor('unreadLetters', 'selectedIndex', 'floatingGap')
  private scheduleBadge(): void {
    if (!this.mounted || this.hideBar || this.unreadLetters <= 0) { return; }
    this.getUIContext().postFrameCallback(new TabBadgeMeasure(() => this.measureBadge()));
  }

  private findIcon(node: FrameNode, depth: number): FrameNode | null {
    if (node.getNodeType() === 'Image' || node.getNodeType() === 'SymbolGlyph') { return node; }
    if (depth === 0) { return null; }
    let child: FrameNode | null = node.getFirstChild();
    while (child !== null) {
      const icon: FrameNode | null = this.findIcon(child, depth - 1);
      if (icon !== null) { return icon; }
      child = child.getNextSibling();
    }
    return null;
  }

  private measureBadge(): void {
    if (!this.mounted || this.hideBar || this.unreadLetters <= 0) { return; }
    try {
      const context = this.getUIContext();
      const tab: FrameNode | null = context.getFrameNodeById('nav-notifications');
      const frame: FrameNode | null = context.getFrameNodeById('starward-tab-frame');
      if (tab === null || frame === null) { return; }
      const icon: FrameNode | null = this.findIcon(tab, 4);
      if (icon === null) { return; }
      const position = icon.getPositionToWindowWithTransform();
      const origin = frame.getPositionToWindowWithTransform();
      const width: number = context.px2vp(icon.getMeasuredSize().width);
      if (width <= 0) { return; }
      this.badgeX = position.x - origin.x + width - 8;
      this.badgeY = position.y - origin.y - 7;
      this.badgeMeasured = true;
    } catch {
      // The native bar may be leaving the tree during a navigation change.
      this.badgeMeasured = false;
    }
  }

  @Monitor('hideBar')
  barVisibilityChanged(): void {
    // Keep Tabs and its page drafts mounted; only the native bar leaves layout and hit testing.
    this.tabBarModifier.visibility(this.hideBar ? Visibility.None : Visibility.Visible);
    this.scheduleBadge();
  }

  private tabStyle(icon: Resource, label: string, nodeId: string): BottomTabBarStyle {
    return BottomTabBarStyle.of(icon, label).id(nodeId)
      .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') })
      .iconStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HdsTabs({ barPosition: BarPosition.End, index: this.selectedIndex, barModifier: this.tabBarModifier }) {
        TabContent() {
          this.journeys()
        }.tabBar(this.tabStyle(this.selectedIndex === 0 ? $r('app.media.icon_nav_compass_fill') :
          $r('app.media.icon_nav_compass_regular'), '启程', 'nav-home'))
        TabContent() {
          this.rewards()
        }.tabBar(this.tabStyle(this.selectedIndex === 1 ? $r('app.media.icon_nav_sparkle_fill') :
          $r('app.media.icon_nav_sparkle_regular'), '收藏', 'nav-rewards'))
        TabContent() {
          this.letters()
        }.tabBar(this.tabStyle(this.selectedIndex === 2 ? $r('app.media.icon_nav_envelope_fill') :
          $r('app.media.icon_nav_envelope_regular'), '来信', 'nav-notifications'))
        TabContent() {
          this.passport()
        }.tabBar(this.tabStyle(this.selectedIndex === 3 ? $r('app.media.icon_nav_passport_fill') :
          $r('app.media.icon_nav_passport_regular'), '护照', 'nav-profile'))
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
        .onSelected((index: number) => {
          // The native selection is committed at the start of the transition.
          // Animation completion can arrive after the next selection.
          if (index !== this.selectedIndex && this.validIndex(index) && this.canSelect(index)) {
            this.selected(index);
          }
          hilog.info(0x0000, 'StarwardNavigation', 'selected index=%{public}d param=%{public}d', index, this.selectedIndex);
        })
        .onChange((index: number) => {
          hilog.info(0x0000, 'StarwardNavigation', 'change index=%{public}d param=%{public}d', index, this.selectedIndex);
        })
      if (!this.hideBar && this.unreadLetters > 0 && this.badgeMeasured) {
        Badge({ count: this.unreadLetters, maxCount: 99, position: { x: 0, y: 0 },
          style: { color: $r('app.color.on_accent'), badgeColor: $r('app.color.accent'),
            fontSize: 10, badgeSize: 17, fontWeight: FontWeight.Medium,
            borderWidth: 0, borderColor: $r('app.color.accent') } }) {
          Row().width(17).height(17)
        }.id('journey-nav-unread').width(17).height(17).position({ x: this.badgeX, y: this.badgeY })
          .hitTestBehavior(HitTestMode.None).accessibilityText(`旅途来信，${this.unreadLetters} 封未读`)
      }
    }.id('starward-tab-frame').width('100%').height('100%').onAreaChange(() => this.scheduleBadge())
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
