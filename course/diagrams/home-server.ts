// Everything deployed so far on a student's cloud server, shown on the home
// page: one nginx listens on port 80 for every site, and hands each request to
// the process of the site named in its Host header, or answers it itself with
// the clock's files. The steps follow one request per site, from the browser to
// the process that answers it. Brewscale 1 answers the request to Brewscale, so
// the connections to the other two are only in the fully drawn diagram.
import {
  ARRIVED,
  connect,
  data,
  diagram,
  pulse,
  show,
  step,
  waiting
} from '../src/diagrams/build/processes';

const CLOCK = 'edge-browser-clock';
const GUESSIT = 'edge-browser-guessit';
const BREWSCALE = 'edge-browser-brewscale';
const GUESSIT_PROXY = 'edge-nginx-guessit';
const DATABASE = 'edge-guessit-postgresql';
const BREWSCALE_PROXY = 'edge-nginx-brewscale-1';

// Who waits for an answer, each time anew.
const browserWaitsForClock = waiting('node-browser');
const browserWaitsForGuessit = waiting('node-browser');
const nginxWaitsForGuessit = waiting('node-nginx');
const guessitWaits = waiting('node-guessit');
const browserWaitsForBrewscale = waiting('node-browser');
const nginxWaitsForBrewscale = waiting('node-nginx');

export default diagram({
  captions: {
    rest:
      'This diagram shows all the exercises deployed on your cloud server so ' +
      'far.',
    start:
      'systemd, the init process, started every process of your server when ' +
      'it booted. nginx listens on port 80 for every site. Your wildcard DNS ' +
      'record, <code>*.jde</code>, points every name to your server.'
  },
  steps: [
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'The browser asks for <code>http://clock.jde.archidep2.ch</code>. It ' +
        'connects to port 80 at your server’s public IP address, where nginx ' +
        'listens, and sends its request with that name in the ' +
        '<code>Host</code> header.',
      connect(CLOCK),
      data(CLOCK, 'GET /').whole(),
      browserWaitsForClock.start()
    ),
    step(
      'nginx picks the configuration of the clock by its ' +
        '<code>server_name</code>, and reads the clock’s files from ' +
        '<code>/srv/clock</code>. The clock has no process of its own on your ' +
        'server: its files travel back to the browser unchanged.',
      pulse('node-nginx'),
      data(CLOCK, 'index.html', { reverse: true }).whole(),
      browserWaitsForClock.stop({ after: ARRIVED })
    ),
    step(
      'The browser asks for <code>http://guessit.jde.archidep2.ch</code>. ' +
        'The request reaches the same nginx on the same port 80, with another ' +
        'name in the <code>Host</code> header.',
      connect(GUESSIT),
      data(GUESSIT, 'GET /').whole(),
      browserWaitsForGuessit.start()
    ),
    step(
      'nginx picks the configuration of Guess It, which proxies the request ' +
        'to <code>http://127.0.0.1:3000</code>. nginx connects to Guess It on ' +
        'port 3000, and forwards the request.',
      connect(GUESSIT_PROXY),
      data(GUESSIT_PROXY, 'GET /').whole(),
      nginxWaitsForGuessit.start()
    ),
    step(
      'Guess It connects to PostgreSQL on port 5432, and queries the ' +
        'leaderboard.',
      connect(DATABASE),
      data(DATABASE, 'SELECT …').whole(),
      guessitWaits.start()
    ),
    step(
      'The rows of the leaderboard travel back to Guess It.',
      data(DATABASE, 'rows', { reverse: true }).whole(),
      guessitWaits.stop({ after: ARRIVED })
    ),
    step(
      'Guess It builds the HTML page from the rows, and sends it back to ' +
        'nginx.',
      data(GUESSIT_PROXY, 'HTML', { reverse: true }).whole(),
      nginxWaitsForGuessit.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the page of Guess It on to the browser.',
      data(GUESSIT, 'HTML', { reverse: true }).whole(),
      browserWaitsForGuessit.stop({ after: ARRIVED })
    ),
    step(
      'The browser asks for <code>http://brewscale.jde.archidep2.ch</code>, ' +
        'again from the same nginx on the same port 80.',
      connect(BREWSCALE),
      data(BREWSCALE, 'GET /').whole(),
      browserWaitsForBrewscale.start()
    ),
    step(
      'nginx picks the configuration of Brewscale, which proxies the request ' +
        'to its upstream of three Brewscale processes. It is the turn of ' +
        'Brewscale 1: nginx connects to it on port 4201, and forwards the ' +
        'request.',
      connect(BREWSCALE_PROXY),
      data(BREWSCALE_PROXY, 'GET /').whole(),
      nginxWaitsForBrewscale.start()
    ),
    step(
      'Brewscale 1 builds its home page, and sends it back to nginx.',
      data(BREWSCALE_PROXY, 'HTML', { reverse: true }).whole(),
      nginxWaitsForBrewscale.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the page of Brewscale on to the browser. Three sites, one ' +
        'nginx, one port 80: the name in the <code>Host</code> header is what ' +
        'told them apart.',
      data(BREWSCALE, 'HTML', { reverse: true }).whole(),
      browserWaitsForBrewscale.stop({ after: ARRIVED })
    )
  ]
});
