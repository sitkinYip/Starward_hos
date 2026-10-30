import { SliceViewModel } from './SliceViewModel';
import { LabeledInput } from '../ui/LabeledInput';
import { InlineError } from '../ui/ErrorMessages';
import { StarwardPlayerAvatar } from '../ui/StarwardPlayerAvatar';
import { StarwardPassport } from '../ui/StarwardPassport';
import { AvatarImage } from '../business/models';

/** Phone profile content; the root owns routes, the system picker and crop Sheet. */
@ComponentV2
export struct ProfilePage {
  @Require @Param vm: SliceViewModel;
  @Param active: boolean = false;
  @Param displayFont: string = 'serif';
  @Param bottomClearance: number = 112;
  @Param pickingAvatar: boolean = false;
  @Event chooseAvatar: () => void = () => {};
  @Event logout: () => void = () => {};
  @Local section: number = 0;
  @Local oldPassword: string = '';
  @Local newPassword: string = '';
  @Local confirmation: string = '';

  @Monitor('vm.securitySuccessRevision')
  passwordSaved(): void {
    this.clearPasswords();
  }

  @Monitor('active')
  activityChanged(): void {
    if (!this.active) {
      this.clearPasswords();
    }
  }

  @Monitor('section')
  sectionChanged(): void {
    if (this.section !== 1) {
      this.clearPasswords();
    }
  }

  aboutToDisappear(): void {
    this.clearPasswords();
  }

  private clearPasswords(): void {
    this.oldPassword = '';
    this.newPassword = '';
    this.confirmation = '';
  }

