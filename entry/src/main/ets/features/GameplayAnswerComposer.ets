import { curves, uiMaterial } from '@kit.ArkUI';
import { StarwardAnswerCapsuleMaterial, StarwardAnswerInput, StarwardAnswerSubmit } from '../ui/StarwardAnswerInput';
import { StarwardMaterial } from '../ui/StarwardMaterial';
import { starwardPageReveal } from '../ui/StarwardMotion';
import { STARWARD_RADIUS_BADGE, STARWARD_RADIUS_PANEL, STARWARD_RADIUS_ROUND } from '../ui/StarwardRadii';
import { GameplayChoicePopup } from './GameplayQuestionOverlays';

export type GameplayComposerAction = 'submit' | 'retry' | 'next' | 'none';

export interface GameplayComposerView {
  choice: boolean;
  choiceKey: string;
  choiceLabel: string;
  answer: string;
  placeholder: string;
  editable: boolean;
  completed: boolean;
  interactionReady: boolean;
  action: GameplayComposerAction;
  actionEnabled: boolean;
  submitting: boolean;
  advancing: boolean;
}

/** Fixed answer surface and its anchored selector. The page owns the draft and dismissal policy. */
@ComponentV2
export struct GameplayAnswerComposer {
  @Require @Param view: GameplayComposerView;
  @Param nativeDock: boolean = false;
  @Param reducedMotion: boolean = true;
  @Param revealOnMount: boolean = false;
  @Param choicesOpen: boolean = false;
  @Param choiceRevision: number = 0;
  @Param choiceStatus: string = '';
  @Param choiceMaxHeight: number = 620;
  @Param popupWidth: number = 0;
  @Param popupAnchorLeft: number = 0;
  @BuilderParam choicesContent: () => void;
  @Event openChoices: () => void = () => {};
  @Event closeChoices: (revision: number) => boolean = () => false;
  @Event choiceStateChanged: (revision: number, visible: boolean) => void = () => {};
  @Event changeAnswer: (value: string) => void = () => {};
  @Event focusChanged: (focused: boolean) => void = () => {};
  @Event editingChanged: (editing: boolean) => void = () => {};
  @Event heightChanged: (height: number) => void = () => {};
  @Local private dockWidth: number = 0;
  private readonly choiceMaterial: uiMaterial.ImmersiveMaterial | undefined =
    StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK, false);

  private choiceAccessibilityText(): string {
    if (this.view.choiceKey.length === 0) { return this.view.editable ? '选择答案' : '查看全部选项'; }
    return `${this.view.completed ? '已作答' : '已选择'} ${this.view.choiceKey} ${this.view.choiceLabel}，查看全部选项`;
  }

  private popupOptions(): CustomPopupOptions {
    const revision: number = this.choiceRevision;
    return { builder: () => { this.choicePopup(); }, placement: Placement.Top,
      targetSpace: 12,
      width: this.popupWidth > 0 ? this.popupWidth : this.dockWidth > 0 ? this.dockWidth : undefined,
      radius: STARWARD_RADIUS_PANEL,
      enableArrow: false, mask: true, showInSubWindow: false, autoCancel: true, focusable: true,
      systemMaterial: this.choiceMaterial,
      popupColor: this.choiceMaterial ? undefined : Color.Transparent,
      backgroundBlurStyle: this.choiceMaterial ? undefined : BlurStyle.COMPONENT_ULTRA_THIN,
      transition: this.reducedMotion ? TransitionEffect.IDENTITY :
        TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 }))
          .combine(TransitionEffect.scale({ x: 0.98, y: 0.98, centerY: '100%' }))
          .animation({ duration: 240, curve: curves.cubicBezierCurve(0.34, 1.38, 0.64, 1) }),
      onWillDismiss: (action: DismissPopupAction) => { if (this.closeChoices(revision)) { action.dismiss(); } },
      onStateChange: (event: PopupStateChangeParam) => this.choiceStateChanged(revision, event.isVisible) };
  }

  @Builder
  private choicePopup() {
    GameplayChoicePopup({ status: this.choiceStatus, maxHeight: this.choiceMaxHeight,
      usesSystemMaterial: this.choiceMaterial !== undefined,
      content: () => { this.choicesContent() }, close: () => { this.closeChoices(this.choiceRevision); } })
  }

  @Builder
  private choices() {
    Stack() {
      if (!this.nativeDock) { StarwardAnswerCapsuleMaterial() }
      Button({ type: ButtonType.Capsule, stateEffect: !this.reducedMotion }) {
        Row({ space: 10 }) {
          if (this.view.choiceKey.length > 0) {
            Text(this.view.choiceKey).constraintSize({ minWidth: 30 }).height(30).padding({ left: 7, right: 7 })
              .textAlign(TextAlign.Center).fontFeature("'tnum' 1")
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent_text'))
              .backgroundColor($r('app.color.accent_soft'))
              .border({ width: 1, radius: STARWARD_RADIUS_BADGE, color: $r('app.color.accent_border') })
              .accessibilityLevel('no')
          }
          Text(this.view.choiceKey.length > 0 ? this.view.choiceLabel : this.view.editable ? '选择答案' : '查看选项')
            .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).fontSize(15)
            .fontWeight(this.view.choiceKey.length > 0 ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.view.choiceKey.length > 0 ? $r('app.color.strong') : $r('app.color.muted'))
          if (!this.view.submitting) {
            Image($r('app.media.icon_caret_up_bold')).width(16).height(16).rotate({ angle: this.choicesOpen ? 180 : 0 })
              .fillColor(this.choicesOpen ? $r('app.color.accent_text') : $r('app.color.muted')).accessibilityLevel('no')
              .animation({ duration: this.reducedMotion ? 0 : 240, curve: Curve.EaseOut })
          }
        }.width('100%')
      }.id('gameplay-choice-trigger').width('100%').height(50)
        .padding({ left: this.view.choiceKey.length > 0 ? 10 : 18, right: 14 }).backgroundColor(Color.Transparent)
        .border({ width: this.nativeDock && !this.choicesOpen ? 0 : 1, radius: 999, color: this.choiceBorder() })
        .outline({ width: this.choicesOpen ? 3 : 0, radius: STARWARD_RADIUS_ROUND, color: $r('app.color.accent_soft') })
        .accessibilityText(this.choiceAccessibilityText()).accessibilityStateDescription(this.choicesOpen ? '已展开' : '')
        .enabled(this.view.interactionReady || this.choicesOpen).onClick(() => this.openChoices())
    }.layoutWeight(1).height(50)
  }

  private choiceBorder(): ResourceColor {
    if (this.choicesOpen) { return $r('app.color.accent'); }
    return this.view.choiceKey.length > 0 ? $r('app.color.accent_border') : $r('app.color.border_strong');
  }

  build() {
    Stack() {
      Row() {
        if (this.view.choice) {
          this.choices()
        } else {
          StarwardAnswerInput({ value: this.view.answer, placeholder: this.view.placeholder,
            editable: this.view.editable, nativeDock: this.nativeDock, reducedMotion: this.reducedMotion,
            focusChanged: (focused: boolean) => this.focusChanged(focused),
            editingChanged: (editing: boolean) => this.editingChanged(editing),
            changed: (value: string) => this.changeAnswer(value) }).layoutWeight(1)
        }
      }.width('100%').transition(starwardPageReveal(this.reducedMotion || !this.revealOnMount, 4))
      if (this.view.choice) {
        // A full-width layout anchor lets the system keep the popup inside the viewport on either side.
        Row().width(this.popupWidth > 0 ? this.popupWidth : '100%').height(50)
          .position({ x: this.popupAnchorLeft, y: 0 }).hitTestBehavior(HitTestMode.None)
          .accessibilityLevel('no-hide-descendants')
          .bindPopup(this.choicesOpen, this.popupOptions())
      }
    }.id('gameplay-answer-form').width('100%').height(50)
      .onAreaChange((_previous: Area, area: Area) => {
        const width: number = Number(area.width);
        if (Number.isFinite(width) && width > 0 && width !== this.dockWidth) { this.dockWidth = width; }
        const height: number = Number(area.height);
        if (Number.isFinite(height) && height > 0) { this.heightChanged(height); }
      })
  }
}

