// Serving the static site of "Deploy a static site with nginx": nginx, which
// systemd started, listens on port 80 and answers a browser that reached the
// server by the site's own name, sending files it reads from disk. No program
// of the site runs on the server: the browser runs its JavaScript.
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

const URL = 'http://clock.jde.archidep2.ch';
const HTTP = 'edge-browser-nginx';
const browserWaits = waiting('node-browser');

export default diagram({
  captions: {
    rest:
      'In this diagram, a browser reaches the clock by a name of its own, ' +
      '<code>clock.jde.archidep2.ch</code>, with no port in the address. ' +
      'nginx listens on port 80 and sends the browser the files of the site. ' +
      'systemd, the init process, started nginx when the server booted.',
    start:
      'systemd, the init process, started nginx when the server booted. nginx ' +
      'listens on port 80, with the configuration of the clock enabled. Your ' +
      'wildcard DNS record, <code>*.jde</code>, points ' +
      '<code>clock.jde.archidep2.ch</code> to your server’s public IP address.'
  },
  steps: [
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type the clock’s address into the browser, with no port. The ' +
        'browser looks up <code>clock.jde.archidep2.ch</code> in the DNS, ' +
        'which answers with your server’s public IP address, from your ' +
        'wildcard record.',
      typedInto('node-browser', URL)
    ),
    step(
      'With no port in the address, the browser connects to port 80, the ' +
        'default port of HTTP, at your server’s public IP address. nginx is ' +
        'listening there.',
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
        'header, and reads <code>/srv/clock/index.html</code> from the disk, ' +
        'as the <code>www-data</code> user.',
      pulse('node-nginx')
    ),
    step(
      'The file travels back over the connection to the browser, unchanged.',
      data(HTTP, 'index.html', { reverse: true }).whole(),
      browserWaits.stop({ after: ARRIVED })
    ),
    step(
      'The page needs a stylesheet and a script. The browser asks nginx for ' +
        'them over the same connection, and waits again.',
      data(HTTP, 'GET /style.css, /script.js').whole(),
      browserWaits.start()
    ),
    step(
      'nginx works again, reading <code>style.css</code> and ' +
        '<code>script.js</code> from <code>/srv/clock</code>.',
      pulse('node-nginx')
    ),
    step(
      'The two files travel back to the browser, unchanged.',
      data(HTTP, 'CSS/JS', { reverse: true }).whole(),
      browserWaits.stop({ after: ARRIVED })
    ),
    step(
      'The browser works, displaying the page and running the clock’s ' +
        'JavaScript, which shows the time. Nothing of the clock runs on your ' +
        'server.',
      pulse('node-browser')
    )
  ]
});
