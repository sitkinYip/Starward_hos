import { uiMaterial } from '@kit.ArkUI';
import { StarwardMaterial } from './StarwardMaterial';

/** Main destinations use the native floating bar; deferred destinations cannot be entered. */
@ComponentV2
export struct StarwardBottomTabs {
  @BuilderParam journeys: () => void;
  @Event unavailableSelected: (index: number) => void = () => {};
  @Param followHandedness: boolean = false;
  @Param floatingGap: number = 10;
  private material: uiMaterial.ImmersiveMaterial | undefined =
    StarwardMaterial.create(uiMaterial.ImmersiveStyle.ULTRA_THIN);

  private tabStyle(icon: Resource, label: string, nodeId: string): BottomTabBarStyle {
    return BottomTabBarStyle.of(icon, label).id(nodeId)
      .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') })
      .iconStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted') });
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() {
        this.journeys()
      }.tabBar(this.tabStyle($r('app.media.icon_compass'), '启程', 'nav-home'))
      TabContent() {
        Column()
      }.tabBar(this.tabStyle($r('app.media.icon_sparkle'), '收藏', 'nav-rewards'))
        .accessibilityText('收藏，暂未开放')
      TabContent() {
        Column()
      }.tabBar(this.tabStyle($r('app.media.icon_envelope'), '来信', 'nav-notifications'))
        .accessibilityText('来信，暂未开放')
      TabContent() {
        Column()
      }.tabBar(this.tabStyle($r('app.media.icon_passport'), '护照', 'nav-profile'))
        .accessibilityText('护照，暂未开放')
    }.width('100%').height('100%').vertical(false).scrollable(false).barOverlap(true)
      .barBackgroundColor(this.material ? Color.Transparent : $r('app.color.raised'))
      .barFloatingStyle({
        barSideMargin: 20,
        barBottomMargin: this.floatingGap,
        maskColor: Color.Transparent,
        adaptToHandedness: this.followHandedness,
        systemMaterial: this.material
      })
      .onContentWillChange((_current: number, coming: number): boolean => coming === 0)
      .onTabBarClick((index: number) => {
        if (index > 0) {
          this.unavailableSelected(index);
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
