/*
 * Keeps the page's single WebSocket to the dashboard application connected.
 *
 * The socket authenticates with a short-lived token fetched from the
 * application, so every connection attempt fetches a new one first. This module
 * owns those attempts: there is one socket for the page and at most one pending
 * attempt at any time, retried with an exponential, jittered backoff and only
 * while the page is visible. Phoenix's own reconnections are cut short whenever
 * the socket closes, as they would present the token the socket last connected
 * with, long expired by then.
 */

export interface SocketParams {
  readonly token: string;
}

/**
 * The part of a Phoenix `Socket` this module drives.
 */
export interface ConnectableSocket {
  connect(): void;
  disconnect(): void;
  isConnected(): boolean;
  onClose(callback: () => void): unknown;
}

export interface SocketConnectionLogger {
  debug(message: string): void;
  info(message: string): void;
}

export interface SocketConnectionOptions<S extends ConnectableSocket> {
  /**
   * Creates the page's socket, which reads its params on each connection.
   */
  readonly createSocket: (params: () => SocketParams) => S;
  /**
   * Fetches a new token, rejecting with `authenticationFailed` on a 401.
   */
  readonly fetchToken: () => Promise<string>;
  /**
   * Whether a closed socket should connect again (someone is logged in).
   */
  readonly shouldReconnect: () => boolean;
  /**
   * Tells whether an error of `fetchToken` means the session is gone.
   */
  readonly authenticationFailed: (error: unknown) => boolean;
  readonly onClose: () => void;
  readonly onAuthenticationFailed: () => void;
  readonly isPageHidden: () => boolean;
  readonly logger: SocketConnectionLogger;
  readonly random?: () => number;
  /**
   * Calls the callback after the delay, unless the returned function is called
   * first to cancel it.
   */
  readonly schedule?: (callback: () => void, ms: number) => () => void;
}

export interface SocketConnection<S extends ConnectableSocket> {
  readonly socket: S;
  /**
   * Connects now unless connected or already attempting to.
   */
  connect(): void;
  /**
   * Resets the backoff, once the connection has proven usable.
   */
  established(): void;
  /**
   * Connects now if an attempt was waiting for the page to be shown.
   */
  pageShown(): void;
  /**
   * Disconnects and stops attempting to connect until `connect` is called.
   */
  stop(): void;
}

export const initialRetryDelay = 500;
export const maxRetryDelay = 30_000;

export function createSocketConnection<S extends ConnectableSocket>(
  options: SocketConnectionOptions<S>
): SocketConnection<S> {
  const random = options.random ?? Math.random;
  const schedule = options.schedule ?? scheduleTimeout;
  const { logger } = options;

  let token = '';
  let failedAttempts = 0;
  let cancelTimer: (() => void) | undefined;
  let fetching = false;
  let waitingForPage = false;
  let stopped = true;

  const socket = options.createSocket(() => ({ token }));

  socket.onClose(() => {
    // Phoenix schedules its own reconnection before calling this, which this
    // cancels.
    socket.disconnect();
    options.onClose();

    if (stopped || !options.shouldReconnect()) {
      stop();
      return;
    }

    retry();
  });

  function connect(): void {
    stopped = false;
    cancelRetry();

    if (fetching || socket.isConnected()) {
      return;
    }

    attempt();
  }

  function attempt(): void {
    fetching = true;
    logger.debug('Connecting...');

    options
      .fetchToken()
      .then(newToken => {
        fetching = false;
        if (stopped) {
          return;
        }

        token = newToken;
        socket.connect();
      })
      .catch((err: unknown) => {
        fetching = false;
        if (stopped) {
          return;
        }

        if (options.authenticationFailed(err)) {
          logger.info('Authentication failed, giving up on reconnecting');
          stop();
          options.onAuthenticationFailed();
          return;
        }

        logger.info(
          `Failed to connect because: ${err instanceof Error ? err.message : String(err)}`
        );
        retry();
      });
  }

  function retry(): void {
    cancelRetry();

    if (options.isPageHidden()) {
      waitForPage();
      return;
    }

    const delay = retryDelay(failedAttempts, random());
    failedAttempts++;
    logger.info(`Will reconnect in ${(delay / 1000).toFixed(1)} second(s)`);

    cancelTimer = schedule(() => {
      cancelTimer = undefined;
      if (options.isPageHidden()) {
        waitForPage();
      } else {
        attempt();
      }
    }, delay);
  }

  function waitForPage(): void {
    logger.debug('Will reconnect once the page is shown');
    waitingForPage = true;
  }

  function cancelRetry(): void {
    waitingForPage = false;
    cancelTimer?.();
    cancelTimer = undefined;
  }

  function stop(): void {
    stopped = true;
    failedAttempts = 0;
    cancelRetry();
    socket.disconnect();
  }

  return {
    socket,
    connect,
    established: () => {
      failedAttempts = 0;
    },
    pageShown: () => {
      if (waitingForPage && !stopped) {
        waitingForPage = false;
        attempt();
      }
    },
    stop
  };
}

function scheduleTimeout(callback: () => void, ms: number): () => void {
  const timeout = setTimeout(callback, ms);
  return () => clearTimeout(timeout);
}

/**
 * The delay before reconnecting after the given number of failed attempts:
 * doubling from `initialRetryDelay` up to `maxRetryDelay`, then randomly
 * reduced by up to half so that the pages that lost their connection together
 * do not all come back at once.
 */
export function retryDelay(failedAttempts: number, random: number): number {
  const ceiling = Math.min(
    maxRetryDelay,
    initialRetryDelay * 2 ** failedAttempts
  );
  return Math.round(ceiling / 2 + (ceiling / 2) * random);
}
