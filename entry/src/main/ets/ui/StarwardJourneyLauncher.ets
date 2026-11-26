import { curves, UIUtils } from '@kit.ArkUI';
import { GameNotification } from '../business/GameNotification';
import { QUEST_BGM_SIZE, questBgmRatio } from '../business/QuestBgmDock';
import { JourneyLauncherPosition } from '../platform/JourneyLauncherPosition';
import { STARWARD_RADIUS_BADGE, STARWARD_RADIUS_CONTROL, STARWARD_RADIUS_PANEL } from './StarwardRadii';

export const JOURNEY_LAUNCHER_SIZE: number = 54;
const DOCK_MARGIN: number = 12;
const DRAG_THRESHOLD: number = 5;
const DOCK_GAP: number = 8;

export class JourneyDockObstacle {
  readonly left: number;
  readonly top: number;
  readonly width: number;
  readonly height: number;

  constructor(left: number, top: number, width: number, height: number) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

function archiveTime(value: string): string {
  const date: Date = new Date(value);
  if (!Number.isFinite(date.getTime())) { return '未知时序'; }
  return `${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')} ` +
    `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
}

function archiveTitle(item: GameNotification): string {
  return item.title || item.popupTitle || '未命名通知';
}

@ComponentV2
struct StarwardJourneyArchiveItem {
  @Require @Param item: GameNotification;
  @Require @Param index: number;
  @Param reducedMotion: boolean = true;
  @Event select: (id: string) => void = () => {};

  build() {
    Button({ type: ButtonType.Normal, stateEffect: !this.reducedMotion }) {
      Row({ space: 12 }) {
        Image(this.item.readAt.length > 0 ? $r('app.media.icon_envelope_open') : $r('app.media.icon_envelope'))
          .width(20).height(20).objectFit(ImageFit.Contain).fillColor($r('app.color.accent_text'))
          .accessibilityLevel('no')
        Column({ space: 4 }) {
          Text(archiveTitle(this.item)).fontSize(14).fontWeight(600).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).fontColor($r('app.color.strong'))
          Text(archiveTime(this.item.sentAt)).fontSize(11).lineHeight('15.4fp')
            .fontFamily('monospace').fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Image($r('app.media.icon_arrow_right')).width(16).height(16)
          .fillColor($r('app.color.accent_muted')).accessibilityLevel('no')
      }.width('100%').padding({ left: 2, right: 2, top: 12, bottom: 12 })
    }.id('gameplay-journey-note-' + this.index).width('100%').padding(0)
      .constraintSize({ minHeight: 44 }).backgroundColor(Color.Transparent).borderRadius(STARWARD_RADIUS_CONTROL)
      .border({ width: { top: 1 }, color: this.index === 0 ? Color.Transparent : $r('app.color.accent_border') })
      .accessibilityText(archiveTitle(this.item)).accessibilityDescription(archiveTime(this.item.sentAt))
      .onClick(() => this.select(this.item.id))
  }
}

@ComponentV2
export struct StarwardJourneyLauncher {
  @Require @Param entries: GameNotification[];
  @Require @Param unreadCount: number;
  @Require @Param viewportWidth: number;
  @Require @Param viewportHeight: number;
  @Param topInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param bottomInset: number = 0;
  @Param bgmLeft: number = -1;
  @Param bgmTop: number = -1;
  @Param combinationDock: JourneyDockObstacle | null = null;
  @Param reducedMotion: boolean = true;
  @Param displayFont: string = 'serif';
  @Event select: (id: string) => void = () => {};
  @Event openInbox: () => void = () => {};
  @Local private opened: boolean = false;
  @Local private x: number = 0;
  @Local private y: number = 1;
  @Local private dragging: boolean = false;
  @Local private entered: boolean = true;
  private startX: number = 0;
  private startY: number = 1;
  private suppressTapUntil: number = 0;
  private preferences: JourneyLauncherPosition | undefined;

  aboutToAppear(): void {
    this.preferences = JourneyLauncherPosition.load();
    this.restorePosition();
    this.entered = this.reducedMotion;
  }

  @Monitor('viewportWidth', 'viewportHeight', 'topInset', 'leftInset', 'rightInset', 'bottomInset')
  geometryChanged(): void { this.finishDrag(true); }

  @Monitor('entries', 'unreadCount')
  unreadChanged(): void {
    if (this.unreadCount === 0) { this.opened = false; }
  }

  private unreadEntries(): GameNotification[] {
    return this.entries.filter((item: GameNotification) => item.readAt.length === 0);
  }

  private appear(): void {
    if (this.reducedMotion) { return; }
    this.getUIContext().animateTo({ duration: 260, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) },
      () => UIUtils.applySync(() => { this.entered = true; }));
  }

  private restorePosition(): void {
    this.x = questBgmRatio(this.preferences?.x ?? 0, 0);
    this.y = questBgmRatio(this.preferences?.y ?? 1);
  }

  private travelX(): number {
    return Math.max(0, this.viewportWidth - this.leftInset - this.rightInset - JOURNEY_LAUNCHER_SIZE - 2 * DOCK_MARGIN);
  }

  private travelY(): number {
    return Math.max(0, this.viewportHeight - this.topInset - this.bottomInset - JOURNEY_LAUNCHER_SIZE - 2 * DOCK_MARGIN);
  }

  private dockLeft(): number { return DOCK_MARGIN + this.leftInset + this.x * this.travelX(); }

  private dockTop(): number {
    const start: number = DOCK_MARGIN + this.topInset;
    const travel: number = this.travelY();
    const preferred: number = start + this.y * travel;
    if (this.dragging) { return preferred; }
    const left: number = this.dockLeft();
    const obstacles: JourneyDockObstacle[] = [];
    if (this.bgmLeft >= 0 && this.bgmTop >= 0) {
      obstacles.push(new JourneyDockObstacle(this.bgmLeft, this.bgmTop, QUEST_BGM_SIZE, QUEST_BGM_SIZE));
    }
    if (this.combinationDock !== null) { obstacles.push(this.combinationDock); }
    const nearby: JourneyDockObstacle[] = obstacles.filter((obstacle: JourneyDockObstacle) =>
      left < obstacle.left + obstacle.width + DOCK_GAP && left + JOURNEY_LAUNCHER_SIZE + DOCK_GAP > obstacle.left);
    const placements: number[] = [preferred];
    for (const obstacle of nearby) {
      placements.push(obstacle.top - JOURNEY_LAUNCHER_SIZE - DOCK_GAP, obstacle.top + obstacle.height + DOCK_GAP);
    }
    let best: number = preferred;
    let distance: number = Infinity;
    for (const candidate of placements) {
      if (candidate < start || candidate > start + travel || Math.abs(candidate - preferred) >= distance ||
        nearby.some((obstacle: JourneyDockObstacle) =>
          candidate < obstacle.top + obstacle.height + DOCK_GAP &&
          candidate > obstacle.top - JOURNEY_LAUNCHER_SIZE - DOCK_GAP)) { continue; }
      best = candidate;
      distance = Math.abs(candidate - preferred);
    }
    return best;
  }

  private startDrag(event: GestureEvent): void {
    this.startX = this.x;
    this.startY = this.travelY() > 0 ? questBgmRatio((this.dockTop() - DOCK_MARGIN - this.topInset) / this.travelY()) :
      this.y;
    this.dragging = true;
    this.followDrag(event);
  }

  private followDrag(event: GestureEvent): void {
    if (!this.dragging) { return; }
    this.x = this.travelX() > 0 ? questBgmRatio(this.startX + event.offsetX / this.travelX(), this.startX) : this.startX;
    this.y = this.travelY() > 0 ? questBgmRatio(this.startY + event.offsetY / this.travelY(), this.startY) : this.startY;
  }

  private finishDrag(cancelled: boolean): void {
    if (!this.dragging) { return; }
    this.dragging = false;
    this.suppressTapUntil = Date.now() + 150;
    const x: number = cancelled ? questBgmRatio(this.preferences?.x ?? 0, 0) : this.x < 0.5 ? 0 : 1;
    const y: number = cancelled ? questBgmRatio(this.preferences?.y ?? 1) : this.y;
    if (!cancelled && this.preferences !== undefined) {
      this.preferences.x = x;
      this.preferences.y = y;
    }
    this.getUIContext().animateTo({ duration: this.reducedMotion ? 0 : 240,
      curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }, () => UIUtils.applySync(() => {
      this.x = x;
      this.y = y;
    }));
  }

  private popupWidth(): number {
    const available: number = this.viewportWidth - this.leftInset - this.rightInset;
    return Math.max(0, Math.min(330, available - 28));
  }

  private popupOptions(): CustomPopupOptions {
    const below: boolean = this.dockTop() + JOURNEY_LAUNCHER_SIZE / 2 < this.viewportHeight / 2;
    return {
      builder: () => { this.archive(); },
      placement: below ? (this.x < 0.5 ? Placement.BottomLeft : Placement.BottomRight) :
        (this.x < 0.5 ? Placement.TopLeft : Placement.TopRight),
      width: this.popupWidth(), targetSpace: 12, enableArrow: false, mask: false, focusable: true,
      popupColor: $r('app.color.raised'), backgroundBlurStyle: BlurStyle.NONE, radius: STARWARD_RADIUS_PANEL,
      transition: this.reducedMotion ? TransitionEffect.IDENTITY : TransitionEffect.opacity(0)
        .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
        .animation({ duration: 220, curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) }),
      onStateChange: (event: PopupStateChangeParam) => { if (!event.isVisible) { this.opened = false; } }
    };
  }

  @Builder
  archive() {
    Column() {
      Row({ space: 12 }) {
        Text('未读来信').fontSize(20).lineHeight('28fp').fontFamily(this.displayFont).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.strong')).layoutWeight(1)
        Text(`${this.unreadCount} 封未读`).fontSize(12).fontFamily('monospace').fontColor($r('app.color.muted'))
      }.width('100%').alignItems(VerticalAlign.Center).padding({ top: 14, bottom: 12 })
        .border({ width: { bottom: 1 }, color: $r('app.color.accent_border') })
      Scroll() {
        Column() {
          ForEach(this.unreadEntries(), (item: GameNotification, index: number) => {
            StarwardJourneyArchiveItem({ item: item, index: index, reducedMotion: this.reducedMotion,
              select: (id: string) => {
                this.opened = false;
                this.select(id);
              } })
          }, (item: GameNotification) => item.id)
        }.width('100%').padding({ top: 2, bottom: 4 })
      }.width('100%').constraintSize({ maxHeight: Math.max(58, Math.min(380, this.viewportHeight - 230)) })
        .scrollBar(BarState.Off)
      Button({ type: ButtonType.Normal, stateEffect: !this.reducedMotion }) {
        Row({ space: 8 }) {
          Text('已阅读的来信可在「来信」中查看').fontSize(12).lineHeight('20fp')
            .fontColor($r('app.color.muted')).layoutWeight(1).textAlign(TextAlign.Start)
          Image($r('app.media.icon_arrow_right')).width(14).height(14)
            .fillColor($r('app.color.accent_text')).accessibilityLevel('no')
        }.width('100%')
      }.id('gameplay-journey-open-inbox').width('100%').constraintSize({ minHeight: 44 })
        .padding({ left: 2, right: 2, top: 10, bottom: 10 }).backgroundColor(Color.Transparent).borderRadius(0)
        .border({ width: { top: 1 }, color: $r('app.color.accent_border') })
        .accessibilityText('前往来信查看已阅读的信件').onClick(() => {
          this.opened = false;
          this.openInbox();
        })
    }.id('gameplay-journey-archive').width(this.popupWidth())
      .padding({ left: 16, right: 16, top: 2, bottom: 5 }).backgroundColor($r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: STARWARD_RADIUS_PANEL })
  }

  @Builder
  signal() {
    Stack() {
      Circle().width(40).height(40).fill($r('app.color.accent_faint'))
        .stroke($r('app.color.accent_border')).strokeWidth(1)
      Image($r('app.media.icon_envelope')).width(23).height(23).objectFit(ImageFit.Contain)
        .fillColor($r('app.color.accent_text')).draggable(false)
    }.width(40).height(40).accessibilityLevel('no-hide-descendants')
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: !this.reducedMotion }) {
      Stack() {
        this.signal()
        if (this.unreadCount > 0) {
          Text(this.unreadCount > 9 ? '9+' : this.unreadCount.toString()).id('gameplay-journey-unread-count')
            .position({ top: -4, right: -4 }).constraintSize({ minWidth: 20 }).height(20)
            .textAlign(TextAlign.Center).padding({ left: 5, right: 5 }).fontSize(10).fontWeight(700).maxFontScale(1)
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .borderRadius(STARWARD_RADIUS_BADGE)
            .draggable(false).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
        }
      }.width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    }.id('gameplay-journey-launcher').width(JOURNEY_LAUNCHER_SIZE).height(JOURNEY_LAUNCHER_SIZE).padding(0)
      .backgroundColor(this.opened ? $r('app.color.surface_hover') : $r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: JOURNEY_LAUNCHER_SIZE / 2 })
      .shadow({ radius: this.getUIContext().vp2px(16), color: $r('app.color.choice_shadow'),
        offsetY: this.getUIContext().vp2px(5) })
      .clickEffect(this.reducedMotion || this.dragging ? null : { level: ClickEffectLevel.LIGHT, scale: 0.94 })
      .accessibilityText(this.opened ? '关闭旅途来信' : '打开旅途来信')
      .accessibilityDescription(`${this.unreadCount} 封未读，可拖动移动并贴边`)
      .onClick((event: ClickEvent) => {
        const pointer: boolean = event.source === SourceType.TouchScreen || event.source === SourceType.Mouse;
        if (!this.dragging && (!pointer || Date.now() >= this.suppressTapUntil)) { this.opened = !this.opened; }
      }, DRAG_THRESHOLD)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down && event.touches.length === 1 && !this.dragging) {
          this.suppressTapUntil = 0;
        }
      })
      .priorityGesture(PanGesture({
        fingers: 1, direction: PanDirection.All, distance: DRAG_THRESHOLD, isFingerCountLimited: true
      }).onActionStart((event: GestureEvent) => this.startDrag(event))
        .onActionUpdate((event: GestureEvent) => this.followDrag(event))
        .onActionEnd((event: GestureEvent) => {
          this.followDrag(event);
          this.finishDrag(false);
        }).onActionCancel(() => this.finishDrag(true)))
      .bindPopup(this.opened, this.popupOptions())
      .position({ x: this.dockLeft(), y: this.dockTop() })
      .opacity(this.reducedMotion || this.entered ? 1 : 0)
      .scale({ x: this.reducedMotion || this.entered ? 1 : 0.92, y: this.reducedMotion || this.entered ? 1 : 0.92 })
      .translate({ y: this.reducedMotion || this.entered ? 0 : 6 })
      .onAppear(() => this.appear())
  }
}
