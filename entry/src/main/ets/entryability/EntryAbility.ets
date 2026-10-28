/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppLifecycle } from '../platform/AppLifecycle';
import { AppEnvironment } from '../platform/AppEnvironment';
import { reportWindowMetrics } from '../platform/WindowMetrics';
import { LaunchRoutes } from '../platform/LaunchRoutes';
import { runTlsProbe } from '../platform/TlsProbe';
import { ImmersiveWindow } from '../platform/ImmersiveWindow';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private integrationWindow: window.Window | null = null;
  private activeStage: window.WindowStage | null = null;
  private stageGeneration: number = 0;
  private immersiveWindow: ImmersiveWindow = new ImmersiveWindow();

  private keepIntegrationScreenOn(visible: boolean): void {
    if (this.integrationWindow !== null && AppEnvironment.endpoint.length > 0) {
      try {
        this.integrationWindow.setWindowKeepScreenOn(visible).catch(() => {
          hilog.warn(DOMAIN, 'StarwardTestWindow', 'Test window screen-on request was not applied');
        });
      } catch (error) {
        hilog.warn(DOMAIN, 'StarwardTestWindow', 'Test window is no longer available');
      }
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppEnvironment.load(this.context.resourceManager);
    LaunchRoutes.receive(want.uri || '');
    runTlsProbe();
    try {
      if (AppEnvironment.fontScale > 0) {
        this.context.getApplicationContext().setFontSizeScale(AppEnvironment.fontScale);
      }
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    LaunchRoutes.receive(want.uri || '');
  }

  onDestroy(): void {
    this.immersiveWindow.detach();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', 'Ability onWindowStageCreate');
    this.activeStage = windowStage;
    const generation: number = ++this.stageGeneration;
    this.prepareWindowStage(windowStage, generation);
  }

  private async prepareWindowStage(windowStage: window.WindowStage, generation: number): Promise<void> {
    try {
      const main: window.Window = windowStage.getMainWindowSync();
      this.integrationWindow = main;
      this.keepIntegrationScreenOn(true);
      // Configure the actual main window before its first page layout.
      await this.immersiveWindow.attach(main, this.context.config.colorMode);
    } catch (error) {
      hilog.warn(DOMAIN, 'StarwardImmersive', 'Main window initialization was not completed');
    }
    if (generation !== this.stageGeneration || this.activeStage !== windowStage) {
      return;
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (generation !== this.stageGeneration || this.activeStage !== windowStage) {
        return;
      }
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content');
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content');
      reportWindowMetrics(windowStage, this.context.config.fontSizeScale || 1, this.context.config.colorMode);
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const generation: number = this.stageGeneration;
    const colorMode: ConfigurationConstant.ColorMode | undefined = newConfig.colorMode === undefined ?
      this.context.config.colorMode : newConfig.colorMode;
    this.immersiveWindow.updateColorMode(colorMode).then(() => {
      if (generation !== this.stageGeneration) {
        return;
      }
      const stage: window.WindowStage | null = this.activeStage;
      if (stage !== null) {
        reportWindowMetrics(stage, this.context.config.fontSizeScale || 1, this.context.config.colorMode);
      }
    });
  }

  onWindowStageDestroy(): void {
    this.stageGeneration++;
    this.activeStage = null;
    this.immersiveWindow.detach();
    this.keepIntegrationScreenOn(false);
    this.integrationWindow = null;
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    this.keepIntegrationScreenOn(true);
    this.immersiveWindow.updateColorMode(this.context.config.colorMode);
    AppLifecycle.publish(true);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    this.keepIntegrationScreenOn(false);
    AppLifecycle.publish(false);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
