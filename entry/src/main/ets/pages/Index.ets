import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { window, KeyboardAvoidMode as PageKeyboardAvoidMode } from '@kit.ArkUI';
import { SliceViewModel } from '../features/SliceViewModel';
import { createSliceViewModel } from '../features/createSliceViewModel';
import { AssignmentSummary, AvatarImage, AvatarUpload, GameFailure } from '../business/models';
import { ProfilePage } from '../features/ProfilePage';
import { AvatarEditor, AvatarSelection } from '../platform/AvatarEditor';
import { assignmentKind, assignmentState } from '../business/assignmentState';
import { AppLifecycle } from '../platform/AppLifecycle';
import { LaunchRoutes } from '../platform/LaunchRoutes';
import { LabeledInput } from '../ui/LabeledInput';
import { ErrorNotice, InlineError } from '../ui/ErrorMessages';
import { PrimaryAction } from '../ui/PrimaryAction';
import { DetailFact } from '../ui/DetailFact';
import { StarwardAtlas } from '../ui/StarwardAtlas';
import { StarwardMaterial, StarwardTitleSurface } from '../ui/StarwardMaterial';
import { StarwardBottomTabs, StarwardJourneyTabs, StarwardSyncNote } from '../ui/StarwardTabs';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardAccountSheet } from '../ui/StarwardAccountSheet';
import { StarwardSidePanel } from '../ui/StarwardSidePanel';
import { StarwardFeedback } from '../ui/StarwardFeedback';
import { StarwardMotion } from '../ui/StarwardMotion';
import { StarwardPlayerAvatar } from '../ui/StarwardPlayerAvatar';
import { StarwardAvatarCrop } from '../ui/StarwardAvatarCrop';
import { StarwardPassport } from '../ui/StarwardPassport';
import { StarwardKeyboard } from '../ui/StarwardKeyboard';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@ComponentV2
struct Index {
  @Env(WritableEnvKey.FONT_SCALE) fontScale: number;
  @Env(ReadonlyEnvKey.WINDOW_AVOID_AREA) avoidArea: window.UIEnvWindowAvoidAreaInfoVP;
  @Local vm: SliceViewModel = createSliceViewModel();
  @Local account: string = '';
  @Local password: string = '';
  @Local oldPassword: string = '';
  @Local newPassword: string = '';
  @Local confirmation: string = '';
  @Local history: boolean = false;
  @Local selectedId: string = '';
  @Local showHelp: boolean = false;
  @Local showAccount: boolean = false;
  @Local accountAnchorWindowX: number = -1;
  @Local mainIndex: number = 0;
  @Local returnAssignmentId: string = '';
  @Local avatarSelection: AvatarSelection | null = null;
  @Local showAvatarCrop: boolean = false;
  @Local avatarPicking: boolean = false;
  @Local theme: number = 0;
  @Local themeError: string = '';
  @Local displayFont: string = 'serif';
  @Local authAtlasWidth: number = 350;
  @Local authAtlasHeight: number = 204.6;
  @Local lobbyAtlasWidth: number = 350;
  @Local detailAtlasWidth: number = 366;
  private motion: StarwardMotion = new StarwardMotion();
  private avatarEditor: AvatarEditor = new AvatarEditor();
  private avatarPickRevision: number = 0;
  private paths: NavPathStack = new NavPathStack();
  private timer: number = -1;
  private lifecycle: (foreground: boolean) => void = (foreground: boolean) => {
    if (foreground) {
      this.startClock();
      if (this.vm.gate === 'home') {
        this.vm.refresh();
        if (this.paths.size() > 0 && this.selectedId.length > 0) {
          this.vm.openAssignment(this.selectedId);
        }
      }
    } else {
      this.stopClock();
    }
  };

  private routeListener: (id: string) => void = (id: string) => {
    if (id.length > 0 && this.vm.gate === 'home') {
      this.dispatchPendingRoute();
    }
  };

  private dispatchPendingRoute(): void {
    if (this.vm.gate !== 'home') {
      return;
    }
    const id: string = LaunchRoutes.take();
    if (id.length === 0) {
      return;
    }
    this.paths.clear();
    this.openAssignment(id);
  }

  aboutToAppear(): void {
    try {
      this.getUIContext().getFont().registerFont({
        familyName: 'StarwardSerif', familySrc: $rawfile('fonts/NotoSerifSC.ttf')
      });
      this.displayFont = 'StarwardSerif';
    } catch (error) {
      this.displayFont = 'serif';
    }
    this.getUIContext().setKeyboardAvoidMode(PageKeyboardAvoidMode.RESIZE);
    this.motion.start();
    AppLifecycle.subscribe(this.lifecycle);
    LaunchRoutes.subscribe(this.routeListener);
    this.startClock();
  }

  aboutToDisappear(): void {
    this.showAccount = false;
    this.motion.stop();
    AppLifecycle.unsubscribe(this.lifecycle);
    LaunchRoutes.unsubscribe(this.routeListener);
    this.stopClock();
    this.clearPasswords();
    this.cancelAvatarCrop();
  }

  @Monitor('vm.gate')
  gateChanged(): void {
    this.clearPasswords();
    if (this.vm.gate !== 'home') {
      this.paths.clear();
      this.showAccount = false;
      this.mainIndex = 0;
      this.returnAssignmentId = '';
      this.cancelAvatarCrop();
    } else {
      this.dispatchPendingRoute();
    }
  }

  @Monitor('showAvatarCrop')
  cropVisibilityChanged(): void {
    if (!this.showAvatarCrop) {
      this.avatarSelection?.dispose();
      this.avatarSelection = null;
      this.avatarEditor.dispose();
    }
  }

