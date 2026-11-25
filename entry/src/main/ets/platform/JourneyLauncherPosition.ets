import { PersistenceV2 } from '@kit.ArkUI';
import { QUEST_FLOATING_DOCK_START_Y } from '../business/QuestBgmDock';

/** The dock position is device-local and contains no notification content. */
@ObservedV2
export class JourneyLauncherPosition {
  @Trace x: number = 0;
  @Trace y: number = QUEST_FLOATING_DOCK_START_Y;

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
