import { CommonModifier, curves } from '@kit.ArkUI';
import { hdsEffect } from '@kit.UIDesignKit';
import { StarwardMaterial } from './StarwardMaterial';

const ANSWER_EDIT_BLUR_RADIUS: number = 18;
const ANSWER_IDLE_BLUR_RADIUS: number = 10;

/** Shared ArkUI glass behind the native input or choice button. */
@ComponentV2
export struct StarwardAnswerCapsuleMaterial {
  @Param editing: boolean = false;
  private blurAllowed: boolean = false;
  private readonly idleLight: CommonModifier = new CommonModifier();

  aboutToAppear(): void {
    this.blurAllowed = StarwardMaterial.backgroundBlurAllowed();
    if (this.blurAllowed && canIUse('SystemCapability.UIDesign.HDSComponent.Core')) {
      try {
        this.idleLight.visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({
          sourceType: hdsEffect.PointLightSourceType.SOFT,
          illuminatedType: hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER
        }).buildEffect());
      } catch {
        // The glass surface remains available when the optional light effect fails.
      }
    }
  }

  build() {
    if (this.editing) {
      Row() {}.width('100%').height(50).borderRadius(999).clip(true)
        .backgroundColor(this.blurAllowed ? $r('app.color.gameplay_overlay_tint') : $r('app.color.raised'))
        .backdropBlur(this.blurAllowed ? ANSWER_EDIT_BLUR_RADIUS : 0)
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    } else {
      Row() {}.width('100%').height(50).borderRadius(25).clip(true)
        .backgroundColor(this.blurAllowed ? Color.Transparent : $r('app.color.raised'))
        .backgroundEffect(this.blurAllowed ? {
          radius: ANSWER_IDLE_BLUR_RADIUS, color: $r('app.color.glass_floating'),
          policy: BlurStyleActivePolicy.FOLLOWS_WINDOW_ACTIVE_STATE, inactiveColor: $r('app.color.raised')
        } : undefined)
        .attributeModifier(this.idleLight)
        .shadow({ radius: 10, offsetY: 3, color: $r('app.color.shadow') })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    }
  }
}

/** Single-line answer control. The gameplay owner supplies the draft or settled answer. */
@ComponentV2
export struct StarwardAnswerInput {
  @Require @Param value: string;
  @Require @Param placeholder: string;
  @Require @Param editable: boolean;
  @Param reducedMotion: boolean = true;
  @Event changed: (value: string) => void = () => {};
  @Event focusChanged: (focused: boolean) => void = () => {};
  @Local private focused: boolean = false;
  @Local private editing: boolean = false;

  aboutToDisappear(): void {
    this.updateFocus(false);
  }

  private updateFocus(focused: boolean): void {
    if (this.focused !== focused) {
      this.focused = focused;
      this.focusChanged(focused);
    }
  }

  private showsFocus(): boolean {
    return this.editable && this.focused;
  }

  private answerLineColor(): ResourceColor {
    if (this.showsFocus()) {
      return $r('app.color.accent');
    }
    return this.editable ? $r('app.color.border_strong') : $r('app.color.answer_readonly_line');
  }

  build() {
    Stack() {
      StarwardAnswerCapsuleMaterial({ editing: this.editable && this.editing })
      TextInput({ text: this.value, placeholder: this.placeholder })
        .id('gameplay-answer-input')
        .accessibilityText('答案')
        .type(InputType.Normal)
        .enableAutoFill(false)
        .cancelButton({ style: CancelButtonStyle.INVISIBLE })
        .showUnderline(false)
        .maxLength(4000)
        .width('100%').height(50)
        .padding({ left: 20, right: 20 })
        .fontSize(15)
        .fontWeight(FontWeight.Normal)
        .fontColor(this.editable ? $r('app.color.strong') : $r('app.color.muted'))
        .placeholderFont({ size: 15, weight: FontWeight.Normal })
        .placeholderColor($r('app.color.muted'))
        .caretColor($r('app.color.accent'))
        .backgroundColor(Color.Transparent)
        .border({ width: 1, radius: 999, color: this.answerLineColor() })
        .outline({ width: this.showsFocus() ? 3 : 0, radius: 999, color: $r('app.color.accent_soft') })
        .animation({ duration: this.reducedMotion ? 0 : 320, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) })
        .enabled(this.editable)
        .onFocus(() => this.updateFocus(true))
        .onBlur(() => {
          this.editing = false;
          this.updateFocus(false);
        })
        .onEditChange((editing: boolean) => { this.editing = editing; })
        .onChange((value: string) => {
          if (this.editable && value !== this.value) {
            this.changed(value);
          }
        })
    }.width('100%').height(50)
  }
}

/** The same native submit control serves both input formats. */
@ComponentV2
export struct StarwardAnswerSubmit {
  @Param actionEnabled: boolean = false;
  @Param submitting: boolean = false;
  @Param reducedMotion: boolean = true;
  @Event action: () => void = () => {};

  build() {
    Button({ type: ButtonType.Circle, stateEffect: !this.reducedMotion }) {
      if (this.submitting) {
        LoadingProgress().width(20).height(20).color($r('app.color.on_accent'))
          .enableLoading(!this.reducedMotion).accessibilityLevel('no')
      } else {
        Image($r('app.media.icon_arrow_right_bold')).width(22).height(22).objectFit(ImageFit.Contain)
          .fillColor($r('app.color.on_accent')).accessibilityLevel('no')
      }
    }.id('gameplay-submit').width(50).height(50).padding(0).flexShrink(0)
      .linearGradient({ angle: 180,
        colors: [[$r('app.color.accent_strong'), 0], [$r('app.color.accent'), 1]] })
      .backgroundColor($r('app.color.accent'))
      .shadow({ radius: this.actionEnabled && !this.submitting ? 16 : 0, offsetY: 6,
        color: $r('app.color.glow_accent_strong') })
      .enabled(this.actionEnabled && !this.submitting)
      .accessibilityText(this.submitting ? '正在提交答案' : '提交答案')
      .onClick(() => this.action())
  }
}
