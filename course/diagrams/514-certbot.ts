// Serving Guess It over HTTPS in "Provision a TLS certificate with Certbot and
// Let's Encrypt": the processes are those of "Deploy a web application with
// nginx as a reverse proxy", but the browser connects to nginx on port 443 and
// talks to it over an encrypted connection. nginx still forwards the request to
// Guess It over plain HTTP on the loopback address.
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

const URL = 'https://guessit.jde.archidep2.ch';
const HTTPS = 'edge-browser-nginx';
const PROXY = 'edge-nginx-guessit';
const DATABASE = 'edge-guessit-postgresql';
const browserWaits = waiting('node-browser');
const nginxWaits = waiting('node-nginx');
const guessitWaits = waiting('node-guessit');

export default diagram({
  captions: {
    rest:
      'In this diagram, a browser reaches Guess It over HTTPS, at ' +
      '<code>https://guessit.jde.archidep2.ch</code>. nginx listens on port ' +
      '443, holds the certificate and its private key, and decrypts the ' +
      'request before forwarding it to Guess It on port 3000 over plain HTTP. ' +
      'systemd, the init process, started all three when the server booted.',
    start:
      'systemd, the init process, started PostgreSQL, Guess It and nginx when ' +
      'the server booted. nginx listens on port 443 for HTTPS, and on port 80 ' +
      'to redirect to HTTPS. Guess It listens on port 3000.'
  },
  steps: [
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type Guess It’s address into the browser, starting with ' +
        '<code>https://</code>. The browser looks up ' +
        '<code>guessit.jde.archidep2.ch</code> in the DNS, which answers with ' +
        'your server’s public IP address.',
      typedInto('node-browser', URL)
    ),
    step(
      'The browser connects to port 443, the default port of HTTPS, where ' +
        'nginx listens. nginx sends its certificate, which the browser checks, ' +
        'and they agree on a key to encrypt the connection.',
      connect(HTTPS)
    ),
    step(
      'The browser sends an HTTP request for the home page over the ' +
        'connection, encrypted, and waits for the answer. Nobody between your ' +
        'computer and the server can read it.',
      data(HTTPS, 'GET /').whole(),
      browserWaits.start()
    ),
    step(
      'nginx works: it decrypts the request, and picks the configuration ' +
        'whose <code>server_name</code> is the name in the <code>Host</code> ' +
        'header. That configuration says to proxy the request to ' +
        '<code>http://127.0.0.1:3000</code>, as before.',
      pulse('node-nginx')
    ),
    step(
      'nginx connects to Guess It on port 3000, at <code>127.0.0.1</code>, ' +
        'the server’s own loopback address. This connection is not encrypted, ' +
        'but it never leaves the server.',
      connect(PROXY)
    ),
    step(
      'nginx sends the request on to Guess It, in plain HTTP, and waits for ' +
        'the answer. Guess It does not know that the browser used HTTPS.',
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
      'The page travels back to nginx, in plain HTTP, over the connection ' +
        'nginx opened.',
      data(PROXY, 'HTML', { reverse: true }).whole(),
      nginxWaits.stop({ after: ARRIVED })
    ),
    step(
      'nginx encrypts the page and sends it on to the browser, over the ' +
        'browser’s connection.',
      data(HTTPS, 'HTML', { reverse: true }).whole(),
      browserWaits.stop({ after: ARRIVED })
    ),
    step(
      'The browser works, decrypting and displaying the page.',
      pulse('node-browser')
    )
  ]
});