  @Builder
  passport() {
    Column() {
      StarwardPassport({ player: this.vm.player, avatar: this.vm.avatarImage, displayFont: this.displayFont,
        decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
    }.id('profile-passport').width('100%').padding(20)
      .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border'), radius: 18 })
  }

  @Builder
  identity() {
    Column({ space: 20 }) {
      Row({ space: 16 }) {
        StarwardPlayerAvatar({ name: this.vm.profileName || this.vm.player.displayName,
          avatar: this.vm.profilePreview || this.vm.avatarImage, avatarSize: 72,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
        Column({ space: 8 }) {
          Button(this.pickingAvatar ? '正在准备照片…' : '更换头像', { type: ButtonType.Normal })
            .id('profile-avatar-pick').constraintSize({ minHeight: 44 }).fontSize(14)
            .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .enabled(!this.vm.profileBusy && !this.vm.securityBusy && !this.vm.securityUnconfirmed && !this.pickingAvatar)
            .onClick(() => this.chooseAvatar())
          Text('JPG / PNG / WebP · 原图最大 50 MB，裁剪后自动压缩')
            .fontSize(11).lineHeight('18fp').fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
      if (this.vm.profileUpload !== null) {
        Text('已选择：avatar.jpg').id('profile-avatar-pending').fontSize(12).fontColor($r('app.color.muted'))
      }
      if (this.vm.avatarError.length > 0) {
        InlineError({ message: this.vm.avatarError, fieldId: 'avatar-error' })
        Button('重新尝试', { type: ButtonType.Normal }).id('avatar-retry').height(44)
          .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
          .enabled(!this.vm.avatarBusy).onClick(() => this.vm.loadAvatar(true))
      }
      LabeledInput({ label: '显示昵称', fieldId: 'profile-name', value: this.vm.profileName, fieldLimit: 40,
        disabled: this.vm.profileBusy || this.vm.securityBusy || this.vm.securityUnconfirmed,
        changed: (value: string) => this.vm.editProfileName(value) })
      Text('你的名字，会和解开的谜题一起被记住。').fontSize(12).lineHeight('20fp')
        .fontColor($r('app.color.muted')).margin({ top: -12 })
      Column({ space: 6 }) {
        Text('登录账号').fontSize(12).fontColor($r('app.color.muted'))
        Text(this.vm.player.account).id('profile-account').fontSize(14).fontColor($r('app.color.text'))
        Text('账号由游戏管理员创建，不可修改').fontSize(11).fontColor($r('app.color.subtle'))
      }.width('100%').alignItems(HorizontalAlign.Start)
      InlineError({ message: this.vm.profileError, fieldId: 'profile-error' })
      if (this.vm.profileSaved) {
        Text('资料已保存。新的名片，新的出发。').id('profile-saved').fontSize(13).lineHeight('22fp')
          .fontColor($r('app.color.accent_text'))
      }
      Button(this.vm.profileBusy ? '正在保存…' : '保存资料', { type: ButtonType.Normal })
        .id('profile-save').width('100%').height(52).borderRadius(10).fontSize(16).fontWeight(600)
        .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
        .enabled(!this.vm.profileBusy && !this.vm.securityBusy && !this.vm.securityUnconfirmed && !this.pickingAvatar)
        .onClick(() => this.vm.saveProfile())
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 24, bottom: 16 })
  }

  @Builder
  security() {
    Column({ space: 20 }) {
      Text('给你的故事，上把锁。').fontFamily(this.displayFont).fontSize(22).fontColor($r('app.color.strong'))
      Text('设置只有你知道的通行密语。使用 10—71 个字符。')
        .fontSize(13).lineHeight('22fp').fontColor($r('app.color.muted'))
      LabeledInput({ label: '当前密码', fieldId: 'security-old-password', secret: true, value: this.oldPassword,
        disabled: this.vm.securityBusy || this.vm.profileBusy || this.vm.securityUnconfirmed,
        changed: (value: string) => { this.oldPassword = value; this.vm.clearSecurityFeedback(); } })
      LabeledInput({ label: '新密码', fieldId: 'security-new-password', secret: true, value: this.newPassword,
        fieldLimit: 71, disabled: this.vm.securityBusy || this.vm.profileBusy || this.vm.securityUnconfirmed,
        changed: (value: string) => { this.newPassword = value; this.vm.clearSecurityFeedback(); } })
      LabeledInput({ label: '确认新密码', fieldId: 'security-confirm-password', secret: true, value: this.confirmation,
        fieldLimit: 71, disabled: this.vm.securityBusy || this.vm.profileBusy || this.vm.securityUnconfirmed,
        changed: (value: string) => { this.confirmation = value; this.vm.clearSecurityFeedback(); } })
      InlineError({ message: this.vm.securityError, fieldId: 'security-error' })
      if (this.vm.securitySaved) {
        Text('密码已更新。你的冒险记录，安心留在这里。').id('security-saved')
          .fontSize(13).lineHeight('22fp').fontColor($r('app.color.accent_text'))
      }
      Button(this.vm.securityBusy ? '正在保存…' : '保存新密码', { type: ButtonType.Normal })
        .id('security-save').width('100%').height(52).borderRadius(10).fontSize(16).fontWeight(600)
        .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
        .enabled(!this.vm.securityBusy && !this.vm.profileBusy && !this.vm.securityUnconfirmed)
        .onClick(() => this.vm.changeAccountPassword(this.oldPassword, this.newPassword, this.confirmation))
      if (this.vm.securityUnconfirmed) {
        Button('退出登录', { type: ButtonType.Normal }).id('security-unconfirmed-logout').width('100%').height(44)
          .fontColor($r('app.color.text')).backgroundColor($r('app.color.surface')).onClick(() => this.logout())
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 24, bottom: 16 })
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        Column({ space: 8 }) {
          Text('每一个名字，都有自己的故事').fontSize(12).fontColor($r('app.color.accent_text'))
          Text('冒险者护照').fontFamily(this.displayFont).fontSize(28).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.strong'))
          Text('让旅途记住你的模样。').fontSize(14).fontColor($r('app.color.muted'))
        }.width('100%').alignItems(HorizontalAlign.Start)
        this.passport()
        if (this.vm.securityUnconfirmed) {
          InlineError({ message: this.vm.securityError, fieldId: 'profile-security-unconfirmed' })
          Button('退出登录', { type: ButtonType.Normal }).id('profile-unconfirmed-logout').width('100%').height(44)
            .fontColor($r('app.color.text')).backgroundColor($r('app.color.surface')).onClick(() => this.logout())
        }
        Tabs({ barPosition: BarPosition.Start, index: this.section!! }) {
          TabContent() {
            this.identity()
          }.tabBar(SubTabBarStyle.of('我的名片').id('profile-identity-tab')
            .indicator({ color: $r('app.color.accent'), height: 2 })
            .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'), font: { size: 15 } }))
          TabContent() {
            this.security()
          }.tabBar(SubTabBarStyle.of('账号安全').id('profile-security-tab')
            .indicator({ color: $r('app.color.accent'), height: 2 })
            .labelStyle({ selectedColor: $r('app.color.accent_text'), unselectedColor: $r('app.color.muted'), font: { size: 15 } }))
        }.width('100%').height('auto').barMode(BarMode.Fixed).barHeight(53).scrollable(false)
          .accessibilityText('护照设置').onChange((index: number) => {
            this.section = index;
          })
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ left: 20, right: 20, top: 16, bottom: this.bottomClearance })
    }.id('profile-scroll').width('100%').height('100%').scrollBar(BarState.Off)
  }
}
