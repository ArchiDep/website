import { CustomProperties, track } from '@plausible-analytics/tracker';

import log from '../logging';

const logger = log.getLogger('plausible');

export function trackEvent(name: string, props: CustomProperties = {}) {
  const plausible: typeof track | undefined = window['plausible'];
  if (plausible === undefined) {
    return;
  }

  if (window.location.hostname === 'localhost') {
    logger.debug(`Tracking event: ${name}`, props);
  }

  plausible(name, { props, callback: trackCallback });
}

function trackCallback(
  result?: { status: number } | { error: unknown } | undefined
): void {
  if (result !== undefined && 'status' in result) {
    logger.debug(`Plausible request done with status ${result.status}`);
  } else if (result?.error) {
    logger.warn('Plausible request error', result.error);
  } else {
    logger.warn('Plausible request ignored');
  }
}
