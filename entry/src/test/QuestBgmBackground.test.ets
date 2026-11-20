import { common } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { QuestBgmBackground } from '../main/ets/platform/QuestBgmBackground';
import {
  QuestBgmBackgroundControls, QuestBgmBackgroundIO, QuestBgmBackgroundSession
} from '../main/ets/platform/QuestBgmBackgroundIO';

class BackgroundGate<T> {
  readonly promise: Promise<T>;
  finish: (value: T) => void = (_value: T): void => {};

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void) => { this.finish = resolve; });
  }
}

class FakeBackgroundSession implements QuestBgmBackgroundSession {
  readonly controls: QuestBgmBackgroundControls;
  readonly cancelled: (taskId: number) => void;
  readonly destroyed: BackgroundGate<void> = new BackgroundGate<void>();
  readonly taskRequested: BackgroundGate<void> = new BackgroundGate<void>();
  readonly events: string[];
  readonly number: number;
  taskGate?: BackgroundGate<number | undefined>;
  taskStarts: number = 0;
  taskStops: number[] = [];
  tasks: number[] = [];
  cancelledIds: number[] = [];
  states: boolean[] = [];
  destroys: number = 0;

  constructor(number: number, controls: QuestBgmBackgroundControls, cancelled: (taskId: number) => void,
    events: string[]) {
    this.number = number;
    this.controls = controls;
    this.cancelled = cancelled;
    this.events = events;
  }

  async startTask(): Promise<number | undefined> {
    this.taskStarts++;
    this.taskRequested.finish(undefined);
    const gate: BackgroundGate<number | undefined> | undefined = this.taskGate;
    this.taskGate = undefined;
    const taskId: number | undefined = gate === undefined ? this.number * 100 + this.taskStarts : await gate.promise;
    if (taskId !== undefined && !this.cancelledIds.includes(taskId)) { this.tasks.push(taskId); }
    return taskId;
  }

  async stopTask(taskId: number): Promise<void> {
    this.taskStops.push(taskId);
    this.tasks = this.tasks.filter((id: number) => id !== taskId);
  }

  async setPlaying(playing: boolean): Promise<void> { this.states.push(playing); }

  async destroy(): Promise<void> {
    this.destroys++;
    this.events.push('destroy:' + this.number);
    this.destroyed.finish(undefined);
  }

  cancel(taskId: number): void {
    this.cancelledIds.push(taskId);
    this.tasks = this.tasks.filter((id: number) => id !== taskId);
    this.cancelled(taskId);
  }
}

class FakeBackgroundIO implements QuestBgmBackgroundIO {
  readonly opened: BackgroundGate<void> = new BackgroundGate<void>();
  readonly events: string[] = [];
  readonly sessions: FakeBackgroundSession[] = [];
  nextOpen?: BackgroundGate<QuestBgmBackgroundSession | undefined>;
  nextTask?: BackgroundGate<number | undefined>;

  async open(_context: common.UIAbilityContext | undefined, controls: QuestBgmBackgroundControls,
    cancelled: (taskId: number) => void): Promise<QuestBgmBackgroundSession | undefined> {
    const session: FakeBackgroundSession = new FakeBackgroundSession(this.sessions.length + 1, controls,
      cancelled, this.events);
    session.taskGate = this.nextTask;
    this.nextTask = undefined;
    this.sessions.push(session);
    this.events.push('open:' + session.number);
    const gate: BackgroundGate<QuestBgmBackgroundSession | undefined> | undefined = this.nextOpen;
    this.nextOpen = undefined;
    this.opened.finish(undefined);
    return gate === undefined ? session : await gate.promise;
  }
}

class BackgroundFixture {
  readonly io: FakeBackgroundIO = new FakeBackgroundIO();
  readonly background: QuestBgmBackground;
  plays: number = 0;
  pauses: number = 0;
  stops: number = 0;
  interruptions: number = 0;

  constructor() {
    this.background = new QuestBgmBackground({
      play: () => { this.plays++; }, pause: () => { this.pauses++; }, stop: () => { this.stops++; },
      interrupted: () => { this.interruptions++; }
    }, this.io);
  }

  async release(): Promise<void> {
    this.background.release();
    await this.io.sessions[this.io.sessions.length - 1].destroyed.promise;
  }
}

