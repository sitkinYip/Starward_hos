import { describe, expect, it } from '@ohos/hypium';
import { createSliceViewModel } from '../main/ets/features/createSliceViewModel';
import { SliceViewModel } from '../main/ets/features/SliceViewModel';
import { AppEnvironment } from '../main/ets/platform/AppEnvironment';

export default function environmentTests(): void {
  describe('Environment', () => {
    it('invalidPackagedConfigurationCannotFallBackToDemoLogin', 0, async () => {
      const endpoint: string = AppEnvironment.endpoint;
      const configurationError: string = AppEnvironment.configurationError;
      try {
        AppEnvironment.endpoint = '';
        AppEnvironment.configurationError = '隔离测试环境配置无效，请重新准备测试构建。';
        const model: SliceViewModel = createSliceViewModel();
        expect(model.mode).assertEqual('unavailable');
        expect(model.errorCode).assertEqual('CONFIG_ERROR');
        await model.login('alice', 'Starward1234');
        expect(model.gate).assertEqual('login');
        expect(model.player.id).assertEqual('');
        expect(model.items.length).assertEqual(0);
        expect(model.errorCode).assertEqual('CONFIG_ERROR');
        expect(model.error).assertEqual(AppEnvironment.configurationError);
        expect(model.busy).assertFalse();
        model.logout();
        await model.login('alice', 'Starward1234');
        expect(model.gate).assertEqual('login');
        expect(model.errorCode).assertEqual('CONFIG_ERROR');
      } finally {
        AppEnvironment.endpoint = endpoint;
        AppEnvironment.configurationError = configurationError;
      }
    });

    it('absentIntegrationConfigurationKeepsExplicitDemoMode', 0, async () => {
      const endpoint: string = AppEnvironment.endpoint;
      const configurationError: string = AppEnvironment.configurationError;
      try {
        AppEnvironment.endpoint = '';
        AppEnvironment.configurationError = '';
        const model: SliceViewModel = createSliceViewModel();
        expect(model.mode).assertEqual('mock');
        expect(model.errorCode).assertEqual('');
        await model.login('alice', 'Starward1234');
        expect(model.gate).assertEqual('password');
        expect(model.player.id).assertEqual('playeralice');
      } finally {
        AppEnvironment.endpoint = endpoint;
        AppEnvironment.configurationError = configurationError;
      }
    });
  });
}
