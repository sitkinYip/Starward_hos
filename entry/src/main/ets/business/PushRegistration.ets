export class PushLease {
  readonly profileId: string;
  readonly revokeTicket: string;
  readonly revoking: boolean;
  readonly ownerId: string;

  constructor(profileId: string, revokeTicket: string, revoking: boolean, ownerId: string) {
    this.profileId = profileId;
    this.revokeTicket = revokeTicket;
    this.revoking = revoking;
    this.ownerId = ownerId;
  }
}

export interface PushDevice {
  isPermissionEnabled(): Promise<boolean>;
  getToken(): Promise<string>;
  deleteToken(): Promise<void>;
  getInstallationId(): Promise<string>;
  newProfileId(): string;
  bindProfile(id: string): Promise<void>;
  unbindProfile(id: string): Promise<void>;
  readLease(): Promise<PushLease | null>;
  saveLease(lease: PushLease | null): Promise<void>;
}

export interface PushBindingApi {
  register(installationId: string, token: string, profileId: string): Promise<string>;
  unregister(installationId: string): Promise<void>;
  revoke(installationId: string, ticket: string): Promise<void>;
}

export type PushStatus = 'unknown' | 'off' | 'ready' | 'retry';

/** Serializes SDK and HTTP writes across account and permission changes. */
export class PushRegistration {
  private work: Promise<void> = Promise.resolve();
  private revision: number = 0;
  private renewedAt: number = 0;
  private readonly device: PushDevice;

  constructor(device: PushDevice) { this.device = device; }

  private enqueue<T>(action: () => Promise<T>): Promise<T> {
    const pending: Promise<T> = this.work.then(action);
    this.work = pending.then(() => {}, () => {});
    return pending;
  }

  sync(api: PushBindingApi, force: boolean, ownerId: string): Promise<PushStatus> {
    const revision: number = this.revision;
    return this.enqueue(async (): Promise<PushStatus> => {
      if (revision !== this.revision) { return 'unknown'; }
      try {
        const permitted: boolean = await this.device.isPermissionEnabled();
        if (revision !== this.revision) { return 'unknown'; }
        let lease: PushLease | null = await this.device.readLease();
        if (!permitted || lease?.revoking || (lease !== null && lease.ownerId !== ownerId)) {
          try {
            await this.cleanup(api, lease, lease?.ownerId === ownerId);
          } catch {
            // Keep the settings entry usable even when an offline revoke is still pending.
            return revision !== this.revision ? 'unknown' : permitted ? 'retry' : 'off';
          }
          lease = null;
        }
        if (revision !== this.revision) { return 'unknown'; }
        if (!permitted) { return 'off'; }
        if (!force && lease !== null && Date.now() - this.renewedAt < 12 * 60 * 60 * 1000) { return 'ready'; }
        const installationId: string = await this.device.getInstallationId();
        const token: string = await this.device.getToken();
        if (revision !== this.revision) { return 'unknown'; }
        if (lease === null) {
          lease = new PushLease(this.device.newProfileId(), '', false, ownerId);
          // Persist before touching Push Kit; a process kill can occur between requests.
          await this.device.saveLease(lease);
        }
        if (revision !== this.revision) { return 'unknown'; }
        await this.device.bindProfile(lease.profileId);
        if (revision !== this.revision) { return 'unknown'; }
        const ticket: string = await api.register(installationId, token, lease.profileId);
        // Even after signout, save the receipt so the queued cleanup can revoke this exact binding.
        await this.device.saveLease(new PushLease(lease.profileId, ticket, false, ownerId));
        if (revision !== this.revision) { return 'unknown'; }
        this.renewedAt = Date.now();
        return 'ready';
      } catch {
        return revision === this.revision ? 'retry' : 'unknown';
      }
    });
  }

  invalidate(): void {
    this.revision++;
    this.renewedAt = 0;
  }

  remove(api: PushBindingApi, ownerId: string): Promise<void> {
    this.invalidate();
    return this.enqueue(async (): Promise<void> => {
      const lease: PushLease | null = await this.device.readLease();
      await this.cleanup(api, lease, lease?.ownerId === ownerId);
    });
  }

  retryRemoval(api: PushBindingApi): Promise<void> {
    return this.enqueue(async (): Promise<void> => {
      const lease: PushLease | null = await this.device.readLease();
      if (lease?.revoking) { await this.cleanup(api, lease, false); }
    });
  }

  async matchesProfile(profileId: string, ownerId: string): Promise<boolean> {
    const revision: number = this.revision;
    try {
      if (!await this.device.isPermissionEnabled()) { return false; }
      const lease: PushLease | null = await this.device.readLease();
      return revision === this.revision && lease !== null && !lease.revoking && lease.revokeTicket.length > 0 &&
        lease.profileId === profileId && lease.ownerId === ownerId;
    } catch {
      return false;
    }
  }

  private async cleanup(api: PushBindingApi, lease: PushLease | null, ownsLease: boolean): Promise<void> {
    this.renewedAt = 0;
    if (lease === null) { return; }
    if (!lease.revoking) {
      await this.device.saveLease(new PushLease(lease.profileId, lease.revokeTicket, true, lease.ownerId));
    }
    const platform: Promise<void> = this.device.unbindProfile(lease.profileId).catch(() => this.device.deleteToken());
    const backend: Promise<void> = this.device.getInstallationId().then((id: string): Promise<void> => {
      if (lease.revokeTicket.length > 0) { return api.revoke(id, lease.revokeTicket); }
      return ownsLease ? api.unregister(id) : Promise.resolve();
    });
    const results = await Promise.allSettled([platform, backend]);
    if (results[0].status === 'rejected' || results[1].status === 'rejected') {
      throw new Error('Push cleanup pending');
    }
    await this.device.saveLease(null);
  }
}
