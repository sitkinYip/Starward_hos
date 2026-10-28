import { display, window, uiMaterial } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

class ContentMetrics {
  widthPx: number = 0;
  heightPx: number = 0;
  density: number = 1;
  topInsetPx: number = 0;
  bottomInsetPx: number = 0;
  widthVp: number = 0;
  contentHeightVp: number = 0;
  fontScale: number = 1;
  appColorMode: number = -1;
  leftInsetPx: number = 0;
  rightInsetPx: number = 0;
  cutoutTopPx: number = 0;
  cutoutBottomPx: number = 0;
  immersiveLayout: string = 'unknown';
  systemBarPropertiesObserved: boolean = false;
  statusBarColor: string = '';
  navigationBarColor: string = '';
  statusBarContentColor: string = '';
  navigationBarContentColor: string = '';
}

class MaterialMetrics {
  supported: boolean = false;
  state: number = -1;
  type: number = -1;
  level: number = -1;
}

export function reportWindowMetrics(stage: window.WindowStage, fontScale: number = 1, colorMode: number = -1): void {
  try {
    const screen: display.Display = display.getDefaultDisplaySync();
    const main: window.Window = stage.getMainWindowSync();
    const rect: window.Rect = main.getWindowProperties().windowRect;
    const system: window.AvoidArea = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const navigation: window.AvoidArea = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const cutout: window.AvoidArea = main.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
    const metrics: ContentMetrics = new ContentMetrics();
    metrics.fontScale = fontScale;
    metrics.appColorMode = colorMode;
    metrics.widthPx = rect.width;
    metrics.heightPx = rect.height;
    metrics.density = screen.densityPixels;
    metrics.topInsetPx = Math.max(system.topRect.height, cutout.topRect.height);
    metrics.bottomInsetPx = Math.max(system.bottomRect.height, navigation.bottomRect.height, cutout.bottomRect.height);
    metrics.leftInsetPx = Math.max(system.leftRect.width, navigation.leftRect.width, cutout.leftRect.width);
    metrics.rightInsetPx = Math.max(system.rightRect.width, navigation.rightRect.width, cutout.rightRect.width);
    metrics.cutoutTopPx = cutout.topRect.height;
    metrics.cutoutBottomPx = cutout.bottomRect.height;
    try {
      metrics.immersiveLayout = main.isImmersiveLayout() ? 'enabled' : 'disabled';
      const bars: window.SystemBarProperties = main.getWindowSystemBarProperties();
      metrics.statusBarColor = bars.statusBarColor || '';
      metrics.navigationBarColor = bars.navigationBarColor || '';
      metrics.statusBarContentColor = bars.statusBarContentColor || '';
      metrics.navigationBarContentColor = bars.navigationBarContentColor || '';
      metrics.systemBarPropertiesObserved = true;
    } catch (error) {
      // Optional window appearance queries cannot erase the geometry evidence.
    }
    metrics.widthVp = rect.width / metrics.density;
    metrics.contentHeightVp = (rect.height - metrics.topInsetPx - metrics.bottomInsetPx) / metrics.density;
    hilog.info(0x0000, 'StarwardMetrics', '%{public}s', JSON.stringify(metrics));
    const material: MaterialMetrics = new MaterialMetrics();
    material.supported = uiMaterial.isImmersiveMaterialSupported();
    const info: uiMaterial.MaterialInfo = uiMaterial.getMaterialInfo();
    material.state = info.state;
    material.type = info.type;
    material.level = uiMaterial.getGlobalMaterialLevel();
    hilog.info(0x0000, 'StarwardMaterial', '%{public}s', JSON.stringify(material));
  } catch (error) {
    hilog.warn(0x0000, 'StarwardMetrics', 'Window metrics unavailable');
  }
}
