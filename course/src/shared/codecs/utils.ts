import { G, O, pipe, S } from '@mobily/ts-belt';
import * as t from 'io-ts';

export function getValidationErrorDetails(errors: t.Errors): string {
  return errors
    .map(error => {
      const path = error.context
        .filter(entry => entry.key)
        .map(entry => entry.key)
        .join('.');

      return G.isNullable(error.value) && error.message === undefined
        ? `value at ${path} is missing`
        : [
            `value ${JSON.stringify(error.value)} at ${path} is invalid`,
            pipe(
              O.fromNullable(error.message),
              O.map(S.prepend('(')),
              O.map(S.append(')')),
              O.toUndefined
            )
          ]
            .filter(G.isNotNullable)
            .join(' ');
    })
    .join(', ');
}

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