export default function questBgmBackgroundTests(): void {
  describe('QuestBgmBackground', () => {
    it('releasesASessionWhoseCreationFinishesAfterExit', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      const gate: BackgroundGate<QuestBgmBackgroundSession | undefined> =
        new BackgroundGate<QuestBgmBackgroundSession | undefined>();
      fixture.io.nextOpen = gate;
      const pending: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await fixture.io.opened.promise;
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      fixture.background.release();
      expect(fixture.background.isRunning).assertFalse();
      gate.finish(session);
      expect(await pending).assertFalse();
      await session.destroyed.promise;
      expect(session.destroys).assertEqual(1);
      expect(session.taskStarts).assertEqual(0);
      session.controls.play();
      expect(fixture.plays).assertEqual(0);
    });

    it('cancelsATaskGrantedAfterExitBeforeDestroyingTheSession', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      const gate: BackgroundGate<number | undefined> = new BackgroundGate<number | undefined>();
      fixture.io.nextTask = gate;
      const pending: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await fixture.io.opened.promise;
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      await session.taskRequested.promise;
      fixture.background.release();
      gate.finish(41);
      expect(await pending).assertFalse();
      await session.destroyed.promise;
      expect(session.tasks.length).assertEqual(0);
      expect(session.taskStops.join(',')).assertEqual('41');
      expect(session.destroys).assertEqual(1);
    });

    it('serializesOldOwnerCleanupBeforeOpeningANewOwner', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      const gate: BackgroundGate<QuestBgmBackgroundSession | undefined> =
        new BackgroundGate<QuestBgmBackgroundSession | undefined>();
      fixture.io.nextOpen = gate;
      const first: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await fixture.io.opened.promise;
      const old: FakeBackgroundSession = fixture.io.sessions[0];
      fixture.background.release();
      const next: Promise<boolean> = fixture.background.start(undefined, 'account-b:quest-b');
      expect(fixture.io.sessions.length).assertEqual(1);
      gate.finish(old);
      expect(await first).assertFalse();
      expect(await next).assertTrue();
      expect(fixture.io.events.join(',')).assertEqual('open:1,destroy:1,open:2');
      old.controls.play();
      old.controls.pause();
      old.controls.stop();
      old.cancel(201);
      expect(fixture.plays + fixture.pauses + fixture.stops + fixture.interruptions).assertEqual(0);
      expect(fixture.background.isRunning).assertTrue();
      await fixture.release();
    });

    it('removesALateTaskWhenPausedDuringStartAndReusesTheSessionOnPlay', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      const gate: BackgroundGate<number | undefined> = new BackgroundGate<number | undefined>();
      fixture.io.nextTask = gate;
      const pending: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await fixture.io.opened.promise;
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      await session.taskRequested.promise;
      const paused: Promise<void> = fixture.background.setPlaying(false);
      expect(fixture.background.isRunning).assertFalse();
      gate.finish(51);
      expect(await pending).assertFalse();
      await paused;
      expect(session.tasks.length).assertEqual(0);
      expect(session.taskStops.join(',')).assertEqual('51');
      expect(session.destroys).assertEqual(0);
      expect(session.states.join(',')).assertEqual('false');
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      expect(fixture.io.sessions.length).assertEqual(1);
      expect(session.taskStarts).assertEqual(2);
      await fixture.release();
    });

    it('honorsThePauseThenPlayOrderWithoutRetainingAnObsoleteTask', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      const paused: Promise<void> = fixture.background.setPlaying(false);
      const resumed: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await paused;
      expect(await resumed).assertTrue();
      expect(session.taskStops.join(',')).assertEqual('101');
      expect(session.tasks.join(',')).assertEqual('102');
      expect(session.taskStarts).assertEqual(2);
      await fixture.release();
    });

    it('ignoresAnOldTaskCancellationAndHonorsTheCurrentSystemControls', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      await fixture.background.setPlaying(false);
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      session.cancel(101);
      expect(fixture.pauses).assertEqual(0);
      expect(fixture.background.isRunning).assertTrue();
      session.controls.play();
      session.controls.pause();
      session.controls.stop();
      expect(fixture.plays).assertEqual(1);
      expect(fixture.pauses).assertEqual(1);
      expect(fixture.stops).assertEqual(1);
      session.cancel(102);
      expect(fixture.background.isRunning).assertFalse();
      expect(fixture.pauses).assertEqual(1);
      expect(fixture.interruptions).assertEqual(1);
      await fixture.release();
    });

    it('doesNotClaimBackgroundSupportWhenTaskAcquisitionFails', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      const gate: BackgroundGate<number | undefined> = new BackgroundGate<number | undefined>();
      fixture.io.nextTask = gate;
      const pending: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await fixture.io.opened.promise;
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      await session.taskRequested.promise;
      gate.finish(undefined);
      expect(await pending).assertFalse();
      expect(fixture.background.isRunning).assertFalse();
      expect(session.tasks.length).assertEqual(0);
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      await fixture.release();
    });

    it('doesNotPublishAQueuedPlayAfterALaterPause', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      expect(await fixture.background.start(undefined, 'account-a:quest-a')).assertTrue();
      const playing: Promise<void> = fixture.background.setPlaying(true);
      const paused: Promise<void> = fixture.background.setPlaying(false);
      await playing;
      await paused;
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      expect(session.states.join(',')).assertEqual('false');
      expect(session.tasks.length).assertEqual(0);
      expect(fixture.background.isRunning).assertFalse();
      await fixture.release();
    });

    it('doesNotRetainATaskCancelledBeforeItsStartPromiseSettles', 0, async () => {
      const fixture: BackgroundFixture = new BackgroundFixture();
      const gate: BackgroundGate<number | undefined> = new BackgroundGate<number | undefined>();
      fixture.io.nextTask = gate;
      const pending: Promise<boolean> = fixture.background.start(undefined, 'account-a:quest-a');
      await fixture.io.opened.promise;
      const session: FakeBackgroundSession = fixture.io.sessions[0];
      await session.taskRequested.promise;
      session.cancel(71);
      gate.finish(71);
      expect(await pending).assertFalse();
      expect(fixture.background.isRunning).assertFalse();
      expect(session.tasks.length).assertEqual(0);
      expect(fixture.interruptions).assertEqual(1);
      expect(fixture.pauses).assertEqual(0);
      await fixture.release();
    });
  });
}
