import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';

export const PRODUCTION_API_ORIGIN: string = 'https://api.sitkin.top';

// Only a packaged configuration can select an HTTPS repository.
// Launch URLs/Want parameters cannot change where credentials are sent.
export class AppEnvironment {
  static endpoint: string = '';
  static isolated: boolean = false;
  static production: boolean = false;
  static productionReadOnly: boolean = false;
  static hostedPrivacy: boolean = false;
  static pushEnabled: boolean = false;
  static configurationError: string = '';
  static caData: string = '';
  static timeoutMs: number = 15000;
  static probeTls: boolean = false;
  static fontScale: number = 0;

  static load(manager: resourceManager.ResourceManager): void {
    AppEnvironment.endpoint = '';
    AppEnvironment.isolated = false;
    AppEnvironment.production = false;
    AppEnvironment.productionReadOnly = false;
    AppEnvironment.hostedPrivacy = false;
    AppEnvironment.pushEnabled = false;
    AppEnvironment.configurationError = '';
    AppEnvironment.caData = '';
    AppEnvironment.timeoutMs = 15000;
    AppEnvironment.probeTls = false;
    AppEnvironment.fontScale = 0;
    let productionMarker: boolean = false;
    try {
      const files: string[] = manager.getRawFileListSync('');
      productionMarker = files.includes('production-smoke.json');
      const integration: boolean = files.includes('integration.json');
      if (productionMarker) {
        const bytes: Uint8Array = manager.getRawFileContentSync('production-smoke.json');
        const text: string = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes);
        const configuration: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
        const mode: Object = configuration['mode'];
        if (integration || files.includes('integration-ca.pem') || Object.keys(configuration).length !== 1 ||
          (mode !== 'production-readonly' && mode !== 'production-write' && mode !== 'production-invite' &&
          mode !== 'production-invite-push')) {
          throw new Error('Invalid production smoke configuration');
        }
        AppEnvironment.production = true;
        AppEnvironment.productionReadOnly = mode === 'production-readonly';
        AppEnvironment.hostedPrivacy = mode === 'production-invite' || mode === 'production-invite-push';
        AppEnvironment.pushEnabled = mode === 'production-invite-push';
        AppEnvironment.endpoint = PRODUCTION_API_ORIGIN;
        return;
      }
      if (!integration) {
        return;
      }
      const bytes: Uint8Array = manager.getRawFileContentSync('integration.json');
      const text: string = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes);
      const data: Record<string, Object> = JSON.parse(text) as Record<string, Object>;
      const endpoint: Object = data['endpoint'];
      if (data['isolated'] !== true || typeof endpoint !== 'string' ||
        !/^https:\/\/(?:[a-z0-9-]+\.trycloudflare\.com|127\.0\.0\.1:18443)$/.test(endpoint as string)) {
        throw new Error('Invalid isolated endpoint');
      }
      if ((endpoint as string).startsWith('https://127.0.0.1:')) {
        const certificate: Uint8Array = manager.getRawFileContentSync('integration-ca.pem');
        const pem: string = util.TextDecoder.create('utf-8').decodeToString(certificate);
        if (!pem.includes('-----BEGIN CERTIFICATE-----') || pem.includes('PRIVATE KEY')) {
          throw new Error('Missing isolated certificate authority');
        }
        AppEnvironment.caData = pem;
      }
      const timeout: Object = data['timeoutMs'];
      if (typeof timeout === 'number' && (timeout as number) >= 1000 && (timeout as number) <= 15000) {
        AppEnvironment.timeoutMs = timeout as number;
      }
      AppEnvironment.probeTls = data['probeTls'] === true;
      const scale: Object = data['fontScale'];
      if (typeof scale === 'number' && (scale as number) >= 1 && (scale as number) <= 1.6) {
        AppEnvironment.fontScale = scale as number;
      }
      AppEnvironment.endpoint = endpoint as string;
      AppEnvironment.isolated = true;
      AppEnvironment.hostedPrivacy = data['hostedPrivacy'] === true;
      AppEnvironment.pushEnabled = data['pushEnabled'] === true && AppEnvironment.hostedPrivacy;
    } catch (error) {
      AppEnvironment.configurationError = productionMarker ? '生产联调配置无效，请重新安装联调包。' :
        '隔离测试环境配置无效，请重新准备测试构建。';
    }
  }
}
