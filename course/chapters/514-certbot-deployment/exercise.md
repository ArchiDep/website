---
title: Provision a TLS certificate with Certbot and Let's Encrypt
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to serve the sites you have deployed with nginx
over HTTPS, with a [TLS certificate][tls-subject] from [Let's
Encrypt][letsencrypt], obtained with [Certbot][certbot].

{% callout type: exercise %}

Connect to your cloud server with SSH for this exercise.

{% endcallout %}

<!-- more -->

## :exclamation: Requirements

Make sure you have completed the [reverse proxy exercise][reverse-proxy-exercise]
first: nginx must serve the clock and Guess It, each at a name of its own, such
as `clock.jde.archidepN.ch` and `guessit.jde.archidepN.ch`. Brewscale too, if
you have deployed it in the [horizontal scaling exercise][brewscale-exercise].

Visit each of your sites in your browser with `http://`, e.g.
`http://guessit.jde.archidepN.ch`, and check that it works. Let's Encrypt will
check that your server answers at each name: a site that does not work over HTTP
will not get a certificate.

## :exclamation: Try HTTPS before you start

Visit one of your sites with `https://` instead of `http://`, e.g.
`https://guessit.jde.archidepN.ch`. What do you think will happen, and why?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

Your browser cannot connect: it shows an error such as
`ERR_CONNECTION_REFUSED`. With `https://` and no port in the address, the
browser connects to port 443, the default port of HTTPS. Nothing listens on
that port on your server: nginx only listens on port 80, as you can see with
the command you used in the [static site exercise][static-listen]:

```bash
$> sudo ss -tlpn
State  Recv-Q Send-Q Local Address:Port ... Process
LISTEN 0      511          0.0.0.0:80   ... users:(("nginx",pid=812,fd=5),...)
LISTEN 0      511             [::]:80   ... users:(("nginx",pid=812,fd=6),...)
...
```

{% endsolution %}

## :exclamation: Install Certbot

Install Certbot, and its plugin to configure nginx:

```bash
$> sudo apt install certbot python3-certbot-nginx
```

## :exclamation: Obtain a TLS certificate from Let's Encrypt

{% callout type: warning %}

Run Certbot **once**, and select **all** your sites when it asks which names to
activate HTTPS for. You will then get a single certificate valid for all of
them.

Let's Encrypt limits how many certificates the same domain may get per week, and
your whole class shares the same domain, `archidepN.ch`. Do not run Certbot
again to experiment.

{% endcallout %}

Run Certbot with its nginx plugin:

```bash
$> sudo certbot --nginx
```

Certbot asks you a few questions:

- **An email address.** Let's Encrypt uses it to contact you about your account.
  You may give one, or press Enter to skip. If you give one, Certbot also asks
  whether you want to share it with the Electronic Frontier Foundation, which
  makes Certbot: answer as you like.
- **The terms of service.** You must agree to them to get a certificate: answer
  `Y`.
- **Which names to activate HTTPS for.** Certbot lists the names it found in
  the `server_name` directives of your enabled nginx configurations, such as:

  ```
  Which names would you like to activate HTTPS for?
  We recommend selecting either all domains, or all domains in a VirtualHost/server block.
  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  1: brewscale.jde.archidepN.ch
  2: clock.jde.archidepN.ch
  3: guessit.jde.archidepN.ch
  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  Select the appropriate numbers separated by commas and/or spaces, or leave input
  blank to select all options shown (Enter 'c' to cancel):
  ```

  Press Enter without typing anything, to select them all.

Certbot then requests the certificate from Let's Encrypt, and installs it in
nginx. It should end with something like this:

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/brewscale.jde.archidepN.ch/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/brewscale.jde.archidepN.ch/privkey.pem
This certificate expires on 2027-02-24.
These files will be updated when the certificate renews.
Certbot has set up a scheduled task to automatically renew this certificate in the background.

