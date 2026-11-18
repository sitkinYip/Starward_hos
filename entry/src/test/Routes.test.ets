import { describe, expect, it } from '@ohos/hypium';
import { LaunchRoutes, PUSH_OPEN_ACTION, PushRoute } from '../main/ets/platform/LaunchRoutes';

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

    it('acceptsAllowlistedPushTargetsAndDeduplicatesPerProfile', 0, () => {
      LaunchRoutes.clear();
      const parameters: Record<string, Object> = {
        'starwardPushVersion': '1', 'starwardPushKind': 'assignment', 'starwardPushEventId': 'event_1',
        'starwardPushProfileId': 'opaque-profile-first', 'starwardPushTargetId': 'assignment_1'
      };
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, parameters)).assertTrue();
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, parameters)).assertFalse();
      const route: PushRoute | null = LaunchRoutes.nextPush();
      expect(route?.target).assertEqual('assignment_1');
      if (route !== null) { expect(LaunchRoutes.consumePush(route)).assertTrue(); }
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, parameters)).assertFalse();
      parameters['starwardPushProfileId'] = 'opaque-profile-second';
      parameters['starwardPushKind'] = 'inbox';
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, parameters)).assertTrue();
      expect(LaunchRoutes.nextPush()?.target).assertEqual('');
      LaunchRoutes.clear();
    });

    it('rejectsUnknownPushActionsVersionsAndExternalTargets', 0, () => {
      LaunchRoutes.clear();
      const parameters: Record<string, Object> = {
        'starwardPushVersion': '1', 'starwardPushKind': 'assignment', 'starwardPushEventId': 'event_2',
        'starwardPushProfileId': 'opaque-profile-first', 'starwardPushTargetId': 'https://example.com/'
      };
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, parameters)).assertFalse();
      parameters['starwardPushTargetId'] = 'assignment_2';
      expect(LaunchRoutes.receivePush('ohos.want.action.home', parameters)).assertFalse();
      parameters['starwardPushVersion'] = 1;
      expect(LaunchRoutes.receivePush(PUSH_OPEN_ACTION, parameters)).assertFalse();
      expect(LaunchRoutes.nextPush()).assertNull();
    });
  });
}