  onBackPress(): boolean {
    const keyboardHeight: number = Math.max(this.avoidArea.keyboard.bottomRect.height,
      this.avoidArea.keyboard.topRect.height, this.avoidArea.keyboard.leftRect.height, this.avoidArea.keyboard.rightRect.height);
    hilog.info(0x0000, 'StarwardBack', 'keyboard=%{public}s height=%{public}d main=%{public}d depth=%{public}d',
      this.avoidArea.keyboard.visible.toString(), Math.round(keyboardHeight), this.mainIndex, this.paths.size());
    if (this.avoidArea.keyboard.visible && keyboardHeight > 0) {
      StarwardKeyboard.dismiss(this.getUIContext());
      return true;
    }
    if (this.showAvatarCrop) {
      this.cancelAvatarCrop();
      return true;
    }
    if (this.showAccount) {
      this.showAccount = false;
      return true;
    }
    if (this.vm.gate === 'home' && this.paths.size() === 0 && this.mainIndex !== 0) {
      this.goMain(0);
      return true;
    }
    return false;
  }

  private cancelAvatarCrop(): void {
    this.avatarPickRevision++;
    this.avatarPicking = false;
    this.showAvatarCrop = false;
    this.avatarSelection?.dispose();
    this.avatarSelection = null;
    this.avatarEditor.dispose();
  }

  private async pickAvatar(): Promise<void> {
    if (this.vm.gate !== 'home' || this.vm.profileBusy || this.vm.securityBusy || this.avatarPicking ||
      this.vm.securityUnconfirmed) {
      return;
    }
    const revision: number = ++this.avatarPickRevision;
    const playerId: string = this.vm.player.id;
    this.avatarPicking = true;
    try {
      const selected: AvatarSelection | null = await this.avatarEditor.pick();
      if (revision !== this.avatarPickRevision || this.vm.gate !== 'home' || this.vm.player.id !== playerId) {
        selected?.dispose();
        return;
      }
      if (selected !== null) {
        this.avatarSelection = selected;
        this.showAvatarCrop = true;
      }
    } catch (error) {
      if (revision === this.avatarPickRevision && this.vm.gate === 'home' && this.vm.player.id === playerId) {
        this.vm.reportProfileError(error instanceof GameFailure ? error.message :
          '图片处理失败，请重新选择 JPG、PNG 或 WebP 图片。');
      }
    } finally {
      if (revision === this.avatarPickRevision) {
        this.avatarPicking = false;
      }
    }
  }

  private goMain(index: number): void {
    if (this.vm.gate !== 'home') {
      return;
    }
    if (index === 1 || index === 2) {
      StarwardFeedback.toast(this.getUIContext(), index === 1 ? '收藏暂未开放' : '来信暂未开放');
      return;
    }
    if (this.paths.size() > 0 && this.selectedId.length > 0) {
      this.returnAssignmentId = this.selectedId;
    }
    this.showAccount = false;
    this.paths.clear();
    this.mainIndex = index;
    if (index === 3) {
      this.vm.openProfile();
    }
  }

  private startClock(): void {
    this.stopClock();
    this.vm.tick();
    this.timer = setInterval(() => this.vm.tick(), 5000);
  }

  private stopClock(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private clearPasswords(): void {
    this.password = '';
    this.oldPassword = '';
    this.newPassword = '';
    this.confirmation = '';
  }

  private logout(): void {
    LaunchRoutes.clear();
    this.vm.logout();
    this.paths.clear();
    this.clearPasswords();
    this.account = '';
    this.history = false;
    this.selectedId = '';
    this.showAccount = false;
    this.mainIndex = 0;
    this.returnAssignmentId = '';
    this.cancelAvatarCrop();
  }

  private setTheme(mode: number): void {
    const modes: ConfigurationConstant.ColorMode[] = [
      ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET,
      ConfigurationConstant.ColorMode.COLOR_MODE_DARK,
      ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    ];
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      context.getApplicationContext().setColorMode(modes[mode]);
      this.theme = mode;
      this.themeError = '';
    } catch (error) {
      this.themeError = '主题切换失败，请重试。';
    }
  }

  private count(history: boolean): number {
    return this.vm.items.filter((item: AssignmentSummary) => history ?
      item.status === 'completed' || item.status === 'cancelled' :
      item.status === 'assigned' || item.status === 'active').length;
  }

  private visibleItems(history: boolean): AssignmentSummary[] {
    return this.vm.items.filter((item: AssignmentSummary) => history ?
      item.status === 'completed' || item.status === 'cancelled' :
      item.status === 'assigned' || item.status === 'active');
  }

  private timeLabel(value: string): string {
    if (value.length === 0) {
      return '时间待确认';
    }
    const date: Date = new Date(value);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  private levelLabel(item: AssignmentSummary): string {
    return item.maxLevel === null ? `等级 ${item.minLevel} 及以上` : `等级 ${item.minLevel}—${item.maxLevel}`;
  }

  private actionLabel(item: AssignmentSummary): string {
    const state: string = assignmentKind(item, this.vm.player.level.order, this.vm.now);
    if (state === 'ready') {
      return '开启旅程';
    }
    if (state === 'active') {
      return '继续探索';
    }
    return state === 'completed' ? '重温旅程' : '查看详情';
  }

  private detailHint(): string {
    const kind: string = assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now);
    const label: string = assignmentState(this.vm.detail, this.vm.player.level.order, this.vm.now);
    if (kind === 'expired') {
      return `${label}，请联系游戏管理员。`;
    }
    if (kind === 'locked') {
      return `${label}，请确认场次的参与等级。`;
    }
    return `${label}，旅程开放后就能出发。`;
  }

  private openAssignment(id: string): void {
    if (this.vm.gate !== 'home') {
      return;
    }
    if (this.vm.securityUnconfirmed) {
      StarwardFeedback.toast(this.getUIContext(), '请先退出并重新登录，确认密码修改结果。');
      return;
    }
    this.mainIndex = 0;
    this.selectedId = id;
    this.vm.openAssignment(id);
    this.paths.pushPath({ name: 'assignment' });
  }

  @Builder
  icon(source: Resource, size: number, color: ResourceColor) {
    Image(source).width(size).height(size).fillColor(color).objectFit(ImageFit.Contain).accessibilityLevel('no')
  }

