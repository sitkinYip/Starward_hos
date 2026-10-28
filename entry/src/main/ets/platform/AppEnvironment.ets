import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';

// Only a packaged, local test resource can select an HTTPS repository.
// Launch URLs/Want parameters cannot change where credentials are sent.
export class AppEnvironment {
  static endpoint: string = '';
  static configurationError: string = '';
  static caData: string = '';
  static timeoutMs: number = 15000;
  static probeTls: boolean = false;
  static fontScale: number = 0;

  static load(manager: resourceManager.ResourceManager): void {
    AppEnvironment.endpoint = '';
    AppEnvironment.configurationError = '';
    AppEnvironment.caData = '';
    AppEnvironment.timeoutMs = 15000;
    AppEnvironment.probeTls = false;
    AppEnvironment.fontScale = 0;
    try {
      if (!manager.getRawFileListSync('').includes('integration.json')) {
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
    } catch (error) {
      AppEnvironment.configurationError = '隔离测试环境配置无效，请重新准备测试构建。';
    }
  }
}
