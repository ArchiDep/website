// Revprod before the reverse proxy serves it as one site, in "Deploy a
// multi-component web application with nginx". The browser reaches the backend
// directly, on port 3001, and gets its form after a redirect from its missing
// home page. It reaches the landing page through nginx, at a name of its own,
// and the landing page has no testimonials to give: they are the backend's.
import {
  ARRIVED,
  child,
  connect,
  data,
  diagram,
  pulse,
  show,
  step,
  typedInto,
  waiting
} from '../src/diagrams/build/processes';

const BACKEND_URL = 'http://jde.archidep2.ch:3001';
const LANDING_URL = 'http://revprod.jde.archidep2.ch';
const DIRECT = 'edge-browser-backend';
const HTTP = 'edge-browser-nginx';
const PROXY = 'edge-nginx-landing';

// Who waits for an answer, each time anew.
const browserWaitsForHome = waiting('node-browser');
const browserWaitsForForm = waiting('node-browser');
const browserWaitsForPage = waiting('node-browser');
const nginxWaitsForPage = waiting('node-nginx');
const browserWaitsForComments = waiting('node-browser');
const nginxWaitsForComments = waiting('node-nginx');

export default diagram({
  captions: {
    rest:
      'This diagram shows an intermediate step of the exercise, not the final ' +
      'deployment. Each half of Revprod is reached at an address of its own. The browser reaches the backend directly, on port 3001. It reaches ' +
      'the landing page through nginx, at ' +
      '<code>revprod.jde.archidep2.ch</code>, which forwards the requests to ' +
      'port 4300. systemd, the init process, started all three.',
    start:
      'systemd, the init process, started nginx when the server booted. nginx ' +
      'listens on port 80. Your wildcard DNS record, <code>*.jde</code>, ' +
      'points <code>revprod.jde.archidep2.ch</code> to your server’s public ' +
      'IP address.'
  },
  steps: [
    step(
      'You start the <code>revprod-backend</code> service: systemd starts the ' +
        'backend, as the <code>revprod-backend</code> user. The backend ' +
        'listens on port 3001, on every address of your server.',
      child('node-backend', 'edge-systemd-backend')
    ),
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type the backend’s address into the browser, with port 3001. The ' +
        'browser looks up <code>jde.archidep2.ch</code> in the DNS, which ' +
        'answers with your server’s public IP address.',
      typedInto('node-browser', BACKEND_URL)
    ),
    step(
      'The browser connects to port 3001 at your server’s public IP address, ' +
        'where the backend listens. Your server’s firewall lets this port ' +
        'through.',
      connect(DIRECT)
    ),
    step(
      'The browser asks the backend for its home page, at <code>/</code>, and ' +
        'waits for the answer.',
      data(DIRECT, 'GET /').whole(),
      browserWaitsForHome.start()
    ),
    step(
      'The backend works. It has no home page: the home page is the landing ' +
        'page, built by the other team.',
      pulse('node-backend')
    ),
    step(
      'The backend answers with a redirect to its form, at ' +
        '<code>/share</code>, the only page it has.',
      data(DIRECT, 'redirect', { reverse: true }).whole(),
      browserWaitsForHome.stop({ after: ARRIVED })
    ),
    step(
      'The browser follows the redirect: it asks the backend for ' +
        '<code>/share</code>, over the same connection.',
      data(DIRECT, 'GET /share').whole(),
      browserWaitsForForm.start()
    ),
    step(
      'The backend sends back its form, which the browser displays.',
      data(DIRECT, 'HTML', { reverse: true }).whole(),
      browserWaitsForForm.stop({ after: ARRIVED })
    ),
    step(
      'You start the <code>revprod-landing</code> service: systemd starts the ' +
        'landing page, as the <code>revprod-landing</code> user. The landing ' +
        'page listens on port 4300, on the loopback address only. You enable ' +
        'Revprod’s nginx configuration, and reload nginx.',
      child('node-landing', 'edge-systemd-landing')
    ),
    step(
      'Someone types Revprod’s address into the browser, with no port. The ' +
        'browser looks up <code>revprod.jde.archidep2.ch</code> in the DNS, ' +
        'which answers with your server’s public IP address, from your ' +
        'wildcard record.',
      typedInto('node-browser', LANDING_URL)
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
      'nginx works: Revprod’s configuration forwards every request to ' +
        '<code>http://127.0.0.1:4300</code>, where the landing page listens.',
      pulse('node-nginx')
    ),
    step(
      'nginx connects to the landing page on port 4300, at ' +
        '<code>127.0.0.1</code>, the server’s own loopback address.',
      connect(PROXY)
    ),
    step(
      'nginx sends the request on to the landing page, and waits for the ' +
        'answer.',
      data(PROXY, 'GET /').whole(),
      nginxWaitsForPage.start()
    ),
    step(
      'The landing page works: Python runs its code, which builds the home ' +
        'page.',
      pulse('node-landing')
    ),
    step(
      'The home page travels back to nginx.',
      data(PROXY, 'HTML', { reverse: true }).whole(),
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
      'nginx forwards every request of Revprod to the landing page, so it ' +
        'sends this one on too, and waits for the answer.',
      data(PROXY, 'GET /comments').whole(),
      nginxWaitsForComments.start()
    ),
    step(
      'The landing page works. It has no testimonials: the testimonials are ' +
        'stored by the backend, built by the other team.',
      pulse('node-landing')
    ),
    step(
      'The landing page answers with the status code 404 Not Found: ' +
        '<code>/comments</code> does not exist.',
      data(PROXY, '404', { reverse: true }).whole(),
      nginxWaitsForComments.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the answer on to the browser.',
      data(HTTP, '404', { reverse: true }).whole(),
      browserWaitsForComments.stop({ after: ARRIVED })
    ),
    step(
      'The browser displays an error message where the testimonials should ' +
        'be. The landing page does not know the backend’s address, so ' +
        'neither does its JavaScript code.',
      pulse('node-browser')
    )
  ]
});
