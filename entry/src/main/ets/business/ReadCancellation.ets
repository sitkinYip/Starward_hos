/** Cancellation for a single read. Callers also guard which result may be applied. */
export class ReadCancellation {
  private stopped: boolean = false;
  private listener: (() => void) | undefined;

  get cancelled(): boolean { return this.stopped; }

  attach(listener: () => void): void {
    if (this.stopped) { listener(); } else { this.listener = listener; }
  }

  detach(): void { this.listener = undefined; }

  cancel(): void {
    this.stopped = true;
    const listener = this.listener;
    this.detach();
    listener?.();
  }
}