  @Builder
  brand() {
    Row({ space: 12 }) {
      Image($r('app.media.starward_mark')).width(36).height(36).objectFit(ImageFit.Contain).accessibilityLevel('no')
      Column({ space: 0 }) {
        Text('赴星之约').fontFamily(this.displayFont).fontSize(16).lineHeight('24fp')
          .fontColor($r('app.color.accent_text')).letterSpacing(2.08)
        Text('向着星辰的冒险').fontSize(10).lineHeight('16fp').letterSpacing(1.8)
          .fontColor($r('app.color.subtle'))
      }.alignItems(HorizontalAlign.Start)
    }.accessibilityText('赴星之约 · 向着星辰的冒险')
  }

  @Builder
  themeChoice(mode: number, label: string, source: Resource, id: string) {
    Button({ type: ButtonType.Normal }) {
      Image(source).width(17).height(17)
        .fillColor(this.theme === mode ? $r('app.color.accent_text') : $r('app.color.subtle'))
        .objectFit(ImageFit.Contain).accessibilityLevel('no')
    }.id(id).height(40).width(37).padding(10).borderRadius(7)
      .backgroundColor(this.theme === mode ? $r('app.color.accent_soft') : Color.Transparent)
      .accessibilityText(label).accessibilitySelected(this.theme === mode).onClick(() => this.setTheme(mode))
  }

  @Builder
  themePicker() {
    Row({ space: 2 }) {
      this.themeChoice(0, '跟随系统', $r('app.media.icon_desktop'), 'theme-system')
      this.themeChoice(2, '浅色', $r('app.media.icon_sun'), 'theme-light')
      this.themeChoice(1, '深色', $r('app.media.icon_moon'), 'theme-dark')
    }.id('theme-picker').padding(3).border({ width: 1, color: $r('app.color.border'), radius: 10 })
      .accessibilityText('主题')
  }

  @Builder
  avatar() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      StarwardPlayerAvatar({ name: this.vm.player.displayName, avatar: this.vm.avatarImage, avatarSize: 44,
        decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
      Text('≡').fontSize(13).fontColor($r('app.color.accent')).width(21).height(21).textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.raised')).border({ width: 1, color: $r('app.color.accent_border'), radius: 11 })
        .offset({ x: 5, y: 2 })
    }.width(44).height(44).id('account-menu').accessibilityText('打开冒险者菜单')
      .accessibilityRole(AccessibilityRoleType.BUTTON).focusable(true)
      .onClick((event: ClickEvent) => this.openAccount(event))
  }

  private openAccount(event: ClickEvent): void {
    if (this.vm.gate !== 'home') {
      return;
    }
    const area: Area = event.target.area;
    const center: number = Number(area.globalPosition.x) + Number(area.width) / 2;
    this.accountAnchorWindowX = Number.isFinite(center) ? center : event.windowX;
    this.showAccount = true;
  }

  @Builder
  header(auth: boolean) {
    Row() {
      this.brand()
      Blank()
      if (auth) {
        this.themePicker()
      } else {
        this.avatar()
      }
      Text(this.vm.mode === 'https' ? '隔离测试环境' : this.vm.mode === 'mock' ? '演示环境' : '环境配置无效').id('environment-badge')
        .fontSize(8).lineHeight('10fp').fontColor($r('app.color.subtle')).position({ x: 0, y: 71 })
    }.width('100%').height(84)
      .border({ width: { bottom: auth ? 0 : 1 }, color: $r('app.color.border') })
  }

  @Builder
  formError() {
    if (this.vm.errorCode === 'VALIDATION_ERROR') {
      InlineError({ message: this.vm.error })
    } else {
      ErrorNotice({ message: this.vm.error, returnHome: () => this.paths.clear() })
    }
  }