Deploying certificate
Successfully deployed certificate for brewscale.jde.archidepN.ch to /etc/nginx/sites-enabled/brewscale
Successfully deployed certificate for clock.jde.archidepN.ch to /etc/nginx/sites-enabled/clock
Successfully deployed certificate for guessit.jde.archidepN.ch to /etc/nginx/sites-enabled/guessit
Congratulations! You have successfully enabled HTTPS on https://brewscale.jde.archidepN.ch, https://clock.jde.archidepN.ch, and https://guessit.jde.archidepN.ch
```

The directory of the certificate is named after the first name it is valid for,
which may be a different site of yours.

{% note type: more %}

Before Let's Encrypt issued the certificate, it checked that you control each of
these names, with the [HTTP validation][http-validation] described in the
subject. Certbot temporarily configured nginx to serve a token for each name,
and Let's Encrypt's servers fetched it from your server on port 80.

{% endnote %}

## :exclamation: See it in action

Visit your sites with `https://`, e.g. `https://guessit.jde.archidepN.ch`. They
now work, and your browser shows no warning.

Look at the certificate in your browser, from the icon on the left of the
address bar. It is issued by Let's Encrypt, and is valid for all your sites'
names. It expires in about 90 days.

## :exclamation: Look at what Certbot changed

Certbot has modified your sites' configurations. Look at Guess It's:

```bash
$> cat /etc/nginx/sites-available/guessit
```

It should look like this, with the name of your certificate's directory:

```nginx
server {
  server_name guessit.jde.archidepN.ch;

  # Forward every request to Guess It.
  location / {
    proxy_pass http://127.0.0.1:3000;
  }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/brewscale.jde.archidepN.ch/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/brewscale.jde.archidepN.ch/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = guessit.jde.archidepN.ch) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


  listen 80;
  server_name guessit.jde.archidepN.ch;
    return 404; # managed by Certbot


}
```

The file now has two `server` blocks:

- The first one is your site, which now listens on port 443, for HTTPS, instead
  of port 80. `ssl_certificate` is the certificate, with the intermediate
  certificate of Let's Encrypt (the **full chain**), and `ssl_certificate_key`
  its private key. The included file and `ssl_dhparam` are settings for the TLS
  protocol that Certbot provides.
- The second one listens on port 80, for HTTP, and answers every request with a
  `301 Moved Permanently` status, a **redirection** that tells the browser to go
  to the same address with `https://` instead. A browser follows it without
  asking you.

Your `clock` and `brewscale` files have changed in the same way, with the same
certificate.

Check that nginx now listens on port 443 as well:

```bash
$> sudo ss -tlpn
State  Recv-Q Send-Q Local Address:Port ... Process
LISTEN 0      511          0.0.0.0:443  ... users:(("nginx",pid=812,fd=7),...)
LISTEN 0      511          0.0.0.0:80   ... users:(("nginx",pid=812,fd=5),...)
LISTEN 0      511             [::]:80   ... users:(("nginx",pid=812,fd=6),...)
...
```

## :exclamation: Is everything encrypted now?

Your browser now talks to your server over HTTPS. Is the connection between nginx
and Guess It encrypted too?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

No. The `proxy_pass` directive has not changed: nginx still forwards requests to
`http://127.0.0.1:3000`, in plain HTTP. nginx decrypts the browser's request,
forwards it to Guess It unencrypted, and encrypts Guess It's answer for the
browser. This is called **TLS termination**: the TLS connection ends at nginx.

This connection does not need to be encrypted, since it never leaves the
server: `127.0.0.1` is the server's loopback address. Guess It has not changed
at all, and does not know that the browser used HTTPS.

{% endsolution %}

## :exclamation: Find out who can read the private key

Try to list the directory where Certbot saved your certificate, without `sudo`:

```bash
$> ls /etc/letsencrypt/live
ls: cannot open directory '/etc/letsencrypt/live': Permission denied
```

Then with `sudo`, replacing the name with the one of your certificate's
directory:

