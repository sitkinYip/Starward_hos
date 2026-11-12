import { PersistenceV2 } from '@kit.ArkUI';

/** Device-local presentation preference: no account, assignment or clue data. */
@ObservedV2
export class CombinationLauncherPosition {
  @Trace x: number = 1;
  @Trace y: number = 0.72;

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
