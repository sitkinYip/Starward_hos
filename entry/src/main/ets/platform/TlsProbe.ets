import { hilog } from '@kit.PerformanceAnalysisKit';
import { GameFailure } from '../business/models';
import { AppEnvironment } from './AppEnvironment';
import { NativeHttpTransport, TransportRequest, TransportResponse } from './HttpTransport';

class TlsProbeResult {
  customCaAccepted: boolean = false;
  untrustedCaRejected: boolean = false;
  untrustedFailureCode: string = '';
  wrongHostnameRejected: boolean = false;
  wrongHostnameFailureCode: string = '';
}

export async function runTlsProbe(): Promise<void> {
  if (!AppEnvironment.probeTls || AppEnvironment.caData.length === 0) {
    return;
  }
  const result: TlsProbeResult = new TlsProbeResult();
  const request: TransportRequest = new TransportRequest();
  request.url = AppEnvironment.endpoint + '/api/health';
  // Independent handshakes: a connection trusted with a custom CA must not be
  // reused as evidence for the no-CA negative check.
  try {
    await new NativeHttpTransport('', 5000, false).send(request);
  } catch (error) {
    if (error instanceof GameFailure) {
      result.untrustedFailureCode = error.code;
      result.untrustedCaRejected = error.code === 'TLS_ERROR';
    }
  }
  try {
    const trusted: TransportResponse = await new NativeHttpTransport(AppEnvironment.caData, 5000, false).send(request);
    result.customCaAccepted = trusted.status === 200;
  } catch (error) {
    result.customCaAccepted = false;
  }
  request.url = AppEnvironment.endpoint.replace('127.0.0.1', 'localhost') + '/api/health';
  try {
    await new NativeHttpTransport(AppEnvironment.caData, 5000, false).send(request);
  } catch (error) {
    if (error instanceof GameFailure) {
      result.wrongHostnameFailureCode = error.code;
      result.wrongHostnameRejected = error.code === 'TLS_ERROR';
    }
  }
  hilog.info(0x0000, 'StarwardTlsProbe', '%{public}s', JSON.stringify(result));
}
