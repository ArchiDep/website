// Two netcats, one connection, data both ways.
import {
  connect,
  data,
  diagram,
  launched,
  spawned,
  step
} from '../src/diagrams/build';

const CONNECTION = 'edge-alice-nc-bob-nc';
const hello = data(CONNECTION, 'Hello', { reverse: true });
const world = data(CONNECTION, 'World');

export default diagram({
  captions: {
    rest:
      'Alice’s netcat is connected to Bob’s, which listens on port 3000. ' +
      'The arrow shows who opened the connection: Alice.',
    start:
      'Two servers, separated by the Internet. Alice and Bob are each ' +
      'connected to their server over SSH, as in the first session; the ' +
      'diagram leaves that out to focus on the connection between the two ' +
      'netcats.'
  },
  steps: [
    step(
      'Bob runs <code>nc -l 3000</code>. His netcat starts and listens on ' +
        'port 3000, waiting for a connection.',
      spawned('node-bob-nc')
    ),
    step(
      'Alice runs <code>nc W.X.Y.Z 3000</code>. Her netcat connects to port ' +
        '3000 on Bob’s server. The arrow starts from the one who connected.',
      spawned('node-alice-nc'),
      connect(CONNECTION, {
        after: launched('nc W.X.Y.Z 3000', { edge: false }) + 0.25
      })
    ),
    step(
      'Bob types <code>Hello</code> and presses Enter. His netcat sends it ' +
        'over the connection…',
      hello.toMiddle()
    ),
    step(
      '…and Alice’s netcat prints it in her terminal. The data travelled ' +
        'against the arrow: once connected, either side can send.',
      hello.onward()
    ),
    step('Alice types <code>World</code> and presses Enter…', world.toMiddle()),
    step(
      '…and Bob’s netcat prints it. One connection, data in both directions.',
      world.onward()
    )
  ]
});
