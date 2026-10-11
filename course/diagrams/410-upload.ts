// Uploading the application of "Deploy a web application with SFTP", 2 of 3.
// The SFTP client opens a second SSH connection while the terminal's is still
// open, and closes it once the files are uploaded.
import {
  child,
  connect,
  data,
  diagram,
  handOver,
  pulse,
  show,
  step,
  teardown
} from '../src/diagrams/build';

const CONNECTION = 'edge-sftp-client-sftp-session';

export default diagram({
  captions: {
    rest:
      'Your SFTP client is connected to your server, uploading the ' +
      'application, while your terminal is still connected over SSH.',
    start:
      'Your terminal is still connected to your server over SSH, and ' +
      'PostgreSQL is running. You now upload the application from your ' +
      'computer.'
  },
  steps: [
    step(
      'You open your SFTP client: WinSCP on Windows, or Cyberduck on macOS.',
      show('node-sftp-client')
    ),
    step(
      'It connects to port 22, where the SSH server is listening, as your ' +
        'SSH client did: SFTP works over SSH.',
      connect(CONNECTION, { after: 0.3 })
    ),
    step(
      'The SSH server accepts the connection, and starts a new SSH session ' +
        'for it. Your terminal’s session is still there: the SSH server is ' +
        'not tied up by one connection.',
      child('node-sftp-session', 'edge-sshd-sftp-session')
    ),
    step(
      'It hands the connection over to the new session, and goes back to ' +
        'waiting on port 22.',
      handOver(CONNECTION)
    ),
    step(
      'This session starts the SFTP server, <code>sftp-server</code>, rather ' +
        'than a shell, because this is an SFTP client connecting, not a human logging in.',
      child('node-sftp-server', 'edge-sftp-session-sftp-server')
    ),
    step(
      'You drag the application’s directory onto the server. Its files travel ' +
        'over the connection: <code>server.js</code>, the application…',
      data(CONNECTION, 'server.js').whole()
    ),
    step(
      '…<code>schema.sql</code>, the structure of its database…',
      data(CONNECTION, 'schema.sql').whole()
    ),
    step(
      '…and <code>node_modules</code>, the libraries it depends on, copied ' +
        'with it: hundreds of small files, which take a while.',
      data(CONNECTION, 'node_modules/', { heavy: true }).whole()
    ),
    step(
      'The SFTP server writes the files to the disk of the server, in the ' +
        'directory you chose.',
      pulse('node-sftp-server')
    ),
    step(
      'You close your SFTP client: its connection closes, and its session and ' +
        'the SFTP server exit. The SSH server is still waiting on port 22, and ' +
        'your terminal is still connected.',
      teardown([
        'node-sftp-client',
        CONNECTION,
        'node-sftp-session',
        'node-sftp-server',
        'edge-sshd-sftp-session',
        'edge-sftp-session-sftp-server'
      ])
    )
  ]
});
