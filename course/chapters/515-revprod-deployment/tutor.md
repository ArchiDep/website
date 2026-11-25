# Tutor notes: 515 Deploy a multi-component web application with nginx

## Starting point

- 511 Deploy a web application with nginx as a reverse proxy: a site with
  `proxy_pass` to `127.0.0.1`, and the `502 Bad Gateway` error and its line in
  `/var/log/nginx/error.log` when nothing listens there.
- 510 Deploy a static site with nginx: a site's file in `sites-available`, its
  link in `sites-enabled`, `nginx -t` and the reload.
- 509 Reverse Proxying: how nginx chooses a `location` (longest prefix, or the
  first regular expression that matches), and a reverse proxy making a frontend
  and a backend appear as one website.
- 514 Provision a TLS certificate with Certbot and Let's Encrypt: the student's
  other sites are on HTTPS. Revprod gets no certificate.
- 512 Horizontally scale a web application with nginx as a load balancer, if
  done: Brewscale's baristas on ports 4200 to 4203, which Revprod's ports avoid.
- 506 Manage a web application with systemd as a Process Manager: a dedicated
  system user, a directory opened to its group with `chown` and `chmod 750`, a
  unit file, `daemon-reload`.
- 503 Unix Environment Variables, and 504 Configure a web application through
  environment variables: configuration in environment variables.
- 501 Deploy a web application with Git: a deployment directory in `/srv`.
- 410 Deploy a web application with SFTP: Node.js 26 installed, and `ss -tlpn`.
- 406 Unix Networking: the loopback address `127.0.0.1`, and ports.

The student works on their server over SSH, and in their browser with its
developer tools. The page's examples use the user `jde` and the hostname
`jde.archidepN.ch`. The server's firewall opens ports 22, 80, 443, 3000 and
3001 only.

## Learning objectives

Deploying Revprod, an application split into two components by two imaginary
teams: a landing page in Python, using only its standard library, and a backend
in Node.js that stores testimonials. Each is deployed like Guess It, with a
directory, a user and a systemd service of its own, and each is first seen to be
broken alone. Linked by their public addresses in environment variables, they
work but show two sites, and the testimonials fail on the same-origin policy.
One nginx site routing by path then makes them a single origin, and the
backend's port becomes an internal detail. The page's "What have I done?"
states what the student should understand afterwards, including what an origin
is and why the browser, not the backend, refused the answer.

Optional: the "Optional: allow the landing page with CORS" section (enable CORS,
then turn it off again), the callouts on multi-component applications and on
the same-origin policy, and the note on `/var/lib`.

Not in the exercise: HTTPS for Revprod, the code of either component, writing
Python or JavaScript, CORS beyond the `Access-Control-Allow-Origin` header
(preflight requests, credentials, other headers), cookies, `proxy_pass` with a
path after the address, rewriting paths, and regular expressions beyond the
alternative the solution shows. `StateDirectory=` is used without other systemd
directory options.

## Where it leads

Little of the course relies on this exercise directly. The single origin made by
a reverse proxy is its own point. In particular:

- "Deploy a PHP application with Docker Compose" writes an nginx configuration
  with several `location` blocks again, inside a container.

## Key steps

- **"Meet The Revolutionary Product"**. The reference deployment at
  `https://revprod.archidep.ch` looks like one website.
- **"Requirements"**. Expected: `node --version` prints v26, `python3
--version` 3.12 or later.
- **"Run the backend with systemd"**.
  Question before: "Why can't the backend keep its default port, 3000?" (Guess
  It listens on it.) "Why can't the backend store its file in
  `/srv/revprod-backend`?" (Its user may only read that directory.)
  Expected: `active (running)`, and `Listening on 0.0.0.0:3001` in the last
  line.
- **"Try the backend on its own"**. The page asks what the Home link will do,
  with its answer on the page while the student works.
  Expected: the form at port 3001; the testimonial in JSON at `/comments`; Home
  and Close lead back to the form.
- **"Run the landing page with systemd"**.
  Question after: "Why does the landing page listen on `127.0.0.1`, while the
  backend listens on every address?" (Only nginx needs to reach it; the backend
  is reached directly, for now.)
  Expected: `active (running)`, and `Listening on 127.0.0.1:4300`.
