# Tutor notes: 509 Reverse Proxying

## Scope

The slides and the subject page hold different parts, with almost no overlap.

The slides hold what a proxy is and its three kinds: a tunneling proxy, which
passes requests through unchanged, as a VPN does; a forward proxy, which works
for its clients, either anonymous (it hides the client) or transparent (the
client configures nothing, and is not hidden); and a reverse proxy, which works
for the servers, in their private network, and looks like an ordinary server to
clients.

The slides then give the uses of a reverse proxy: sharing port 80 between
several sites by the name in the `Host` header, which they call name-based
virtual hosting; hiding the internal architecture; making a separate frontend
and backend appear as one website, avoiding CORS issues; TLS termination;
vertical against horizontal scaling, and load balancing; and a list of other
uses (caching, compression, spoon-feeding, DoS protection, A/B testing,
authentication), each told in a sentence.

The slides end with nginx: a competitor of Apache, made for the C10k problem;
how it runs, a master process started as `root` that opens the ports and worker
processes running as `www-data` that handle the requests, and why only `root`
may listen on a port below 1024; how the `HUP` signal makes the master reload
its configuration without stopping; and its market share against Apache.

The subject page holds nginx's configuration on Ubuntu: the files of
`/etc/nginx`, the contexts of `nginx.conf` (main, `events`, `http`, `server`),
`include`, the `sites-available` and `sites-enabled` convention with symbolic
links, checking with `nginx -t` and reloading with `systemctl reload nginx`. It
then says how nginx chooses a `server` block (by port, then `server_name`
against the `Host` header, else the default server) and a `location` (longest
prefix, or the first regular expression that matches), and gives a table of
seven directives. Its three examples are a static site, a reverse proxy with
`proxy_pass`, and a load balancer with an `upstream` block, followed by the
`502 Bad Gateway` and `504 Gateway Timeout` errors and the error log.

Optional: the "more" notes of the page, and its appendix, "What the application
sees": the application sees nginx's address, not the browser's, and the
`proxy_pass` address in the `Host` header, unless `proxy_params` passes them on
in headers such as `X-Forwarded-For`. No exercise uses the appendix.

## Left out

Taught later:

- HTTPS on nginx, with `listen 443 ssl` and certificates: "TLS/SSL
  Certificates", then "Provision a TLS certificate with Certbot and Let's
  Encrypt", which has Certbot edit the configuration.
- One site proxying to two components by path, with several `location` blocks,
  and the same-origin policy and CORS: "Deploy a multi-component web application
  with nginx".
- An `upstream` used for real, and a load test: "Horizontally scale a web
  application with nginx as a load balancer".

Not in the course: configuring a forward or tunneling proxy, VPNs, Apache's
configuration, nginx's caching, compression, rate limiting and authentication,
`try_files`, `rewrite` and `return`, writing a `default_server`, `conf.d` and
`snippets` beyond their one-line description, load-balancing methods other than
weighted round robin, health checks, sticky sessions, and how nginx's
event-driven architecture works inside.

## Key concepts and vocabulary

- **Proxy**: an intermediary for the requests of clients to other servers.
- **Forward proxy**: works for its clients, on their side. **Anonymous**: hides
  the client from the server. **Transparent**: the client does not configure it,
  and it does not hide the client.
- **Reverse proxy**: works for the servers, on their side, and appears to
  clients as an ordinary server.
- **Name-based virtual hosting**: several sites on one IP address and one port,
  told apart by the name in the `Host` header.
- **TLS termination**: the reverse proxy is the HTTPS endpoint, and talks plain
  HTTP to the servers behind it.
- **Vertical scaling**: a more powerful computer. **Horizontal scaling**: more
  computers, or more instances, doing the same work.
- **Load balancing**: distributing requests among several instances.
- **Master process** and **worker processes**: the master, started as `root`,
  opens the ports and reloads the configuration; the workers, as `www-data`,
  handle the requests.
- **Context**: a block of nginx's configuration between braces, such as
  `http`, `server` or `location`. **Directive**: one setting in a context.
- **`sites-available`** holds the configurations; **`sites-enabled`**, which
  nginx includes, holds symbolic links to the ones that are enabled.
- **Reload**: nginx reads its configuration again without stopping, on the
  `HUP` signal; a **restart** stops it and starts it again.
- **Default server**: the `server` block that answers on a port when no
  `server_name` matches the `Host` header. On Ubuntu, the `default` site.
- **`proxy_pass`**: forward the request to another address. **Upstream**: what
  nginx calls the application it proxies to, and the `upstream` block that
  names a group of them.
- **`502 Bad Gateway`**: nginx got no answer from the upstream.
  **`504 Gateway Timeout`**: the upstream took too long to answer.

## Misconceptions

- **Misconception:** a reverse proxy is a forward proxy pointed the other way,
  or both are set up by the client.
  **Correction:** the difference is who it works for and where it sits. A
  forward proxy works for clients, on their side; a reverse proxy works for the
  servers, on their side, and the client does not know it is there.
  Question that reveals it: "Who installs the reverse proxy in front of Guess
  It: you, or the people who visit it?"
- **Misconception:** nginx and the application listen on the same port, or
  several applications can share port 80 by themselves.
  **Correction:** only one process listens on a port. nginx alone listens on
  port 80, and each application on a port of its own, which nobody types.
- **Misconception:** the DNS sends each name to its site, or to its port.
  **Correction:** every name of the server has the same IP address. nginx tells
  the sites apart by the name in the `Host` header, which the browser sends.
  Question that reveals it: "`clock.jde.archidepN.ch` and
  `guessit.jde.archidepN.ch` have the same address. How does nginx know which
  one you asked for?"
- **Misconception:** the browser connects to the application through nginx, on
  one connection that nginx passes along.
  **Correction:** there are two connections: one from the browser to nginx, and
  one from nginx to the application. For the application, nginx is a client
  like any other.
- **Misconception:** a file in `sites-available` is active once it is saved.
  **Correction:** nginx includes only `sites-enabled`, and reads its
  configuration only when told to reload it.
- **Misconception:** reloading and restarting nginx are the same.
  **Correction:** a reload keeps nginx running, and keeps the old configuration
  if the new one has an error. A restart stops it, and it does not start again
  with a broken configuration.
- **Misconception:** nginx runs as `root`, so everything it does is done as
  `root`.
  **Correction:** only the master process does. The workers, which read files
  and connect to applications, run as `www-data`.
- **Misconception:** an error page from nginx means nginx is broken.
  **Correction:** a `502` or `504` means nginx is working and the application
  behind it is not answering.
- **Misconception:** a request for a name no configuration has is refused.
  **Correction:** it is answered by the default server of that port, nginx's
  welcome page on Ubuntu.

## Used in

Every exercise that serves a site on the student's server from here on puts
nginx in front of it, by the same steps: a file in `sites-available`, a link in
`sites-enabled`, `nginx -t`, then a reload. In particular:

- "Deploy a static site with nginx" uses the static configuration example, the
  `sites-enabled` link, the reload, and the default site.
- "Deploy a web application with nginx as a reverse proxy" uses the reverse
  proxy example, the `502 Bad Gateway` error, and the master and worker
  processes.
- "Horizontally scale a web application with nginx as a load balancer" uses
  `proxy_pass`, then the `upstream` block of the load balancing example.
- "TLS/SSL Certificates" and "Provision a TLS certificate with Certbot and Let's
  Encrypt" add HTTPS to the nginx sites, which is TLS termination.
- "Deploy a multi-component web application with nginx" uses several `location`
  blocks in one site to make a frontend and a backend appear as one website.
