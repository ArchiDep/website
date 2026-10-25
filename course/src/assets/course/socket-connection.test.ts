import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';

import {
  createSocketConnection,
  maxRetryDelay,
  retryDelay,
  type ConnectableSocket,
  type SocketConnection,
  type SocketParams
} from './socket-connection';

class FakeSocket implements ConnectableSocket {
  /**
   * The token presented by each connection, in order.
   */
  readonly connections: string[] = [];
  disconnects = 0;
  connected = false;
  private readonly closeCallbacks: (() => void)[] = [];

  constructor(private readonly params: () => SocketParams) {}

  connect(): void {
    this.connections.push(this.params().token);
  }

  disconnect(): void {
    this.disconnects++;
    this.connected = false;
  }

  isConnected(): boolean {
    return this.connected;
  }

  onClose(callback: () => void): void {
    this.closeCallbacks.push(callback);
  }

  close(): void {
    this.connected = false;
    this.closeCallbacks.forEach(callback => callback());
  }
}

interface PendingToken {
  resolve(token: string): void;
  reject(error: unknown): void;
}

class AuthenticationError extends Error {}

interface Harness {
  readonly connection: SocketConnection<FakeSocket>;
  readonly sockets: FakeSocket[];
  readonly tokenRequests: PendingToken[];
  /**
   * The pending timers, by id.
   */
  readonly timers: Map<
    number,
    { readonly ms: number; readonly run: () => void }
  >;
  readonly events: string[];
  hidden: boolean;
  session: boolean;
}

function createHarness(): Harness {
  const sockets: FakeSocket[] = [];
  const tokenRequests: PendingToken[] = [];
  const timers = new Map<number, { ms: number; run: () => void }>();
  const events: string[] = [];
  let nextTimer = 1;

  const harness: Omit<Harness, 'connection'> = {
    sockets,
    tokenRequests,
    timers,
    events,
    hidden: false,
    session: true
  };

  const connection = createSocketConnection({
    createSocket: params => {
      const socket = new FakeSocket(params);
      sockets.push(socket);
      return socket;
    },
    fetchToken: () =>
      new Promise<string>((resolve, reject) => {
        tokenRequests.push({ resolve, reject });
      }),
    shouldReconnect: () => harness.session,
    authenticationFailed: err => err instanceof AuthenticationError,
    onClose: () => events.push('close'),
    onAuthenticationFailed: () => events.push('authentication failed'),
    isPageHidden: () => harness.hidden,
    logger: { debug: () => undefined, info: () => undefined },
    random: () => 1,
    schedule: (run, ms) => {
      const id = nextTimer++;
      timers.set(id, {
        ms,
        run: () => {
          timers.delete(id);
          run();
        }
      });
      return () => {
        timers.delete(id);
      };
    }
  });

  return Object.assign(harness, { connection });
}

function pendingDelays(harness: Harness): number[] {
  return [...harness.timers.values()].map(timer => timer.ms);
}

function runTimers(harness: Harness): void {
  [...harness.timers.values()].forEach(timer => timer.run());
}

function flush(): Promise<void> {
  return new Promise(resolve => setImmediate(resolve));
}

async function connectWith(harness: Harness, token: string): Promise<void> {
  const request = harness.tokenRequests[harness.tokenRequests.length - 1];
  assert.ok(request, 'no token request is pending');
  request.resolve(token);
  await flush();
  const socket = harness.sockets[0];
  assert.ok(socket);
  socket.connected = true;
}

