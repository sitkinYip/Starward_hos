import { Binding, uiMaterial, UIUtils } from '@kit.ArkUI';
import { STARWARD_SESSION_TITLE_HEIGHT } from '../ui/StarwardGlassHeader';
import { StarwardMaterial } from '../ui/StarwardMaterial';
import { STARWARD_RADIUS_PANEL } from '../ui/StarwardRadii';

export const GAMEPLAY_TITLE_MIN_TOP: number = 14;
export const GAMEPLAY_TITLE_SIDE_GUTTER: number = 14;
export const GAMEPLAY_MAX_CONTENT_WIDTH: number = 920;
export const GAMEPLAY_TITLE_CLEARANCE: number = STARWARD_SESSION_TITLE_HEIGHT + 14;
export const GAMEPLAY_COMPOSER_SIDE_GUTTER: number = 16;
export const GAMEPLAY_COMPOSER_MIN_HEIGHT: number = 50;

const PROGRESS_NODE_SIZE: number = 30;
const PROGRESS_CURRENT_SIZE: number = 36;
const PROGRESS_GAP: number = 10;
const PROGRESS_RAIL_INSET: number = 8;
const PROGRESS_STAR_FILL: string = 'M228.13 116.77 L162.94 93.06 L139.23 27.87 A11.95 11.95 0 0 0 116.77 27.87 ' +
  'L93.06 93.06 L27.87 116.77 A11.95 11.95 0 0 0 27.87 139.23 L93.06 162.94 L116.77 228.13 ' +
  'A11.95 11.95 0 0 0 139.23 228.13 L162.94 162.94 L228.13 139.23 A11.95 11.95 0 0 0 228.13 116.77 Z';

export interface GameplayProgressItem {
  id: string;
  completed: boolean;
  enabled: boolean;
  locked: boolean;
}

/** Shared native material for the visible gameplay surfaces. */
@ComponentV2
export struct GameplaySurface {
  @Param radius: number = STARWARD_RADIUS_PANEL;
  @Param lightweight: boolean = false;
  @Param interactive: boolean = true;
  @Param reducedMotion: boolean = true;
  @BuilderParam content: () => void;
  @Local private material: uiMaterial.ImmersiveMaterial | undefined = undefined;

  aboutToAppear(): void { this.updateMaterial(); }

  @Monitor('lightweight', 'interactive', 'reducedMotion')
  private updateMaterial(): void {
    this.material = this.lightweight ? undefined : StarwardMaterial.create(uiMaterial.ImmersiveStyle.THIN,
      this.interactive && !this.reducedMotion, $r('app.color.accent'));
  }

  build() {
    Column() {
      if (this.lightweight) {
        Column() { this.content() }.width('100%')
          .linearGradient({ direction: GradientDirection.Bottom,
            colors: [[$r('app.color.glass_card_top'), 0], [$r('app.color.glass_card_bottom'), 1]] })
          .border({ width: 1, radius: this.radius, color: $r('app.color.border_strong') })
          .clip(true).shadow({ radius: 26, offsetY: 12, color: $r('app.color.shadow') })
      } else {
        Column() { this.content() }.width('100%')
          .backgroundColor(this.material ? Color.Transparent : $r('app.color.raised'))
          .systemMaterial(this.material)
          .border({ width: 1, radius: this.radius, color: $r('app.color.border_strong') })
      }
    }.width('100%')
  }
}

@ComponentV2
export struct GameplayProgress {
  @Require @Param items: GameplayProgressItem[];
  @Param activeIndex: number = 0;
  @Param reducedMotion: boolean = true;
  @Event select: (index: number) => void = () => {};
  private readonly scroller: Scroller = new Scroller();
  private viewportWidth: number = 0;

  @Monitor('activeIndex', 'items')
  private revealActive(): void {
    const step: number = PROGRESS_NODE_SIZE + PROGRESS_GAP;
    const railWidth: number = Math.max(0, this.items.length - 1) * step + PROGRESS_CURRENT_SIZE + 2 * PROGRESS_RAIL_INSET;
    if (this.viewportWidth <= 0 || this.viewportWidth >= railWidth) { return; }
    const center: number = PROGRESS_RAIL_INSET + this.activeIndex * step + PROGRESS_CURRENT_SIZE / 2;
    const end: number = railWidth - this.viewportWidth;
    this.scroller.scrollTo({ xOffset: Math.max(0, Math.min(end, center - this.viewportWidth / 2)),
      yOffset: 0, animation: !this.reducedMotion });
  }

