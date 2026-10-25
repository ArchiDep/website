import { defineLogicDiagramElement } from 'companion-gate';
import { G, O, pipe } from '@mobily/ts-belt';
import { effect } from '@preact/signals';
import ClipboardJS from 'clipboard';
import { isRight } from 'fp-ts/lib/Either';
import * as t from 'io-ts';
import { Socket } from 'phoenix';

import { setUpPageDiagrams } from '../diagrams/runtime';
import './course/aside';
import './course/back-to-top';
import { setUpCircuits } from './course/circuits';
import { cloudServer, cloudServerDataType } from './course/cloud-server';
import {
  enlargeCircuit,
  enlargeDiagram,
  setUpLightbox
} from './course/lightbox';
import './course/randomize';
import './course/search';
import {
  createSocketConnection,
  type SocketConnection
} from './course/socket-connection';
import {
  anonymousSession,
  cachedSession,
  connectedSession,
  currentSession,
  currentSessionRootFlag,
  getSession,
  sessionConnectionError,
  sessionType
} from './course/session';
import './course/tell-me-more';
import './course/toc';
import { HttpAuthenticationError } from './errors';
import log from './logging';
import { defineStoryElement } from './simgit';
import { required, toggleClass } from './utils';

const logger = log.getLogger('course');

logger.info('ArchiDep 🚀');

new ClipboardJS('[data-clipboard-target], [data-clipboard-text]');

const standalone =
  document.querySelector('head')?.dataset['archidepStandalone'] === 'true';

defineLogicDiagramElement();
defineStoryElement();
setUpPageDiagrams(document, { enlarge: enlargeDiagram });
setUpCircuits(document, { enlarge: enlargeCircuit });
setUpLightbox();

window['logOut'] = logOut;

if (!standalone) {
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
    toggleClass($sidebarAdminItem, 'hidden', !currentSessionRootFlag.value);
  });

  effect(() => {
    toggleClass(
      $loginButton,
      'flex',
      getSession(currentSession.value) === undefined
    );
    toggleClass(
      $loginButton,
      'hidden',
      getSession(currentSession.value) !== undefined
    );
    toggleClass(
      $navbarProfile,
      'hidden',
      getSession(currentSession.value) === undefined
    );
    $logoutButton.removeAttribute('disabled');
  });

  effect(() => {
    toggleClass(
      $navbarProfileUser,
      'hidden',
      getSession(currentSession.value)?.impersonating === true
    );
    toggleClass(
      $navbarProfileImpersonator,
      'hidden',
      getSession(currentSession.value)?.impersonating !== true
    );
  });

  $logoutButton.addEventListener('click', logOut);
}

const socketLogger = log.getLogger('socket');

const connection = standalone ? undefined : connectToApplication();

function connectToApplication(): SocketConnection<Socket> {
  const socketConnection = createSocketConnection({
    createSocket: params => new Socket('/socket', { params }),
    fetchToken,
    shouldReconnect: () => localStorage.getItem('archidep:session') !== null,
    authenticationFailed: err => err instanceof HttpAuthenticationError,
    onClose: () => {
      socketLogger.info('Connection closed');
      const session = getSession(currentSession.value);
      currentSession.value =
        session === undefined ? anonymousSession() : cachedSession(session);
    },
    onAuthenticationFailed: () => {
      // The session is presumably no longer valid. The user will have to leave
      // the page or log in from another tab to connect again.
      currentSession.value = anonymousSession();
      localStorage.removeItem('archidep:session');
    },
    isPageHidden: () => document.visibilityState === 'hidden',
    logger: socketLogger
  });

  const { socket } = socketConnection;

  socket.onError(error => {
    const errorMessage =
      G.isString(error) || G.isNumber(error) ? String(error) : '(unknown)';
    socketLogger.warn(`Connection error ${errorMessage}`);

    currentSession.value = sessionConnectionError(
      errorMessage,
      getSession(currentSession.value)
    );
  });

  // Phoenix rejoins the channel whenever the socket connects again.
  const channel = socket.channel('me', {});

  channel.on('cloudServerData', payload => {
    cloudServer.value = pipe(
      O.fromNullable(payload),
      O.map(cloudServerDataType.decode),
      O.flatMap(decoded => (isRight(decoded) ? O.Some(decoded.right) : O.None)),
      O.toUndefined
    );
  });

  channel.on('session', payload => {
    const decodedSession = sessionType.decode(payload);
    if (isRight(decodedSession)) {
      const session = decodedSession.right;
      currentSession.value = connectedSession(session);
      socketLogger.debug(`Session ${session.sessionId} updated`);
      localStorage.setItem('archidep:session', JSON.stringify(session));
    } else {
      socketLogger.error(
        `Failed to decode 'session' channel payload: ${JSON.stringify(payload)}`
      );
      currentSession.value = sessionConnectionError(
        'Failed to decode session payload',
        getSession(currentSession.value)
      );
      localStorage.removeItem('archidep:session');
    }
  });

  channel
    .join()
    .receive('ok', resp => {
      socketConnection.established();
      const decodedSession = sessionType.decode(resp);
      if (isRight(decodedSession)) {
        const session = decodedSession.right;
        currentSession.value = connectedSession(session);
        socketLogger.debug(`Welcome, ${session.username}!`);
        localStorage.setItem('archidep:session', JSON.stringify(session));
      } else {
        socketLogger.error(
          `Failed to decode 'me' channel payload: ${JSON.stringify(resp)}`
        );
      }
    })
    .receive('error', resp => {
      socketLogger.warn(`Failed to join 'me' channel: ${JSON.stringify(resp)}`);
    });

  // Another tab logged in, or connected with a session this one lost.
  window.addEventListener('storage', event => {
    if (event.key === 'archidep:session' && event.newValue !== null) {
      socketConnection.connect();
    }
  });

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState !== 'hidden') {
      socketConnection.pageShown();
    }
  });

  socketConnection.connect();

  return socketConnection;
}

const socketTokenType = t.readonly(t.type({ token: t.string }));

function fetchToken(): Promise<string> {
  return fetch('/auth/socket')
    .then(res => {
      if (!res.ok) {
        if (res.status === 401) {
          throw new HttpAuthenticationError(res);
        }

        throw new Error(`Connection request failed with status ${res.status}`);
      }

      return res.json();
    })
    .then((data: unknown) => {
      const decoded = socketTokenType.decode(data);
      if (isRight(decoded)) {
        return decoded.right.token;
      }

      throw new Error('Connection request returned no token');
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
      connection?.stop();
    })
    .catch(err => logger.warn(`Logout failed: ${err.message}`));
}
