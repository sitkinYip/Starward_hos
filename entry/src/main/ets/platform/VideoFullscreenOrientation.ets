import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Serializes video orientation changes on the main window and preserves its previous policy. */
export class VideoFullscreenOrientation {
  private static attached: VideoFullscreenOrientation | undefined;
  private static mainWindow: window.Window | undefined;
  private readonly read: () => window.Orientation;
  private readonly write: (orientation: window.Orientation) => Promise<void>;
  private owner: Object | undefined;
  private previous: window.Orientation | undefined;
  private revision: number = 0;
  private updates: Promise<void> = Promise.resolve();

  constructor(read: () => window.Orientation, write: (orientation: window.Orientation) => Promise<void>) {
    this.read = read;
    this.write = write;
  }

  static attach(target: window.Window): void {
    if (VideoFullscreenOrientation.mainWindow === target) { return; }
    VideoFullscreenOrientation.attached?.reset();
    VideoFullscreenOrientation.mainWindow = target;
    VideoFullscreenOrientation.attached = new VideoFullscreenOrientation(() => target.getPreferredOrientation(),
      (orientation: window.Orientation) => target.setPreferredOrientation(orientation));
  }

  static detach(target: window.Window): void {
    if (VideoFullscreenOrientation.mainWindow !== target) { return; }
    VideoFullscreenOrientation.attached?.reset();
    VideoFullscreenOrientation.attached = undefined;
    VideoFullscreenOrientation.mainWindow = undefined;
  }

  static begin(owner: Object, width: number, height: number): void {
    void VideoFullscreenOrientation.attached?.enter(owner, width, height);
  }

  static end(owner: Object): void {
    void VideoFullscreenOrientation.attached?.exit(owner);
  }

  enter(owner: Object, width: number, height: number): Promise<void> {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0 || width === height) {
      return this.updates;
    }
    this.owner = owner;
    return this.schedule(width > height ? window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT);
  }

  exit(owner: Object): Promise<void> {
    return this.owner === owner ? this.reset() : this.updates;
  }

  private reset(): Promise<void> {
    this.owner = undefined;
    return this.schedule(undefined);
  }

  private schedule(orientation: window.Orientation | undefined): Promise<void> {
    const revision: number = ++this.revision;
    this.updates = this.updates.then(async (): Promise<void> => {
      if (revision !== this.revision) { return; }
      try {
        if (orientation === undefined) {
          if (this.previous !== undefined) {
            await this.write(this.previous);
            this.previous = undefined;
          }
          return;
        }
        const current = this.read();
        if (this.previous === undefined) { this.previous = current; }
        if (current !== orientation) { await this.write(orientation); }
      } catch {
        hilog.warn(0x0000, 'StarwardVideo', 'Could not update the main window orientation for video');
      }
    });
    return this.updates;
  }
}
