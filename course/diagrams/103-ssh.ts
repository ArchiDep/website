// An SSH connection and the processes at both ends. Your computer alone first,
// to contrast running a command locally and remotely; then what you type
// travels over the connection, a keystroke at a time, which only this diagram
// shows, being the first to explain an SSH connection.
import {
  ARRIVED,
  child,
  connect,
  data,
  diagram,
  handOver,
  launched,
  pulse,
  show,
  spawned,
  step,
  teardown
} from '../src/diagrams/build';

const CONNECTION = 'edge-ssh-client-ssh-session';

export default diagram({
  captions: {
    rest:
      'Your terminal’s shell started the SSH client, which is connected to ' +
      '<code>example.com</code> on port 22. There, the SSH session started a ' +
      'shell, which runs your commands on the server.',
    start: 'Your computer.'
  },
  steps: [
    step(
      'You open a terminal, which starts a shell: Bash or Zsh.',
      show('node-terminal'),
      child('node-local-shell', 'edge-terminal-local-shell')
    ),
    step(
      'You run a command, <code>ls</code> or any other: the shell starts it, ' +
        'and it runs on your computer.',
      spawned('node-local-command', {
        shell: 'node-local-shell',
        edge: 'edge-local-shell-local-command'
      })
    ),
    step(
      '<code>ls</code> works: it lists the files of the current directory, ' +
        'and prints them to your terminal.',
      pulse('node-local-command')
    ),
    step(
      'It has finished, and exits.',
      teardown(['node-local-command', 'edge-local-shell-local-command'])
    ),
    step(
      'Across the Internet, a server runs an SSH server, waiting for ' +
        'connections on port 22.',
      show('lane-server', 'boundary-internet', 'cloud-internet', 'node-sshd')
    ),
    step(
      'You run <code>ssh jde@example.com</code>: your shell starts the SSH ' +
        'client, which connects to port 22 on <code>example.com</code>.',
      spawned('node-ssh-client', {
        shell: 'node-local-shell',
        edge: 'edge-local-shell-ssh-client'
      }),
      connect(CONNECTION, { after: launched('ssh jde@example.com') + 0.4 })
    ),
    step(
      'The SSH server accepts the connection, and starts a new SSH session to ' +
        'take care of it.',
      child('node-ssh-session', 'edge-sshd-ssh-session')
    ),
    step(
      'It hands the connection over to the session, then goes back to ' +
        'waiting for the next one.',
      handOver(CONNECTION)
    ),
    step(
      'The session starts a shell on the server.',
      child('node-remote-shell', 'edge-ssh-session-remote-shell')
    ),
    step(
      'You type <code>l</code>. Your terminal hands it to the SSH client, ' +
        'which sends it over the connection at once, encrypted. On the ' +
        'server, the session hands it to the shell.',
      data(CONNECTION, 'l').whole(),
      show('remote-prompt-l')
    ),
    step(
      'You type <code>s</code>: it travels the same way.',
      data(CONNECTION, 's').whole(),
      show('remote-prompt-ls'),
      teardown(['remote-prompt-l'], { after: ARRIVED })
    ),
    step(
      'You press Enter, which travels too. Once it has arrived, the server’s ' +
        'shell runs <code>ls</code>, on the server.',
      data(CONNECTION, '⏎').whole(),
      teardown(['remote-prompt-ls'], { after: ARRIVED }),
      child('node-remote-command', 'edge-remote-shell-remote-command', {
        after: ARRIVED
      })
    ),
    step(
      '<code>ls</code> works, on the server: it lists the files of the ' +
        'current directory there.',
      pulse('node-remote-command')
    ),
    step(
      'Its output travels back over the connection, against the arrow, and ' +
        'your terminal displays it.',
      data(CONNECTION, 'output', { reverse: true }).whole()
    )
  ]
});
