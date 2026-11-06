import { curves } from '@kit.ArkUI';

/** Single-line answer control. The gameplay owner supplies the draft or settled answer. */
@ComponentV2
export struct StarwardAnswerInput {
  @Require @Param value: string;
  @Require @Param placeholder: string;
  @Require @Param editable: boolean;
  @Param reducedMotion: boolean = true;
  @Event changed: (value: string) => void = () => {};
  @Local private focused: boolean = false;

  private showsFocus(): boolean {
    return this.editable && this.focused;
  }

  private answerLineColor(): ResourceColor {
    if (this.showsFocus()) {
      return $r('app.color.accent');
    }
    return this.editable ? $r('app.color.accent_border') : $r('app.color.answer_readonly_line');
  }

  build() {
    TextInput({ text: this.value, placeholder: this.placeholder })
      .id('gameplay-answer-input')
      .accessibilityText('答案')
      .type(InputType.Normal)
      .enableAutoFill(false)
      .cancelButton({ style: CancelButtonStyle.INVISIBLE })
      .showUnderline(false)
      .maxLength(4000)
      .width('100%')
      .constraintSize({ minHeight: 58 })
      .padding({ top: 0, bottom: 0, left: 2, right: 2 })
      .fontSize(18)
      .fontWeight(FontWeight.Normal)
      .fontColor($r('app.color.strong'))
      .placeholderFont({ size: 18, weight: FontWeight.Normal })
      .placeholderColor('#757575')
      .caretColor($r('app.color.accent'))
      .backgroundColor(Color.Transparent)
      .border({ width: { top: 0, right: 0, bottom: 1, left: 0 }, radius: 0, color: this.answerLineColor() })
      .outline({ width: this.showsFocus() ? 2 : 0, radius: 0, color: $r('app.color.accent') })
      .translate({ y: this.showsFocus() ? -1 : 0 })
      .animation({ duration: this.reducedMotion ? 0 : 320, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) })
      // TextInput already dims its disabled text. Fade only the custom bottom border.
      .enabled(this.editable)
      .onFocus(() => { this.focused = true; })
      .onBlur(() => { this.focused = false; })
      .onChange((value: string) => {
        if (this.editable && value !== this.value) {
          this.changed(value);
        }
      })
  }
}
