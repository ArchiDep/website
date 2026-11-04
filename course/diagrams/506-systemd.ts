// Running the application of "Deploy with systemd": started by systemd at your
// request, it outlives your SSH session; then you reboot the server, and
// systemd, the first process, starts PostgreSQL and the application again,
// before a request is served from the browser to the database and back. What runs before
// the reboot is drawn apart from what runs after it, and only shown while
// stepping, since the fully drawn diagram is the server once rebooted.
import {
  ARRIVED,
  child,
  connect,
  data,
  diagram,
  launched,
  pulse,
  show,
  spawned,
  step,
  teardown,
  typedInto,
  typing,
  waiting
} from '../src/diagrams/build/processes';

const REBOOT_COMMAND = 'sudo reboot';
// Once the control edge from systemd is drawn and Guess It has appeared.
const GUESSIT_STARTED = 1;
const URL = 'http://W.X.Y.Z:3000';
const HTTP = 'edge-browser-guessit';
const DATABASE = 'edge-guessit-postgresql';
const browserWaits = waiting('node-browser');
const guessitWaits = waiting('node-guessit');

export default diagram({
  captions: {
    rest:
      'In this diagram, systemd, the init process, has started PostgreSQL and ' +
      'then Guess It when the server booted, without anyone logging in. Your ' +
      'browser talks to Guess It, which talks to PostgreSQL.',
    start:
      'Your terminal is connected to your server over SSH. systemd, the init ' +
      'process, started the SSH server and PostgreSQL when the server booted. ' +
      'You have enabled the Guess It service, which is not running yet.'
  },
  steps: [
    step(
      'You run <code>systemctl</code> to start the Guess It service. ' +
        '<code>systemctl</code> does not start Guess It itself: it asks ' +
        'systemd to, through a local socket.',
      spawned('node-systemctl', {
        shell: 'node-remote-shell',
        edge: 'edge-remote-shell-systemctl'
      }),
      pulse('node-systemctl')
    ),
    step(
      'systemd starts Guess It as the <code>guessit</code> user, with the ' +
        'variables of its configuration file. <code>systemctl</code> exits ' +
        'once Guess It runs.',
      child('node-guessit-before-reboot', 'edge-systemd-guessit-before-reboot'),
      teardown(['node-systemctl', 'edge-remote-shell-systemctl'], {
        after: GUESSIT_STARTED
      })
    ),
    step(
      'You log out and close your terminal: the SSH connection closes, and ' +
        'the processes at both of its ends exit. Guess It keeps running, ' +
        'since systemd started it, not your shell.',
      teardown([
        'node-terminal',
        'node-local-shell',
        'node-ssh-client',
        'edge-ssh-client-ssh-session',
        'node-ssh-session',
        'node-remote-shell',
        'edge-sshd-ssh-session'
      ])
    ),
    step(
      'You connect to your server over SSH again.',
      show(
        'node-terminal-again',
        'node-local-shell-again',
        'node-ssh-client-again',
        'edge-ssh-client-ssh-session-again',
        'node-ssh-session-again',
        'node-remote-shell-again',
        'edge-sshd-ssh-session-again'
      )
    ),
    step(
      'You reboot the server with <code>sudo reboot</code>: every process on ' +
        'the server stops, systemd included, and your SSH connection closes.',
      spawned('node-reboot', {
        shell: 'node-remote-shell-again',
        edge: 'edge-remote-shell-reboot'
      }),
      teardown(
        [
          'node-reboot',
          'edge-remote-shell-reboot',
          'node-terminal-again',
          'node-local-shell-again',
          'node-ssh-client-again',
          'edge-ssh-client-ssh-session-again',
          'node-ssh-session-again',
          'node-remote-shell-again',
          'edge-sshd-ssh-session-again',
          'node-sshd',
          'edge-systemd-sshd-before-reboot',
          'node-systemd-before-reboot',
          'node-guessit-before-reboot',
          'edge-systemd-guessit-before-reboot',
          'node-postgresql-before-reboot',
          'edge-systemd-postgresql-before-reboot'
        ],
        { after: launched(REBOOT_COMMAND) + 1 }
      )
    ),
    step(
      'The server boots. The kernel starts the first process, the init ' +
        'process with process ID 1, which is systemd on Linux.',
      show('node-systemd')
    ),
    step(
      'systemd starts the services enabled on boot, such as the SSH server, ' +
        'which is not drawn here, and PostgreSQL, which listens on port 5432.',
      child('node-postgresql', 'edge-systemd-postgresql')
    ),
    step(
      'systemd starts Guess It, which you enabled, once PostgreSQL has ' +
        'started, as <code>After=postgresql.service</code> in its unit file ' +
        'asks. Guess It listens on port 3000, though nobody has logged in.',
      child('node-guessit', 'edge-systemd-guessit')
    ),
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type your server’s public IP address and port into it. The ' +
        'browser connects to port 3000, where Guess It is listening.',
      typedInto('node-browser', URL),
      connect(HTTP, { after: typing(URL).enter + 0.2 })
    ),
    step(
      'The browser sends an HTTP request for the home page over the ' +
        'connection, and waits for the answer.',
      data(HTTP, 'GET /').whole(),
      browserWaits.start()
    ),
    step(
      'Guess It works: Node.js runs its JavaScript code, which needs the ' +
        'leaderboard from the database.',
      pulse('node-guessit')
    ),
    step(
      'Guess It connects to PostgreSQL on port 5432, with the database URL ' +
        'systemd gave it from its configuration file.',
      connect(DATABASE)
    ),
    step(
      'Guess It sends its query over the connection.',
      data(DATABASE, 'SELECT …').whole(),
      guessitWaits.start()
    ),
    step(
      'PostgreSQL works, running the query, while Guess It waits for the ' +
        'answer.',
      pulse('node-postgresql')
    ),
    step(
      'The rows of the leaderboard travel back to Guess It.',
      data(DATABASE, 'rows', { reverse: true }).whole(),
      guessitWaits.stop({ after: ARRIVED })
    ),
    step(
      'Guess It works again, building the HTML page from the rows.',
      pulse('node-guessit')
    ),
    step(
      'The page travels back over the connection to the browser, with its ' +
        'stylesheets and scripts.',
      data(HTTP, 'HTML/CSS/JS', { reverse: true }).whole(),
      browserWaits.stop({ after: ARRIVED })
    ),
    step('The browser works, displaying the page.', pulse('node-browser'))
  ]
});
