// The SSH connection of "Secure Shell (SSH)", already open, seen through the
// standard streams: what you type reaches the server's shell, and what a
// command there prints comes back to your terminal, because each process
// inherited its streams from the one that started it.
import {
  ARRIVED,
  child,
  data,
  diagram,
  pulse,
  show,
  step,
  teardown
} from '../src/diagrams/build';

const CONNECTION = 'edge-ssh-client-ssh-session';

export default diagram({
  captions: {
    rest:
      'The SSH client inherited the standard streams of your shell: it reads ' +
      'what you type, and writes to your terminal. On the server, the shell ' +
      'and the commands it starts read from and write to the SSH session.',
    start:
      'You are connected to a server over SSH. Your shell started the SSH ' +
      'client, and on the server, the SSH session started a shell. The ' +
      'connection is open, waiting for you to type.'
  },
  steps: [
    step(
      'You type <code>l</code>. It goes to the standard input of the SSH ' +
        'client, which it inherited from your shell. The client sends it over ' +
        'the connection, and on the server, the session hands it to the ' +
        'standard input of the shell.',
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
        'shell starts <code>ls</code>, which inherits the shell’s standard ' +
        'streams.',
      data(CONNECTION, '⏎').whole(),
      teardown(['remote-prompt-ls'], { after: ARRIVED }),
      child('node-remote-command', 'edge-remote-shell-remote-command', {
        after: ARRIVED
      })
    ),
    step(
      '<code>ls</code> lists the files of the current directory on the ' +
        'server, and writes them to its standard output. It does not know ' +
        'where that goes.',
      pulse('node-remote-command')
    ),
    step(
      'Its output goes to the SSH session, back over the connection, and out ' +
        'of the standard output of the SSH client: your terminal displays it.',
      data(CONNECTION, 'output', { reverse: true }).whole()
    )
  ]
});