- **"Try the landing page on its own"**. The page asks what Share will do and
  why the testimonials are missing, with its answer on the page while the
  student works.
  Expected: an error message instead of the testimonials; the landing page's
  `Not Found` page at `/share`.
- **"Two halves of one application"**. A stepped diagram of the state so far.
  Question after: "Who knows the backend's address on the web: the landing page
  team, or whoever deploys it?" (Whoever deploys it, hence an environment
  variable.)
- **"Link the components"**.
  Expected: Share and Home lead from one component to the other, and the address
  bar changes between `revprod.jde.archidepN.ch` and `jde.archidepN.ch:3001`.
- **"It's not working!"**.
  Expected: the request to `comments` with the status **CORS error**, and
  `blocked by CORS policy: No 'Access-Control-Allow-Origin' header` in the
  console; the request in the backend's logs.
  Question after: "Did the backend answer the request for the testimonials?"
  (Yes; the browser refused to hand the answer over.) "Which parts of the two
  addresses differ?" (The host name and the port.)
- **"Optional: allow the landing page with CORS"**. Optional.
  Expected: the testimonials, and `Access-Control-Allow-Origin` with the landing
  page's origin among the response headers; missing again after the lines are
  commented out and the page is reloaded holding Shift.
  Question after: "Which component had to change, so that the landing page could
  read the testimonials?" (The backend.)
- **"Serve both components as a single site"**. The student writes the
  `location` blocks themselves; the page lists the backend's three paths and
  requires a single `server` block. The file's solution is not on the page until
  the class has covered the chapter.
  Question before: "Which component must answer a request for `/share`? For
  `/comments`? For `/`?" "If a `server` block has `location /` and another
  `location` that also matches a path, which one does nginx choose?" (The longest
  prefix, from 509.)
  Expected after: the address stays `revprod.jde.archidepN.ch` from one
  component to the other; the request to `comments` at the same origin, `200
OK` or `304 Not Modified`, with no `Access-Control-Allow-Origin` header and no
  console error.
  Question after: "CORS is still off. Why are the testimonials there?" (There is
  only one origin.) "Why does neither component need the other's address any
  more?" (A link to a path on the same site reaches the right one through
  nginx.)
- **"Hide the backend's port"**.
  Question before: "Once the backend listens on port 4301, what will nginx
  answer for `/share`? And for `/`?" (`502 Bad Gateway`; the landing page still
  works.)
  Expected: `502 Bad Gateway` at `/share`, explained by the page in place, with
  `connect() failed (111: Connection refused)` and `upstream:
"http://127.0.0.1:3001/share"` in the error log; after the `proxy_pass`
  change, Revprod works and `http://jde.archidepN.ch:3001` refuses to connect.
  Question after: "Who had to know that the backend changed port?" (Only
  nginx.)

## Common pitfalls

- **A link leads to a name that is not the student's, or to nothing**: a base
  URL in a unit file still has the page's `jde.archidepN.ch`. Hint: where does
  the link point, when you hover it? Hint: which variable holds that address?
- **A change to a unit file has no effect, and `systemctl status` warns that the
  unit file changed on disk**: `daemon-reload` or the restart was skipped.
  Hint: what does systemd know of a file you changed, until you tell it?
- **`nginx -t` warns `conflicting server name … ignored`**: the backend's paths
  were put in a second `server` block, or a second site, with the same
  `server_name`, and nginx uses only one of them. Hint: how many `server` blocks
  does the page allow?
- **`/share` gives the landing page's `Not Found` page although a location for
  it exists**: the location is written `/share/`, and the path `/share` does not
  start with `/share/`. Hint: compare the path in the address bar with your
  location, character by character.
- **`/share` fails with `ERR_TOO_MANY_REDIRECTS`, or the testimonials stay
  missing, although the locations exist**: a `proxy_pass` to the backend has a
  path after the port, such as `http://127.0.0.1:3001/`. nginx then replaces the
  matched part of the path with it, so the backend receives `/` instead of
  `/share` or `/comments`, and its `/` redirects the browser to `/share`, which
  nginx sends to the backend as `/` again. Hint: compare that `proxy_pass` with
  the landing page's. Hint: which path does the backend log for each request,
  in `journalctl -u revprod-backend`?
- **The whole site behaves like the backend after "Hide the backend's port"**:
  the landing page's `proxy_pass` was changed to 4301 as well. Hint: which
  component listens on port 4300?