```bash
$> sudo ls -l /etc/letsencrypt/live/brewscale.jde.archidepN.ch
total 4
-rw-r--r-- 1 root root 692 Nov 26 09:12 README
lrwxrwxrwx 1 root root  51 Nov 26 09:12 cert.pem -> ../../archive/brewscale.jde.archidepN.ch/cert1.pem
lrwxrwxrwx 1 root root  52 Nov 26 09:12 chain.pem -> ../../archive/brewscale.jde.archidepN.ch/chain1.pem
lrwxrwxrwx 1 root root  56 Nov 26 09:12 fullchain.pem -> ../../archive/brewscale.jde.archidepN.ch/fullchain1.pem
lrwxrwxrwx 1 root root  54 Nov 26 09:12 privkey.pem -> ../../archive/brewscale.jde.archidepN.ch/privkey1.pem
```

The files are symbolic links to the actual files, in the `archive` directory.
Each renewal adds new files there, and Certbot points the links to them, so that
nginx's configuration never has to change.

Only `root` can read the private key. In the [reverse proxy
exercise][nginx-processes], you saw that nginx has a master process, which runs
as `root`, and worker processes, which run as `www-data` and handle the
requests. Which of them reads the private key?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

The master process, which runs as `root`. It reads the certificate and the
private key when nginx starts, or when its configuration is reloaded, along with
the rest of the configuration, and its worker processes inherit them. The
worker processes cannot read the files themselves, so a vulnerability in the
code that handles requests cannot be used to read the private key from the
disk.

{% endsolution %}

## :exclamation: Check the automatic renewal

Your certificate expires in about 90 days. When you installed Certbot, it also
installed a systemd **timer**: a unit that starts another unit, here Certbot's
service, at given times. List it:

```bash
$> systemctl list-timers 'certbot*'
NEXT                            LEFT LAST PASSED UNIT          ACTIVATES
Thu 2026-11-26 21:43:10 UTC 9h left -       -    certbot.timer certbot.service

1 timers listed.
```

The timer runs `certbot renew` twice a day. It renews every certificate that has
less than a third of its lifetime left, 30 days for yours, and reloads nginx so
that it uses the new one.

## :checkered_flag: What have I done?

You have served your sites over HTTPS, with a certificate from Let's Encrypt,
which every browser trusts. Your browser now talks to your server over an
encrypted connection, and knows it is talking to your server.

The certificate binds your sites' names to a public key. The private key that
goes with it was generated on your server and never left it. The certificate
itself is public: nginx sends it to every browser that connects. What proves
your server's identity is that nginx signs each connection with the private
key.

Your browser trusts the certificate because it is signed by Let's Encrypt, and
Let's Encrypt's root certificate is in the list your browser already trusts.
Nobody had to send your browser anything for your sites in particular.

Let's Encrypt issued the certificate only once it had checked that you control
the names. Certbot and Let's Encrypt's servers did this for you, automatically:
Certbot had nginx serve a token on port 80 at each name, and Let's Encrypt's
servers fetched it from your server. This is why your DNS records and nginx had
to work over HTTP before you started.

nginx **terminates** TLS. It decrypts the browser's requests, and forwards them
to Guess It over plain HTTP, on the server's loopback address. Guess It has not
changed, and one certificate in nginx serves all your sites.

The certificate expires in about 90 days. A systemd timer periodically renews it
for you, with no one involved.

Deploying a new version of an application, however, is still done by hand, over
SSH.

### :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise. The processes are those of the
[reverse proxy exercise][reverse-proxy-architecture], but the browser connects
to nginx on port 443, and checks its certificate before sending its request.
Step through the diagram to see what happens when a browser requests Guess It's
home page over HTTPS.

{% include diagrams/514-certbot.html %}

{% note %}

Note that this diagram simplifies nginx by showing only one process, while in
reality it has a master process and several worker processes, but this is
sufficient to understand the architecture.

{% endnote %}

## :file_folder: Where is everything?

These are the files and directories of your server that matter for this
deployment.

<div class="file-map">

