import { describe, expect, it } from '@ohos/hypium';
import { PushBindingApi, PushDevice, PushLease, PushRegistration, PushStatus } from '../main/ets/business/PushRegistration';

const FIRST_OWNER: string = 'fixture-player-a';
const SECOND_OWNER: string = 'fixture-player-b';

class RegistrationGate {
  readonly entered: Promise<void>;
  readonly receipt: Promise<string>;
  private onEnter: () => void = () => {};
  private onReceipt: (ticket: string) => void = () => {};

  constructor() {
    this.entered = new Promise<void>((resolve: () => void) => { this.onEnter = resolve; });
    this.receipt = new Promise<string>((resolve: (ticket: string) => void) => { this.onReceipt = resolve; });
  }

  hold(): Promise<string> {
    this.onEnter();
    return this.receipt;
  }

  finish(ticket: string): void { this.onReceipt(ticket); }
}

class TestPushDevice implements PushDevice {
  allowed: boolean = true;
  token: string = 'fixture-token-a';
  boundProfile: string = '';
  lease: PushLease | null = null;
  tokenReads: number = 0;
  installationReads: number = 0;
  failSave: boolean = false;
  private profileNumber: number = 0;

  async isPermissionEnabled(): Promise<boolean> { return this.allowed; }
  async getToken(): Promise<string> { this.tokenReads++; return this.token; }
  async deleteToken(): Promise<void> { this.boundProfile = ''; }
  async getInstallationId(): Promise<string> { this.installationReads++; return 'fixture-installation'; }
  newProfileId(): string { return 'fixture-profile-' + ++this.profileNumber; }
  async bindProfile(id: string): Promise<void> { this.boundProfile = id; }
  async unbindProfile(id: string): Promise<void> { if (this.boundProfile === id) { this.boundProfile = ''; } }
  async readLease(): Promise<PushLease | null> { return this.lease; }
  async saveLease(lease: PushLease | null): Promise<void> {
    if (this.failSave) { throw new Error('Fixture storage unavailable'); }
    this.lease = lease;
  }
}

class TestPushApi implements PushBindingApi {
  readonly registrations: string[] = [];
  readonly attemptedRevocations: string[] = [];
  readonly unregistrations: string[] = [];
  readonly timeline: string[] = [];
  failRevoke: boolean = false;
  gate: RegistrationGate | null = null;
  private readonly device: TestPushDevice;

  constructor(device: TestPushDevice) { this.device = device; }

  async register(installationId: string, token: string, profileId: string): Promise<string> {
    // A server receipt is useful only after this profile is bound on the device and can be cleaned up after restart.
    if (this.device.boundProfile !== profileId || this.device.lease?.profileId !== profileId ||
      this.device.lease?.revoking) {
      throw new Error('Unexpected server registration before the local binding was made durable');
    }
    this.timeline.push('register:' + profileId);
    this.registrations.push([installationId, token, profileId].join(':'));
    const gate: RegistrationGate | null = this.gate;
    if (gate !== null) { return gate.hold(); }
    return 'fixture-ticket-' + this.registrations.length;
  }

  async unregister(installationId: string): Promise<void> { this.unregistrations.push(installationId); }

  async revoke(installationId: string, ticket: string): Promise<void> {
    this.timeline.push('revoke:' + ticket);
    this.attemptedRevocations.push([installationId, ticket].join(':'));
    if (this.failRevoke) { throw new Error('Fixture service unavailable'); }
  }
}

