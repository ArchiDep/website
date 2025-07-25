import { G } from '@mobily/ts-belt';
import * as t from 'io-ts';

export function ioTsValidator<T>(
  parser: (value: unknown) => T | false,
  failureMessage?: string | ((value: unknown) => string)
): t.Validate<unknown, T> {
  return (value: unknown, context: t.Context) => {
    const parsed = parser(value);
    if (parsed === false) {
      return t.failure(
        value,
        context,
        G.isFunction(failureMessage) ? failureMessage(value) : failureMessage
      );
    }

    return t.success(parsed);
  };
}
