import { common } from '@kit.AbilityKit';
import { BusinessError, settings } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { AppEnvironment } from './AppEnvironment';

const GAMEPLAY_USAGE: vibrator.VibrateAttribute = { usage: 'physicalFeedback' };
const PERMISSION_DENIED: number = 201;
const CAPABILITY_UNAVAILABLE: number = 801;
const CORRECT_PULSE_MS: number = 60;
const INCORRECT_PULSE_MS: number = 140;

export function openSystemHapticsSettings(context: common.UIAbilityContext): boolean {
  try {
    settings.openSoundSettingsPage(context);
    return true;
  } catch {
    return false;
  }
}

function report(correct: boolean, stage: string, code: number): void {
  if (AppEnvironment.showEnvironmentDiagnostics && AppEnvironment.isolated) {
    hilog.info(0x0000, 'StarwardAnswerHaptics', 'effect=%{public}s stage=%{public}s code=%{public}d',
      correct ? 'success' : 'failure', stage, code);
  }
}

/** The sensor service applies the user's system touch-feedback policy. */
export async function playAnswerHaptics(correct: boolean, current: () => boolean): Promise<void> {
  if (!current()) { return; }
  if (!canIUse('SystemCapability.Sensors.MiscDevice')) {
    report(correct, 'capability', CAPABILITY_UNAVAILABLE);
    return;
  }
  const preset = correct ? vibrator.HapticFeedback.EFFECT_NOTICE_SUCCESS :
    vibrator.HapticFeedback.EFFECT_NOTICE_FAILURE;
  try {
    if (vibrator.isSupportEffectSync(preset)) {
      await vibrator.startVibration({ type: 'preset', effectId: preset }, GAMEPLAY_USAGE);
      report(correct, 'preset', 0);
      return;
    }
  } catch (error) {
    const code = (error as BusinessError).code;
    report(correct, 'preset', code);
    if (code === PERMISSION_DENIED || code === CAPABILITY_UNAVAILABLE) { return; }
  }
  if (!current()) { return; }
  try {
    await vibrator.startVibration({ type: 'time', duration: correct ? CORRECT_PULSE_MS : INCORRECT_PULSE_MS },
      GAMEPLAY_USAGE);
    report(correct, 'pulse', 0);
  } catch (error) {
    report(correct, 'pulse', (error as BusinessError).code);
  }
}
