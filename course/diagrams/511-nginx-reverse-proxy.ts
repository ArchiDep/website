// Serving Guess It through nginx in "Deploy a web application with nginx as a
// reverse proxy": a browser reaches Guess It by a name of its own on port 80,
// where nginx listens, and nginx forwards the request to Guess It on port 3000,
// as a client of its own, before passing the answer back. The processes systemd
// runs are those of "Deploy with systemd", with nginx in front of Guess It.
import {
  ARRIVED,
  connect,
  data,
  diagram,
  pulse,
  show,
  step,
  typedInto,
  waiting
} from '../src/diagrams/build/processes';

const URL = 'http://guessit.jde.archidep2.ch';
const HTTP = 'edge-browser-nginx';
const PROXY = 'edge-nginx-guessit';
const DATABASE = 'edge-guessit-postgresql';
const browserWaits = waiting('node-browser');
const nginxWaits = waiting('node-nginx');
const guessitWaits = waiting('node-guessit');

export default diagram({
  captions: {
    rest:
      'In this diagram, a browser reaches Guess It by a name of its own, ' +
      '<code>guessit.jde.archidep2.ch</code>, with no port in the address. ' +
      'nginx listens on port 80 and forwards the request to Guess It on port ' +
      '3000, which talks to PostgreSQL. systemd, the init process, started all ' +
      'three when the server booted.',
    start:
      'systemd, the init process, started PostgreSQL, Guess It and nginx when ' +
      'the server booted. nginx listens on port 80, with the configurations of ' +
      'the clock and of Guess It enabled. Guess It listens on port 3000. Your ' +
      'wildcard DNS record, <code>*.jde</code>, points ' +
      '<code>guessit.jde.archidep2.ch</code> to your server’s public IP address.'
  },
  steps: [
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type Guess It’s address into the browser, with no port. The ' +
        'browser looks up <code>guessit.jde.archidep2.ch</code> in the DNS, ' +
        'which answers with your server’s public IP address, from your ' +
        'wildcard record.',
      typedInto('node-browser', URL)
    ),
    step(
      'With no port in the address, the browser connects to port 80, the ' +
        'default port of HTTP, at your server’s public IP address. nginx is ' +
        'listening there, not Guess It.',
      connect(HTTP)
    ),
    step(
      'The browser sends an HTTP request for the home page over the ' +
        'connection, with the name it was given in its <code>Host</code> ' +
        'header, and waits for the answer.',
      data(HTTP, 'GET /').whole(),
      browserWaits.start()
    ),
    step(
      'nginx works: it picks the configuration whose ' +
        '<code>server_name</code> is the name in the <code>Host</code> ' +
        'header. That configuration has no files to send: it says to proxy ' +
        'the request to <code>http://127.0.0.1:3000</code>.',
      pulse('node-nginx')
    ),
    step(
      'nginx connects to Guess It on port 3000, at <code>127.0.0.1</code>, ' +
        'the server’s own loopback address. For Guess It, nginx is a client ' +
        'like any browser.',
      connect(PROXY)
    ),
    step(
      'nginx sends the browser’s request on to Guess It, and waits for the ' +
        'answer.',
      data(PROXY, 'GET /').whole(),
      nginxWaits.start()
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
      'The page travels back to nginx, over the connection nginx opened.',
      data(PROXY, 'HTML', { reverse: true }).whole(),
      nginxWaits.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the page on to the browser, over the browser’s ' +
        'connection. The browser never talked to Guess It.',
      data(HTTP, 'HTML', { reverse: true }).whole(),
      browserWaits.stop({ after: ARRIVED })
    ),
    step('The browser works, displaying the page.', pulse('node-browser'))
  ]
});
