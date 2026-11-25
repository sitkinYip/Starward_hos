import { PersistenceV2 } from '@kit.ArkUI';

export const COMBINATION_LAUNCHER_DEFAULT_Y: number = 0.74;

/** Device-local presentation preference: no account, assignment or clue data. */
@ObservedV2
export class CombinationLauncherPosition {
  @Trace x: number = 1;
  @Trace y: number = COMBINATION_LAUNCHER_DEFAULT_Y;

  private static fallback: CombinationLauncherPosition = new CombinationLauncherPosition();

  static load(): CombinationLauncherPosition {
    try {
      return PersistenceV2.globalConnect({
        type: CombinationLauncherPosition, key: 'StarwardCombinationLauncherPosition',
        defaultCreator: () => new CombinationLauncherPosition()
      }) ?? CombinationLauncherPosition.fallback;
    } catch {
      return CombinationLauncherPosition.fallback;
    }
  }
}
