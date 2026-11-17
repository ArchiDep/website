# Tutor notes: 510 Deploy a static site with nginx

## Starting point

- 508 Domain name configuration: the `jde` and `*.jde` `A` records of the
  student's hostname, such as `jde.archidepN.ch`, point to the server's public
  address.
- 506 Manage a web application with systemd as a Process Manager: Guess It runs
  as the `guessit` service on port 3000, and its code in `/srv/guessit` is
  opened to the `guessit` group with `chown` and `chmod 750`, the model this
  exercise repeats for `www-data`.
- 509 Reverse Proxying: the subject page's nginx configuration, the static
  website example, `sites-available` and `sites-enabled`, and how nginx chooses
  a `server` block by name.
- 404 Run your own virtual server on Microsoft Azure: port 80 open in the
  network security group.

nginx is not installed yet. The student works on their server over SSH; the
page's examples use the user `jde` and the hostname `jde.archidepN.ch`.

## Learning objectives

Installing nginx and serving a static site, the clock, at a name of its own,
`clock.` followed by the student's hostname, with no port in the address. The
student practises the steps every later nginx site repeats: a configuration in
`sites-available`, a symbolic link in `sites-enabled`, `nginx -t`, and a reload.
The page's "What have I done?" states what the student should understand
afterwards, including why a new site needs no new DNS record, and why Guess It
still needs its port.

The exercise uses the static example of 509 unchanged but for `server_name`
and `root`. Not in it: reverse proxying, HTTPS, writing a `location` of one's
own (apart from the optional `.git` one), the `default` site's configuration,
and the access log beyond the example's `access_log off`.

## Where it leads

Every later site on the student's server is an nginx configuration enabled by
the same steps, at a name of its own under the wildcard record. In particular:

- "Deploy a web application with nginx as a reverse proxy" adds Guess It
  beside the clock, on the same port 80, with `proxy_pass` instead of `root`.
- "Horizontally scale a web application with nginx as a load balancer" and
  "Deploy a multi-component web application with nginx" add sites of their own
  the same way.
- "Provision an SSL certificate using Certbot by Let's Encrypt" has Certbot
  find the sites by their `server_name` and edit their configurations.
- "Set up an automated deployment with Git hooks" deploys into a directory
  nginx serves, as `/srv/clock` is here.

## Key steps

- **"Install nginx on the server"**.
  Question before: "Once nginx is installed, which port will a browser use for
  `http://W.X.Y.Z`, with no port?" (80.)
  Expected after: `sudo ss -tlpn` shows `nginx` listening on `0.0.0.0:80` and
  `[::]:80`; `systemctl status nginx` shows `active (running)`; the server's
  public address shows "Welcome to nginx!".
  Question after: "Who started nginx, since you did not?" (systemd, when APT
  installed it.)
- **"Put the static website on the server"**.
  Question before: "Which user must be able to read `/srv/clock`? And why not
  put the clock in your home directory?" (`www-data`, which is not allowed into
  it.)
  Expected after: `drwxr-x--- … jde www-data … /srv/clock`, then `index.html`,
  `README.md`, `script.js` and `style.css` in it.
  Question after: "Why can you clone into `/srv/clock` without `sudo`?" (You own
  it.)
- **"Choose the name of the site"**.
  Question before: "Do you need a new DNS record for `clock.jde.archidepN.ch`?"
  (No, the `*.jde` wildcard covers it.)
- **"Create an nginx configuration file to serve the website"**. The page asks
  for two changes to the example, `server_name` and `root`. The file's solution
  is not on the page until the class has covered the chapter.
  Question after: "Which of the two directives decides which requests this
  configuration answers?"
- **"Enable the nginx configuration"**.
  Question before: "If you reloaded nginx now, without the link, would the clock
  work? Why?" (No. nginx includes `sites-enabled`, not `sites-available`.)
  Expected after: `ls -l` shows the link `-> /etc/nginx/sites-available/clock`.
- **"Reload the nginx configuration"**.
  Expected: `syntax is ok` and `test is successful`, then a reload that prints
  nothing.
  Question after: "If your configuration had an error, what would the reload do
  to the sites nginx already serves? And a restart?"
- **"See it in action"**.
  Expected: the clock at `http://clock.jde.archidepN.ch`, with no port.
  Question before visiting the hostname alone: "What will
  `http://jde.archidepN.ch` show now? And `http://jde.archidepN.ch:3000`?"
  (nginx's welcome page, since no `server_name` matches; Guess It, which nginx
  is not involved in.)
- **"Optional: hide the Git repository for security"**.
  Expected before the change: the contents of the clone's Git configuration,
  with the repository's URL; some browsers download the file, named `config`,
  instead of showing it. Expected after: `403 Forbidden`.
  Question after: "Why does nginx serve `.git` at all?" (It serves every file
  under `root`.)

## Common pitfalls

- **`git clone` says `Permission denied`**: `/srv/clock` still belongs to
  `root`, because the `chown` was skipped or mistyped. Running `git clone` with
  `sudo` gets past it, but leaves files the student cannot update without
  `sudo`. Hint: who owns `/srv/clock`, according to `ls -ld`? Hint: which
  command of the step gave it to you?
- **`nginx -t` reports `[emerg]` with a file and a line number, such as
  `unexpected "}"` or `directive "server_name" is not terminated by ";"`**: a
  typo in the configuration, often a missing `;`. Hint: what is on the line the
  error names, or the line just before it?
- **`nginx -t` says `open() "/etc/nginx/sites-enabled/clock" failed`, or `Too
many levels of symbolic links`**: the link was made with a relative or wrong
  target, so it points nowhere, or to itself. Hint: what does `ls -l
/etc/nginx/sites-enabled` show after the arrow?
- **`systemctl reload nginx` says `Job for nginx.service failed`**: the new
  configuration has an error, and nginx keeps serving the old one. Hint: what
  does `sudo nginx -t` say?
- **Changes to `/etc/nginx/sites-available/clock` have no effect, although
  nginx was reloaded**: `sites-enabled/clock` is a copy, made with `cp`, rather
  than a link. Hint: does `ls -l /etc/nginx/sites-enabled` show an arrow for
  `clock`?
- **The browser shows a security error, or the address starts with
  `https://`**: some browsers try HTTPS first, and nothing listens on port 443
  yet. Hint: what does the address bar show, exactly?
- **The student asks why the server's IP address shows the welcome page and not
  the clock**: that is the intended result. Hint: what name does the browser
  send in the `Host` header when you type an IP address?