@ComponentV2
export struct GameplayAnswerAction {
  @Require @Param view: GameplayComposerView;
  @Require @Param maxWidth: number;
  @Param reducedMotion: boolean = true;
  @Param revealOnMount: boolean = false;
  @Event primaryAction: (action: GameplayComposerAction) => void = () => {};

  private foreground(): ResourceColor {
    return this.view.actionEnabled ? Color.White : $r('app.color.muted');
  }

  @Builder
  private actionButton() {
    if (this.view.action === 'submit') {
      StarwardAnswerSubmit({ actionEnabled: this.view.actionEnabled, submitting: this.view.submitting,
        reducedMotion: this.reducedMotion, action: () => this.primaryAction('submit') })
    } else if (this.view.action === 'retry') {
      Button('重新连接', { type: ButtonType.Capsule }).id('gameplay-answer-retry-inline')
        .height(50).padding({ left: 12, right: 12 }).fontSize(14).fontWeight(FontWeight.Medium)
        .constraintSize({ maxWidth: this.maxWidth })
        .fontColor(this.foreground()).backgroundColor(Color.Transparent)
        .enabled(this.view.actionEnabled).onClick(() => this.primaryAction('retry'))
    } else if (this.view.action === 'next') {
      Button({ type: ButtonType.Capsule, stateEffect: !this.reducedMotion }) {
        Row({ space: 8 }) {
          Text(this.view.advancing ? '即将前往下一题…' : '前往下一题').fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(this.foreground()).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
          Image($r('app.media.icon_arrow_right_bold')).width(16).height(16).fillColor(this.foreground())
            .accessibilityLevel('no')
        }
      }.id('gameplay-next').height(50).padding({ left: 20, right: 20 }).flexShrink(0)
        .constraintSize({ maxWidth: this.maxWidth })
        .backgroundColor(Color.Transparent)
        .enabled(this.view.actionEnabled).onClick(() => this.primaryAction(this.view.action))
    }
  }

  build() {
    Row() {
      this.actionButton()
    }.width(LayoutPolicy.wrapContent).height(50).flexShrink(0)
      .transition(starwardPageReveal(this.reducedMotion || !this.revealOnMount, 4))
  }
}
