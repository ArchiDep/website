// The café of "Horizontally scale a web application with nginx as a load
// balancer", from one barista to three. One barista, one process serving one
// order at a time, brews a browser's order, then the three orders Locust's
// customers send at once, one after the other while the others queue. Three
// baristas then replace it: nginx forwards three reloads of the page to each in
// turn, then Locust's three orders to the three at once, which brew them in
// parallel. The lone barista is only shown while stepping, and so is Locust,
// which students are not expected to draw.
import {
  ARRIVED,
  child,
  connect,
  data,
  diagram,
  pulse,
  show,
  step,
  teardown,
  typedInto,
  waiting
} from '../src/diagrams/build/processes';

const URL = 'http://brewscale.jde.archidep2.ch';
const HTTP = 'edge-browser-nginx';
const CUSTOMERS = [
  'edge-locust-nginx-1',
  'edge-locust-nginx-2',
  'edge-locust-nginx-3'
] as const;
const LONE = 'edge-nginx-barista';
const BARISTAS = [
  'edge-nginx-barista-1',
  'edge-nginx-barista-2',
  'edge-nginx-barista-3'
] as const;

// Who waits for an answer, each time anew.
const browserWaitsForCoffee = waiting('node-browser');
const nginxWaitsForCoffee = waiting('node-nginx');
const loneBrewsForBrowser = waiting('node-barista');
const locustWaitsInQueue = waiting('node-locust');
const nginxWaitsInQueue = waiting('node-nginx');
const loneBrews = [
  waiting('node-barista'),
  waiting('node-barista'),
  waiting('node-barista')
] as const;
const browserWaitsForPage = [
  waiting('node-browser'),
  waiting('node-browser'),
  waiting('node-browser')
] as const;
const locustWaitsInParallel = waiting('node-locust');
const nginxWaitsInParallel = waiting('node-nginx');
const baristasBrew = [
  waiting('node-barista-1'),
  waiting('node-barista-2'),
  waiting('node-barista-3')
] as const;

const ORDINALS = ['first', 'second', 'third'] as const;

const BREWING_IN_QUEUE = [
  'The barista brews the first order, for a second. It serves one customer ' +
    'at a time: the other two orders wait in the queue.',
  'The barista brews the second order. The third still waits in the queue.',
  'The barista brews the third order, whose customer has already waited two ' +
    'seconds.'
] as const;

// One order of the queue: the lone barista brews it and sends the page back to
// nginx, which passes it on to its customer, and the next order on to the
// barista at the same time.
function queued(index: 0 | 1 | 2) {
  const brews = loneBrews[index];
  const brewing = step(BREWING_IN_QUEUE[index], brews.start());
  const back = data(LONE, 'HTML', { reverse: true }).whole();
  const served = data(CUSTOMERS[index], 'HTML', { reverse: true }).whole();

  if (index === 2) {
    return [
      brewing,
      step(
        'The page of the third order travels back to nginx.',
        brews.stop(),
        back,
        nginxWaitsInQueue.stop({ after: ARRIVED })
      ),
      step(
        'nginx sends the page on to the third customer, who waited three ' +
          'seconds for a coffee that took one second to brew.',
        served,
        locustWaitsInQueue.stop({ after: ARRIVED })
      )
    ];
  }

  return [
    brewing,
    step(
      `The page of the ${ORDINALS[index]} order travels back to nginx.`,
      brews.stop(),
      back
    ),
    step(
      `nginx sends the page on to the ${ORDINALS[index]} customer, and the ` +
        `${ORDINALS[index + 1]} order on to the barista.`,
      served,
      data(LONE, 'POST /orders').whole()
    )
  ];
}

// One reload of the page in the browser, which nginx forwards to the next
// barista of its upstream.
function reload(index: 0 | 1 | 2) {
  const number = index + 1;
  const edge = BARISTAS[index];
  const waits = browserWaitsForPage[index];
  const turn =
    index === 0
      ? 'nginx now proxies the café’s requests to its upstream, which lists ' +
        'the three baristas, and takes them in turn. It is the turn of ' +
        'barista 1: nginx connects to it on port 4201, and forwards the ' +
        'request.'
      : `It is the turn of barista ${number}: nginx connects to it on port ` +
        `420${number}, and forwards the request.`;
  return [
    step(
      index === 0
        ? 'You reload the café’s page in the browser. The browser asks nginx ' +
            'for the order form, over the same connection.'
        : 'You reload the page once more.',
      data(HTTP, 'GET /').whole(),
      waits.start()
    ),
    step(turn, connect(edge), data(edge, 'GET /').whole()),
    step(
      `Barista ${number} builds the order form at once, with nothing to ` +
        'brew, and sends it back to nginx.',
      data(edge, 'HTML', { reverse: true }).whole()
    ),
    step(
      'nginx sends the page on to the browser, which shows the café in the ' +
        `colour of barista ${number}.`,
      data(HTTP, 'HTML', { reverse: true }).whole(),
      waits.stop({ after: ARRIVED })
    )
  ];
}

