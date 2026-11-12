import { common } from '@kit.AbilityKit';
import { url } from '@kit.ArkTS';

interface LinkLaunchFailure {
  errMsg?: string;
}

function launchCancelled(message: string): boolean {
  try {
    const failure: LinkLaunchFailure = JSON.parse(message) as LinkLaunchFailure;
    return failure.errMsg === 'User refused redirection' ||
      failure.errMsg === 'User closed the implicit startup picker' || failure.errMsg === 'User closed the app clone picker';
  } catch {
    return false;
  }
}

export function externalClueLinkHref(href: string): string {
  const value: string = href.trim();
  if (!/^https?:\/\/[^/?#]+/i.test(value) || /[\\\u0000-\u001f\u007f]/.test(value) ||
    /^https?:\/\/[^/?#]*@/i.test(value)) {
    return '';
  }
  try {
    const target: url.URL = url.URL.parseURL(value);
    if ((target.protocol === 'https:' || target.protocol === 'http:') && target.hostname !== '' &&
      target.username === '' && target.password === '') {
      return target.href;
    }
  } catch {
    return '';
  }
  return '';
}

/** Returns false when the user cancels the system's chooser. */
export async function openExternalClueLink(context: common.UIAbilityContext | undefined, href: string): Promise<boolean> {
  if (context === undefined) {
    throw new Error('Missing ability context');
  }
  const target: string = externalClueLinkHref(href);
  if (target === '') {
    throw new Error('Invalid external link');
  }

  return new Promise<boolean>((resolve, reject) => {
    context.openLink(target, {
      appLinkingOnly: false,
      hideFailureTipDialog: true,
      completionHandler: {
        onRequestSuccess: () => resolve(true),
        onRequestFailure: (_element, message: string) => {
          if (launchCancelled(message)) { resolve(false); } else { reject(new Error('Unable to open link')); }
        }
      }
    }).catch(() => reject(new Error('Unable to open link')));
  });
}