export default function pushRegistrationTests(): void {
  describe('PushRegistration', () => {
    it('deniedPermissionDoesNotRequestIdentityTokenOrServerBinding', 0, async () => {
      const device: TestPushDevice = new TestPushDevice();
      const api: TestPushApi = new TestPushApi(device);
      const registration: PushRegistration = new PushRegistration(device);
      device.allowed = false;

      expect(await registration.sync(api, true, FIRST_OWNER)).assertEqual('off');
      expect(device.tokenReads).assertEqual(0);
      expect(device.installationReads).assertEqual(0);
      expect(api.timeline.length).assertEqual(0);
      expect(device.boundProfile).assertEqual('');
      expect(device.lease === null).assertTrue();
    });

    it('aBindingIsUsableOnlyAfterDeviceBindingAndServerReceipt', 0, async () => {
      const device: TestPushDevice = new TestPushDevice();
      const api: TestPushApi = new TestPushApi(device);
      const registration: PushRegistration = new PushRegistration(device);
      const gate: RegistrationGate = new RegistrationGate();
      api.gate = gate;

      const syncing: Promise<PushStatus> = registration.sync(api, true, FIRST_OWNER);
      try {
        expect(await Promise.race([gate.entered.then(() => true), syncing.then(() => false)])).assertTrue();
        expect(api.registrations[0]).assertEqual('fixture-installation:fixture-token-a:fixture-profile-1');
        expect(await registration.matchesProfile('fixture-profile-1', FIRST_OWNER)).assertFalse();
      } finally {
        gate.finish('fixture-ticket-1');
      }
      expect(await syncing).assertEqual('ready');
      expect(await registration.matchesProfile('fixture-profile-1', FIRST_OWNER)).assertTrue();
      expect(await registration.matchesProfile('different-profile', FIRST_OWNER)).assertFalse();
      expect(await registration.matchesProfile('fixture-profile-1', SECOND_OWNER)).assertFalse();
    });

    it('logoutDuringRegisterRevokesTheLateReceiptAndDoesNotRestoreTheBinding', 0, async () => {
      const device: TestPushDevice = new TestPushDevice();
      const api: TestPushApi = new TestPushApi(device);
      const registration: PushRegistration = new PushRegistration(device);
      const gate: RegistrationGate = new RegistrationGate();
      api.gate = gate;

      const oldSync: Promise<PushStatus> = registration.sync(api, true, FIRST_OWNER);
      expect(await Promise.race([gate.entered.then(() => true), oldSync.then(() => false)])).assertTrue();
      const cleanup: Promise<void> = registration.remove(api, FIRST_OWNER);
      gate.finish('late-fixture-ticket');

      expect(await oldSync).assertEqual('unknown');
      await cleanup;
      expect(api.attemptedRevocations.join(',')).assertEqual('fixture-installation:late-fixture-ticket');
      expect(api.unregistrations.length).assertEqual(0);
      expect(device.boundProfile).assertEqual('');
      expect(device.lease === null).assertTrue();
      expect(await registration.matchesProfile('fixture-profile-1', FIRST_OWNER)).assertFalse();
    });

    it('failedRevokeCanBeRetriedAcrossCoordinatorRestartBeforeCreatingAnotherBinding', 0, async () => {
      const device: TestPushDevice = new TestPushDevice();
      const api: TestPushApi = new TestPushApi(device);
      const original: PushRegistration = new PushRegistration(device);
      expect(await original.sync(api, true, FIRST_OWNER)).assertEqual('ready');

      api.failRevoke = true;
      let failed: boolean = false;
      try {
        await original.remove(api, FIRST_OWNER);
      } catch {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(device.boundProfile).assertEqual('');
      expect(device.lease?.revokeTicket).assertEqual('fixture-ticket-1');
      expect(device.lease?.revoking).assertTrue();

      const restored: PushRegistration = new PushRegistration(device);
      expect(await restored.matchesProfile('fixture-profile-1', FIRST_OWNER)).assertFalse();
      api.failRevoke = false;
      expect(await restored.sync(api, true, FIRST_OWNER)).assertEqual('ready');
      expect(api.timeline.join(',')).assertEqual('register:fixture-profile-1,revoke:fixture-ticket-1,' +
        'revoke:fixture-ticket-1,register:fixture-profile-2');
      expect(await restored.matchesProfile('fixture-profile-2', FIRST_OWNER)).assertTrue();
    });

    it('switchingAccountDisownsTheFormerProfileEvenIfLogoutCouldNotMarkItsLease', 0, async () => {
      const device: TestPushDevice = new TestPushDevice();
      const api: TestPushApi = new TestPushApi(device);
      const original: PushRegistration = new PushRegistration(device);
      expect(await original.sync(api, true, FIRST_OWNER)).assertEqual('ready');

      device.failSave = true;
      let failed: boolean = false;
      try {
        await original.remove(api, FIRST_OWNER);
      } catch {
        failed = true;
      }
      expect(failed).assertTrue();
      expect(device.lease?.revoking).assertFalse();
      expect(device.lease?.ownerId).assertEqual(FIRST_OWNER);

      device.failSave = false;
      const next: PushRegistration = new PushRegistration(device);
      expect(await next.matchesProfile('fixture-profile-1', SECOND_OWNER)).assertFalse();
      expect(await next.sync(api, true, SECOND_OWNER)).assertEqual('ready');
      expect(api.timeline.join(',')).assertEqual('register:fixture-profile-1,revoke:fixture-ticket-1,' +
        'register:fixture-profile-2');
      expect(await next.matchesProfile('fixture-profile-2', SECOND_OWNER)).assertTrue();
      expect(await next.matchesProfile('fixture-profile-2', FIRST_OWNER)).assertFalse();
    });

    it('routineSyncDoesNotFetchTheTokenAgainButForcedSyncCanRotateIt', 0, async () => {
      const device: TestPushDevice = new TestPushDevice();
      const api: TestPushApi = new TestPushApi(device);
      const registration: PushRegistration = new PushRegistration(device);
      expect(await registration.sync(api, false, FIRST_OWNER)).assertEqual('ready');

      device.token = 'fixture-token-b';
      expect(await registration.sync(api, false, FIRST_OWNER)).assertEqual('ready');
      expect(device.tokenReads).assertEqual(1);
      expect(api.registrations.length).assertEqual(1);

      expect(await registration.sync(api, true, FIRST_OWNER)).assertEqual('ready');
      expect(api.registrations[1]).assertEqual('fixture-installation:fixture-token-b:fixture-profile-1');
      expect(device.lease?.revokeTicket).assertEqual('fixture-ticket-2');
      expect(api.attemptedRevocations.length).assertEqual(0);
    });
  });
}
