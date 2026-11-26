import { CapsuleSegmentButtonV2, ColorMetrics, CommonModifier, curves, FrameCallback, FrameNode, LengthMetrics,
  SegmentButtonV2Items, UIUtils } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { StarwardMaterial } from './StarwardMaterial';
import { STARWARD_PAGE_TRANSITION_MS } from './StarwardMotion';

const PANE_TRANSITION_CURVE: ICurve = curves.cubicBezierCurve(0.2, 0, 0, 1);

export function starwardImmersiveTabsAvailable(): boolean {
  try {
    return StarwardMaterial.immersiveAvailable() &&
      hdsMaterial.getSystemMaterialTypes().includes(hdsMaterial.MaterialType.IMMERSIVE);
  } catch {
    return false;
  }
}

/** A declarative index seeds native Tabs, while subsequent owner requests use the animated controller. */
class NativeTabIndex {
  index: number = 0;
  attached: boolean = false;

  sync(index: number, controller: TabsController): void {
    if (!this.attached || this.index === index) { return; }
    this.index = index;
    controller.changeIndex(index);
  }
}

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
  @Param reducedMotion: boolean = true;
  @Param unreadAssignments: number = 0;
  @Param unreadRewards: number = 0;
  @Param unreadLetters: number = 0;
  @Local private tabBarModifier: CommonModifier = UIUtils.makeObserved(new CommonModifier());
  @Local private badgePositions: Map<string, Position> = new Map();
  @Local private immersiveBar: boolean = false;
  private readonly controller: HdsTabsController = new HdsTabsController();
  private readonly nativeIndex: NativeTabIndex = new NativeTabIndex();
  private mounted: boolean = false;
  private badgeMeasureQueued: boolean = false;

  private validIndex(index: number): boolean { return Number.isInteger(index) && index >= 0 && index <= 3; }

  aboutToAppear(): void {
    this.mounted = true;
    this.nativeIndex.index = this.selectedIndex;
    this.updateMaterial();
    this.tabBarModifier.id('starward-native-tabbar');
    this.tabBarModifier.onAreaChange(() => this.scheduleBadge());
    this.barVisibilityChanged();
  }

  aboutToDisappear(): void {
    this.nativeIndex.attached = false;
    this.mounted = false;
  }

  @Monitor('selectedIndex')
  private applyOwnerIndex(): void {
    if (this.validIndex(this.selectedIndex)) { this.nativeIndex.sync(this.selectedIndex, this.controller); }
  }

  @Monitor('materialInteractionEnabled')
  private updateMaterial(): void {
    this.immersiveBar = starwardImmersiveTabsAvailable();
  }

  @Monitor('unreadAssignments', 'unreadRewards', 'unreadLetters', 'selectedIndex', 'floatingGap', 'followHandedness')
  private scheduleBadge(): void {
    if (!this.mounted || this.hideBar || this.badgeMeasureQueued ||
      this.unreadAssignments + this.unreadRewards + this.unreadLetters <= 0) { return; }
    this.badgeMeasureQueued = true;
    this.getUIContext().postFrameCallback(new TabBadgeMeasure(() => {
      this.badgeMeasureQueued = false;
      this.measureBadges();
    }));
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

  private unreadCount(tabId: string): number {
    if (tabId === 'nav-home') { return this.unreadAssignments; }
    if (tabId === 'nav-rewards') { return this.unreadRewards; }
    return this.unreadLetters;
  }

  private measureBadges(): void {
    if (!this.mounted || this.hideBar) { return; }
    const positions: Map<string, Position> = new Map();
    try {
      const context = this.getUIContext();
      const frame: FrameNode | null = context.getFrameNodeById('starward-tab-frame');
      if (frame !== null) {
        const origin = frame.getPositionToWindowWithTransform();
        for (const tabId of ['nav-home', 'nav-rewards', 'nav-notifications']) {
          if (this.unreadCount(tabId) <= 0) { continue; }
          const tab: FrameNode | null = context.getFrameNodeById(tabId);
          const icon: FrameNode | null = tab === null ? null : this.findIcon(tab, 4);
          if (icon === null) { continue; }
          const position = icon.getPositionToWindowWithTransform();
          const width: number = context.px2vp(icon.getMeasuredSize().width);
          if (width > 0) {
            positions.set(tabId, { x: position.x - origin.x + width - 8, y: position.y - origin.y - 7 });
          }
        }
      }
    } catch {
      // The native bar may be leaving the tree during a navigation change.
      positions.clear();
    }
    this.badgePositions = positions;
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

  @Builder
  private unreadBadge(tabId: string, nodeId: string, label: string) {
    if (!this.hideBar && this.unreadCount(tabId) > 0 && this.badgePositions.has(tabId)) {
      Badge({ count: this.unreadCount(tabId), maxCount: 99, position: { x: 0, y: 0 },
        style: { color: $r('app.color.on_accent'), badgeColor: $r('app.color.accent'),
          fontSize: 10, badgeSize: 17, fontWeight: FontWeight.Medium,
          borderWidth: 0, borderColor: $r('app.color.accent') } }) {
        Row().width(17).height(17)
      }.id(nodeId).width(17).height(17).position(this.badgePositions.get(tabId) ?? { x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
        .accessibilityText(`${label}，${this.unreadCount(tabId)} ${tabId === 'nav-notifications' ? '封' : '项'}未读`)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      HdsTabs({ barPosition: BarPosition.End, index: this.nativeIndex.index, controller: this.controller,
        barModifier: this.tabBarModifier }) {
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
        .animationDuration(this.reducedMotion ? 0 : STARWARD_PAGE_TRANSITION_MS)
        .barBackgroundColor(this.immersiveBar ? Color.Transparent : $r('app.color.raised'))
        .barFloatingStyle({
          barSideMargin: 20,
          barBottomMargin: this.floatingGap,
          gradientMask: { maskColor: Color.Transparent },
          adaptToHandedness: this.followHandedness,
          lightColor: this.immersiveBar && this.materialInteractionEnabled ?
            $r('app.color.accent') : Color.Transparent,
          systemMaterialEffect: this.immersiveBar ? { materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE } : undefined
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
          if (this.validIndex(index) && (index === this.selectedIndex || this.canSelect(index))) {
            this.nativeIndex.index = index;
            if (index !== this.selectedIndex) { this.selected(index); }
          }
          hilog.info(0x0000, 'StarwardNavigation', 'selected index=%{public}d param=%{public}d', index, this.selectedIndex);
        })
        .onChange((index: number) => {
          hilog.info(0x0000, 'StarwardNavigation', 'change index=%{public}d param=%{public}d', index, this.selectedIndex);
        })
        .onAppear(() => {
          this.nativeIndex.attached = true;
          this.applyOwnerIndex();
        })
      this.unreadBadge('nav-home', 'assignment-nav-unread', '新场次')
      this.unreadBadge('nav-rewards', 'rewards-nav-unread', '待领奖品')
      this.unreadBadge('nav-notifications', 'journey-nav-unread', '旅途来信')
    }.id('starward-tab-frame').width('100%').height('100%').onAreaChange(() => this.scheduleBadge())
  }
}

/** The page owns category state; ArkUI supplies the capsule, selection and input feedback. */
@ComponentV2
export struct StarwardCapsuleSegment {
  @Require @Param items: SegmentButtonV2Items;
  @Param selectedIndex: number = 0;
  @Param reducedMotion: boolean = true;
  @Param nodeId: string = '';
  @Event selectionChanged: (index: number) => void = () => {};

  build() {
    Column() {
      CapsuleSegmentButtonV2({
        items: this.items,
        selectedIndex: this.selectedIndex,
        $selectedIndex: (index: number) => this.selectionChanged(index),
        buttonPadding: LengthMetrics.vp(4),
        buttonBorderRadius: LengthMetrics.vp(999),
        buttonBackgroundColor: ColorMetrics.resourceColor($r('app.color.inset')),
        itemSpace: LengthMetrics.vp(0),
        itemMinHeight: LengthMetrics.vp(44),
        itemBorderRadius: LengthMetrics.vp(999),
        itemFontColor: ColorMetrics.resourceColor($r('app.color.muted')),
        itemSelectedFontColor: ColorMetrics.resourceColor($r('app.color.on_accent')),
        itemSelectedBackgroundColor: ColorMetrics.resourceColor($r('app.color.accent')),
        itemFontWeight: FontWeight.Medium,
        itemSelectedFontWeight: FontWeight.Medium,
        enableStateAnimation: !this.reducedMotion
      }).width('100%')
    }.id(this.nodeId).width('100%').border({ width: 1, radius: 999, color: $r('app.color.border') })
  }
}

/** ArkUI handles horizontal gestures between two independently scrollable categories. */
@ComponentV2
export struct StarwardPaneTabs {
  @Param selectedIndex: number = 0;
  @Param reducedMotion: boolean = true;
  @Param nodeId: string = '';
  @Event selectionChanged: (index: number) => void = () => {};
  @BuilderParam first: () => void;
  @BuilderParam second: () => void;
  private readonly controller: TabsController = new TabsController();
  private readonly nativeIndex: NativeTabIndex = new NativeTabIndex();

  aboutToAppear(): void { this.nativeIndex.index = this.selectedIndex; }

  aboutToDisappear(): void { this.nativeIndex.attached = false; }

  @Monitor('selectedIndex')
  private applyOwnerIndex(): void { this.nativeIndex.sync(this.selectedIndex, this.controller); }

  build() {
    Tabs({ barPosition: BarPosition.Start, index: this.nativeIndex.index, controller: this.controller }) {
      TabContent() { this.first() }
      TabContent() { this.second() }
    }.id(this.nodeId).width('100%').height('100%').barHeight(0)
      .animationCurve(PANE_TRANSITION_CURVE)
      .animationDuration(this.reducedMotion ? 0 : STARWARD_PAGE_TRANSITION_MS)
      .onSelected((index: number) => {
        this.nativeIndex.index = index;
        if (index !== this.selectedIndex) { this.selectionChanged(index); }
      })
      .onAppear(() => {
        this.nativeIndex.attached = true;
        this.applyOwnerIndex();
      })
  }
}

/** The native segment and scrollable panes share the owner's selected category. */
@ComponentV2
export struct StarwardJourneyTabs {
  @Param selectedCategory: number = 0;
  @Param reducedMotion: boolean = true;
  @Event categoryChanged: (index: number) => void = () => {};
  @BuilderParam currentJourneys: () => void;
  @BuilderParam pastJourneys: () => void;
  private readonly segments: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '待赴', accessibilityText: '待赴' },
    { text: '回响', accessibilityText: '回响' }
  ]);

  private select(index: number): void {
    if ((index === 0 || index === 1) && index !== this.selectedCategory) {
      this.categoryChanged(index);
    }
  }

  build() {
    Column() {
      StarwardCapsuleSegment({ items: this.segments, selectedIndex: this.selectedCategory,
        reducedMotion: this.reducedMotion, nodeId: 'journey-segment',
        selectionChanged: (index: number) => this.select(index) }).margin({ bottom: 18 })
      StarwardPaneTabs({ selectedIndex: this.selectedCategory, reducedMotion: this.reducedMotion,
        nodeId: 'journey-panes', selectionChanged: (index: number) => this.select(index),
        first: () => { this.currentJourneys() }, second: () => { this.pastJourneys() } }).layoutWeight(1)
    }.width('100%').height('100%')
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
