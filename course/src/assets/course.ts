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
  currentSession,
  currentSessionRootFlag,
  sessionType
} from './course/session';
import './course/tell-me-more';
import './course/toc';
import { HttpAuthenticationError } from './errors';
import { GitMemoirController } from './git-memoir/git-memoir-controller';
import './git-memoir/git-memoirs-registry';
import log from './logging';
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

// Display Git memoirs on page as they come into view
const gitMemoirsOnPage = document.querySelectorAll('git-memoir');
const urlParams = new URLSearchParams(window.location.search);
const forceGitMemoirs = urlParams.get('git-memoir-force') === 'true';
if (forceGitMemoirs) {
  gitMemoirsOnPage.forEach(el => GitMemoirController.startNewGitMemoir(el));
} else if (gitMemoirsOnPage.length !== 0) {
  const options = {
    root: null,
    rootMargin: '0px',
    scrollMargin: '0px',
    threshold: 0.25,
    delay: 100
  };

  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        GitMemoirController.startNewGitMemoir(entry.target);
      }
    }
  }, options);

  gitMemoirsOnPage.forEach(el => observer.observe(el));
}

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
    toggleClass($loginButton, 'flex', currentSession.value === undefined);
    toggleClass($loginButton, 'hidden', currentSession.value !== undefined);
    toggleClass($navbarProfile, 'hidden', currentSession.value === undefined);
    $logoutButton.removeAttribute('disabled');
  });

  effect(() => {
    toggleClass(
      $navbarProfileUser,
      'hidden',
      currentSession.value?.impersonating === true
    );
    toggleClass(
      $navbarProfileImpersonator,
      'hidden',
      !currentSession.value?.impersonating
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
        socketLogger.warn(
          `Connection error ${G.isString(error) || G.isNumber(error) ? String(error) : '(unknown)'}`
        );
      });

      socket.onClose(() => {
        socket.disconnect();
        socketLogger.info(
          `Connection closed; will reconnect in ${retryInterval / 1000} seconds`
        );
        currentSession.value = undefined;

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
          currentSession.value = session;
          socketLogger.debug(`Session ${session.sessionId} updated`);
          localStorage.setItem('archidep:session', JSON.stringify(session));
        }
      });

      channel
        .join()
        .receive('ok', resp => {
          const decodedSession = sessionType.decode(resp);
          if (isRight(decodedSession)) {
            const payload = decodedSession.right;
            currentSession.value = payload;
            socketLogger.debug(`Welcome, ${payload.username}!`);
            localStorage.setItem('archidep:session', JSON.stringify(payload));
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