| Path                                                                                       | What it is                                                                                            | What you did                                                                | Who uses it                                  |
| :----------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------- | :------------------------------------------- |
| :file_folder: `/etc/letsencrypt` <span class="new">new</span>                              | Certbot's directory: your Let's Encrypt account, your certificates, and how to renew them             | Nothing: Certbot created it when you ran it                                 | Certbot, to renew the certificate            |
| :file_folder: `/etc/letsencrypt/live/…` <span class="new">new</span>                       | Your certificate, with its intermediate certificate, and its private key, readable by `root` only     | Nothing: Certbot saved them there                                           | nginx's master process, which runs as `root` |
| :page_facing_up: `/etc/nginx/sites-available/guessit` <span class="changed">changed</span> | The configuration of Guess It, now on port 443 with the certificate, and redirecting port 80 to HTTPS | Nothing: Certbot changed it, and you read it with `cat`                     | nginx, through the link in `sites-enabled`   |
| :page_facing_up: `/etc/nginx/sites-available/clock` <span class="changed">changed</span>   | The configuration of the clock, changed in the same way                                               | Nothing: Certbot changed it                                                 | nginx, through the link in `sites-enabled`   |
| :page_facing_up: `/usr/lib/systemd/system/certbot.timer` <span class="new">new</span>      | The timer that runs Certbot twice a day, to renew the certificates that expire soon                   | Installed it with `apt install`, and listed it with `systemctl list-timers` | systemd, to start `certbot.service`          |

</div>

The configuration of Brewscale, if you have deployed it, has changed like those
of Guess It and the clock.

You can explore all of this yourself: `ls -l` shows what a directory contains,
with its permissions, and `cat`, `head` and `tail` what a file contains, as in
the [command line cheatsheet][command-line-cheatsheet]. Use `sudo` for what only
`root` can read. For example:

```bash
# The certificates Certbot manages, their names and their expiry dates.
$> sudo certbot certificates

# How Certbot will renew your certificate.
$> sudo ls /etc/letsencrypt/renewal
```

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: `Certbot failed to authenticate some domains`

Let's Encrypt could not check that you control one of the names. Certbot lists
each name that failed, with the problem Let's Encrypt reported, for example:

- `DNS problem: NXDOMAIN looking up A for …`: the name does not exist in the
  DNS. Check your records as in the [DNS exercise][dns-exercise].
- `Timeout during connect (likely firewall problem)`: Let's Encrypt could not
  connect to your server on port 80.

In every case, check that each of your sites works over HTTP, e.g.
`http://guessit.jde.archidepN.ch`, from your computer, as in the
[requirements](#requirements). Fix the site that does not work before running
Certbot again.

### :boom: Certbot does not list one of my sites

Certbot lists the names in the `server_name` directives of the configurations
in `/etc/nginx/sites-enabled`. Check that the site's configuration is enabled,
with `ls -l /etc/nginx/sites-enabled`, and that `sudo nginx -t` reports no
error.

### :boom: The browser says the certificate is not valid for one of my sites

You did not select that site's name when you ran Certbot, so your certificate is
not valid for it. Run `sudo certbot --nginx` again, and select all your names.
Certbot tells you that you have an existing certificate with some of these names,
and asks whether to expand it: answer `E` to replace it with a certificate valid
for all of them.

[brewscale-exercise]: {% link chapters/512-brewscale-deployment/exercise.md %}
[certbot]: https://certbot.eff.org
[command-line-cheatsheet]: {% link cheatsheets/command-line/cheatsheet.md %}#whats-in-this-file-cat-head-tail-less
[dns-exercise]: {% link chapters/508-dns-config/exercise.md %}
[http-validation]: {% link chapters/513-tls/subject.md %}#domain-validation
[letsencrypt]: https://letsencrypt.org
[nginx-processes]: {% link chapters/511-nginx-reverse-proxy-deployment/exercise.md %}#find-out-who-listens-on-port-80
[reverse-proxy-architecture]: {% link chapters/511-nginx-reverse-proxy-deployment/exercise.md %}#architecture
[reverse-proxy-exercise]: {% link chapters/511-nginx-reverse-proxy-deployment/exercise.md %}
[static-listen]: {% link chapters/510-nginx-static-deployment/exercise.md %}#install-nginx-on-the-server
[tls-subject]: {% link chapters/513-tls/subject.md %}
