import { describe, expect, it } from '@ohos/hypium';
import { PushStatus } from '../main/ets/business/PushRegistration';
import { PushPermissionFlow, PushPermissionPlatform } from '../main/ets/features/PushPermissionFlow';

class Gate<T> {
  readonly entered: Promise<void>;
  readonly result: Promise<T>;
  private enter: () => void = () => {};
  private resolve: (value: T) => void = (_value: T) => {};

  constructor() {
    this.entered = new Promise<void>((resolve: () => void) => { this.enter = resolve; });
    this.result = new Promise<T>((resolve: (value: T) => void) => { this.resolve = resolve; });
  }

  hold(): Promise<T> {
    this.enter();
    return this.result;
  }

  finish(value: T): void { this.resolve(value); }
}

class TestPlatform implements PushPermissionPlatform {
  permissionGate: Gate<boolean> | null = null;
  settingsGate: Gate<boolean> | null = null;
  listener: (() => void) | null = null;
  unsubscribed: number = 0;

  claimInitialPermissionPrompt(): boolean { return false; }
  async requestPermission(): Promise<boolean> { return true; }

  openSettings(): Promise<boolean> {
    const gate: Gate<boolean> | null = this.settingsGate;
    this.settingsGate = null;
    return gate === null ? Promise.resolve(true) : gate.hold();
  }

  isPermissionEnabled(): Promise<boolean> {
    const gate: Gate<boolean> | null = this.permissionGate;
    this.permissionGate = null;
    return gate === null ? Promise.resolve(true) : gate.hold();
  }

  watchTokenUpdates(callback: () => void): () => void {
    this.listener = callback;
    return () => {
      if (this.listener === callback) { this.listener = null; }
      this.unsubscribed++;
    };
  }
}

class FlowFixture {
  readonly platform: TestPlatform = new TestPlatform();
  readonly forceFlags: boolean[] = [];
  readonly flow: PushPermissionFlow;
  owner: string = 'account-a:1';
  foreground: boolean = true;
  registrationGate: Gate<PushStatus> | null = null;

  constructor() {
    this.flow = new PushPermissionFlow(this.platform, () => this.owner, () => this.foreground,
      (force: boolean) => this.register(force));
  }

  private register(force: boolean): Promise<PushStatus> {
    this.forceFlags.push(force);
    const gate: Gate<PushStatus> | null = this.registrationGate;
    this.registrationGate = null;
    return gate === null ? Promise.resolve<PushStatus>('ready') : gate.hold();
  }
}

export default function pushPermissionFlowTests(): void {
  describe('PushPermissionFlow', () => {
    it('consumes a rotation received while permission is pending in that registration', 0, async () => {
      const fixture: FlowFixture = new FlowFixture();
      await fixture.flow.sync();
      const permission: Gate<boolean> = new Gate<boolean>();
      fixture.platform.permissionGate = permission;
      const pending: Promise<void> = fixture.flow.sync();
      await permission.entered;
      fixture.platform.listener?.();
      permission.finish(true);
      await pending;
      expect(fixture.forceFlags.length).assertEqual(2);
      expect(fixture.forceFlags[0]).assertFalse();
      expect(fixture.forceFlags[1]).assertTrue();
      expect(fixture.flow.busy).assertFalse();
    });

    it('coalesces rotations during the registration request into one forced follow-up', 0, async () => {
      const fixture: FlowFixture = new FlowFixture();
      await fixture.flow.sync();
      const request: Gate<PushStatus> = new Gate<PushStatus>();
      fixture.registrationGate = request;
      const pending: Promise<void> = fixture.flow.sync();
      await request.entered;
      fixture.platform.listener?.();
      fixture.platform.listener?.();
      const followUp: Gate<PushStatus> = new Gate<PushStatus>();
      fixture.registrationGate = followUp;
      request.finish('ready');
      await pending;
      await followUp.entered;
      expect(fixture.forceFlags.length).assertEqual(3);
      expect(fixture.forceFlags[1]).assertFalse();
      expect(fixture.forceFlags[2]).assertTrue();
      followUp.finish('ready');
      await followUp.result;
      expect(fixture.flow.busy).assertFalse();
      expect(fixture.forceFlags.length).assertEqual(3);
    });

    it('rejects a stale account result and queued watcher callback after reset', 0, async () => {
      const fixture: FlowFixture = new FlowFixture();
      await fixture.flow.sync();
      const staleListener: (() => void) | null = fixture.platform.listener;
      const request: Gate<PushStatus> = new Gate<PushStatus>();
      fixture.registrationGate = request;
      const pending: Promise<void> = fixture.flow.sync();
      await request.entered;
      fixture.owner = 'account-a:2';
      fixture.flow.reset();
      staleListener?.();
      request.finish('off');
      await pending;
      expect(fixture.platform.unsubscribed).assertEqual(1);
      expect(fixture.forceFlags.length).assertEqual(2);
      expect(fixture.flow.status).assertEqual('unknown');
      expect(fixture.flow.permission === null).assertTrue();
      expect(fixture.flow.busy).assertFalse();
      await fixture.flow.sync();
      expect(fixture.forceFlags[2]).assertFalse();
    });

    it('retains rotation across a temporary authorization gate', 0, async () => {
      const fixture: FlowFixture = new FlowFixture();
      await fixture.flow.sync();
      fixture.owner = '';
      fixture.platform.listener?.();
      await fixture.flow.sync();
      expect(fixture.forceFlags.length).assertEqual(1);
      fixture.owner = 'account-a:1';
      await fixture.flow.sync();
      expect(fixture.forceFlags.length).assertEqual(2);
      expect(fixture.forceFlags[1]).assertTrue();
    });

    it('defers settings synchronization until the authorized account is foreground', 0, async () => {
      const fixture: FlowFixture = new FlowFixture();
      const systemSettings: Gate<boolean> = new Gate<boolean>();
      fixture.platform.settingsGate = systemSettings;
      const pending: Promise<void> = fixture.flow.sync('settings');
      await systemSettings.entered;
      fixture.foreground = false;
      systemSettings.finish(true);
      await pending;
      expect(fixture.forceFlags.length).assertEqual(0);
      expect(fixture.flow.permission === true).assertTrue();
      fixture.foreground = true;
      await fixture.flow.sync();
      expect(fixture.forceFlags.length).assertEqual(1);
      expect(fixture.forceFlags[0]).assertTrue();
    });
  });
}
