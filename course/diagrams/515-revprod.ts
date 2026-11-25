// Revprod served as a single site by nginx, at the end of "Deploy a
// multi-component web application with nginx". The browser talks only to
// nginx, at one origin, and nginx forwards each request to one component or
// the other by its path: the home page to the landing page, the testimonials
// that the home page's JavaScript code asks for to the backend. Both components
// listen on the loopback address only.
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

const URL = 'http://revprod.jde.archidep2.ch';
const HTTP = 'edge-browser-nginx';
const LANDING = 'edge-nginx-landing';
const BACKEND = 'edge-nginx-backend';

// Who waits for an answer, each time anew.
const browserWaitsForPage = waiting('node-browser');
const nginxWaitsForPage = waiting('node-nginx');
const browserWaitsForComments = waiting('node-browser');
const nginxWaitsForComments = waiting('node-nginx');

export default diagram({
  captions: {
    rest:
      'In this diagram, a browser reaches both halves of Revprod at a single ' +
      'address, <code>revprod.jde.archidep2.ch</code>. nginx listens on port ' +
      '80, and forwards each request by its path: to the backend on port 4301 ' +
      'for <code>/share</code>, <code>/comments</code> and ' +
      '<code>/css/</code>, to the landing page on port 4300 for everything ' +
      'else. systemd, the init process, started all three when the server ' +
      'booted.',
    start:
      'systemd, the init process, started nginx, the landing page and the ' +
      'backend when the server booted. nginx listens on port 80. The landing ' +
      'page listens on port 4300 and the backend on port 4301, both on the ' +
      'loopback address only. Your wildcard DNS record, <code>*.jde</code>, ' +
      'points <code>revprod.jde.archidep2.ch</code> to your server’s public ' +
      'IP address.'
  },
  steps: [
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type Revprod’s address into the browser, with no port. The ' +
        'browser looks up <code>revprod.jde.archidep2.ch</code> in the DNS, ' +
        'which answers with your server’s public IP address, from your ' +
        'wildcard record.',
      typedInto('node-browser', URL)
    ),
    step(
      'With no port in the address, the browser connects to port 80, the ' +
        'default port of HTTP, where nginx listens.',
      connect(HTTP)
    ),
    step(
      'The browser asks nginx for the home page, at <code>/</code>, and waits ' +
        'for the answer.',
      data(HTTP, 'GET /').whole(),
      browserWaitsForPage.start()
    ),
    step(
      'nginx works: in Revprod’s configuration, the path <code>/</code> ' +
        'matches only <code>location /</code>, which forwards it to ' +
        '<code>http://127.0.0.1:4300</code>, where the landing page listens.',
      pulse('node-nginx')
    ),
    step(
      'nginx connects to the landing page on port 4300, at ' +
        '<code>127.0.0.1</code>, the server’s own loopback address.',
      connect(LANDING)
    ),
    step(
      'nginx sends the request on to the landing page, and waits for the ' +
        'answer.',
      data(LANDING, 'GET /').whole(),
      nginxWaitsForPage.start()
    ),
    step(
      'The landing page works: Python runs its code, which builds the home ' +
        'page.',
      pulse('node-landing')
    ),
    step(
      'The home page travels back to nginx.',
      data(LANDING, 'HTML', { reverse: true }).whole(),
      nginxWaitsForPage.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the home page on to the browser.',
      data(HTTP, 'HTML', { reverse: true }).whole(),
      browserWaitsForPage.stop({ after: ARRIVED })
    ),
    step(
      'The browser works: it displays the home page, and runs its ' +
        'JavaScript code, which asks for the testimonials at ' +
        '<code>/comments</code>, on the same site.',
      pulse('node-browser')
    ),
    step(
      'The browser sends the request for <code>/comments</code> to nginx, ' +
        'over the same connection, and waits for the answer.',
      data(HTTP, 'GET /comments').whole(),
      browserWaitsForComments.start()
    ),
    step(
      'nginx works: the path <code>/comments</code> matches both ' +
        '<code>location /</code> and <code>location /comments</code>. nginx ' +
        'chooses the longest, which forwards it to ' +
        '<code>http://127.0.0.1:4301</code>, where the backend listens.',
      pulse('node-nginx')
    ),
    step(
      'nginx connects to the backend on port 4301, at <code>127.0.0.1</code>, ' +
        'the server’s own loopback address.',
      connect(BACKEND)
    ),
    step(
      'nginx sends the request on to the backend, and waits for the answer.',
      data(BACKEND, 'GET /comments').whole(),
      nginxWaitsForComments.start()
    ),
    step(
      'The backend works: Node.js runs its JavaScript code, which reads the ' +
        'testimonials it stores.',
      pulse('node-backend')
    ),
    step(
      'The testimonials travel back to nginx, in the JSON format.',
      data(BACKEND, 'JSON', { reverse: true }).whole(),
      nginxWaitsForComments.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the testimonials on to the browser. They came from ' +
        '<code>revprod.jde.archidep2.ch</code>, like the home page: the ' +
        'browser never talked directly to the backend.',
      data(HTTP, 'JSON', { reverse: true }).whole(),
      browserWaitsForComments.stop({ after: ARRIVED })
    ),
    step(
      'The browser works: the home page and the testimonials have the same ' +
        'origin, so it gives the testimonials to the home page’s JavaScript ' +
        'code, which displays them.',
      pulse('node-browser')
    )
  ]
});
