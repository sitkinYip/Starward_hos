// UIAbility and ArkUI share this only inside the App process, never with Forms.
export class AppLifecycle {
  private static listeners: Set<(foreground: boolean) => void> = new Set();
  private static foreground: boolean = true;

  static isForeground(): boolean { return AppLifecycle.foreground; }

  static subscribe(listener: (foreground: boolean) => void): void {
    AppLifecycle.listeners.add(listener);
  }

  static unsubscribe(listener: (foreground: boolean) => void): void {
    AppLifecycle.listeners.delete(listener);
  }

  static publish(foreground: boolean): void {
    AppLifecycle.foreground = foreground;
    AppLifecycle.listeners.forEach((listener: (foreground: boolean) => void) => listener(foreground));
  }
}
