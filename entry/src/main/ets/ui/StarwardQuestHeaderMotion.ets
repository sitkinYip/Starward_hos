import { curves, UIUtils } from '@kit.ArkUI';
import { AvatarImage } from '../business/models';
import { StarwardPlayerAvatar } from './StarwardPlayerAvatar';

@ComponentV2
export struct StarwardQuestAvatar {
  @Param name: string = '';
  @Param avatar: AvatarImage | null = null;
  @Param motionEnabled: boolean = false;
  @Event decodeFailed: (avatar: AvatarImage) => void = () => {};
  @Local private raised: boolean = false;
  private mounted: boolean = false;

  @Monitor('motionEnabled')
  updateAura(): void {
    if (!this.mounted) { return; }
    const ui = this.getUIContext();
    if (this.motionEnabled) {
      ui.animateTo({ duration: 4800, iterations: -1, playMode: PlayMode.Alternate,
        curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) }, () => UIUtils.applySync(() => { this.raised = true; }));
    } else {
      ui.animateTo({ duration: 0 }, () => UIUtils.applySync(() => { this.raised = false; }));
    }
  }

  aboutToDisappear(): void { this.mounted = false; }

  build() {
    Stack() {
      Stack() {
        Stack().width(56).height(56).position({ x: -6, y: -6 }).borderRadius(28)
          .border({ width: 1, color: $r('app.color.quest_avatar_outline') })
          .backgroundColor($r('app.color.accent_faint'))
          .shadow({ radius: 34, color: $r('app.color.quest_avatar_glow') })
          .id('quest-avatar-aura').accessibilityLevel('no').hitTestBehavior(HitTestMode.None)
        StarwardPlayerAvatar({ name: this.name, avatar: this.avatar, avatarSize: 44,
          outlineTint: $r('app.color.accent'), decodeFailed: (avatar: AvatarImage) => this.decodeFailed(avatar) })
      }.width(44).height(44).clip(false).hitTestBehavior(HitTestMode.None)
        .scale({ x: this.raised ? 1.035 : 1, y: this.raised ? 1.035 : 1 })
        .translate({ y: this.raised ? -2 : 0 })
    }.width(44).height(44).clip(false).hitTestBehavior(HitTestMode.None)
      .onAppear(() => { this.mounted = true; this.updateAura(); })
  }
}

@ComponentV2
export struct StarwardQuestHeaderEntrance {
  @Param motionEnabled: boolean = false;
  @BuilderParam content: () => void;
  @Local private entered: boolean = true;

  aboutToAppear(): void { this.entered = !this.motionEnabled; }

  @Monitor('motionEnabled')
  settleWhenDisabled(): void {
    if (!this.motionEnabled) {
      this.getUIContext().animateTo({ duration: 0 }, () => UIUtils.applySync(() => { this.entered = true; }));
    }
  }

  build() {
    Stack() {
      this.content()
    }.width('100%').opacity(this.entered ? 1 : 0).translate({ y: this.entered ? 0 : -18 })
      .onAppear(() => {
        if (!this.entered) {
          this.getUIContext().animateTo({ duration: 760, curve: curves.cubicBezierCurve(0.32, 0.72, 0, 1) },
            () => UIUtils.applySync(() => { this.entered = true; }));
        }
      })
  }
}

@ComponentV2
export struct StarwardQuestProgress {
  @Param completed: number = 0;
  @Param total: number = 0;
  @Param motionEnabled: boolean = false;
  @Local private entered: boolean = true;
  private mounted: boolean = false;

  aboutToAppear(): void { this.entered = !this.motionEnabled; }
  aboutToDisappear(): void { this.mounted = false; }

  @Monitor('completed')
  progressChanged(): void {
    if (this.mounted && this.motionEnabled) {
      this.getUIContext().animateTo({ duration: 0 }, () => UIUtils.applySync(() => { this.entered = false; }));
      this.animateCount();
    }
  }

  @Monitor('motionEnabled')
  settleWhenDisabled(): void {
    if (this.mounted && !this.motionEnabled) {
      this.getUIContext().animateTo({ duration: 0 }, () => UIUtils.applySync(() => { this.entered = true; }));
    }
  }

  private animateCount(): void {
    this.getUIContext().animateTo({ duration: 680, curve: curves.cubicBezierCurve(0.22, 0.78, 0.18, 1) },
      () => UIUtils.applySync(() => { this.entered = true; }));
  }

  build() {
    Column({ space: 6 }) {
      Text(`${this.completed}/${this.total}`).id('quest-progress-count').fontFamily('monospace').fontSize(27)
        .fontWeight(FontWeight.Medium).lineHeight('27fp').fontColor($r('app.color.strong'))
        .textShadow({ radius: 22, color: $r('app.color.quest_avatar_glow') })
        .opacity(this.entered ? 1 : 0).translate({ y: this.entered ? 0 : 8 })
        .scale({ x: this.entered ? 1 : 0.82, y: this.entered ? 1 : 0.82 })
      Text('已完成').fontSize(11).lineHeight('17fp').fontColor($r('app.color.subtle'))
    }.id('detail-progress').alignItems(HorizontalAlign.End)
      .onAppear(() => { this.mounted = true; if (!this.entered) { this.animateCount(); } })
  }
}
