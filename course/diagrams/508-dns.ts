// Reaching the application of "Configure a DNS zone" by its domain name: the
// processes systemd runs are those of "Deploy with systemd", and a request is
// served from the browser to the database and back. What changes is the address
// typed into the browser, which the DNS translates into the server's public IP
// address before the browser connects.
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

const URL = 'http://jde.archidep2.ch:3000';
const HTTP = 'edge-browser-guessit';
const DATABASE = 'edge-guessit-postgresql';
const browserWaits = waiting('node-browser');
const guessitWaits = waiting('node-guessit');

export default diagram({
  captions: {
    rest:
      'In this diagram, a browser reaches Guess It by your domain name, ' +
      '<code>jde.archidep2.ch</code>, instead of your server’s IP address. ' +
      'Guess It talks to PostgreSQL. systemd, the init process, started both ' +
      'when the server booted.',
    start:
      'systemd, the init process, has started PostgreSQL and then Guess It on ' +
      'your server. You have added an <code>A</code> record for ' +
      '<code>jde.archidep2.ch</code> to the DNS zone of ' +
      '<code>archidep2.ch</code>, pointing to your server’s public IP address.'
  },
  steps: [
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type your domain name and port into the browser. The browser ' +
        'looks up <code>jde.archidep2.ch</code> in the DNS, which answers with ' +
        'your server’s public IP address, from the <code>A</code> record you ' +
        'added.',
      typedInto('node-browser', URL)
    ),
    step(
      'The browser connects to port 3000 at your server’s public IP address, ' +
        'where Guess It is listening, as when the IP address was typed.',
      connect(HTTP)
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
