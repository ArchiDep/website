# Tutor notes: 514 Provision a TLS certificate with Certbot and Let's Encrypt

## Starting point

- 511 Deploy a web application with nginx as a reverse proxy: Guess It behind
  nginx at `guessit.jde.archidepN.ch`, and nginx's master process as `root` and
  workers as `www-data`.
- 510 Deploy a static site with nginx: the clock at `clock.jde.archidepN.ch`,
  `sites-available` and `sites-enabled`, and `sudo ss -tlpn` showing nginx on
  port 80.
- 512 Horizontally scale a web application with nginx as a load balancer, if
  done: Brewscale at `brewscale.jde.archidepN.ch`. The exercise works without
  it.
- 513 TLS/SSL Certificates: certificates, the chain of trust, HTTP validation,
  Let's Encrypt, Certbot and TLS termination.
- 508 Domain name configuration: the records that make each site's name point
  to the server, which Let's Encrypt checks.
- 506 Manage a web application with systemd as a Process Manager: units, which
  the renewal timer is one more kind of.
- 403 Unix Permissions: a directory only `root` may read.

Every site must work over plain HTTP before the exercise starts. The student
works on their server over SSH; the page's examples use the user `jde` and the
hostname `jde.archidepN.ch`.

## Learning objectives

Serving every nginx site of the student's server over HTTPS with one Let's
Encrypt certificate valid for all their names, obtained with a single run of
Certbot's nginx plugin. The student then sees what Certbot changed in a site's
configuration (a `server` block on port 443 with the certificate, and one on
port 80 redirecting to HTTPS), that TLS ends at nginx, that only `root` can read
the private key, and the timer that renews it. The page's "What have I done?"
states what the student should understand afterwards.

Not in the exercise: writing the HTTPS configuration by hand, the TLS options
Certbot includes (`options-ssl-nginx.conf`, `ssl_dhparam`), the `if` and
`return` directives of the redirection beyond what they do, running a renewal
by hand or as a dry run, DNS validation and wildcard certificates, and HTTPS
for Revprod, which is deployed after this exercise and stays on HTTP. Guess It
still answers in plain HTTP at `http://jde.archidepN.ch:3000`, which does not
go through nginx.

## Where it leads

Little of the course relies on this exercise directly, beyond the sites staying
on HTTPS. In particular:

- "Deploy a multi-component web application with nginx" serves Revprod over
  HTTP only; its troubleshooting explains the certificate warning a browser
  shows for Revprod's name over HTTPS.
- "Deploy static sites to Netlify" and "Deploy web applications with a database
  to Render" have the platform obtain Let's Encrypt certificates, which the
  student did by hand here.

## Key steps

- **"Requirements"**. Expected: every site works at `http://` followed by its
  name.
- **"Try HTTPS before you start"**. The page asks what will happen, with its
  answer on the page while the student works.
  Expected: `ERR_CONNECTION_REFUSED` or a similar error, and `ss -tlpn` showing
  nginx on port 80 only.
- **"Install Certbot"**. `certbot` and `python3-certbot-nginx` with `apt`.
- **"Obtain a TLS certificate from Let's Encrypt"**. The page asks for one run,
  selecting every name by pressing Enter.
  Question before: "Let's Encrypt's servers will check each of your names. What
  must already work for that check to succeed?" (Each name points to the server,
  and nginx answers it on port 80.)
  Expected after: `Successfully received certificate`, a certificate in a
  directory named after the first name, a `Successfully deployed certificate`
  line per site, and `Congratulations!`.
- **"See it in action"**.
  Expected: each site at `https://`, with no warning; the certificate issued by
  Let's Encrypt, valid for every name, expiring in about 90 days.
  Question after: "Why does your browser trust this certificate, when nobody
  sent it anything about your sites?" (Let's Encrypt's root is in its list.)
- **"Look at what Certbot changed"**.
  Expected: two `server` blocks in each site's file, the first with `listen 443
ssl` and the certificate's paths, the second with `listen 80` and a `301`
  redirection; `ss -tlpn` now showing port 443.
  Question after: "What happens now when you type `http://` followed by one of
  your sites' names?" (The second block redirects the browser to `https://`.)
  "Why do the clock's and Guess It's files name the same certificate?" (One
  certificate is valid for all the names.)
- **"Is everything encrypted now?"**. The page asks whether nginx's connection
  to Guess It is encrypted, with its answer on the page while the student works.
  Question after: "Which line of Guess It's configuration did Certbot not
  change?" (`proxy_pass`.)
- **"Find out who can read the private key"**. The page asks which nginx process
  reads the key, with its answer on the page while the student works.
  Expected: `Permission denied` without `sudo`; with it, `cert.pem`,
  `chain.pem`, `fullchain.pem` and `privkey.pem` as links into `archive`.
  Question after: "Why are these files links rather than the files themselves?"
  (Each renewal adds new files, and the links follow, so nginx's configuration
  never changes.)
- **"Check the automatic renewal"**.
  Expected: one timer, `certbot.timer`, activating `certbot.service`.
  Question after: "Your certificate lasts about 90 days. When will the timer
  renew it?" (When less than a third of its lifetime is left, about 30 days.)

## Common pitfalls

- **`certbot` without `sudo` fails with a permission error** on
  `/var/log/letsencrypt` or `/etc/letsencrypt`: Certbot changes files only
  `root` may write. Hint: which files is Certbot about to change, and who owns
  them?
- **The student asks why Guess It still answers in plain HTTP at `:3000`**:
  that port reaches Guess It directly, not nginx, and the certificate is
  nginx's. Nothing in the exercise closes it.
- **The student asks why they could not get one wildcard certificate for every
  name under their hostname**: a wildcard needs DNS validation, a `TXT` record
  in the zone, while Certbot's nginx plugin uses HTTP validation (513).
- **The student expects Guess It's code or its unit file to need changing for
  HTTPS**: nginx terminates TLS, and Guess It sees the same plain HTTP requests
  from nginx as before. Hint: which process does your browser's TLS connection
  end at?
