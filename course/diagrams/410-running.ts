// Running the application of "Deploy a web application with SFTP", 3 of 3: its
// database created, then the application started by hand in the SSH session,
// and a request served from the browser to the database and back. The password
// was put in the files before they were uploaded, so there is nothing to edit.
import {
  ARRIVED,
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
} from '../src/diagrams/build';

const SHELL = 'node-remote-shell';
const PSQL = 'sudo -u postgres psql < schema.sql';
const PSQL_CONNECTION = 'edge-psql-postgresql';
const URL = 'http://W.X.Y.Z:3000';
const HTTP = 'edge-browser-guessit';
const DATABASE = 'edge-guessit-postgresql';
const psqlWaits = waiting('node-psql');
const browserWaits = waiting('node-browser');
const guessitWaits = waiting('node-guessit');

export default diagram({
  captions: {
    rest:
      'Your browser talks to the Guess It application running on your server. ' +
      'Guess It talks to the PostgreSQL database server also running on your server. ' +
      'You started Guess It manually in your SSH session, in a shell running on the server.',
    start:
      'Your terminal is still connected to your server over SSH, PostgreSQL ' +
      'is running, and the application’s files are on the server.'
  },
  steps: [
    step(
      'You run <code>sudo -u postgres psql &lt; schema.sql</code>. psql ' +
        'starts and connects to PostgreSQL through its Unix socket, as the ' +
        '<code>postgres</code> user.',
      spawned('node-psql', { shell: SHELL, edge: 'edge-remote-shell-psql' }),
      connect(PSQL_CONNECTION, { after: launched(PSQL) + 0.2 })
    ),
    step(
      'Your shell opened <code>schema.sql</code> and gave its contents to the ' +
        'standard input of psql, which sends the SQL to PostgreSQL, and waits ' +
        'for it to be run.',
      data(PSQL_CONNECTION, 'SQL').whole(),
      psqlWaits.start()
    ),
    step(
      'PostgreSQL works: it creates the <code>guessit</code> user, its ' +
        'database and its table.',
      pulse('node-postgresql')
    ),
    step(
      'psql has nothing more to send, and exits.',
      psqlWaits.stop(),
      teardown(['node-psql', 'edge-remote-shell-psql', PSQL_CONNECTION])
    ),
    step(
      'You run <code>npm run dev</code>, as on your computer. Your shell ' +
        'starts Guess It, which listens on port 3000.',
      spawned('node-guessit', {
        shell: SHELL,
        edge: 'edge-remote-shell-guessit'
      })
    ),
    step('You open a browser on your computer.', show('node-browser')),
    step(
      'You type your server’s public IP address and port into it. It ' +
        'connects to port 3000, where Guess It is listening.',
      typedInto('node-browser', URL),
      connect(HTTP, { after: typing(URL).enter + 0.2 })
    ),
    step(
      'It sends an HTTP request for the home page over the connection, and ' +
        'waits for the answer.',
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
        'you configured.',
      connect(DATABASE)
    ),
    step(
      'It sends its query over the connection.',
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
      'The page travels back over the connection to your browser, with its ' +
        'stylesheets and scripts.',
      data(HTTP, 'HTML/CSS/JS', { reverse: true }).whole(),
      browserWaits.stop({ after: ARRIVED })
    ),
    step('Your browser works, displaying the page.', pulse('node-browser'))
  ]
});
