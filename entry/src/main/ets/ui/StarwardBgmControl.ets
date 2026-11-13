import { curves, UIUtils } from '@kit.ArkUI';
import { QUEST_BGM_SIZE, questBgmCoordinate, questBgmRatio, questBgmTravel } from '../business/QuestBgmDock';

const DRAG_THRESHOLD: number = 5;

@ComponentV2
struct StarwardBgmWave {
  @Require @Param barHeight: number;
  @Require @Param phaseDelay: number;
  @Param animated: boolean = false;
  @Local private extended: boolean = false;

  build() {
    Rect().width(2).height(this.barHeight).fill($r('app.color.accent_text'))
      .scale({ x: 1, y: this.animated && !this.extended ? 0.45 : 1 })
      .onAppear(() => {
        if (!this.animated) { return; }
        this.getUIContext().animateTo({ duration: 800, delay: this.phaseDelay, iterations: -1,
          playMode: PlayMode.Alternate, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) }, () =>
          UIUtils.applySync(() => { this.extended = true; }));
      })
  }
}

/** The native button presents playback state and holds only the in-progress drag. */
@ComponentV2
export struct StarwardBgmControl {
  @Require @Param state: string;
  @Require @Param ownerKey: string;
  @Require @Param viewportWidth: number;
  @Require @Param viewportHeight: number;
  @Param topInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param bottomInset: number = 0;
  @Param savedX: number = 1;
  @Param savedY: number = 1;
  @Param reducedMotion: boolean = true;
  @Event toggle: () => void = () => {};
  @Event positionCommitted: (owner: string, x: number, y: number) => void = () => {};
  @Local private x: number = 1;
  @Local private y: number = 1;
  @Local private dragging: boolean = false;
  private startX: number = 1;
  private startY: number = 1;
  private dragOwner: string = '';
  private suppressPointerClickUntil: number = 0;

  aboutToAppear(): void { this.restorePosition(); }

  aboutToDisappear(): void {
    this.dragging = false;
    this.dragOwner = '';
  }

  @Monitor('ownerKey', 'viewportWidth', 'viewportHeight', 'topInset', 'leftInset', 'rightInset', 'bottomInset')
  geometryChanged(): void {
    if (this.dragging) { this.suppressPointerClickUntil = Date.now() + 150; }
    this.dragOwner = '';
    this.dragging = false;
    this.restorePosition();
  }

  @Monitor('savedX', 'savedY')
  savedPositionChanged(): void {
    if (!this.dragging) { this.restorePosition(); }
  }

  private restorePosition(): void {
    const x: number = questBgmRatio(this.savedX);
    const y: number = questBgmRatio(this.savedY);
    if (this.x !== x) { this.x = x; }
    if (this.y !== y) { this.y = y; }
  }

  private startDrag(event: GestureEvent): void {
    if (this.ownerKey.length === 0) { return; }
    this.startX = this.x;
    this.startY = this.y;
    this.dragOwner = this.ownerKey;
    this.dragging = true;
    this.followDrag(event);
  }

  private followDrag(event: GestureEvent): void {
    if (!this.dragging || this.dragOwner !== this.ownerKey) { return; }
    const travelX: number = questBgmTravel(this.viewportWidth, this.leftInset, this.rightInset);
    const travelY: number = questBgmTravel(this.viewportHeight, this.topInset, this.bottomInset);
    this.x = travelX > 0 ? questBgmRatio(this.startX + event.offsetX / travelX, this.startX) : this.startX;
    this.y = travelY > 0 ? questBgmRatio(this.startY + event.offsetY / travelY, this.startY) : this.startY;
  }