  @Builder
  loadingCards() {
    Column({ space: 16 }) {
      ForEach([0, 1], (index: number) => {
        Row({ space: 16 }) {
          Column().width(70).height(110).backgroundColor($r('app.color.accent_soft')).borderRadius(10)
          Column({ space: 16 }) {
            Row().height(46).width('100%').backgroundColor($r('app.color.accent_soft')).borderRadius(10)
            Row().height(46).width('65%').backgroundColor($r('app.color.accent_soft')).borderRadius(10)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.width('100%').constraintSize({ minHeight: 160 }).padding(24)
          .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border'), radius: 18 })
          .accessibilityText(`正在读取冒险足迹，加载项${index + 1}`)
      }, (index: number) => index.toString())
    }.width('100%')
  }

  @Builder
  authStory() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        StarwardAtlas({ atlasSize: 420, renderX: this.authAtlasWidth - 270,
          renderY: this.authAtlasHeight / 2 - 210 }).opacity(0.22)
      }.width(0).height(0).clip(false).hitTestBehavior(HitTestMode.None)
      Column() {
        Text('一场属于你的解谜之旅').fontSize(10).fontFamily('monospace').fontWeight(600)
          .lineHeight('12fp').constraintSize({ minHeight: 12 }).letterSpacing(1.4).fontColor($r('app.color.accent_muted')).width('100%')
        Text('答案之外，\n另有天地。').fontFamily(this.displayFont).fontSize(34).fontWeight(FontWeight.Medium)
          .lineHeight('47.6fp').letterSpacing(1.36).fontColor($r('app.color.strong')).width('100%')
          .margin({ top: 16, bottom: 13 })
        Text('循着线索，走进属于你的故事。').fontSize(13).lineHeight('23.4fp').letterSpacing(0.325)
          .fontColor($r('app.color.muted')).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 32, bottom: 13 })
    }.width('100%').clip(false).onAreaChange((_oldArea: Area, area: Area) => {
      const width: number = Number(area.width);
      const height: number = Number(area.height);
      if (Number.isFinite(width) && width > 0 && width !== this.authAtlasWidth) {
        this.authAtlasWidth = width;
      }
      if (Number.isFinite(height) && height > 0 && height !== this.authAtlasHeight) {
        this.authAtlasHeight = height;
      }
    })
  }

  @Builder
  login() {
    Column() {
      Text('以你的名字，开启冒险。').fontFamily(this.displayFont).fontSize(21).fontWeight(FontWeight.Medium)
        .lineHeight('33.6fp').letterSpacing(0.735).fontColor($r('app.color.strong')).width('100%')
        .margin({ bottom: 16 })
      Column({ space: 16 }) {
        LabeledInput({ label: '登录账号', placeholder: '你的冒险者账号', fieldId: 'account',
          value: this.account, disabled: this.vm.busy, changed: (value: string) => this.account = value })
        LabeledInput({ label: '密码', placeholder: '输入通行密语', fieldId: 'password', value: this.password,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.password = value })
        this.formError()
        PrimaryAction({ label: this.vm.busy ? '正在打开故事…' : '进入冒险', arrow: true,
          actionEnabled: !this.vm.busy && this.vm.mode !== 'unavailable',
          action: () => { this.vm.login(this.account, this.password); } })
      }.width('100%')
      Button({ type: ButtonType.Normal }) {
        Text(`${this.showHelp ? '▾' : '▸'} 还没有账号，或忘记了密码？`).fontSize(12).lineHeight('21.6fp')
          .fontColor($r('app.color.muted')).width('100%')
      }.width('100%').height(45.6).padding({ top: 12, bottom: 12 }).backgroundColor(Color.Transparent)
        .margin({ top: 12 }).id('login-help').onClick(() => {
          this.getUIContext().animateTo({ duration: this.motion.duration(180), curve: Curve.EaseInOut },
            () => { this.showHelp = !this.showHelp; });
        })
      if (this.showHelp) {
        Text('账号由游戏管理员提供，暂不开放注册。忘记密码时，请联系游戏管理员重置。')
          .fontSize(12).lineHeight('21.6fp').fontColor($r('app.color.muted')).width('100%').margin({ top: 8 })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 20, bottom: 12 })
  }

  @Builder
  changePassword() {
    Column() {
      Row({ space: 12 }) {
        this.icon($r('app.media.icon_key'), 24, $r('app.color.accent'))
        Text('首次登录，请先修改密码').fontFamily(this.displayFont).fontSize(24).fontWeight(FontWeight.Medium)
          .lineHeight('36fp').fontColor($r('app.color.strong')).layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Center)
      Text('设置只有你知道的通行密语。使用 10—71 个字符。')
        .fontSize(13).lineHeight('23.4fp').fontColor($r('app.color.muted')).width('100%')
        .margin({ top: 12, bottom: 24 })
      Column({ space: 16 }) {
        LabeledInput({ label: '当前密码', fieldId: 'old-password', value: this.oldPassword,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.oldPassword = value })
        LabeledInput({ label: '新密码', fieldId: 'new-password', value: this.newPassword,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.newPassword = value })
        LabeledInput({ label: '确认新密码', fieldId: 'confirm-password', value: this.confirmation,
          secret: true, disabled: this.vm.busy, changed: (value: string) => this.confirmation = value })
        this.formError()
        PrimaryAction({ label: this.vm.busy ? '正在保存…' : '保存新密码',
          actionEnabled: !this.vm.busy && this.vm.mode !== 'unavailable',
          action: () => { this.vm.changePassword(this.oldPassword, this.newPassword, this.confirmation); } })
        Button('退出登录', { type: ButtonType.Normal }).id('forced-logout').width('100%').height(44)
          .fontSize(14).fontColor($r('app.color.muted')).backgroundColor(Color.Transparent).onClick(() => this.logout())
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ top: 20, bottom: 12 })
  }

  @Builder
  authPage() {
    Scroll() {
      Column() {
        InlineError({ message: this.themeError, fieldId: 'theme-error-message' })
        this.authStory()
        if (this.vm.gate === 'login') {
          this.login()
        } else {
          this.changePassword()
        }
        Text('每一个问题，都是一扇门。').fontFamily(this.displayFont).fontSize(12).lineHeight('21.6fp')
          .letterSpacing(2.4).fontColor($r('app.color.subtle')).width('100%').textAlign(TextAlign.Center)
          .padding({ top: 12, bottom: 24 })
        if (this.vm.mode === 'mock') {
          Text('演示环境 · 数据仅保留在本次运行中').fontSize(10).fontColor($r('app.color.subtle'))
            .margin({ bottom: 8 })
          if (this.vm.gate === 'login') {
            Text('演示账号 alice · 初始密码 Starward1234').fontSize(10).fontColor($r('app.color.subtle'))
              .margin({ bottom: 16 })
          }
        } else {
          Text(this.vm.mode === 'https' ? '隔离测试环境' : '环境配置无效')
            .fontSize(10).fontColor($r('app.color.subtle')).margin({ bottom: 16 })
        }
      }.width('100%').constraintSize({ maxWidth: 440 }).padding({ left: 20, right: 20 })
    }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off)
  }

  @Builder
  assignmentCard(item: AssignmentSummary, index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Blank().width(58)
        Column() {
          Row({ space: 8 }) {
            Circle().width(6).height(6).fill($r('app.color.accent_text')).accessibilityLevel('no')
            Text(assignmentState(item, this.vm.player.level.order, this.vm.now)).id(`assignment-state-${item.id}`)
              .fontSize(13).lineHeight('19fp')
              .fontColor($r('app.color.accent_text'))
          }.width('100%')
          Text(item.title).fontSize(24).fontWeight(FontWeight.Medium).lineHeight('36fp').fontFamily(this.displayFont)
            .letterSpacing(0.6).fontColor($r('app.color.strong')).width('100%').margin({ top: 12, bottom: 12 })
          Text(item.description || `${item.totalLevels} 道谜题，藏着尚未揭开的故事。`)
            .fontSize(13).lineHeight('24.05fp').fontColor($r('app.color.muted')).width('100%').margin({ bottom: 16 })
          Row({ space: 12 }) {
            Text(`${item.totalLevels} 道谜题`).fontSize(11).lineHeight('16fp').fontColor($r('app.color.subtle'))
            Text(this.levelLabel(item)).fontSize(11).lineHeight('16fp').fontColor($r('app.color.subtle'))
              .padding({ left: 12 }).border({ width: { left: 1 }, color: $r('app.color.border_strong') })
          }.width('100%')
          if (item.startsAt.length > 0 || item.endsAt.length > 0) {
            Row({ space: 8 }) {
              this.icon($r('app.media.icon_clock'), 14, $r('app.color.muted'))
              Column() {
                if (item.startsAt.length > 0) {
                  Text(`开放 ${this.timeLabel(item.startsAt)}`).fontSize(11).lineHeight('19.8fp')
                    .fontColor($r('app.color.muted')).width('100%')
                }
                if (item.endsAt.length > 0) {
                  Text(`截止 ${this.timeLabel(item.endsAt)}`).fontSize(11).lineHeight('19.8fp')
                    .fontColor($r('app.color.muted')).width('100%')
                }
              }.layoutWeight(1)
            }.width('100%').margin({ top: 12 }).alignItems(VerticalAlign.Top)
          }
          Column() {
            Text(`已解开 ${item.completedLevels} / ${item.totalLevels}`).fontSize(11).lineHeight('18fp')
              .fontColor($r('app.color.muted')).width('100%')
            Progress({ value: item.completedLevels, total: Math.max(1, item.totalLevels), type: ProgressType.Linear })
              .width('100%').height(4).style({ strokeWidth: 4 }).color($r('app.color.accent'))
              .backgroundColor($r('app.color.border')).margin({ top: 10 })
              .accessibilityText(`${item.title}探索进度：${item.completedLevels}/${item.totalLevels}`)
          }.width('100%').padding({ bottom: 5 }).margin({ top: 20, bottom: 16 })
          Button({ type: ButtonType.Normal }) {
            Row() {
              Text(this.actionLabel(item)).fontSize(13).fontWeight(600)
              Blank()
              this.icon($r('app.media.icon_arrow_right'), 18, $r('app.color.on_accent'))
            }.width('100%')
          }.id(`assignment-${item.id}`).height(46).width('100%').padding({ left: 20, right: 20 })
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent')).borderRadius(10)
            .onClick(() => this.openAssignment(item.id))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ top: 20, bottom: 20, left: 16, right: 16 })
          .border({ width: { left: 1 }, color: $r('app.color.border'), style: BorderStyle.Dashed })
      }.width('100%')
      Column({ space: 8 }) {
        Text((index + 1).toString().padStart(2, '0')).fontFamily(this.displayFont).fontSize(32).lineHeight('32fp')
          .fontColor($r('app.color.accent_muted')).opacity(0.7)
        Text('CHAPTER').fontFamily('monospace').fontSize(6).letterSpacing(0.6)
          .fontColor($r('app.color.accent_muted'))
      }.width(58).padding({ top: 24 }).accessibilityLevel('no')
      Stack() {
        Circle().width(38).height(38).fill(Color.Transparent).stroke($r('app.color.border')).strokeWidth(1)
        Rect().width(18).height(18).fill(Color.Transparent).stroke($r('app.color.accent_border')).strokeWidth(1)
          .rotate({ angle: 45 })
      }.width(38).height(38).align(Alignment.BottomStart).margin({ left: 10, bottom: 28 }).accessibilityLevel('no')
    }.width('100%').constraintSize({ minHeight: 296 }).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: 18 }).clip(true)
  }

  @Builder
  lobbyIntro() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        StarwardAtlas({ atlasSize: 210, renderX: this.lobbyAtlasWidth - 200, renderY: -40 }).opacity(0.17)
      }.width(0).height(0).clip(false).hitTestBehavior(HitTestMode.None)
      Column() {
        Text('你的冒险，从这里续写').fontFamily('monospace').fontWeight(600).fontSize(10)
          .lineHeight('12fp').constraintSize({ minHeight: 12 }).letterSpacing(1.4).fontColor($r('app.color.accent_muted')).width('100%')
        Text('下一段故事，等你落笔。').fontFamily(this.displayFont).fontWeight(FontWeight.Medium)
          .fontSize(28).lineHeight('40.6fp').letterSpacing(0.42).fontColor($r('app.color.strong')).width('100%')
          .margin({ top: 6, bottom: 6 })
        Text('有些答案，要亲自出发才能找到。').fontSize(14).lineHeight('26.6fp')
          .fontColor($r('app.color.muted')).width('100%')
      }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 16 })
    }.width('100%').clip(false).onAreaChange((_oldArea: Area, area: Area) => {
      const width: number = Number(area.width);
      if (Number.isFinite(width) && width > 0 && width !== this.lobbyAtlasWidth) {
        this.lobbyAtlasWidth = width;
      }
    })
  }

  @Builder
  emptyState(history: boolean) {
    Column({ space: 16 }) {
      this.icon($r('app.media.icon_compass_thin'), 64, $r('app.color.accent_muted'))
      Text(history ? '故事的第一页，还空着。' : '下一场奇遇，正在酝酿。')
        .fontFamily(this.displayFont).fontSize(21).fontWeight(FontWeight.Medium).lineHeight('31.5fp')
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text(history ? '完成一场冒险，就会在这里留下你的足迹。' :
        '还没有待玩场次。找游戏管理员领取你的旅程，新的邀请会自动出现在这里。')
        .fontSize(13).lineHeight('24.7fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
    }.width('100%').constraintSize({ minHeight: 280 }).padding({ top: 32, bottom: 32, left: 20, right: 20 })
      .justifyContent(FlexAlign.Center).backgroundColor($r('app.color.accent_faint')).borderRadius(18)
  }

  @Builder
  journeyScroll(history: boolean) {
    Scroll() {
      Column({ space: 20 }) {
        if (this.vm.listBusy && this.vm.items.length === 0) {
          this.loadingCards()
        }
        ErrorNotice({ message: this.vm.listError, retryable: !this.vm.listBusy,
          retry: () => this.vm.refresh(), returnHome: () => this.paths.clear() })
        if (!this.vm.listBusy && this.vm.listError.length === 0 && this.visibleItems(history).length === 0) {
          this.emptyState(history)
        }
        // Server projection only: time does not change component identity.
        ForEach(this.visibleItems(history), (item: AssignmentSummary, index: number) => {
          this.assignmentCard(item, index)
        }, (item: AssignmentSummary, index: number) => `${index}:${JSON.stringify(item)}`)
        StarwardSyncNote({ tailClearance: this.bottomContentClearance() })
      }.width('100%').padding({ top: 24, left: 6, right: 6 })
    }.id(history ? 'history-scroll' : 'current-scroll').width('100%').height('100%')
      .scrollBar(BarState.Off).align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  journeyList(history: boolean) {
    StarwardRefresh({ refreshEnabled: this.vm.gate === 'home' && !this.vm.listBusy,
      request: async () => { await this.vm.refresh(); },
      content: () => { this.journeyScroll(history) }
    })
  }

  @Builder
  currentJourneys() {
    this.journeyList(false)
  }

  @Builder
  pastJourneys() {
    this.journeyList(true)
  }

  @Builder
  journeys() {
    Column() {
      this.lobbyIntro()
      StarwardJourneyTabs({ currentCount: this.count(false), historyCount: this.count(true),
        selectedCategory: this.history ? 1 : 0,
        categoryChanged: (index: number) => { this.history = index === 1; },
        currentJourneys: () => { this.currentJourneys() }, pastJourneys: () => { this.pastJourneys() }
      }).layoutWeight(1)
    }.width('100%').height('100%').padding({ left: 20, right: 20, top: 16 })
  }

  @Builder
  home() {
    StarwardBottomTabs({ floatingGap: 10 + this.safeBottom(), selectedIndex: this.mainIndex,
      hideBar: this.keyboardOccupiesViewport(), materialInteractionEnabled: !this.motion.reduced,
      selected: (index: number) => {
        if (this.vm.gate !== 'home' || this.paths.size() > 0) {
          return;
        }
        this.mainIndex = index;
        if (index === 3) {
          this.vm.openProfile();
        }
      }, journeys: () => { this.journeys() }, passport: () => { this.profile() },
      unavailableSelected: (index: number) => {
        const names: string[] = ['启程', '收藏', '来信', '护照'];
        StarwardFeedback.toast(this.getUIContext(), `${names[index]}暂未开放`);
      }
    })
  }

  @Builder
  profile() {
    ProfilePage({ vm: this.vm, active: this.mainIndex === 3 && this.paths.size() === 0,
      displayFont: this.displayFont, bottomClearance: this.bottomContentClearance(), pickingAvatar: this.avatarPicking,
      chooseAvatar: () => this.pickAvatar(), logout: () => this.logout() })
  }

  @Builder
  sessionHeader() {
    Row({ space: 12 }) {
      this.avatar()
      Column() {
        Text('QUEST SESSION').fontFamily('monospace').fontSize(12).fontWeight(600).lineHeight('14.4fp')
          .letterSpacing(1.68).fontColor($r('app.color.accent_muted'))
        Text(this.vm.player.displayName).fontFamily(this.displayFont).fontSize(22).lineHeight('30fp')
          .fontColor($r('app.color.strong')).margin({ top: 6 }).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`RANK ${this.vm.player.level.order} · ${this.vm.player.level.name}`).fontFamily('monospace')
          .fontSize(11).lineHeight('13.2fp').letterSpacing(0.88).fontColor($r('app.color.accent_muted')).margin({ top: 5 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      if (this.vm.detail.id.length > 0) {
        Column({ space: 6 }) {
        Text(`${this.vm.detail.completedLevels}/${this.vm.detail.totalLevels}`).fontFamily('monospace').fontSize(27)
          .fontWeight(FontWeight.Medium).lineHeight('27fp').fontColor($r('app.color.strong'))
        Text('已完成').fontSize(11).lineHeight('17fp').fontColor($r('app.color.subtle'))
        }.id('detail-progress').alignItems(HorizontalAlign.End)
      }
    }.width('100%').constraintSize({ minHeight: 68.6 }).alignItems(VerticalAlign.Center)
  }

  @Builder
  detailCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        StarwardAtlas({ atlasSize: 200, renderX: this.detailAtlasWidth - 141, renderY: -59 }).opacity(0.16)
      }.width(0).height(0).clip(false).hitTestBehavior(HitTestMode.None)
      Column() {
        Text('一段新的旅程').fontFamily('monospace').fontWeight(600).fontSize(12).lineHeight('14.4fp')
          .letterSpacing(1.68).fontColor($r('app.color.accent_muted')).width('100%')
        Text(this.vm.detail.title).fontFamily(this.displayFont).fontSize(30).fontWeight(FontWeight.Medium).lineHeight('45fp')
          .letterSpacing(0.75).fontColor($r('app.color.strong')).width('100%').margin({ top: 16, bottom: 16 })
        Text(this.vm.detail.description || '循着线索，去发现故事另一面的答案。').fontSize(14).lineHeight('26.6fp')
          .fontColor($r('app.color.muted')).width('100%')
        Column({ space: 20 }) {
          Row({ space: 20 }) {
            DetailFact({ label: '谜题', value: `${this.vm.detail.totalLevels} 道等待解开`, source: $r('app.media.icon_puzzle') })
            DetailFact({ label: '参与等级', value: this.levelLabel(this.vm.detail), source: $r('app.media.icon_map') })
          }.width('100%').alignItems(VerticalAlign.Top)
          Row({ space: 20 }) {
            DetailFact({ label: '开放时间', value: this.vm.detail.startsAt.length > 0 ?
              this.timeLabel(this.vm.detail.startsAt) : '现在就能出发', source: $r('app.media.icon_clock') })
            if (this.vm.detail.endsAt.length > 0) {
              DetailFact({ label: '旅程截止', value: this.timeLabel(this.vm.detail.endsAt), source: $r('app.media.icon_clock') })
            } else {
              Blank().layoutWeight(1)
            }
          }.width('100%').alignItems(VerticalAlign.Top)
        }.width('100%').margin({ top: 24, bottom: 24 })
        if (assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now) !== 'ready') {
          Text(this.detailHint()).id('detail-state-hint').fontSize(13).lineHeight('23.4fp')
            .fontColor($r('app.color.muted')).width('100%').margin({ bottom: 12 })
        }
        Button({ type: ButtonType.Normal }) {
          Row({ space: 16 }) {
            Text('开始本场冒险').fontSize(16).fontWeight(600).letterSpacing(0.96)
            this.icon($r('app.media.icon_arrow_right'), 20, $r('app.color.on_accent'))
          }.width('100%').justifyContent(FlexAlign.Center)
        }.id('start-assignment').enabled(false).height(52).width('100%').borderRadius(10)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent')).opacity(0.45)
          .accessibilityText('开始本场冒险，此切片仅查看场次，暂不支持开始')
        if (assignmentKind(this.vm.detail, this.vm.player.level.order, this.vm.now) === 'expired') {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Image($r('app.media.icon_house')).width(18).height(18).fillColor($r('app.color.on_accent'))
                .objectFit(ImageFit.Contain).accessibilityLevel('no')
              Text('回到首页').fontSize(13).fontWeight(600)
            }.justifyContent(FlexAlign.Center)
          }.id('expired-return-home').width('100%').height(46).padding({ top: 10, bottom: 10, left: 20, right: 20 })
            .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
            .border({ width: 1, color: $r('app.color.accent'), radius: 10 }).margin({ top: 12 })
            .responseRegion({ x: 0, y: 0, width: '100%', height: '100%' })
            .accessibilityText('回到首页，当前场次已过开放时间').onClick(() => this.paths.clear())
        }
        Text('解谜进度会自动保存，随时可以回来继续。').fontSize(11).lineHeight('19.8fp')
          .fontColor($r('app.color.muted')).width('100%').margin({ top: 11 })
        Text('此切片仅查看场次，暂不支持开始冒险。').fontSize(10).lineHeight('18fp')
          .fontColor($r('app.color.subtle')).width('100%').margin({ top: 4 })
      }.width('100%').alignItems(HorizontalAlign.Start).padding(24)
    }.width('100%').backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_border'), radius: 18 }).clip(true)
      .onAreaChange((_oldArea: Area, area: Area) => {
        const width: number = Number(area.width);
        if (Number.isFinite(width) && width > 0 && width !== this.detailAtlasWidth) {
          this.detailAtlasWidth = width;
        }
      })
  }

  @Builder
  destination(name: string) {
    if (name === 'assignment') {
      NavDestination() {
        Scroll() {
          Column({ space: 16 }) {
            if (this.vm.gate === 'home') {
              if (this.vm.detailBusy && this.vm.detail.id.length === 0) {
                Text('正在准备本场冒险…').fontSize(13).fontColor($r('app.color.muted')).width('100%')
              }
              ErrorNotice({ message: this.vm.detailError, retryable: !this.vm.detailBusy,
                retry: () => {
                  if (this.selectedId.length > 0) {
                    this.vm.openAssignment(this.selectedId);
                  }
                }, returnHome: () => this.paths.clear() })
              if (this.vm.detail.id.length > 0) {
                this.detailCard()
              }
              // Native return control supplements the frozen Web expired-state action inside the brief.
              Button({ type: ButtonType.Normal }) {
                Row({ space: 8 }) {
                  this.icon($r('app.media.icon_arrow_left'), 18, $r('app.color.accent_text'))
                  Text('回到首页').fontSize(13).fontColor($r('app.color.accent_text'))
                }
              }.id('return-home').height(44).backgroundColor(Color.Transparent).onClick(() => this.paths.pop())
            }
          }.width('100%').constraintSize({ maxWidth: 720 }).alignItems(HorizontalAlign.Start)
            .padding({ left: 12, right: 12, top: 16, bottom: 24 })
        }.height('100%').width('100%').align(Alignment.Top).scrollBar(BarState.Off)
      }.title({ builder: this.detailTitle, height: this.detailTitleHeight() + 24 + this.safeTop() }, StarwardMaterial.titleOptions())
        .hideTitleBar(false).hideBackButton(true).backgroundColor($r('app.color.canvas'))
    }
  }

  private keyboardOccupiesViewport(): boolean {
    const area: window.UIEnvAvoidAreaVP = this.avoidArea.keyboard;
    return area.visible && Math.max(area.bottomRect.height, area.topRect.height,
      area.leftRect.height, area.rightRect.height) > 0;
  }

  private bottomContentClearance(): number {
    return this.keyboardOccupiesViewport() ? 20 : 84 + this.safeBottom();
  }

  private safeTop(): number {
    return Math.max(0, this.avoidArea.statusBar.topRect.height, this.avoidArea.cutout.topRect.height);
  }

  private safeBottom(): number {
    return Math.max(0, this.avoidArea.statusBar.bottomRect.height, this.avoidArea.cutout.bottomRect.height,
      this.avoidArea.navigationIndicator.bottomRect.height);
  }

  private detailTitleHeight(): number {
    // Track the actual window font environment, including runtime changes.
    if (!Number.isFinite(this.fontScale) || this.fontScale <= 0) {
      return 68.6;
    }
    const context = this.getUIContext();
    return Math.max(68.6, context.px2vp(context.fp2px(57.6)) + 11);
  }

  @Builder
  detailTitle() {
    StarwardTitleSurface({ titleHeight: this.detailTitleHeight(), horizontalGutter: 12,
      topInset: this.safeTop() + 24, titleContent: () => { this.sessionHeader() } })
  }

  @Builder
  rootHeader() {
    this.header(this.vm.gate !== 'home')
  }

  @Builder
  rootTitle() {
    StarwardTitleSurface({ topInset: this.safeTop(), titleContent: () => { this.rootHeader() } })
  }

  @Builder
  menuDestination(index: number, label: string, description: string, hint: string, normalIcon: Resource,
    selectedIcon: Resource) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 14 }) {
        this.icon(this.paths.size() === 0 && this.mainIndex === index ? selectedIcon : normalIcon, 23,
          $r('app.color.accent_text'))
        Column({ space: 4 }) {
          Text(description).fontSize(15).fontColor($r('app.color.text'))
          Text(hint).fontSize(11).fontColor($r('app.color.muted'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        if (index === 1 || index === 2) {
          Text('暂未开放').fontSize(10).fontColor($r('app.color.subtle'))
        }
        this.icon($r('app.media.icon_arrow_right'), 17, $r('app.color.subtle'))
      }.width('100%').padding({ top: 12, bottom: 12 })
    }.id(index === 0 ? 'menu-home' : index === 1 ? 'menu-rewards' : index === 2 ? 'menu-notifications' : 'menu-profile')
      .width('100%').constraintSize({ minHeight: 64 }).borderRadius(10).padding({ left: 12, right: 12 })
      .backgroundColor(this.paths.size() === 0 && this.mainIndex === index ? $r('app.color.accent_faint') : Color.Transparent)
      .accessibilitySelected(this.paths.size() === 0 && this.mainIndex === index)
      .accessibilityText(`${label}，${description}，${hint}${index === 1 || index === 2 ? '，暂未开放' : ''}`)
      .onClick(() => this.goMain(index))
  }

  @Builder
  accountSheet() {
    Scroll() {
      Column({ space: 20 }) {
        StarwardPassport({ player: this.vm.player, avatar: this.vm.avatarImage, displayFont: this.displayFont, menu: true,
          decodeFailed: (avatar: AvatarImage) => this.vm.reportAvatarDecodeFailure(avatar) })
        Column({ space: 4 }) {
          if (this.returnAssignmentId.length > 0 && this.paths.size() === 0) {
            Button('返回答题 · 接着刚才的线索继续', { type: ButtonType.Normal })
              .id('menu-return-assignment').width('100%').constraintSize({ minHeight: 52 })
              .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
              .onClick(() => {
                this.showAccount = false;
                this.openAssignment(this.returnAssignmentId);
              })
          }
          this.menuDestination(0, '启程', '我的场次', '继续未完的冒险', $r('app.media.icon_nav_compass_regular'),
            $r('app.media.icon_nav_compass_fill'))
          this.menuDestination(1, '收藏', '奇遇收藏', '收好线索与战利品', $r('app.media.icon_nav_sparkle_regular'),
            $r('app.media.icon_nav_sparkle_fill'))
          this.menuDestination(2, '来信', '旅途来信', '查收远方的消息', $r('app.media.icon_nav_envelope_regular'),
            $r('app.media.icon_nav_envelope_fill'))
          this.menuDestination(3, '护照', '冒险者护照', '装扮你的冒险名片', $r('app.media.icon_nav_passport_regular'),
            $r('app.media.icon_nav_passport_fill'))
        }.width('100%')
        Text('旅途光线').fontSize(12).fontColor($r('app.color.muted'))
        this.themePicker()
        InlineError({ message: this.themeError, fieldId: 'theme-error-message' })
        Text(this.vm.mode === 'mock' ? '演示环境 · 数据仅保留在本次运行中' : this.vm.mode === 'https' ? '隔离测试环境' : '环境配置无效')
          .fontSize(11).fontColor($r('app.color.subtle'))
        Button('退出登录', { type: ButtonType.Normal }).id('logout').width('100%').height(44)
          .fontColor($r('app.color.muted')).backgroundColor(Color.Transparent).onClick(() => this.logout())
      }.width('100%').alignItems(HorizontalAlign.Start).padding(24)
    }.id('account-menu-scroll').width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  accountOverlay() {
    StarwardSidePanel({ visible: this.showAccount!!, title: '冒险者菜单', ownerActive: this.vm.gate === 'home',
      ownerKey: this.vm.player.id, anchorWindowX: this.accountAnchorWindowX, reducedMotion: this.motion.reduced,
      failed: () => StarwardFeedback.toast(this.getUIContext(), '菜单暂时无法打开，请重试。'),
      anchor: () => { this.rootNavigation() }, content: () => { this.accountSheet() } })
  }

  @Builder
  avatarCropContent() {
    StarwardAvatarCrop({ selection: this.avatarSelection,
      confirmed: (upload: AvatarUpload) => {
        if (this.vm.gate === 'home') {
          this.vm.selectProfileAvatar(upload);
        }
        this.cancelAvatarCrop();
      }, cancelled: () => this.cancelAvatarCrop(), reselect: () => this.pickAvatar() })
  }

  @Builder
  rootNavigation() {
    Navigation(this.paths) {
      if (this.vm.gate === 'home') {
        this.home()
      } else {
        this.authPage()
      }
    }.navDestination(this.destination)
      .mode(this.vm.gate === 'home' ? NavigationMode.Auto : NavigationMode.Stack)
      .navBarWidth('40%').navBarWidthRange([320, 440]).minContentWidth(360)
      .title({ builder: this.rootTitle, height: 84 + this.safeTop() }, StarwardMaterial.titleOptions()).hideTitleBar(false).hideBackButton(true)
      .width('100%').height('100%').backgroundColor($r('app.color.canvas'))
  }

  build() {
    Stack() {
      StarwardAccountSheet({ visible: this.showAvatarCrop!!, title: '裁剪头像',
        anchor: () => { this.accountOverlay() }, content: () => { this.avatarCropContent() }
      }).width('100%').height('100%')
    }.width('100%').height('100%').backgroundColor($r('app.color.canvas'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
