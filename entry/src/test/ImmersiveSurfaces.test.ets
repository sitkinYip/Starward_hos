import { describe, expect, it } from '@ohos/hypium';
import { ImmersiveSurfaces } from '../main/ets/platform/ImmersiveSurfaces';

export default function immersiveSurfacesTests(): void {
  describe('ImmersiveSurfacesTests', () => {
    it('overlappingDarkSurfacesRequireTheLastLeaseAndIgnoreRepeatedRelease', 0, () => {
      ImmersiveSurfaces.reset();
      const states: boolean[] = [];
      const unsubscribe: () => void = ImmersiveSurfaces.subscribe((dark: boolean): void => { states.push(dark); });
      let first: number = 0;
      let second: number = 0;
      try {
        expect(states.length).assertEqual(1);
        expect(states[0]).assertFalse();
        first = ImmersiveSurfaces.acquireDark();
        second = ImmersiveSurfaces.acquireDark();
        expect(second > first).assertTrue();
        expect(states.length).assertEqual(2);
        expect(states[1]).assertTrue();
        ImmersiveSurfaces.releaseDark(first);
        ImmersiveSurfaces.releaseDark(first);
        expect(states.length).assertEqual(2);
        ImmersiveSurfaces.releaseDark(second);
        ImmersiveSurfaces.releaseDark(second);
        expect(states.length).assertEqual(3);
        expect(states[2]).assertFalse();
      } finally {
        unsubscribe();
        ImmersiveSurfaces.releaseDark(first);
        ImmersiveSurfaces.releaseDark(second);
        ImmersiveSurfaces.reset();
      }
    });

    it('windowResetInvalidatesOldIdsWithoutReusingThemOrReleasingTheNewSurface', 0, () => {
      ImmersiveSurfaces.reset();
      const old: number = ImmersiveSurfaces.acquireDark();
      ImmersiveSurfaces.reset();
      const states: boolean[] = [];
      const unsubscribe: () => void = ImmersiveSurfaces.subscribe((dark: boolean): void => { states.push(dark); });
      let current: number = 0;
      try {
        expect(states.length).assertEqual(1);
        expect(states[0]).assertFalse();
        current = ImmersiveSurfaces.acquireDark();
        expect(current > old).assertTrue();
        expect(states.length).assertEqual(2);
        expect(states[1]).assertTrue();
        ImmersiveSurfaces.releaseDark(old);
        ImmersiveSurfaces.releaseDark(old);
        expect(states.length).assertEqual(2);
        ImmersiveSurfaces.releaseDark(current);
        expect(states.length).assertEqual(3);
        expect(states[2]).assertFalse();
      } finally {
        unsubscribe();
        ImmersiveSurfaces.releaseDark(old);
        ImmersiveSurfaces.releaseDark(current);
        ImmersiveSurfaces.reset();
      }
    });

    it('newSubscriberImmediatelyObservesTheActiveSurfaceAndUnsubscribeIsIdempotent', 0, () => {
      ImmersiveSurfaces.reset();
      const active: number = ImmersiveSurfaces.acquireDark();
      const states: boolean[] = [];
      const unsubscribe: () => void = ImmersiveSurfaces.subscribe((dark: boolean): void => { states.push(dark); });
      try {
        expect(states.length).assertEqual(1);
        expect(states[0]).assertTrue();
        unsubscribe();
        unsubscribe();
        ImmersiveSurfaces.releaseDark(active);
        expect(states.length).assertEqual(1);
      } finally {
        unsubscribe();
        ImmersiveSurfaces.releaseDark(active);
        ImmersiveSurfaces.reset();
      }
    });
  });
}
