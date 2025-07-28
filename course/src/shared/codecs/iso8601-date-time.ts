import { G } from '@mobily/ts-belt';
import * as t from 'io-ts';
import { DateTime } from 'luxon';

import { ioTsValidator } from './utils';

export const iso8601DateTime = new t.Type<DateTime<true>, string, unknown>(
  'ISO 8601 date time',
  (value): value is DateTime<true> =>
    DateTime.isDateTime(value) && value.isValid,
  ioTsValidator(
    parseIso8601DateTime,
    'must be a valid date in the ISO 8601 format'
  ),
  url => url.toString()
);

function parseIso8601DateTime(value: unknown): DateTime<true> | false {
  if (!G.isString(value)) {
    return false;
  }

  const parsed = DateTime.fromISO(value);
  return parsed.isValid ? parsed : false;
}
