import * as t from 'io-ts';
import { iso8601DateTime } from '../../shared/codecs/iso8601-date-time';
import { O, pipe } from '@mobily/ts-belt';
import { parseJsonSafe } from '../utils';
import { isRight } from 'fp-ts/lib/Either';
import { DateTime } from 'luxon';
import { computed, signal } from '@preact/signals';

const studentType = t.readonly(
  t.exact(
    t.type({
      username: t.string,
      usernameConfirmed: t.boolean,
      domain: t.string
    })
  )
);

export type Student = t.TypeOf<typeof studentType>;

export const sessionType = t.readonly(
  t.intersection([
    t.exact(
      t.type({
        root: t.boolean,
        impersonating: t.boolean,
        sessionId: t.string,
        sessionExpiresAt: iso8601DateTime
      })
    ),
    t.exact(
      t.partial({
        username: t.union([t.string, t.null]),
        student: t.union([studentType, t.null])
      })
    )
  ])
);

export type Session = t.TypeOf<typeof sessionType>;

const cachedSessionString = window.localStorage.getItem('archidep:session');
const decodedCachedSession = pipe(
  O.fromNullable(cachedSessionString),
  O.mapNullable(parseJsonSafe),
  O.map(sessionType.decode),
  O.flatMap(decoded => (isRight(decoded) ? O.Some(decoded.right) : O.None)),
  O.filter(session => session.sessionExpiresAt > DateTime.now()),
  O.toUndefined
);

export const currentSession = signal<Session | undefined>(decodedCachedSession);
export const currentSessionRootFlag = computed(
  () => currentSession.value?.root === true
);
