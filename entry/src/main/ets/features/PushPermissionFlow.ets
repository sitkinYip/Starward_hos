import { PushStatus } from '../business/PushRegistration';

export type PushAction = 'sync' | 'initial' | 'settings' | 'retry';

export interface PushPermissionPlatform {
  claimInitialPermissionPrompt(): boolean;
  requestPermission(): Promise<boolean>;
  openSettings(): Promise<boolean>;
  isPermissionEnabled(): Promise<boolean>;
  watchTokenUpdates(callback: () => void): (() => void) | null;
}

/** Connects system authorization and token updates to the current account registration. */
@ObservedV2
export class PushPermissionFlow {
  @Trace busy: boolean = false;
  @Trace permission: boolean | null = null;
  @Trace status: PushStatus = 'unknown';
  @Trace settingsError: string = '';
  @Trace promptChecked: boolean = false;
  private owner: string = '';
  private generation: number = 0;
  private watchRevision: number = 0;
  private tokenDirty: boolean = false;
  private unsubscribeToken: (() => void) | null = null;
  private readonly platform: PushPermissionPlatform;
  private readonly accountOwner: () => string;
  private readonly foreground: () => boolean;
  private readonly register: (force: boolean) => Promise<PushStatus>;

  constructor(platform: PushPermissionPlatform, accountOwner: () => string, foreground: () => boolean,
    register: (force: boolean) => Promise<PushStatus>) {
    this.platform = platform;
    this.accountOwner = accountOwner;
    this.foreground = foreground;
    this.register = register;
  }

  reset(): void {
    this.generation++;
    this.owner = '';
    this.stopWatching();
    this.busy = false;
    this.permission = null;
    this.status = 'unknown';
    this.settingsError = '';
  }

  async sync(action: PushAction = 'sync'): Promise<void> {
    const owner: string = this.accountOwner();
    if (owner.length === 0 || !this.foreground()) { return; }
    if (this.owner !== owner) {
      this.reset();
      this.owner = owner;
    }
    if (this.busy) { return; }
    const generation: number = this.generation;
    this.busy = true;
    try {
      if (action === 'initial' || action === 'settings') {
        await this.openSystemControl(action, generation, owner);
      }
      if (!this.canRegister(action, generation, owner)) { return; }
      const allowed: boolean | null = await this.platform.isPermissionEnabled().catch(() => null);
      if (!this.isCurrent(generation, owner)) { return; }
      this.permission = allowed;
      if (!this.canRegister(action, generation, owner)) { return; }

      // Consume updates only when a synchronization can use them. Events that
      // arrive during this request remain dirty for the next synchronization.
      const force: boolean = this.tokenDirty || action === 'retry';
      this.tokenDirty = false;
      const status: PushStatus = await this.register(force);
      if (!this.isCurrent(generation, owner)) { return; }
      this.status = status;
      if (status === 'ready' || status === 'off') { this.permission = status === 'ready'; }
      if (status === 'ready') {
        this.watchTokens(generation, owner);
      } else if (status === 'off' || status === 'unavailable') {
        this.stopWatching();
      }
    } catch {
      if (this.isCurrent(generation, owner)) { this.status = 'retry'; }
    } finally {
      if (generation === this.generation) {
        this.busy = false;
        if (this.tokenDirty && this.isCurrent(generation, owner) && this.foreground()) { void this.sync(); }
      }
    }
  }

  private async openSystemControl(action: PushAction, generation: number, owner: string): Promise<void> {
    if (action === 'initial') {
      this.promptChecked = true;
      if (!this.platform.claimInitialPermissionPrompt()) { return; }
    } else {
      this.settingsError = '';
    }
    try {
      const allowed: boolean = await (action === 'initial' ? this.platform.requestPermission() :
        this.platform.openSettings());
      if (this.isCurrent(generation, owner)) { this.permission = allowed; }
    } catch {
      if (action === 'settings' && this.isCurrent(generation, owner)) {
        this.settingsError = '暂时无法打开系统通知设置，请重试。';
      }
    }
  }

  private isCurrent(generation: number, owner: string): boolean {
    return generation === this.generation && owner === this.accountOwner();
  }

  private canRegister(action: PushAction, generation: number, owner: string): boolean {
    if (!this.isCurrent(generation, owner)) { return false; }
    if (this.foreground()) { return true; }
    // Settings can settle before the application returns to the foreground.
    if (action !== 'sync') { this.tokenDirty = true; }
    return false;
  }

  private watchTokens(generation: number, owner: string): void {
    if (this.unsubscribeToken !== null) { return; }
    const revision: number = ++this.watchRevision;
    this.unsubscribeToken = this.platform.watchTokenUpdates(() => {
      if (revision !== this.watchRevision || generation !== this.generation) { return; }
      const currentOwner: string = this.accountOwner();
      if (currentOwner.length > 0 && owner !== currentOwner) { return; }
      // A temporary authorization gate does not release the account's watcher.
      this.tokenDirty = true;
      if (currentOwner === owner && this.foreground()) { void this.sync(); }
    });
  }

  private stopWatching(): void {
    this.watchRevision++;
    const unsubscribe: (() => void) | null = this.unsubscribeToken;
    this.unsubscribeToken = null;
    this.tokenDirty = false;
    unsubscribe?.();
  }
}
