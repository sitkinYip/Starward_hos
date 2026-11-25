import { AvatarImage } from '../business/models';
import { InlineError } from '../ui/ErrorMessages';
import { LabeledInput } from '../ui/LabeledInput';
import { StarwardPlayerAvatar } from '../ui/StarwardPlayerAvatar';
import { SliceViewModel } from './SliceViewModel';

@ComponentV2
export struct PassportProfileEditor {
  @Require @Param vm: SliceViewModel;
  @Param pickingAvatar: boolean = false;
  @Event chooseAvatar: () => void = () => {};

  private editorDisabled(): boolean {
    return this.vm.profileBusy || this.vm.securityBusy || this.vm.securityUnconfirmed;
  }

  build() {
    Column({ space: 16 }) {
      Row({ space: 16 }) {
        StarwardPlayerAvatar({ name: this.vm.profileName || this.vm.player.displayName,
          avatar: this.vm.profilePreview || this.vm.avatarImage, avatarSize: 64,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
        Column({ space: 6 }) {
          Button(this.pickingAvatar ? '正在准备照片…' : '更换头像', { type: ButtonType.Capsule })
            .id('profile-avatar-pick').constraintSize({ minHeight: 44 }).fontSize(14)
            .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .enabled(!this.editorDisabled() && !this.pickingAvatar).onClick(() => this.chooseAvatar())
          Text('JPG / PNG / WebP · 原图最大 50 MB，裁剪后自动压缩')
            .fontSize(12).lineHeight('18fp').fontColor($r('app.color.muted'))
          if (this.vm.profileUpload !== null) {
            Text('已选择：avatar.jpg').id('profile-avatar-pending').fontSize(12).fontColor($r('app.color.muted'))
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
      if (this.vm.avatarError.length > 0) {
        InlineError({ message: this.vm.avatarError, fieldId: 'avatar-error' })
        Button('重新尝试', { type: ButtonType.Capsule }).id('avatar-retry').height(44)
          .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
          .enabled(!this.vm.avatarBusy).onClick(() => this.vm.loadAvatar(true))
      }
      LabeledInput({ label: '显示昵称', fieldId: 'profile-name', value: this.vm.profileName, fieldLimit: 40,
        disabled: this.editorDisabled(), changed: (value: string) => this.vm.editProfileName(value) })
      Row({ space: 12 }) {
        Text('登录账号').fontSize(13).fontColor($r('app.color.muted'))
        Text(this.vm.player.account).id('profile-account').layoutWeight(1).fontSize(14)
          .fontColor($r('app.color.text')).fontWeight(FontWeight.Medium).fontFeature("'tnum' 1")
          .textAlign(TextAlign.End).wordBreak(WordBreak.BREAK_WORD)
      }.width('100%').padding(12).backgroundColor($r('app.color.accent_faint')).borderRadius(10)
      InlineError({ message: this.vm.profileError, fieldId: 'profile-error' })
      if (this.vm.profileSaved) {
        Text('资料已保存。新的名片，新的出发。').id('profile-saved').fontSize(13).lineHeight('22fp')
          .fontColor($r('app.color.accent_text'))
      }
      Button(this.vm.profileBusy ? '正在保存…' : '保存资料', { type: ButtonType.Capsule })
        .id('profile-save').width('100%').height(52).fontSize(16).fontWeight(600)
        .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
        .enabled(!this.editorDisabled() && !this.pickingAvatar).onClick(() => this.vm.saveProfile())
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}

@ComponentV2
export struct PassportPasswordEditor {
  @Require @Param vm: SliceViewModel;
  @Event logout: () => void = () => {};
  @Local private oldPassword: string = '';
  @Local private newPassword: string = '';
  @Local private confirmation: string = '';

  @Monitor('vm.securitySuccessRevision')
  private clearPasswords(): void {
    this.oldPassword = '';
    this.newPassword = '';
    this.confirmation = '';
  }

  aboutToDisappear(): void { this.clearPasswords(); }

  private editorDisabled(): boolean {
    return this.vm.securityBusy || this.vm.profileBusy || this.vm.securityUnconfirmed;
  }

  build() {
    Column({ space: 16 }) {
      LabeledInput({ label: '当前密码', fieldId: 'security-old-password',
        inputType: InputType.Password, value: this.oldPassword, disabled: this.editorDisabled(),
        changed: (value: string) => { this.oldPassword = value; this.vm.clearSecurityFeedback(); } })
      LabeledInput({ label: '新密码', fieldId: 'security-new-password',
        inputType: InputType.Password, value: this.newPassword, fieldLimit: 71, disabled: this.editorDisabled(),
        changed: (value: string) => { this.newPassword = value; this.vm.clearSecurityFeedback(); } })
      LabeledInput({ label: '确认新密码', fieldId: 'security-confirm-password',
        inputType: InputType.Password, value: this.confirmation, fieldLimit: 71, disabled: this.editorDisabled(),
        changed: (value: string) => { this.confirmation = value; this.vm.clearSecurityFeedback(); } })
      InlineError({ message: this.vm.securityError, fieldId: 'security-error' })
      if (this.vm.securitySaved) {
        Text('密码已更新。你的冒险记录，安心留在这里。').id('security-saved')
          .fontSize(13).lineHeight('22fp').fontColor($r('app.color.accent_text'))
      }
      Button(this.vm.securityBusy ? '正在保存…' : '保存新密码', { type: ButtonType.Capsule })
        .id('security-save').width('100%').height(52).fontSize(16).fontWeight(600)
        .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
        .enabled(!this.editorDisabled())
        .onClick(() => this.vm.changeAccountPassword(this.oldPassword, this.newPassword, this.confirmation))
      if (this.vm.securityUnconfirmed) {
        Button('退出登录', { type: ButtonType.Normal }).id('security-unconfirmed-logout').width('100%').height(44)
          .fontColor($r('app.color.text')).backgroundColor($r('app.color.surface')).onClick(() => this.logout())
      }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
