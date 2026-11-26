import { window } from '@kit.ArkUI';
import { describe, expect, it } from '@ohos/hypium';
import { VideoFullscreenOrientation } from '../main/ets/platform/VideoFullscreenOrientation';

class VideoTestWindow {
  current: window.Orientation = window.Orientation.AUTO_ROTATION;
  writes: window.Orientation[] = [];
  private accept: () => void = () => {};
  nextWrite: Promise<void> | undefined;

  holdNextWrite(): void {
    this.nextWrite = new Promise<void>((resolve) => { this.accept = resolve; });
  }

  finishWrite(): void { this.accept(); }

  policy(): VideoFullscreenOrientation {
    return new VideoFullscreenOrientation(() => this.current,
      (orientation: window.Orientation) => this.setPreferredOrientation(orientation));
  }

  async setPreferredOrientation(orientation: window.Orientation): Promise<void> {
    this.writes.push(orientation);
    const pending = this.nextWrite;
    this.nextWrite = undefined;
    if (pending !== undefined) { await pending; }
    this.current = orientation;
  }
}

export default function videoFullscreenOrientationTests(): void {
  describe('VideoFullscreenOrientation', () => {
    it('UsesDisplayAspectAndRestoresOriginalPolicy', 0, async () => {
      const target = new VideoTestWindow();
      const policy = target.policy();
      const owner: Object = new Object();
      await policy.enter(owner, 1280, 720);
      expect(target.current).assertEqual(window.Orientation.LANDSCAPE);
      await policy.exit(owner);
      expect(target.current).assertEqual(window.Orientation.AUTO_ROTATION);
      await policy.enter(owner, 576, 1024);
      expect(target.current).assertEqual(window.Orientation.PORTRAIT);
      await policy.exit(owner);
      expect(target.current).assertEqual(window.Orientation.AUTO_ROTATION);
      await policy.enter(owner, 720, 720);
      await policy.enter(owner, 0, 0);
      await policy.exit(owner);
      expect(target.writes.length).assertEqual(4);
    });

    it('SerializesInFlightRotationAndIgnoresOldPlaybackExit', 0, async () => {
      const target = new VideoTestWindow();
      const policy = target.policy();
      const first: Object = new Object();
      const next: Object = new Object();
      target.holdNextWrite();
      const entered: Promise<void> = policy.enter(first, 1280, 720);
      await Promise.resolve();
      expect(target.writes[0]).assertEqual(window.Orientation.LANDSCAPE);
      const exited: Promise<void> = policy.exit(first);
      const nextEntered: Promise<void> = policy.enter(next, 720, 1280);
      const lateExit: Promise<void> = policy.exit(first);
      target.finishWrite();
      await entered;
      await exited;
      await nextEntered;
      await lateExit;
      expect(target.current).assertEqual(window.Orientation.PORTRAIT);
      await policy.exit(next);
      expect(target.current).assertEqual(window.Orientation.AUTO_ROTATION);
      expect(target.writes.length).assertEqual(3);
    });
  });
}
