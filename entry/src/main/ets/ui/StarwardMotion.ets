import { accessibility } from '@kit.AccessibilityKit';
import { curves, FrameCallback } from '@kit.ArkUI';

export const STARWARD_PAGE_TRANSITION_MS: number = 240;

/** Single entrance for content that already owns its layout slot. */
export function starwardPageReveal(reducedMotion: boolean, offsetY: number = 0): TransitionEffect {
  if (reducedMotion) { return TransitionEffect.IDENTITY; }
  const reveal: TransitionEffect = TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: offsetY }));
  return TransitionEffect.asymmetric(reveal.animation({ duration: STARWARD_PAGE_TRANSITION_MS,
    curve: curves.cubicBezierCurve(0.2, 0, 0, 1) }), TransitionEffect.IDENTITY);
}

// Motion Prompt #002 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#002
export function starwardListReveal(motionEnabled: boolean, delay: number = 0): AnimateParam {
  return { duration: motionEnabled ? 640 : 0, delay: motionEnabled ? delay : 0,
    curve: curves.cubicBezierCurve(0.16, 1, 0.3, 1) };
}

class CountUpFrame extends FrameCallback {
  private readonly update: (time: number) => void;

  constructor(update: (time: number) => void) {
    super();
    this.update = update;
  }

  onFrame(time: number): void { this.update(time); }
}

// Motion Prompt #007 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#007
export function starwardCountUp(context: UIContext, total: number, durationMs: number,
  current: () => boolean, render: (value: number, settled: boolean) => void): void {
  let start: number = -1;
  const durationNs: number = durationMs * 1_000_000;
  const frame: CountUpFrame = new CountUpFrame((now: number): void => {
    if (!current()) { return; }
    if (start < 0) { start = now; }
    const progress: number = Math.min(1, (now - start) / durationNs);
    render(Math.round(total * (1 - Math.pow(1 - progress, 4))), progress >= 1);
    if (progress < 1) { context.postFrameCallback(frame); }
  });
  context.postFrameCallback(frame);
}

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