  private finishDrag(cancelled: boolean): void {
    if (!this.dragging) { return; }
    const owner: string = this.dragOwner;
    const commit: boolean = !cancelled && owner === this.ownerKey;
    this.dragOwner = '';
    this.suppressPointerClickUntil = Date.now() + 150;
    const x: number = commit ? (this.x < 0.5 ? 0 : 1) : questBgmRatio(this.savedX);
    const y: number = commit ? this.y : questBgmRatio(this.savedY);
    if (this.reducedMotion) {
      this.dragging = false;
      this.x = x;
      this.y = y;
    } else {
      const ui = this.getUIContext();
      const impact = curves.cubicBezierCurve(0.16, 1, 0.3, 1);
      ui.animateTo({ duration: 240, curve: impact }, () => UIUtils.applySync(() => {
        this.x = x;
      }));
      ui.animateTo({ duration: 200, curve: impact }, () => UIUtils.applySync(() => {
        this.y = y;
      }));
      ui.animateTo({ duration: 480, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) }, () =>
        UIUtils.applySync(() => { this.dragging = false; }));
    }
    if (commit) { this.positionCommitted(owner, x, y); }
  }

  private click(event: ClickEvent): void {
    const pointer: boolean = event.source === SourceType.TouchScreen || event.source === SourceType.Mouse;
    if (!this.dragging && (!pointer || Date.now() >= this.suppressPointerClickUntil)) { this.toggle(); }
  }

  private label(): string {
    if (this.state === 'error') { return '重试播放背景音乐'; }
    if (this.state === 'loading') { return '取消加载背景音乐'; }
    return this.state === 'playing' ? '暂停背景音乐' : '播放背景音乐';
  }

  private playbackDescription(): string {
    if (this.state === 'playing') { return '当前正在播放'; }
    if (this.state === 'loading') { return '正在加载背景音乐'; }
    return this.state === 'error' ? '背景音乐播放失败' : '当前已暂停';
  }

  @Builder
  waves(animated: boolean) {
    Row({ space: 3 }) {
      StarwardBgmWave({ barHeight: 8, phaseDelay: 0, animated: animated })
      StarwardBgmWave({ barHeight: 14, phaseDelay: 180, animated: animated })
      StarwardBgmWave({ barHeight: 8, phaseDelay: 340, animated: animated })
    }.height(14).opacity(0.42)
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }

  @Builder
  playbackBadge() {
    Stack() {
      if (this.state === 'playing') {
        Row({ space: 2 }) {
          Rect().width(2).height(7).radius(1).fill($r('app.color.on_accent'))
          Rect().width(2).height(7).radius(1).fill($r('app.color.on_accent'))
        }.height(7)
      } else if (this.state === 'loading') {
        if (this.reducedMotion) {
          Circle().width(8).height(8).fill(Color.Transparent).stroke($r('app.color.accent_text')).strokeWidth(1)
        } else {
          LoadingProgress().width(10).height(10).color($r('app.color.accent_text'))
        }
      } else if (this.state === 'error') {
        Image($r('app.media.icon_reconnect')).width(12).height(12).fillColor($r('app.color.accent_text'))
      } else {
        Polygon().width(6).height(8).points([[0, 0], [6, 4], [0, 8]])
          .fill($r('app.color.text')).strokeWidth(0).translate({ x: 1 })
      }
    }.width(18).height(18).position({ right: 5, bottom: 5 }).borderRadius(9)
      .backgroundColor(this.state === 'playing' ? $r('app.color.accent') : $r('app.color.surface_hover'))
      .border({ width: 1, color: this.state === 'playing' ?
        $r('app.color.bgm_badge_active_border') : $r('app.color.answer_recovery_button_border') })
      .shadow({ radius: this.getUIContext().vp2px(this.state === 'playing' ? 12 : 8),
        color: this.state === 'playing' ? $r('app.color.bgm_badge_glow') : $r('app.color.choice_shadow'),
        offsetY: this.getUIContext().vp2px(2) })
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: !this.reducedMotion }) {
      Stack() {
        if (this.state === 'playing') {
          if (this.reducedMotion) {
            this.waves(false)
          } else {
            this.waves(true)
          }
        }
        Text('♪').fontFamily('Georgia').fontSize(22).maxFontScale(1)
          .fontColor(this.state === 'playing' ? $r('app.color.accent_text') : $r('app.color.accent_muted'))
          .translate({ x: -1, y: -1 })
        this.playbackBadge()
      }.width('100%').height('100%')
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    }.id('gameplay-bgm-toggle').width(QUEST_BGM_SIZE).height(QUEST_BGM_SIZE).padding(0)
      .backgroundColor($r('app.color.bgm_control_surface'))
      .border({ width: 1, radius: 28, color: this.state === 'playing' ?
        $r('app.color.accent') : $r('app.color.accent_border') })
      .shadow({ radius: this.getUIContext().vp2px(this.state === 'playing' ? 46 : 42),
        color: this.state === 'playing' ? $r('app.color.bgm_control_glow') : $r('app.color.bgm_control_shadow'),
        offsetY: this.getUIContext().vp2px(this.state === 'playing' ? 8 : 12) })
      .animation({ duration: this.reducedMotion ? 0 : 320, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) })
      .position({ x: questBgmCoordinate(this.x, this.viewportWidth, this.leftInset, this.rightInset),
        y: questBgmCoordinate(this.y, this.viewportHeight, this.topInset, this.bottomInset) })
      .scale({ x: this.dragging ? 0.96 : 1, y: this.dragging ? 0.96 : 1 })
      .clickEffect(this.reducedMotion || this.dragging ? null : { level: ClickEffectLevel.LIGHT, scale: 0.96 })
      .accessibilityText(this.label()).accessibilityDescription(this.playbackDescription() + '，可拖动后贴边')
      .onClick((event: ClickEvent) => this.click(event), DRAG_THRESHOLD)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down && event.touches.length === 1 && !this.dragging) {
          this.suppressPointerClickUntil = 0;
        } else if (event.type === TouchType.Cancel) {
          this.finishDrag(true);
        }
      })
      .onMouse((event: MouseEvent) => {
        if (event.action === MouseAction.Press && event.button === MouseButton.Left && !this.dragging) {
          this.suppressPointerClickUntil = 0;
        }
      })
      .priorityGesture(PanGesture({
        fingers: 1, direction: PanDirection.All, distance: DRAG_THRESHOLD, isFingerCountLimited: true
      }).onActionStart((event: GestureEvent) => this.startDrag(event))
        .onActionUpdate((event: GestureEvent) => this.followDrag(event))
        .onActionEnd((event: GestureEvent) => {
          this.followDrag(event);
          this.finishDrag(false);
        })
        .onActionCancel(() => this.finishDrag(true)))
  }
}