describe('createSocketConnection', () => {
  let harness: Harness;

  beforeEach(() => {
    harness = createHarness();
  });

  it('connects its single socket with a newly fetched token', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    assert.equal(harness.sockets.length, 1);
    assert.deepEqual(harness.sockets[0]?.connections, ['token-1']);
    assert.equal(harness.tokenRequests.length, 1);
  });

  it('fetches a new token for each reconnection of the same socket', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    harness.sockets[0]?.close();
    runTimers(harness);
    await connectWith(harness, 'token-2');

    assert.equal(harness.sockets.length, 1);
    assert.deepEqual(harness.sockets[0]?.connections, ['token-1', 'token-2']);
  });

  it('cancels the reconnection Phoenix schedules when the socket closes', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    harness.sockets[0]?.close();

    assert.equal(harness.sockets[0]?.disconnects, 1);
    assert.deepEqual(harness.events, ['close']);
  });

  it('keeps a single pending reconnection however often it is asked for', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    harness.sockets[0]?.close();
    harness.sockets[0]?.close();
    harness.sockets[0]?.close();

    assert.equal(harness.timers.size, 1);

    harness.connection.connect();
    harness.connection.connect();

    assert.deepEqual(pendingDelays(harness), []);
    assert.equal(harness.tokenRequests.length, 2);
  });

  it('doubles the delay after each failed attempt until it is reset', async () => {
    harness.connection.connect();
    harness.tokenRequests[0]?.reject(new Error('offline'));
    await flush();
    assert.deepEqual(pendingDelays(harness), [500]);

    runTimers(harness);
    harness.tokenRequests[1]?.reject(new Error('offline'));
    await flush();
    assert.deepEqual(pendingDelays(harness), [1000]);

    runTimers(harness);
    await connectWith(harness, 'token-1');
    harness.connection.established();
    harness.sockets[0]?.close();

    assert.deepEqual(pendingDelays(harness), [500]);
  });

  it('waits for the page to be shown instead of retrying while it is hidden', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    harness.hidden = true;
    harness.sockets[0]?.close();

    assert.deepEqual(pendingDelays(harness), []);
    assert.equal(harness.tokenRequests.length, 1);

    harness.hidden = false;
    harness.connection.pageShown();

    assert.equal(harness.tokenRequests.length, 2);
  });

  it('does not connect when the page is shown without a pending attempt', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    harness.connection.pageShown();

    assert.equal(harness.tokenRequests.length, 1);
  });

  it('defers a retry that comes due while the page is hidden', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');
    harness.sockets[0]?.close();

    harness.hidden = true;
    runTimers(harness);

    assert.equal(harness.tokenRequests.length, 1);

    harness.hidden = false;
    harness.connection.pageShown();

    assert.equal(harness.tokenRequests.length, 2);
  });

  it('gives up when authentication fails', async () => {
    harness.connection.connect();
    harness.tokenRequests[0]?.reject(new AuthenticationError());
    await flush();

    assert.deepEqual(harness.events, ['authentication failed']);
    assert.deepEqual(pendingDelays(harness), []);
    assert.deepEqual(harness.sockets[0]?.connections, []);
  });

  it('does not reconnect once nobody is logged in', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');

    harness.session = false;
    harness.sockets[0]?.close();

    assert.deepEqual(pendingDelays(harness), []);
  });

  it('stops reconnecting when stopped', async () => {
    harness.connection.connect();
    await connectWith(harness, 'token-1');
    harness.sockets[0]?.close();

    harness.connection.stop();
    harness.sockets[0]?.close();

    assert.deepEqual(pendingDelays(harness), []);
    assert.equal(harness.tokenRequests.length, 1);
  });

  it('ignores a token that arrives after it was stopped', async () => {
    harness.connection.connect();
    harness.connection.stop();
    harness.tokenRequests[0]?.resolve('token-1');
    await flush();

    assert.deepEqual(harness.sockets[0]?.connections, []);
  });
});

describe('retryDelay', () => {
  it('doubles from half a second up to the maximum', () => {
    assert.deepEqual(
      [0, 1, 2, 3, 4, 5, 6, 7, 10].map(attempts => retryDelay(attempts, 1)),
      [500, 1000, 2000, 4000, 8000, 16_000, 30_000, 30_000, maxRetryDelay]
    );
  });

  it('is reduced by up to half at random', () => {
    assert.deepEqual(
      [0, 0.5, 1].map(random => retryDelay(3, random)),
      [2000, 3000, 4000]
    );
  });
});
