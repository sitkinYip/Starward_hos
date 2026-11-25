import { bundleManager } from '@kit.AbilityKit';

export interface InstalledAppVersion {
  name: string;
  code: number;
}

export function readInstalledAppVersion(): InstalledAppVersion | null {
  try {
    const bundle: bundleManager.BundleInfo =
      bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    if (bundle.versionName.length > 0 && Number.isInteger(bundle.versionCode) && bundle.versionCode > 0) {
      return { name: bundle.versionName, code: bundle.versionCode };
    }
  } catch {
    // The settings page can still be used if Bundle Manager is unavailable.
  }
  return null;
}
