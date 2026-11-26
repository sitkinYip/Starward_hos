export const PUSH_OPEN_ACTION: string = 'com.sitkin.starward.action.PUSH_OPEN';

export class PushRoute {
  readonly kind: string;
  readonly eventId: string;
  readonly profileId: string;
  readonly target: string;

  constructor(kind: string, eventId: string, profileId: string, target: string) {
    this.kind = kind;
    this.eventId = eventId;
    this.profileId = profileId;
    this.target = target;
  }
}

// Shared App-process routing intent; never accepts external websites or endpoints.
export class LaunchRoutes {
  static pending: string = '';
  private static listeners: Set<(id: string) => void> = new Set();
  private static push: PushRoute | null = null;
  private static processed: string[] = [];

  static receive(uri: string): boolean {
    const match: RegExpMatchArray | null = uri.match(/^starward:\/\/assignment\/([A-Za-z0-9_-]{1,100})$/);
    if (match === null) {
      return false;
    }
    const id: string = match[1];
    LaunchRoutes.pending = id;
    LaunchRoutes.push = null;
    LaunchRoutes.listeners.forEach((listener: (id: string) => void) => listener(id));
    return true;
  }

  static receivePush(action: string, parameters?: Record<string, Object>): boolean {
    if (action !== PUSH_OPEN_ACTION || parameters === undefined || parameters['starwardPushVersion'] !== '1') {
      return false;
    }
    const kind: Object = parameters['starwardPushKind'];
    const event: Object = parameters['starwardPushEventId'];
    const profile: Object = parameters['starwardPushProfileId'];
    const target: Object = parameters['starwardPushTargetId'];
    if ((kind !== 'inbox' && kind !== 'assignment' && kind !== 'progress') || typeof event !== 'string' ||
      !/^[A-Za-z0-9_-]{1,100}$/.test(event as string) || typeof profile !== 'string' ||
      !/^[A-Za-z0-9_-]{16,64}$/.test(profile as string) || (kind !== 'inbox' &&
      (typeof target !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(target as string)))) { return false; }
    if (kind === 'progress' && !/^[a-z0-9]{15}$/.test(target as string)) { return false; }
    const route: PushRoute = new PushRoute(kind as string, event as string, profile as string,
      kind !== 'inbox' ? target as string : '');
    if (LaunchRoutes.processed.includes(LaunchRoutes.key(route)) ||
      (LaunchRoutes.push !== null && LaunchRoutes.key(LaunchRoutes.push) === LaunchRoutes.key(route))) { return false; }
    LaunchRoutes.pending = '';
    LaunchRoutes.push = route;
    LaunchRoutes.listeners.forEach((listener: (id: string) => void) => listener(''));
    return true;
  }

  static nextPush(): PushRoute | null { return LaunchRoutes.push; }

  static consumePush(route: PushRoute): boolean {
    if (LaunchRoutes.push !== route) { return false; }
    LaunchRoutes.push = null;
    LaunchRoutes.processed.push(LaunchRoutes.key(route));
    if (LaunchRoutes.processed.length > 32) { LaunchRoutes.processed.shift(); }
    return true;
  }

  private static key(route: PushRoute): string { return route.profileId + ':' + route.eventId; }

  static take(): string {
    const value: string = LaunchRoutes.pending;
    LaunchRoutes.pending = '';
    return value;
  }

  static clear(): void {
    LaunchRoutes.pending = '';
    LaunchRoutes.push = null;
    LaunchRoutes.processed = [];
  }

  static subscribe(listener: (id: string) => void): void {
    LaunchRoutes.listeners.add(listener);
  }

  static unsubscribe(listener: (id: string) => void): void {
    LaunchRoutes.listeners.delete(listener);
  }
}
