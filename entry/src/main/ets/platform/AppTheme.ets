import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

export enum ThemePreference {
  System = 'system',
  Light = 'light',
  Dark = 'dark'
}

export enum ThemeSelection {
  Saved,
  SaveFailed,
  ApplyFailed
}

const STORE_NAME = 'starward_appearance';
const THEME_KEY = 'theme';
const TAG = 'StarwardTheme';

export class AppTheme {
  private static selected: ThemePreference = ThemePreference.System;

  static get preference(): ThemePreference {
    return AppTheme.selected;
  }

  private static store(context: common.UIAbilityContext): preferences.Preferences | undefined {
    try {
      return preferences.getPreferencesSync(context.getApplicationContext(), { name: STORE_NAME });
    } catch (error) {
      hilog.warn(0x0000, TAG, 'Could not open the theme preferences');
      return undefined;
    }
  }

  static load(context: common.UIAbilityContext): void {
    AppTheme.selected = ThemePreference.System;
    try {
      const saved = AppTheme.store(context)?.getSync(THEME_KEY, ThemePreference.System);
      if (saved === ThemePreference.Light || saved === ThemePreference.Dark) {
        AppTheme.selected = saved;
      }
    } catch (error) {
      hilog.warn(0x0000, TAG, 'Could not read the saved theme preference');
    }
  }

  private static apply(context: common.UIAbilityContext, preference: ThemePreference): boolean {
    let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (preference === ThemePreference.Light) {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (preference === ThemePreference.Dark) {
      mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      context.getApplicationContext().setColorMode(mode);
      return true;
    } catch (error) {
      hilog.warn(0x0000, TAG, 'Could not apply the theme');
      return false;
    }
  }

  static restore(context: common.UIAbilityContext): void {
    AppTheme.apply(context, AppTheme.selected);
  }

  static select(context: common.UIAbilityContext, preference: ThemePreference): ThemeSelection {
    if (!AppTheme.apply(context, preference)) {
      return ThemeSelection.ApplyFailed;
    }
    AppTheme.selected = preference;
    const store = AppTheme.store(context);
    if (store === undefined) {
      return ThemeSelection.SaveFailed;
    }
    try {
      store.putSync(THEME_KEY, preference);
      // Commit this single setting before the tap completes so a cold launch sees the last choice.
      store.flushSync();
      return ThemeSelection.Saved;
    } catch (error) {
      hilog.warn(0x0000, TAG, 'Could not save the selected theme');
      return ThemeSelection.SaveFailed;
    }
  }
}
