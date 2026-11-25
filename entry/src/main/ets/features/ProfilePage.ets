import { uiMaterial, window } from '@kit.ArkUI';
import { AvatarImage } from '../business/models';
import { InlineError } from '../ui/ErrorMessages';
import { StarwardMaterial } from '../ui/StarwardMaterial';
import { StarwardPageHeading } from '../ui/StarwardPageHeading';
import { StarwardPassport } from '../ui/StarwardPassport';
import { PassportSummary, summarizePassport } from './PassportSummary';
import { PassportPasswordEditor, PassportProfileEditor } from './ProfileEditors';
import { SliceViewModel } from './SliceViewModel';

type PassportEditor = 'profile' | 'password' | 'theme';

@ComponentV2
struct PassportSettingRow {
  @Require @Param nodeId: string;
  @Require @Param label: string;
  @Param detail: string = '';
  @Param destructive: boolean = false;
  @Param actionEnabled: boolean = true;
  @Event action: () => void = () => {};

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(this.label).layoutWeight(1).fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor(this.destructive ? $r('app.color.danger_strong') : $r('app.color.strong'))
          .wordBreak(WordBreak.BREAK_WORD)
        if (this.detail.length > 0) {
          Text(this.detail).fontSize(14).fontColor($r('app.color.muted'))
        }
        if (!this.destructive) {
          SymbolGlyph($r('sys.symbol.chevron_right')).fontSize('14vp').fontColor([$r('app.color.muted')])
            .accessibilityLevel('no')
        }
      }.width('100%').padding({ left: 18, right: 18, top: 12, bottom: 12 })
    }.id(this.nodeId).width('100%').padding(0).constraintSize({ minHeight: 56 })
      .backgroundColor(Color.Transparent).enabled(this.actionEnabled)
      .accessibilityText(this.detail.length > 0 ? this.label + '，' + this.detail : this.label)
      .onClick(() => this.action())
  }
}

/** Passport editors retain their own native sheet anchor. The root owns the picker, crop, and routes. */
@ComponentV2
export struct ProfilePage {
  @Require @Param vm: SliceViewModel;
  @Param active: boolean = false;
  @Param motionEnabled: boolean = false;
  @Param bottomClearance: number = 112;
  @Param pickingAvatar: boolean = false;
  @Param showPrivacyPolicy: boolean = false;
  @Param showNotifications: boolean = false;
  @Param themeLabel: string = '跟随系统';
  @Param themeError: string = '';
  @Param environmentLabel: string = '';
  @BuilderParam appearanceControls: () => void;
  @Event chooseAvatar: () => void = () => {};
  @Event openSettings: () => void = () => {};
  @Event openNotifications: () => void = () => {};
  @Event openPrivacyPolicy: () => void = () => {};
  @Event logout: () => void = () => {};
  @Env(ReadonlyEnvKey.WINDOW_SIZE) private windowSize: window.SizeInVP;
  @Local private editor: PassportEditor | null = null;
  @Local private editorVisible: boolean = false;
  private editorOwner: string = '';
  private editorRevision: number = 0;
  private editorMaterial: uiMaterial.ImmersiveMaterial | undefined =
    StarwardMaterial.create(uiMaterial.ImmersiveStyle.THICK);

  @Computed
  get summary(): PassportSummary {
    return summarizePassport(this.vm.lobbyHasList ? this.vm.items : null,
      this.vm.rewards.loaded ? this.vm.rewards.entries.length : null);
  }

  @Monitor('active', 'vm.player')
  private ownerChanged(): void {
    if (this.editor !== null && (!this.active || this.editorOwner !== this.vm.player.id)) {
      this.resetEditor();
    }
  }

  aboutToDisappear(): void { this.resetEditor(); }

  private resetEditor(): void {
    this.editorRevision++;
    this.editorVisible = false;
    this.editor = null;
    this.editorOwner = '';
  }

  private openEditor(editor: PassportEditor): void {
    if (this.editor !== null || !this.active || this.vm.gate !== 'home' || this.vm.player.id.length === 0 ||
      (editor !== 'theme' && this.vm.securityUnconfirmed)) { return; }
    this.editorRevision++;
    this.editorOwner = this.vm.player.id;
    this.editor = editor;
    this.editorVisible = true;
  }

  private editorTitle(): string {
    if (this.editor === 'profile') { return '修改资料'; }
    return this.editor === 'password' ? '修改密码' : '外观';
  }

