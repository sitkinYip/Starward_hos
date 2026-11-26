import { ProgressAttempt, ProgressWatch } from '../business/ProgressWatch';
import { InlineError } from '../ui/ErrorMessages';
import { StarwardRefresh } from '../ui/StarwardRefresh';
import { StarwardGlassDialog } from '../ui/StarwardGlassDialog';
import { STARWARD_RADIUS_PANEL } from '../ui/StarwardRadii';
import { ProgressWatchViewModel } from './ProgressWatchViewModel';

const EVENT_LABELS: Record<string, string> = { 'correct': '答对', 'incorrect': '答错', 'completed': '通关' };

function localTime(value: string): string {
  const time: Date = new Date(value);
  return `${time.getMonth() + 1}月${time.getDate()}日 ${time.getHours().toString().padStart(2, '0')}:` +
    time.getMinutes().toString().padStart(2, '0');
}

@ComponentV2
export struct ProgressWatchPage {
  @Require @Param model: ProgressWatchViewModel;
  @Param active: boolean = false;
  @Param bottomInset: number = 0;
  @Param leftInset: number = 0;
  @Param rightInset: number = 0;
  @Param permission: boolean | null = null;
  @Param localPushEnabled: boolean = false;
  @Param panelWidth: number = 320;
  @Param reducedMotion: boolean = true;
  @Event openSystemSettings: () => void = () => {};
  @Local private confirmation: ProgressWatch | null = null;

  aboutToAppear(): void {
    this.model.openPage(this.active);
  }

  aboutToDisappear(): void {
    this.model.closePage();
  }

  @Monitor('active')
  private activeChanged(): void {
    if (!this.active) { this.confirmation = null; }
    this.model.setPageActive(this.active);
  }

  @Monitor('model.detail', 'model.draft', 'permission')
  private consentChanged(): void {
    if (this.confirmation !== null && !this.canConfirmNotifications) { this.confirmation = null; }
  }

  @Computed
  get canConfirmNotifications(): boolean {
    const watch: ProgressWatch | undefined = this.model.detail?.watch;
    return this.active && this.permission === true && this.localPushEnabled && this.model.detail?.pushAvailable === true &&
      this.confirmation !== null && watch !== undefined && watch.subscribed && !watch.pushEnabled &&
      this.confirmation.id === watch.id && this.confirmation.revision === watch.revision && !this.model.hasUnsavedSelection();
  }

  private selectedIndex(): number {
    return this.model.items.findIndex((item: ProgressWatch) => item.id === this.model.selectedId);
  }

  private confirmNotifications(): void {
    const watch: ProgressWatch | null = this.confirmation;
    if (watch !== null && this.canConfirmNotifications && !this.model.loading && !this.model.saving) {
      void this.model.setPush(watch.id, watch.revision, true);
    }
    this.confirmation = null;
  }

