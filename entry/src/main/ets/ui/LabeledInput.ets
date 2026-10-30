@ComponentV2
export struct LabeledInput {
  @Param label: string = '';
  @Param value: string = '';
  @Param placeholder: string = '';
  @Param fieldId: string = '';
  @Param secret: boolean = false;
  @Param disabled: boolean = false;
  @Param fieldLimit: number = 1000;
  @Event changed: (value: string) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Text(this.label).fontSize(13).fontWeight(FontWeight.Medium).lineHeight('19fp')
        .fontColor($r('app.color.text')).width('100%')
      TextInput({ text: this.value, placeholder: this.placeholder })
        .id(this.fieldId)
        .accessibilityText(this.label)
        .type(this.secret ? InputType.Password : InputType.Normal)
        .showPasswordIcon(this.secret)
        .enableAutoFill(false)
        .enabled(!this.disabled)
        .maxLength(this.fieldLimit)
        .height(52)
        .fontSize(16)
        .fontColor($r('app.color.text'))
        .placeholderColor($r('app.color.subtle'))
        .backgroundColor($r('app.color.input'))
        .padding({ left: 12, right: 12 })
        .border({ width: 1, color: $r('app.color.border_strong'), radius: 10 })
        .onChange((value: string) => {
          if (value !== this.value) {
            this.changed(value);
          }
        })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
