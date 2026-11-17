# Tutor notes: 511 Deploy a web application with nginx as a reverse proxy

## Starting point

- 510 Deploy a static site with nginx: nginx installed and serving the clock at
  `clock.jde.archidepN.ch`, from `/etc/nginx/sites-available/clock` and its
  link in `sites-enabled`.
- 506 Manage a web application with systemd as a Process Manager: Guess It runs
  as the `guessit` service and the `guessit` user, on port 3000, and answers at
  `http://jde.archidepN.ch:3000`.
- 509 Reverse Proxying: the reverse proxy configuration example, the `502 Bad
Gateway` error, and the master and worker processes of nginx.
- 406 Unix Networking: the loopback address `127.0.0.1`, and the well-known
  ports below 1024.

The student works on their server over SSH; the page's examples use the user
`jde` and the hostname `jde.archidepN.ch`.

## Learning objectives

Putting nginx in front of Guess It as a reverse proxy, so that Guess It is
reached at `guessit.` followed by the student's hostname, with no port, beside
the clock on the same port 80. Guess It itself does not change. The student
then sees that nginx and Guess It are separate processes, by stopping Guess It,
and that nginx's master process runs as `root` while its workers run as
`www-data`. The page's "What have I done?" states what the student should
understand afterwards, including the two HTTP connections and why Guess It does
not listen on port 80 itself.

Not in the exercise: HTTPS, passing the browser's address or name on to Guess
It (the appendix of 509), several `location` blocks, load balancing, and
closing port 3000: Guess It still answers at `http://jde.archidepN.ch:3000`.

## Where it leads

The applications deployed on the student's server from here on sit behind nginx
in the same way. In particular:

- "Horizontally scale a web application with nginx as a load balancer" proxies
  to one instance first, then to several through an `upstream` block, and meets
  `502 Bad Gateway` when nothing listens at the address.
- "TLS/SSL Certificates" and "Provision an SSL certificate using Certbot by
  Let's Encrypt" add HTTPS on nginx, which removes the last flaw this exercise
  names: Guess It is still served over plain HTTP.
- "Deploy a multi-component web application with nginx" proxies to two
  components from one site, by path.

## Key steps

- **"Requirements"**. Expected: `active (running)` for `guessit`.
- **"Choose the name of the site"**.
  Question before: "Do you need a new DNS record for
  `guessit.jde.archidepN.ch`?" (No, the wildcard covers it.)
- **"Create an nginx configuration file to serve the application"**. The page
  asks for two changes to the example, `server_name` and `proxy_pass`. The
  file's solution is not on the page until the class has covered the chapter.
  Question before: "Which address does nginx forward to, given that Guess It
  runs on the same server?"
  Question after: "Why does this configuration have no `root`, unlike the
  clock's?" (nginx has no files of Guess It to send.)
- **"Enable the nginx configuration"** and **"Reload the nginx
  configuration"**: the steps of 510.
  Expected: the link `-> /etc/nginx/sites-available/guessit`, `syntax is ok`,
  `test is successful`.
- **"See it in action"**.
  Question before: "Will the clock still work, now that nginx also serves Guess
  It on port 80?"
  Expected: Guess It at `http://guessit.jde.archidepN.ch`, with no port and the
  leaderboard of the earlier deployments; the clock unchanged.
  Question after: "How many HTTP connections does one page of Guess It take
  now, and between which processes?" (Two: browser to nginx, nginx to Guess It.)
- **"Stop Guess It behind nginx's back"**. The page asks who sent the error page
  and why, with its answer on the page while the student works.
  Question before: "What will the browser show for Guess It once it is stopped?
  And for the clock?"
  Expected: `502 Bad Gateway` with `nginx` under it; the clock still works; the
  last line of `/var/log/nginx/error.log` has `connect() failed (111:
Connection refused) while connecting to upstream`. After `systemctl start
guessit`, the game is back.
- **"Find out who listens on port 80"**. The page asks which user nginx was
  started as, with its answer on the page while the student works.
  Expected: one `nginx: master process` line as `root` with a PPID of 1, and
  `nginx: worker process` lines as `www-data` whose PPID is the master's PID,
  one per processor core.
  Question after: "Which nginx process connects to Guess It?" (A worker.) "Why
  can Guess It listen on port 3000 as `guessit`?" (Any user may listen on a port
  above 1024.)

## Common pitfalls

- **`nginx -t` says `invalid URL prefix`**: `proxy_pass` is missing its
  `http://`, as in `proxy_pass 127.0.0.1:3000;`. Hint: compare your
  `proxy_pass` with the example's, character by character.
- **nginx answers Guess It's name with an error page, and its logs get many
  lines for a single visit**: `proxy_pass` names Guess It's own site, such as
  `http://guessit.jde.archidepN.ch`, which resolves to the server's port 80:
  nginx forwards the request to itself. Hint: which process listens at the
  address in your `proxy_pass`? Hint: where does Guess It listen, according to
  the last line of `systemctl status guessit`?
- **`proxy_pass` has the server's public address, such as
  `http://W.X.Y.Z:3000`, and it works**: Guess It listens on every address of
  the server. The page asks for the loopback address, which keeps the
  connection inside the server. Hint: which address does your server use to
  talk to itself?
- **The student asks why Guess It still answers at `:3000`**: nothing in the
  exercise stops it; Guess It still listens on port 3000 of every address, and
  the port is open in Azure. A browser that uses Guess It's name goes through
  nginx.
