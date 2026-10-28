import { accessibility } from '@kit.AccessibilityKit';

/** API23+ reduced-motion policy, owned by one UI lifecycle rather than a singleton. */
@ObservedV2
export class StarwardMotion {
  @Trace reduced: boolean = true;
  private listening: boolean = false;
  private readonly reduceStateChanged: (reduced: boolean) => void = (reduced: boolean): void => {
    if (this.listening) {
      this.reduced = reduced;
    }
  };

  start(): void {
    if (this.listening) {
      return;
    }
    try {
      this.reduced = accessibility.isAnimationReduceEnabledSync();
      this.listening = true;
      accessibility.onAnimationReduceStateChange(this.reduceStateChanged);
    } catch (error) {
      this.listening = false;
      this.reduced = true;
      // Also release a registration if a platform error occurred after setup.
      try {
        accessibility.offAnimationReduceStateChange(this.reduceStateChanged);
      } catch (cleanupError) {
        // Cleanup could not be confirmed; any queued callback remains inert.
      }
    }
  }

  stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    this.reduced = true;
    try {
      accessibility.offAnimationReduceStateChange(this.reduceStateChanged);
    } catch (error) {
      // A queued callback is inert after listening is cleared.
    }
  }

  duration(milliseconds: number): number {
    // Visual policy only: business completion must never depend on onFinish.
    if (this.reduced || !Number.isFinite(milliseconds)) {
      return 0;
    }
    return Math.max(0, milliseconds);
  }
}
