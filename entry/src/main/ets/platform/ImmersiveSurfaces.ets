/** Dark-content leases for the single main window; UI never owns a Window handle. */
export class ImmersiveSurfaces {
  private static nextId: number = 0;
  private static leases: Set<number> = new Set<number>();
  private static listeners: Set<(dark: boolean) => void> = new Set<(dark: boolean) => void>();

  /** @throws {Error} Refuse exhaustion rather than reuse an earlier lease id. */
  static acquireDark(): number {
    if (ImmersiveSurfaces.nextId >= Number.MAX_SAFE_INTEGER) {
      throw new Error('Immersive surface lease limit reached');
    }
    const wasDark: boolean = ImmersiveSurfaces.leases.size > 0;
    const id: number = ++ImmersiveSurfaces.nextId;
    ImmersiveSurfaces.leases.add(id);
    if (!wasDark) {
      ImmersiveSurfaces.publish(true);
    }
    return id;
  }

  static releaseDark(id: number): void {
    if (ImmersiveSurfaces.leases.delete(id) && ImmersiveSurfaces.leases.size === 0) {
      ImmersiveSurfaces.publish(false);
    }
  }

  static subscribe(listener: (dark: boolean) => void): () => void {
    ImmersiveSurfaces.listeners.add(listener);
    listener(ImmersiveSurfaces.leases.size > 0);
    return (): void => { ImmersiveSurfaces.listeners.delete(listener); };
  }

  /** Detach first removes its writer. The next window reads its own initial state. */
  static reset(): void {
    ImmersiveSurfaces.leases.clear();
    // Do not broadcast an old window's reset to a later window subscription.
  }

  private static publish(dark: boolean): void {
    ImmersiveSurfaces.listeners.forEach((listener: (dark: boolean) => void) => listener(dark));
  }
}
