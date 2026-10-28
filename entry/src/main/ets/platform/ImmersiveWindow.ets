import { ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Main-window edge-to-edge policy. System bars stay visible above the app. */
export class ImmersiveWindow {
  private target: window.Window | null = null;
  private generation: number = 0;
  private revision: number = 0;
  private colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  private updates: Promise<void> = Promise.resolve();

  attach(target: window.Window, colorMode: ConfigurationConstant.ColorMode | undefined): Promise<void> {
    this.detach();
    this.target = target;
    const generation: number = this.generation;
    this.updates = this.enableLayout(target, generation);
    return this.updateColorMode(colorMode);
  }

  detach(): void {
    this.generation++;
    this.revision++;
    this.target = null;
  }

  updateColorMode(colorMode: ConfigurationConstant.ColorMode | undefined): Promise<void> {
    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ||
      colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      this.colorMode = colorMode;
    }
    const target: window.Window | null = this.target;
    const generation: number = this.generation;
    const revision: number = ++this.revision;
    const dark: boolean = this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    // Serialize this window's changes and skip stale rapid theme selections.
    this.updates = this.updates.then(async () => {
      if (target === null || target !== this.target || generation !== this.generation || revision !== this.revision) {
        return;
      }
      try {
        await target.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
          navigationBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
          isStatusBarLightIcon: dark,
          isNavigationBarLightIcon: dark
        });
      } catch (error) {
        hilog.warn(0x0000, 'StarwardImmersive', 'System bar appearance was not applied');
      }
    });
    return this.updates;
  }

  private async enableLayout(target: window.Window, generation: number): Promise<void> {
    if (target !== this.target || generation !== this.generation) {
      return;
    }
    try {
      await target.setWindowLayoutFullScreen(true);
    } catch (error) {
      hilog.warn(0x0000, 'StarwardImmersive', 'Immersive main-window layout was not applied');
    }
  }
}
