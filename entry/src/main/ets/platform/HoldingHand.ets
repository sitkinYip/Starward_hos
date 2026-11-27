import { motion } from '@kit.MultimodalAwarenessKit';

/** The default side is used for both hands, unheld devices and unknown posture. */
export function watchLeftHoldingHand(changed: (left: boolean) => void): (() => void) | undefined {
  if (!canIUse('SystemCapability.MultimodalAwareness.Motion')) { return undefined; }

  let active: boolean = true;
  const listener = (status: motion.HoldingHandStatus): void => {
    if (active) { changed(status === motion.HoldingHandStatus.LEFT_HAND_HELD); }
  };
  try {
    motion.on('holdingHandChanged', listener);
  } catch {
    // Some devices declare Motion but do not support holding-hand detection.
    return undefined;
  }
  return (): void => {
    active = false;
    try {
      motion.off('holdingHandChanged', listener);
    } catch {
      // The OS service can become unavailable after subscription.
    }
  };
}
