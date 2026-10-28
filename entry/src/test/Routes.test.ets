import { describe, expect, it } from '@ohos/hypium';
import { LaunchRoutes } from '../main/ets/platform/LaunchRoutes';

export default function routeTests(): void {
  describe('Routes', () => {
    it('onlyAcceptsKnownPrivateAssignmentRoutes', 0, () => {
      LaunchRoutes.clear();
      expect(LaunchRoutes.receive('https://example.com/assignment/abc')).assertFalse();
      expect(LaunchRoutes.receive('starward://assignment/abc?endpoint=https://example.com')).assertFalse();
      expect(LaunchRoutes.receive('starward://assignment/../admin')).assertFalse();
      expect(LaunchRoutes.receive('starward://assignment/')).assertFalse();
      expect(LaunchRoutes.pending).assertEqual('');
      expect(LaunchRoutes.receive('starward://assignment/assignment1')).assertTrue();
      expect(LaunchRoutes.pending).assertEqual('assignment1');
      expect(LaunchRoutes.take()).assertEqual('assignment1');
      expect(LaunchRoutes.take()).assertEqual('');
    });

    it('notifiesWarmRequestsWithoutDroppingPendingAuthTarget', 0, () => {
      LaunchRoutes.clear();
      let notified: string = '';
      const listener: (id: string) => void = (id: string) => { notified = id; };
      LaunchRoutes.subscribe(listener);
      LaunchRoutes.receive('starward://assignment/a1');
      expect(notified).assertEqual('a1');
      expect(LaunchRoutes.pending).assertEqual('a1');
      LaunchRoutes.unsubscribe(listener);
      LaunchRoutes.clear();
      expect(LaunchRoutes.pending).assertEqual('');
    });
  });
}
