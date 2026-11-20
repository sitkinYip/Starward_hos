import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  NativeQuestBgmBackgroundIO, QuestBgmBackgroundControls, QuestBgmBackgroundIO, QuestBgmBackgroundSession
} from './QuestBgmBackgroundIO';

export { QuestBgmBackgroundControls } from './QuestBgmBackgroundIO';

class BgmBackgroundLease {
  readonly context?: common.UIAbilityContext;
  readonly owner: string;
  session?: QuestBgmBackgroundSession;
  taskId?: number;
  startingTask: boolean = false;
  cancelledDuringStart: number[] = [];
  requested: number = 0;
  completed: number = -1;
  callbacks: number = 0;
  available: boolean = false;

  constructor(context: common.UIAbilityContext | undefined, owner: string) {
    this.context = context;
    this.owner = owner;
  }
}

/** Serializes the native media session and task for one quest/account owner. */
export class QuestBgmBackground {
  private readonly controls: QuestBgmBackgroundControls;
  private readonly io: QuestBgmBackgroundIO;
  private lease?: BgmBackgroundLease;
  private pending: Promise<void> = Promise.resolve();

  constructor(controls: QuestBgmBackgroundControls, io: QuestBgmBackgroundIO = new NativeQuestBgmBackgroundIO()) {
    this.controls = controls;
    this.io = io;
  }

  get isRunning(): boolean {
    const lease: BgmBackgroundLease | undefined = this.lease;
    return lease !== undefined && lease.available && lease.taskId !== undefined &&
      lease.completed === lease.requested;
  }

  async start(context: common.UIAbilityContext | undefined, owner: string): Promise<boolean> {
    if (owner.length === 0) { return false; }
    let lease: BgmBackgroundLease | undefined = this.lease;
    if (lease === undefined || lease.context !== context || lease.owner !== owner) {
      this.release();
      lease = new BgmBackgroundLease(context, owner);
      this.lease = lease;
    }
    const active: BgmBackgroundLease = lease;
    if (this.isRunning) { return true; }
    const revision: number = ++active.requested;
    let started: boolean = false;
    await this.enqueue(async () => {
      if (!this.live(active)) { return; }
      try {
        await this.ensureSession(active);
        if (!this.live(active) || revision !== active.requested || active.session === undefined) { return; }
        if (active.taskId === undefined) {
          active.startingTask = true;
          active.cancelledDuringStart = [];
          try { active.taskId = await active.session.startTask(); } finally { active.startingTask = false; }
          if (active.taskId !== undefined && active.cancelledDuringStart.includes(active.taskId)) {
            active.taskId = undefined;
            active.requested++;
            if (this.live(active)) { this.controls.interrupted(); }
          }
          active.cancelledDuringStart = [];
        }
        if (!this.live(active)) { await this.dispose(active); return; }
        active.completed = revision;
        active.available = revision === active.requested && active.taskId !== undefined;
        started = this.isRunning;
      } catch (error) {
        active.available = false;
        await this.dispose(active);
        hilog.warn(0x0000, 'StarwardBgmBackground', 'Native background playback was not acquired code=%{public}d',
          (error as BusinessError).code ?? 0);
      }
    });
    return started && this.live(active) && revision === active.requested && this.isRunning;
  }

  async setPlaying(playing: boolean): Promise<void> {
    const active: BgmBackgroundLease | undefined = this.lease;
    if (active === undefined) { return; }
    if (!playing) { active.available = false; active.requested++; }
    const revision: number = active.requested;
    await this.enqueue(async () => {
      if (!this.live(active)) { return; }
      if (!playing) { await this.stopTask(active); }
      // A queued playing update must not overwrite a subsequent pause or owner change.
      if (!this.live(active) || revision !== active.requested) { return; }
      await active.session?.setPlaying(playing);
    });
  }

  release(): void {
    const active: BgmBackgroundLease | undefined = this.lease;
    this.lease = undefined;
    if (active === undefined) { return; }
    active.available = false;
    active.requested++;
    active.callbacks++;
    this.enqueue(async () => { await this.dispose(active); });
  }

  private live(active: BgmBackgroundLease): boolean { return this.lease === active; }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next: Promise<void> = this.pending.then(operation);
    this.pending = next.catch((error: BusinessError) => {
      hilog.warn(0x0000, 'StarwardBgmBackground', 'Native background playback cleanup was incomplete code=%{public}d',
        error.code ?? 0);
    });
    return this.pending;
  }

  private async ensureSession(active: BgmBackgroundLease): Promise<void> {
    if (active.session !== undefined) { return; }
    const token: number = ++active.callbacks;
    const valid = (): boolean => this.live(active) && active.callbacks === token;
    const controls: QuestBgmBackgroundControls = {
      play: () => { if (valid()) { this.controls.play(); } },
      pause: () => { if (valid()) { this.controls.pause(); } },
      stop: () => { if (valid()) { this.controls.stop(); } },
      interrupted: () => { if (valid()) { this.controls.interrupted(); } }
    };
    active.session = await this.io.open(active.context, controls, (taskId: number) => {
      if (!valid()) { return; }
      if (active.taskId !== taskId) {
        if (active.startingTask) { active.cancelledDuringStart.push(taskId); }
        return;
      }
      active.taskId = undefined;
      active.available = false;
      active.requested++;
      this.controls.interrupted();
    });
    if (!this.live(active)) { await this.dispose(active); }
    else if (active.session === undefined) { active.callbacks++; }
  }

  private async stopTask(active: BgmBackgroundLease): Promise<void> {
    const taskId: number | undefined = active.taskId;
    active.taskId = undefined;
    active.available = false;
    if (taskId !== undefined) { await active.session?.stopTask(taskId); }
  }

  private async dispose(active: BgmBackgroundLease): Promise<void> {
    active.callbacks++;
    await this.stopTask(active);
    const session: QuestBgmBackgroundSession | undefined = active.session;
    active.session = undefined;
    await session?.destroy();
  }
}
