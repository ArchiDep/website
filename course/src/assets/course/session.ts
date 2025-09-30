import * as t from 'io-ts';
import { iso8601DateTime } from '../../shared/codecs/iso8601-date-time';
import { O, pipe } from '@mobily/ts-belt';
import { parseJsonSafe } from '../utils';
import { isRight } from 'fp-ts/lib/Either';
import { DateTime } from 'luxon';
import { computed, signal } from '@preact/signals';
import { match } from 'ts-pattern';

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

export enum CurrentSessionType {
  /**
   * No session, user is anonymous.
   */
  Anonymous = 'anonymous',
  /**
   * User has previously logged in and had a valid session, but we don't know if
   * it's still valid until we manage to connect again.
   */
  Cached = 'cached',
  /**
   * User is logged in with a valid session.
   */
  Connected = 'connected',
  /**
   * There was an error trying to connect to the server (e.g. network error).
   * There might be a cached session, but we don't know if it's still valid.
   */
  ConnectionError = 'connection-error'
}

export const anonymousSessionType = t.readonly(
  t.exact(
    t.type({
      type: t.literal(CurrentSessionType.Anonymous)
    })
  )
);

export type AnonymousSession = t.TypeOf<typeof anonymousSessionType>;

export function anonymousSession(): AnonymousSession {
  return { type: CurrentSessionType.Anonymous };
}

export const cachedSessionType = t.readonly(
  t.exact(
    t.type({
      type: t.literal(CurrentSessionType.Cached),
      session: sessionType
    })
  )
);

export type CachedSession = t.TypeOf<typeof cachedSessionType>;

export function cachedSession(session: Session): CachedSession {
  return { type: CurrentSessionType.Cached, session };
}

export const connectedSessionType = t.readonly(
  t.exact(
    t.type({
      type: t.literal(CurrentSessionType.Connected),
      session: sessionType
    })
  )
);

export type ConnectedSession = t.TypeOf<typeof connectedSessionType>;

export function connectedSession(session: Session): ConnectedSession {
  return { type: CurrentSessionType.Connected, session };
}

export const sessionConnectionErrorType = t.readonly(
  t.exact(
    t.type({
      type: t.literal(CurrentSessionType.ConnectionError),
      message: t.string,
      session: t.union([sessionType, t.undefined])
    })
  )
);

export type SessionConnectionError = t.TypeOf<
  typeof sessionConnectionErrorType
>;

export function sessionConnectionError(
  message: string,
  session?: Session
): SessionConnectionError {
  return { type: CurrentSessionType.ConnectionError, message, session };
}

export const currentSessionType = t.union([
  anonymousSessionType,
  cachedSessionType,
  connectedSessionType,
  sessionConnectionErrorType
]);

export type CurrentSession =
  | AnonymousSession
  | CachedSession
  | ConnectedSession
  | SessionConnectionError;

const cachedSessionString = window.localStorage.getItem('archidep:session');
const decodedCachedSession = pipe(
  O.fromNullable(cachedSessionString),
  O.mapNullable(parseJsonSafe),
  O.map(sessionType.decode),
  O.flatMap(decoded => (isRight(decoded) ? O.Some(decoded.right) : O.None)),
  O.filter(session => session.sessionExpiresAt > DateTime.now()),
  O.toUndefined
);

export const currentSession = signal<CurrentSession>(
  decodedCachedSession === undefined
    ? anonymousSession()
    : cachedSession(decodedCachedSession)
);

export const currentSessionRootFlag = computed(
  () => getSession(currentSession.value)?.root === true
);

export function getSession(
  currentSession: CurrentSession
): Session | undefined {
  return match(currentSession)
    .with({ type: CurrentSessionType.Anonymous }, () => undefined)
    .with({ type: CurrentSessionType.Cached }, ({ session }) => session)
    .with({ type: CurrentSessionType.Connected }, ({ session }) => session)
    .with(
      { type: CurrentSessionType.ConnectionError },
      ({ session }) => session
    )
    .exhaustive();
}
