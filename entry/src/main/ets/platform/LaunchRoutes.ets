// Shared App-process routing intent; never accepts external websites or endpoints.
export class LaunchRoutes {
  static pending: string = '';
  private static listeners: Set<(id: string) => void> = new Set();

  static receive(uri: string): boolean {
    const match: RegExpMatchArray | null = uri.match(/^starward:\/\/assignment\/([A-Za-z0-9_-]{1,100})$/);
    if (match === null) {
      return false;
    }
    const id: string = match[1];
    LaunchRoutes.pending = id;
    LaunchRoutes.listeners.forEach((listener: (id: string) => void) => listener(id));
    return true;
  }

  static take(): string {
    const value: string = LaunchRoutes.pending;
    LaunchRoutes.pending = '';
    return value;
  }

  static clear(): void {
    LaunchRoutes.pending = '';
  }

  static subscribe(listener: (id: string) => void): void {
    LaunchRoutes.listeners.add(listener);
  }

  static unsubscribe(listener: (id: string) => void): void {
    LaunchRoutes.listeners.delete(listener);
  }
}