  private label(index: number): string {
    const item: GameplayProgressItem | undefined = this.items[index];
    const state: string = `${item?.completed ? '，已完成' : ''}${item?.locked ? '，未解锁' : ''}`;
    return `第 ${index + 1} 题${index === this.activeIndex ? '，当前题目' : ''}${state}`;
  }

  @Builder
  private question(position: Binding<number>) {
    Button({ type: ButtonType.Normal }) {
      if (position.value === this.activeIndex || this.items[position.value]?.completed) {
        Shape() {
          Path({ commands: PROGRESS_STAR_FILL }).fill(position.value === this.activeIndex ?
            $r('app.color.accent_text') : $r('app.color.accent'))
        }.width(position.value === this.activeIndex ? 18 : 14).height(position.value === this.activeIndex ? 18 : 14)
          .viewPort({ x: '0px', y: '0px', width: '256px', height: '256px' }).accessibilityLevel('no')
      } else {
        Image($r('app.media.icon_star_four')).width(14).height(14)
          .fillColor($r('app.color.text_disabled')).accessibilityLevel('no')
      }
    }.id(`gameplay-question-${position.value}`).padding(0)
      .width(position.value === this.activeIndex ? PROGRESS_CURRENT_SIZE : PROGRESS_NODE_SIZE)
      .height(position.value === this.activeIndex ? PROGRESS_CURRENT_SIZE : PROGRESS_NODE_SIZE)
      .borderRadius(PROGRESS_CURRENT_SIZE / 2)
      .backgroundColor(position.value === this.activeIndex ? $r('app.color.accent_soft') : Color.Transparent)
      .shadow({ radius: position.value === this.activeIndex ? 12 : 0,
        color: position.value === this.activeIndex ? $r('app.color.glow_accent_soft') : Color.Transparent })
      .accessibilityText(this.label(position.value)).accessibilitySelected(position.value === this.activeIndex)
      .enabled(this.items[position.value]?.enabled === true && this.items[position.value]?.locked === false)
      .onClick(() => this.select(position.value))
  }

  build() {
    Scroll(this.scroller) {
      Row({ space: PROGRESS_GAP }) {
        ForEach(this.items, (item: GameplayProgressItem) => {
          this.question(UIUtils.makeBinding<number>(() =>
            this.items.findIndex((candidate: GameplayProgressItem) => candidate.id === item.id)))
        }, (item: GameplayProgressItem) => item.id)
      }.padding({ top: 2, bottom: 2, left: PROGRESS_RAIL_INSET, right: PROGRESS_RAIL_INSET })
    }.id('gameplay-question-progress').width('100%').align(Alignment.Center)
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 0 && width !== this.viewportWidth) {
          this.viewportWidth = width;
          this.revealActive();
        }
      })
  }
}

@ComponentV2
export struct GameplayQuestionHeading {
  @Require @Param questionNumber: number;
  @Param active: boolean = false;
  @Param hasHint: boolean = false;
  @Param hintExpanded: boolean = false;
  @Param hintEnabled: boolean = false;
  @Event openHint: () => void = () => {};

  build() {
    Row() {
      Text(`第 ${this.questionNumber} 题`).id(this.active ? 'question-number' : '')
        .fontSize(14).fontWeight(FontWeight.Medium).fontFeature("'tnum' 1").fontColor($r('app.color.accent_text'))
      Blank()
      if (this.hasHint) {
        Button({ type: ButtonType.Circle }) {
          Row() {
            Image(this.hintExpanded ? $r('app.media.icon_hint_filament_fill') :
              $r('app.media.icon_hint_filament_regular')).width(19).height(19)
              .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
          }.width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor($r('app.color.accent_soft'))
            .border({ width: 1, color: $r('app.color.border_strong'), radius: 19 })
        }.id(this.active ? 'question-hint' : '').width(38).height(38).padding(0)
          .backgroundColor(Color.Transparent).enabled(this.active && (this.hintEnabled || this.hintExpanded))
          .responseRegion({ x: -3, y: -3, width: 44, height: 44 })
          .accessibilityText('查看提示').accessibilityStateDescription(this.hintExpanded ? '已展开' : '')
          .onClick(() => this.openHint())
      }
    }.width('100%').constraintSize({ minHeight: 36 })
  }
}