  private editorOptions(): SheetOptions {
    const revision: number = this.editorRevision;
    return {
      height: SheetSize.FIT_CONTENT, preferType: SheetType.BOTTOM, dragBar: true, showClose: true,
      title: { title: this.editorTitle() }, keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
      backgroundColor: this.editorMaterial ? Color.Transparent : $r('app.color.raised'),
      systemMaterial: this.editorMaterial,
      maskColor: $r('app.color.modal_mask'),
      onWillDismiss: (action: DismissSheetAction) => {
        if (revision !== this.editorRevision) { return; }
        this.editorVisible = false;
        action.dismiss();
      },
      onDisappear: () => { if (revision === this.editorRevision) { this.resetEditor(); } }
    };
  }

  @Builder
  private editorContent() {
    Scroll() {
      if (this.editor === 'profile') {
        PassportProfileEditor({ vm: this.vm, pickingAvatar: this.pickingAvatar,
          chooseAvatar: () => this.chooseAvatar() })
      } else if (this.editor === 'password') {
        PassportPasswordEditor({ vm: this.vm, logout: () => this.logout() })
      } else if (this.editor === 'theme') {
        Column({ space: 8 }) {
          this.appearanceControls()
          InlineError({ message: this.themeError, fieldId: 'passport-theme-error' })
        }.width('100%')
      }
    }.id(this.editor === 'profile' ? 'passport-profile-sheet' :
      this.editor === 'password' ? 'passport-password-sheet' : 'passport-appearance-sheet')
      .width('100%').constraintSize({ maxHeight: Math.max(140, this.windowSize.height * 0.8) })
      .padding({ left: 20, right: 20, top: 12, bottom: 24 }).scrollBar(BarState.Auto)
  }

  @Builder
  private settingDivider() {
    Divider().color($r('app.color.border')).strokeWidth(1)
  }

  @Builder
  private settingRows() {
    Column() {
      PassportSettingRow({ nodeId: 'passport-edit-profile', label: '修改资料',
        actionEnabled: !this.vm.securityUnconfirmed, action: () => this.openEditor('profile') })
      this.settingDivider()
      PassportSettingRow({ nodeId: 'passport-edit-password', label: '修改密码',
        actionEnabled: !this.vm.securityUnconfirmed, action: () => this.openEditor('password') })
      this.settingDivider()
      PassportSettingRow({ nodeId: 'passport-appearance', label: '外观', detail: this.themeLabel,
        action: () => this.openEditor('theme') })
      this.settingDivider()
      PassportSettingRow({ nodeId: 'passport-settings', label: '设置', action: () => this.openSettings() })
      if (this.showNotifications) {
        this.settingDivider()
        PassportSettingRow({ nodeId: 'passport-notifications', label: '旅途通知与订阅设置',
          action: () => this.openNotifications() })
      }
      this.settingDivider()
      PassportSettingRow({ nodeId: this.vm.securityUnconfirmed ? 'profile-unconfirmed-logout' : 'logout',
        label: '退出登录', destructive: true, action: () => this.logout() })
    }.id('passport-settings-group').width('100%')
      .linearGradient({ angle: 180, colors: [[$r('app.color.glass_card_top'), 0], [$r('app.color.glass_card_bottom'), 1]] })
      .border({ width: 1, color: $r('app.color.border_strong'), radius: 24 }).clip(true)
      .shadow({ radius: 14, offsetY: 6, color: $r('app.color.shadow') })
  }

  @Builder
  private secondaryRoutes() {
    Column({ space: 4 }) {
      if (this.showPrivacyPolicy) {
        Button('隐私政策', { type: ButtonType.Normal }).id('account-privacy-policy')
          .constraintSize({ minHeight: 44 }).fontSize(13)
          .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent)
          .onClick(() => this.openPrivacyPolicy())
      }
      if (this.environmentLabel.length > 0) {
        Text(this.environmentLabel).fontSize(11).fontColor($r('app.color.subtle')).textAlign(TextAlign.Center)
      }
    }.width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        StarwardPageHeading({ title: '护照', nodeId: 'passport-heading' }).margin({ bottom: 4 })
        StarwardPassport({ player: this.vm.player, avatar: this.vm.avatarImage,
          active: this.active, reducedMotion: !this.motionEnabled,
          solved: this.summary.solved, sessions: this.summary.sessions, rewards: this.summary.rewards,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
        if (this.vm.securityUnconfirmed) {
          InlineError({ message: this.vm.securityError, fieldId: 'profile-security-unconfirmed' })
        }
        this.settingRows()
        this.secondaryRoutes()
      }.width('100%').alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, top: 16, bottom: this.bottomClearance })
    }.id('profile-scroll').width('100%').height('100%').scrollBar(BarState.Off)
      .bindSheet(this.editorVisible, this.editorContent(), this.editorOptions())
  }
}
