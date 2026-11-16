import { PersistenceV2 } from '@kit.ArkUI';

/** The dock position is device-local and contains no notification content. */
@ObservedV2
export class JourneyLauncherPosition {
  @Trace x: number = 0;
  @Trace y: number = 1;

  private static fallback: JourneyLauncherPosition = new JourneyLauncherPosition();

  static load(): JourneyLauncherPosition {
    try {
      return PersistenceV2.globalConnect({
        type: JourneyLauncherPosition, key: 'StarwardJourneyLauncherPosition',
        defaultCreator: () => new JourneyLauncherPosition()
      }) ?? JourneyLauncherPosition.fallback;
    } catch {
      return JourneyLauncherPosition.fallback;
    }
  }
}