  @Builder
  private notificationConsent() {
    Column({ space: 14 }) {
      Text('接收场次进度通知？').fontSize(20).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.strong')).textAlign(TextAlign.Center)
      Text(`开启后，手机会收到《${this.confirmation?.title ?? ''}》的` +
        `${this.confirmation?.eventKinds.map((kind: string) => EVENT_LABELS[kind]).join('、') ?? ''}通知。`)
        .fontSize(14).lineHeight('22fp').fontColor($r('app.color.muted')).textAlign(TextAlign.Center)
      Button('接收通知', { type: ButtonType.Capsule }).id('progress-watch-confirm-push')
        .width('100%').constraintSize({ minHeight: 44 }).fontSize(15)
        .backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
        .enabled(!this.model.loading && !this.model.saving)
        .onClick(() => this.confirmNotifications())
      Button('暂不接收', { type: ButtonType.Capsule }).id('progress-watch-decline-push')
        .width('100%').constraintSize({ minHeight: 44 }).fontSize(14)
        .backgroundColor(Color.Transparent).fontColor($r('app.color.muted'))
        .onClick(() => { this.confirmation = null; })
    }.width('100%').padding(24).backgroundColor($r('app.color.raised'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
  }

  @Builder
  private summary() {
    Column({ space: 8 }) {
      Text(this.model.detail?.watch.title ?? '').fontSize(20).fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.strong')).lineHeight('28fp')
      Text(this.model.detail?.watch.playerName ?? '').fontSize(14).fontColor($r('app.color.muted'))
      Row({ space: 10 }) {
        Text(`已解开 ${this.model.detail?.solved ?? 0} / ${this.model.detail?.total ?? 0} 关`).id('progress-watch-count')
          .fontSize(16).fontWeight(FontWeight.Medium).fontFeature("'tnum' 1").fontColor($r('app.color.text'))
      }.width('100%')
      if (this.model.detail?.watch.status === 'completed') {
        Text(`已通关${this.model.detail.completedAt.length > 0 ? ' · ' + localTime(this.model.detail.completedAt) : ''}`)
          .id('progress-watch-completed').fontSize(14).fontColor($r('app.color.accent_text')).fontFeature("'tnum' 1")
      } else if ((this.model.detail?.currentPosition ?? 0) > 0) {
        Text(`当前第 ${this.model.detail?.currentPosition ?? 0} 关`).fontSize(14)
          .fontColor($r('app.color.accent_text')).fontFeature("'tnum' 1")
      } else {
        Text('尚未入场').fontSize(14).fontColor($r('app.color.muted'))
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
  }

  @Builder
  private eventOption(label: string, kind: string) {
    Row({ space: 8 }) {
      Text(label).layoutWeight(1).fontSize(15).fontColor($r('app.color.text'))
      Checkbox({ name: kind, group: 'progress-watch-events' })
        .id('progress-event-' + kind).select(this.model.draft.includes(kind)).selectedColor($r('app.color.accent'))
        .accessibilityText(label).enabled(!this.model.saving && !this.model.retryPending)
        .onChange((checked: boolean) => this.model.choose(kind, checked))
    }.width('100%').constraintSize({ minHeight: 44 })
  }

  @Builder
  private subscription() {
    Column({ space: 8 }) {
      Text('提醒事件').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
      this.eventOption(EVENT_LABELS['correct'], 'correct')
      this.eventOption(EVENT_LABELS['incorrect'], 'incorrect')
      this.eventOption(EVENT_LABELS['completed'], 'completed')
      Button(this.model.detail?.watch.subscribed ? '保存提醒事件' : '订阅进度', { type: ButtonType.Capsule })
        .id('progress-watch-save').width('100%').constraintSize({ minHeight: 44 })
        .fontSize(15).backgroundColor($r('app.color.accent')).fontColor($r('app.color.on_accent'))
        .enabled(this.model.draft.length > 0 && !this.model.saving && !this.model.loading && !this.model.retryPending)
        .onClick(() => { void this.model.saveSelection(); })
      if (this.model.detail?.watch.subscribed) {
        Divider().color($r('app.color.border')).margin({ top: 4, bottom: 2 })
        Text(!this.model.detail.pushAvailable || !this.localPushEnabled ? '进度通知服务尚未启用' :
          this.model.detail.watch.pushEnabled && this.permission === true ? '已订阅 · 接收系统通知' :
          '已订阅 · 系统通知未开启')
          .id('progress-watch-notification-state').fontSize(13).fontColor($r('app.color.muted')).lineHeight('20fp')
        if (this.model.detail.watch.pushEnabled ||
          (this.model.detail.pushAvailable && this.localPushEnabled && this.permission === true)) {
          if (!this.model.detail.watch.pushEnabled && this.model.hasUnsavedSelection()) {
            Text('请先保存提醒事件，再开启通知。').fontSize(13).fontColor($r('app.color.muted')).lineHeight('20fp')
          }
          Button(this.model.detail.watch.pushEnabled ? '关闭进度通知' : '开启进度通知', { type: ButtonType.Capsule })
            .id('progress-watch-push').constraintSize({ minHeight: 44 }).fontSize(14)
            .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
            .enabled(!this.model.saving && !this.model.loading && !this.model.retryPending && this.confirmation === null &&
              (this.model.detail.watch.pushEnabled || !this.model.hasUnsavedSelection()))
            .onClick(() => {
              const watch: ProgressWatch | undefined = this.model.detail?.watch;
              if (watch?.pushEnabled) {
                void this.model.setPush(watch.id, watch.revision, false);
              } else if (!this.model.hasUnsavedSelection()) {
                this.confirmation = watch ?? null;
              }
            })
        }
        if (this.model.detail.pushAvailable && this.localPushEnabled && this.permission !== true) {
          Button('打开系统通知设置', { type: ButtonType.Capsule }).id('progress-watch-system-settings')
            .constraintSize({ minHeight: 44 }).fontSize(14).fontColor($r('app.color.accent_text'))
            .backgroundColor($r('app.color.accent_faint')).onClick(() => this.openSystemSettings())
        }
        Button('取消订阅', { type: ButtonType.Capsule }).id('progress-watch-unsubscribe')
          .constraintSize({ minHeight: 44 }).fontSize(14).fontColor($r('app.color.muted'))
          .backgroundColor(Color.Transparent)
          .enabled(!this.model.saving && !this.model.loading && !this.model.retryPending)
          .onClick(() => { void this.model.unsubscribe(); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
  }

  @Builder
  private saveFeedback() {
    if (this.model.saving) {
      Text('正在保存…').fontSize(13).fontColor($r('app.color.muted'))
    }
    InlineError({ message: this.model.writeError, fieldId: 'progress-watch-write-error' })
    if (this.model.retryPending) {
      Button('重试保存', { type: ButtonType.Capsule }).id('progress-watch-retry-save')
        .constraintSize({ minHeight: 44 }).backgroundColor($r('app.color.accent_faint'))
        .fontColor($r('app.color.accent_text')).enabled(!this.model.loading)
        .onClick(() => { void this.model.retrySave(); })
    }
  }

  @Builder
  private attempts() {
    Column({ space: 8 }) {
      Text('最近答题').fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.strong'))
      if ((this.model.detail?.recent.length ?? 0) === 0) {
        Text('还没有答题记录').fontSize(14).fontColor($r('app.color.muted')).lineHeight('21fp')
      }
      ForEach(this.model.detail?.recent ?? [], (attempt: ProgressAttempt) => {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(`第 ${attempt.position} 关 · ${attempt.result === 'correct' ? '答对' : '答错'}`)
              .layoutWeight(1).fontSize(14).fontColor($r('app.color.text')).fontFeature("'tnum' 1")
            Text(localTime(attempt.submittedAt)).fontSize(13).fontColor($r('app.color.muted')).fontFeature("'tnum' 1")
          }.width('100%')
          if (attempt.result === 'incorrect' && attempt.submittedAnswer.length > 0) {
            Text(`作答 · ${attempt.submittedAnswer}` +
              (attempt.submittedOptionLabel.length > 0 ? ` · ${attempt.submittedOptionLabel}` : ''))
              .width('100%').fontSize(13).fontColor($r('app.color.muted')).lineHeight('20fp')
              .wordBreak(WordBreak.BREAK_WORD)
          }
        }.width('100%').padding({ top: 5, bottom: 5 })
      }, (attempt: ProgressAttempt) => `${attempt.id}:${attempt.submittedAnswer.length > 0}:${attempt.submittedOptionLabel.length > 0}`)
    }.width('100%').alignItems(HorizontalAlign.Start).padding(16).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border'), radius: STARWARD_RADIUS_PANEL })
  }

  @Builder
  private content() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.model.items.length > 1 || (this.model.items.length === 1 && this.selectedIndex() < 0)) {
          Select(this.model.items.map((item: ProgressWatch): SelectOption => ({ value: `${item.title} · ${item.playerName}` })))
            .id('progress-watch-scenes').selected(this.selectedIndex()).width('100%').accessibilityText('授权场次')
            .enabled(!this.model.saving).onSelect((index: number) => this.model.select(this.model.items[index]?.id ?? ''))
        }
        if (this.model.detail !== null) {
          this.summary()
          this.subscription()
          this.saveFeedback()
          this.attempts()
        } else if (this.model.loading) {
          Row({ space: 10 }) {
            LoadingProgress().width(23).height(23).color($r('app.color.accent')).accessibilityLevel('no')
            Text('正在读取进度…').fontSize(14).fontColor($r('app.color.muted'))
          }.width('100%').constraintSize({ minHeight: 44 })
        } else {
          this.saveFeedback()
        }
        if (this.model.readError.length > 0) {
          InlineError({ message: this.model.readError, fieldId: 'progress-watch-read-error' })
          Button('重新加载', { type: ButtonType.Capsule }).id('progress-watch-retry')
            .constraintSize({ minHeight: 44 }).backgroundColor($r('app.color.accent_faint'))
            .fontColor($r('app.color.accent_text')).onClick(() => { void this.model.refresh(); })
        }
      }.width('100%').constraintSize({ maxWidth: 480 }).alignItems(HorizontalAlign.Start)
        .padding({ left: 20 + this.leftInset, right: 20 + this.rightInset, top: 20, bottom: 24 + this.bottomInset })
    }.id('progress-watch-page').width('100%').height('100%').align(Alignment.Top).scrollBar(BarState.Auto)
  }

  build() {
    Stack() {
      StarwardRefresh({ refreshEnabled: !this.model.saving && !this.model.retryPending,
        request: () => this.model.refresh(), content: () => { this.content() } })
      StarwardGlassDialog({ visible: this.canConfirmNotifications,
        panelWidth: this.panelWidth, reducedMotion: this.reducedMotion, dismissOnTapOutside: true,
        content: () => { this.notificationConsent() }, back: () => { this.confirmation = null; },
        failed: () => { this.confirmation = null; } })
    }.width('100%').height('100%')
  }
}
