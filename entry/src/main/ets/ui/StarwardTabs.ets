import { CapsuleSegmentButtonV2, ColorMetrics, CommonModifier, FrameCallback, FrameNode, LengthMetrics,
  SegmentButtonV2Items, UIUtils } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HdsTabs, hdsMaterial } from '@kit.UIDesignKit';
import { StarwardMaterial } from './StarwardMaterial';

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
  @Local private immersiveBar: boolean = false;
  private mounted: boolean = false;

  private validIndex(index: number): boolean { return Number.isInteger(index) && index >= 0 && index <= 3; }

  aboutToAppear(): void {
    this.mounted = true;
    this.updateMaterial();
    this.tabBarModifier.id('starward-native-tabbar');
    this.tabBarModifier.onAreaChange(() => this.scheduleBadge());
    this.barVisibilityChanged();
  }

  aboutToDisappear(): void { this.mounted = false; }

  @Monitor('materialInteractionEnabled')
  private updateMaterial(): void {
    try {
      this.immersiveBar = StarwardMaterial.immersiveAvailable() &&
        hdsMaterial.getSystemMaterialTypes().includes(hdsMaterial.MaterialType.IMMERSIVE);
    } catch {
      this.immersiveBar = false;
    }
  }

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

  build() {
    Tabs({ barPosition: BarPosition.Start, index: this.selectedIndex }) {
      TabContent() { this.first() }
      TabContent() { this.second() }
    }.id(this.nodeId).width('100%').height('100%').barHeight(0)
      .animationDuration(this.reducedMotion ? 0 : 250)
      .onSelected((index: number) => this.selectionChanged(index))
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