export default diagram({
  captions: {
    rest:
      'In this diagram, three baristas of Brewscale, three processes running ' +
      'the same jar, listen on ports 4201 to 4203. nginx listens on port 80, ' +
      'and balances the orders of the café among them. systemd, the init ' +
      'process, started all of them when the server booted.',
    start:
      'systemd, the init process, started nginx when the server booted. ' +
      'nginx listens on port 80. Your wildcard DNS record, <code>*.jde</code>, ' +
      'points <code>brewscale.jde.archidep2.ch</code> to your server’s public ' +
      'IP address.'
  },
  steps: [
    step(
      'You start the Brewscale service: systemd starts one barista, as the ' +
        '<code>brewscale</code> user. The barista listens on port 4200.',
      child('node-barista', 'edge-systemd-barista')
    ),
    step('Someone opens a browser on their computer.', show('node-browser')),
    step(
      'They type the café’s address into the browser. The browser looks up ' +
        '<code>brewscale.jde.archidep2.ch</code> in the DNS, which answers ' +
        'with your server’s public IP address.',
      typedInto('node-browser', URL)
    ),
    step(
      'The browser connects to port 80, the default port of HTTP, at your ' +
        'server’s public IP address, where nginx listens.',
      connect(HTTP)
    ),
    step(
      'The browser sends an order for a flat white over the connection, and ' +
        'waits for the answer.',
      data(HTTP, 'POST /orders').whole(),
      browserWaitsForCoffee.start()
    ),
    step(
      'nginx works: the configuration of ' +
        '<code>brewscale.jde.archidep2.ch</code> proxies the request to ' +
        '<code>http://127.0.0.1:4200</code>, where the barista listens.',
      pulse('node-nginx')
    ),
    step(
      'nginx connects to the barista on port 4200, at <code>127.0.0.1</code>, ' +
        'the server’s own loopback address.',
      connect(LONE)
    ),
    step(
      'nginx sends the order on to the barista, and waits for the answer.',
      data(LONE, 'POST /orders').whole(),
      nginxWaitsForCoffee.start()
    ),
    step(
      'The barista brews the flat white: it waits for a second, without ' +
        'using the CPU, as an application waits for a database or another ' +
        'service.',
      loneBrewsForBrowser.start()
    ),
    step(
      'The barista works, building the page that hands over the flat ' +
        'white.',
      loneBrewsForBrowser.stop(),
      pulse('node-barista')
    ),
    step(
      'The page travels back to nginx, over the connection nginx opened.',
      data(LONE, 'HTML', { reverse: true }).whole(),
      nginxWaitsForCoffee.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the page on to the browser. The flat white took about a ' +
        'second.',
      data(HTTP, 'HTML', { reverse: true }).whole(),
      browserWaitsForCoffee.stop({ after: ARRIVED })
    ),
    step(
      'You run Locust in a container on your computer, and start a load test ' +
        'with three customers in its web interface.',
      show('node-locust')
    ),
    step(
      'Each customer of Locust connects to the café by its name, as any ' +
        'customer would: to port 80 at your server’s public IP address, ' +
        'where nginx listens.',
      ...CUSTOMERS.map(edge => connect(edge))
    ),
    step(
      'The three customers send their orders at the same time, each over its ' +
        'own connection, and wait for the answers.',
      ...CUSTOMERS.map(edge => data(edge, 'POST').whole()),
      locustWaitsInQueue.start()
    ),
    step(
      'nginx sends the first order on to the barista.',
      data(LONE, 'POST /orders').whole(),
      nginxWaitsInQueue.start()
    ),
    ...queued(0),
    ...queued(1),
    ...queued(2),
    step(
      'You stop the Brewscale service: the barista exits.',
      teardown(['node-barista', 'edge-systemd-barista', LONE])
    ),
    step(
      'You start <code>brewscale.target</code>: systemd starts three baristas ' +
        'from the template <code>brewscale@.service</code>, each with its own ' +
        'number, and listening on port 420 followed by that number.',
      child('node-barista-1', 'edge-systemd-barista-1'),
      child('node-barista-2', 'edge-systemd-barista-2'),
      child('node-barista-3', 'edge-systemd-barista-3')
    ),
    ...reload(0),
    ...reload(1),
    ...reload(2),
    step(
      'The three customers of Locust send their orders at the same time ' +
        'again.',
      ...CUSTOMERS.map(edge => data(edge, 'POST').whole()),
      locustWaitsInParallel.start()
    ),
    step(
      'nginx gives one order to each barista, in turn: barista 1, barista 2, ' +
        'then barista 3.',
      ...BARISTAS.map(edge => data(edge, 'POST /orders').whole()),
      nginxWaitsInParallel.start()
    ),
    step(
      'The three baristas brew at the same time, each waiting for a second. ' +
        'Waiting uses no CPU, so the processor is free for all three.',
      ...baristasBrew.map(brews => brews.start())
    ),
    step(
      'The three pages travel back to nginx: three orders served in about the ' +
        'time one barista takes for one.',
      ...baristasBrew.map(brews => brews.stop()),
      ...BARISTAS.map(edge => data(edge, 'HTML', { reverse: true }).whole()),
      nginxWaitsInParallel.stop({ after: ARRIVED })
    ),
    step(
      'nginx sends the pages on to the three customers, who each waited about ' +
        'a second.',
      ...CUSTOMERS.map(edge => data(edge, 'HTML', { reverse: true }).whole()),
      locustWaitsInParallel.stop({ after: ARRIVED })
    )
  ]
});
