import { G, O, pipe } from '@mobily/ts-belt';
import { init } from '@plausible-analytics/tracker';
import { effect } from '@preact/signals';
import ClipboardJS from 'clipboard';
import { isRight } from 'fp-ts/lib/Either';
import { Socket } from 'phoenix';

import './course/back-to-top';
import { cloudServer, cloudServerDataType } from './course/cloud-server';
import './course/randomize';
import './course/search';
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
import './simgit';
import {
  defineSimgitStoryElement,
  verticalStackArrangement,
  type RenderLayout,
  type SimgitStoryElement
} from '@alphahydrae/simgit';
import { required, toggleClass } from './utils';

const logger = log.getLogger('course');

logger.info('ArchiDep 🚀');

new ClipboardJS('[data-clipboard-target], [data-clipboard-text]');

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

// A multi-computer story needs both of these, and they are rich values the
// element takes by property rather than by attribute: the renderer otherwise
// draws every computer at the same origin, piling the story into one illegible
// heap, and without chrome the stacked repositories carry no machine names.
// The stack keeps each computer's intrinsic height rather than filling the
// canvas: these embeds size themselves to their content (`sizing='auto-height'`),
// so equal-height fill would give every computer the height of the tallest and
// leave a two-repository chapter three times taller than it needs to be.
//
// The layout is set before the element is defined, so the value is in place
// when each embed connects and reads it.
const collaborationLayout: RenderLayout = {
  containerArrangement: verticalStackArrangement(),
  showComputerChrome: true
};
for (const el of document.querySelectorAll<SimgitStoryElement>(
  'simgit-story'
)) {
  if (el.getAttribute('name') === 'github') {
    el.renderLayout = collaborationLayout;
  }
}

// Stories are registered by importing the registry above, and only then is the
// custom element defined, so the `<simgit-story>` tags already in the page
// upgrade against a populated registry. Each embed defers on its own
// IntersectionObserver, so there is nothing to observe here.
defineSimgitStoryElement();

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

const retryIntervals = [
  500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 10_000, 20_000
];
const defaultRetryInterval = 30_000;
let connectionAttempt = 0;
const socketLogger = log.getLogger('socket');

if (!standalone) {
  connectSocket();
}

let connectionTimeout: NodeJS.Timeout | undefined;

window.addEventListener('storage', event => {
  if (event.key !== 'archidep:session' || event.newValue === null) {
    return;
  }

  clearTimeout(connectionTimeout);
  connectSocket();
});

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
        const errorMessage =
          G.isString(error) || G.isNumber(error) ? String(error) : '(unknown)';
        socketLogger.warn(`Connection error ${errorMessage}`);

        currentSession.value = sessionConnectionError(
          errorMessage,
          getSession(currentSession.value)
        );
      });

      socket.onClose(() => {
        socket.disconnect();
        socketLogger.info(
          `Connection closed; will reconnect in ${retryInterval / 1000} seconds`
        );
        const session = getSession(currentSession.value);
        currentSession.value =
          session === undefined ? anonymousSession() : cachedSession(session);

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

      channel.on('cloudServerData', payload => {
        cloudServer.value = pipe(
          O.fromNullable(payload),
          O.map(cloudServerDataType.decode),
          O.flatMap(decoded =>
            isRight(decoded) ? O.Some(decoded.right) : O.None
          ),
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
            `Failed to decode 'session' channel payload: ${JSON.stringify(
              payload
            )}`
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
          socketLogger.warn(
            `Failed to join 'me' channel: ${JSON.stringify(resp)}`
          );
        });
    })
    .catch(err => {
      socketLogger.info(
        `Failed to connect because: ${err.message}; will retry in ${retryInterval / 1000} second(s)`
      );

      if (err instanceof HttpAuthenticationError) {
        // If authentication failed, this presumably means that the session is
        // no longer valid. Clear the session and give up attempting to
        // reconnect. The user will have to leave the page to log in again.
        connectionAttempt = 0;
        socketLogger.info('Authentication failed, giving up on reconnecting');
        currentSession.value = anonymousSession();
        localStorage.removeItem('archidep:session');
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
