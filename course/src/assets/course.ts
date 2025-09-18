import { G, O, pipe } from '@mobily/ts-belt';
import { init } from '@plausible-analytics/tracker';
import { computed, effect, signal } from '@preact/signals-core';
import { isRight } from 'fp-ts/lib/Either';
import * as t from 'io-ts';
import { DateTime } from 'luxon';
import { Socket } from 'phoenix';

import { iso8601DateTime } from '../shared/codecs/iso8601-date-time';
import { parseJsonSafe, required, toggleClass } from './utils';
import { HttpAuthenticationError } from './errors';
import './course/tell-me-more';
import './course/back-to-top';
import './course/search';
import './course/toc';
import log from './logging';

const logger = log.getLogger('course');

logger.info('ArchiDep 🚀');

const standalone =
  document.querySelector('head')?.dataset['archidepStandalone'] === 'true';

if (!standalone) {
  init({
    domain: 'archidep.ch',
    endpoint: 'https://plausible.alphahydrae.ch/api/event',
    autoCapturePageviews: true,
    outboundLinks: true
  });
}

window['logOut'] = logOut;

const sessionType = t.readonly(
  t.exact(
    t.type({
      username: t.string,
      root: t.boolean,
      impersonating: t.boolean,
      sessionExpiresAt: iso8601DateTime
    })
  )
);

type Session = t.TypeOf<typeof sessionType>;

const cachedSessionString = window.localStorage.getItem('archidep:session');
const decodedCachedSession = pipe(
  O.fromNullable(cachedSessionString),
  O.mapNullable(parseJsonSafe),
  O.map(sessionType.decode),
  O.flatMap(decoded => (isRight(decoded) ? O.Some(decoded.right) : O.None)),
  O.filter(session => session.sessionExpiresAt > DateTime.now()),
  O.toUndefined
);

const me = signal<Session | undefined>(decodedCachedSession);
const root = computed(() => me.value?.root === true);

const $sidebarAdminItem = required(
  document.getElementById('sidebar-admin-item'),
  'Sidebar admin item not found'
);
const $navbarProfile = required(
  document.getElementById('navbar-profile'),
  'Navbar profile not found'
);
const $navbarProfileUser = required(
  $navbarProfile.querySelector('.user'),
  'Navbar profile user not found'
);
const $navbarProfileImpersonator = required(
  $navbarProfile.querySelector('.impersonator'),
  'Navbar profile impersonator not found'
);
const $loginButton = required(
  document.getElementById('login-button'),
  'Login button not found'
);
const $logoutButton = required(
  document.getElementById('logout-button'),
  'Logout button not found'
);

effect(() => {
  toggleClass($sidebarAdminItem, 'hidden', !root.value);
});

effect(() => {
  toggleClass($loginButton, 'flex', me.value === undefined);
  toggleClass($loginButton, 'hidden', me.value !== undefined);
  toggleClass($navbarProfile, 'hidden', me.value === undefined);
  $logoutButton.removeAttribute('disabled');
});

effect(() => {
  toggleClass($navbarProfileUser, 'hidden', me.value?.impersonating === true);
  toggleClass($navbarProfileImpersonator, 'hidden', !me.value?.impersonating);
});

const retryIntervals = [
  500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 10_000, 20_000
];
const defaultRetryInterval = 30_000;
let connectionAttempt = 0;
const socketLogger = log.getLogger('socket');

connectSocket();
let connectionTimeout: NodeJS.Timeout | undefined;

window.addEventListener('storage', event => {
  if (event.key !== 'archidep:session' || event.newValue === null) {
    return;
  }

  clearTimeout(connectionTimeout);
  connectSocket();
});

$logoutButton.addEventListener('click', logOut);

function connectSocket(): void {
  const retryInterval =
    retryIntervals[connectionAttempt] ?? defaultRetryInterval;

  socketLogger.debug('Connecting...');

  fetch('/auth/socket')
    .then(res => {
      if (!res.ok) {
        if (res.status === 401) {
          localStorage.removeItem('archidep:session');
          throw new HttpAuthenticationError(res);
        }

        throw new Error(`Connection request failed with status ${res.status}`);
      }

      return res;
    })
    .then(res => res.json())
    .then((data: { readonly token: string }) => {
      const token = data.token;
      const socket = new Socket('/socket', {
        params: { token }
      });

      socket.onOpen(() => {
        connectionAttempt = 0;
      });

      socket.onError(error => {
        socketLogger.warn(
          `Connection error ${G.isString(error) || G.isNumber(error) ? String(error) : '(unknown)'}`
        );
      });

      socket.onClose(() => {
        socket.disconnect();
        socketLogger.info(
          `Connection closed; will reconnect in ${retryInterval / 1000} seconds`
        );
        me.value = undefined;

        if (localStorage.getItem('archidep:session') !== null) {
          connectionAttempt++;
          connectionTimeout = setTimeout(connectSocket, retryInterval);
        } else {
          connectionAttempt = 0;
          clearTimeout(connectionTimeout);
        }
      });

      socket.connect();

      const channel = socket.channel('me', {});
      channel
        .join()
        .receive('ok', resp => {
          const decodedMe = sessionType.decode(resp);
          if (isRight(decodedMe)) {
            const payload = decodedMe.right;
            me.value = payload;
            socketLogger.debug(`Welcome, ${payload.username}!`);
            if (localStorage.getItem('archidep:session') === null) {
              localStorage.setItem('archidep:session', JSON.stringify(payload));
            }
          } else {
            socketLogger.error(
              `Failed to decode 'me' channel payload: ${JSON.stringify(resp)}`
            );
          }
        })
        .receive('error', resp => {
          socketLogger.warn(
            `Failed to join 'me' channel: ${JSON.stringify(resp)}`
          );
        });
    })
    .catch(err => {
      socketLogger.warn(
        `Failed to connect because: ${err.message}; will retry in ${retryInterval / 1000} second(s)`
      );

      if (err instanceof HttpAuthenticationError) {
        // If authentication failed, this presumably means that the session is
        // no longer valid. Clear the session and give up attempting to
        // reconnect. The user will have to leave the page to log in again.
        connectionAttempt = 0;
        socketLogger.info('Authentication failed, giving up on reconnecting');
        clearTimeout(connectionTimeout);
      } else {
        connectionAttempt++;
        connectionTimeout = setTimeout(connectSocket, retryInterval);
      }
    });
}

function logOut(): void {
  log.debug('Logging out...');

  fetch('/auth/csrf')
    .then(res => {
      if (!res.ok) {
        throw new Error(`Connection request failed with status ${res.status}`);
      }

      return res;
    })
    .then(res => res.json())
    .then(resp =>
      fetch('/logout', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({
          _method: 'delete',
          _csrf_token: resp.token
        })
      })
    )
    .then(() => {
      localStorage.removeItem('archidep:session');
      logger.info('Logout successful');
      connectionAttempt = 0;
      clearTimeout(connectionTimeout);
    })
    .catch(err => logger.warn(`Logout failed: ${err.message}`));
}
