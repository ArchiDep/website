---
title: Reverse Proxying
excerpt_separator: <!-- more -->
---

Learn what a reverse proxy is, and how to configure nginx to be one.

<!-- more -->

**Recommended reading**

- [Unix Administration]({% link chapters/402-unix-basics/subject.md %})
- [Unix Networking]({% link chapters/406-unix-networking/subject.md %})

## nginx configuration

Nginx stores its configuration in the `/etc/nginx` directory.

```bash
$> ls -1 /etc/nginx
conf.d
fastcgi.conf
fastcgi_params
koi-utf
koi-win
mime.types
modules-available
modules-enabled
nginx.conf
proxy_params
scgi_params
sites-available
sites-enabled
snippets
uwsgi_params
win-utf
```

The most important files are:

- `nginx.conf` is the main configuration file. Everything starts from there.
- `sites-available` is a directory where website configuration files are stored.
- `sites-enabled` is a directory containing symbolic links to the configurations
  in `sites-available`.
- `conf.d` is another directory of configuration files, included in the same
  place as `sites-enabled`. It is empty on Ubuntu, which puts the configurations
  of websites in `sites-available` instead.
- `snippets` is a directory to store reusable configuration fragments, which
  other configuration files can include.

### The main configuration file

The main `/etc/nginx/nginx.conf` file is a tree-like structure formed of
**contexts** delimited by braces (`{` and `}`). Each context contains
configuration related to a specific area of concern.

The basic structure is as follows:

```nginx
# Main context: global nginx options

events {
  # Events context: connection handling options
}

http {
  # HTTP context: web server & reverse proxy configuration

  server {
    # Server context: website configuration
  }

  server {
    # Another server...
  }
}
```

These contexts can contain a number of [directives][nginx-directives].

### Includes

Nginx has an [`include` directive][nginx-include] which allows you to split the
configuration into several files instead of having one big file. As you can see,
nginx already includes several other files out of the box:

```
$> grep include /etc/nginx/nginx.conf
include /etc/nginx/modules-enabled/*.conf;
include /etc/nginx/mime.types;
include /etc/nginx/conf.d/*.conf;
include /etc/nginx/sites-enabled/*;
```

The most important include is `/etc/nginx/sites-enabled/*`. Any file in there
will be loaded in the `http` context, which makes it a good place to define
`server` contexts in.

### `sites-available` vs. `sites-enabled`

The nginx package of Ubuntu (and of Debian, which Ubuntu is based on) has two
directories for website configuration files. This is a convention of these
distributions, not of nginx itself: other distributions only have `conf.d`.

- **`sites-available`** contains the actual configuration files. For example,
  you could create a file at `/etc/nginx/sites-available/example` to configure
  nginx to serve your website.

  This directory is **not** included by nginx, so configuration files in it are
  not automatically picked up.

- **`sites-enabled`** contains **symbolic links** to the configuration files in
  `sites-available`.

  This directory is included by nginx. Configuration files in it (or links to
  configuration files) are automatically loaded.

```
/etc/nginx/sites-enabled/example -> /etc/nginx/sites-available/example
```

Things are set up like this so that you can work on configuration files in
`sites-available` but not actually enable them until you put the symbolic link
in `sites-enabled`. It also allows you to **quickly disable** a website by
removing its symbolic link, while its configuration file stays in
`sites-available`, ready to be enabled again with a new link.

### Reloading nginx's configuration

When you put new symbolic links in `sites-enabled`, or modify configurations in
`sites-available`, nginx will not automatically reload them.

First, check that the configuration is valid. The `nginx -t` command (as in
**t**est) loads the whole configuration, including the files it includes, and
reports any error:

```bash
$> sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

You could then restart nginx, but you can also tell it to **reload its
configuration without shutting down**. Nginx reacts to [some Unix
signals][nginx-signals] in certain ways. Notably, it reloads its configuration
when its master process receives a `HUP` signal. The `nginx -s reload` command
sends it for you:

```bash
$> sudo nginx -s reload
```

The systemd service of nginx runs that same command when you reload it. This is
how you will reload nginx in this course, the same way you manage any other
service:

```bash
$> sudo systemctl reload nginx
```

If the new configuration has an error, nginx keeps running with the old one.

### How nginx chooses a configuration

A request reaches nginx on a port, such as 80. Among the `server` blocks that
[`listen`][nginx-directive-listen] on that port, nginx picks the one whose
[`server_name`][nginx-server-names] is the name in the `Host` header of the
request: the name of the site the browser was asked for. If none has that name,
it uses the **default server** of that port: the one marked `default_server` in
its `listen` directive, or else the first one. On Ubuntu, that is the `default`
site, nginx's welcome page.

Within the chosen `server` block, nginx picks the
[`location`][nginx-directive-location] block that matches the path of the
request. A `location /api` block matches any path starting with `/api`, and when
several such locations match, the one with the longest prefix wins. A location
can also be a regular expression (`location ~* \.png$`). nginx checks these
after the prefixes, in order, and the first one that matches wins over the
longest prefix. [How nginx processes a request][nginx-request-processing] gives
the exact rules.

### Common nginx directives

Nginx has many [directives][nginx-directives] that can be put in various
contexts.

These are the most commonly used ones in the `server` context, used to serve
websites (static or dynamic):

| Directive                                  | Example value                     | Description                                                                                   |
| :----------------------------------------- | :-------------------------------- | :-------------------------------------------------------------------------------------------- |
| [`listen`][nginx-directive-listen]         | `80`, `localhost:8000`            | Port (and optional address) on which to listen and accept requests from.                      |
| [`server_name`][nginx-server-names]        | `example.com www.example.com`     | Space-separated list of domain names. Determine which `server` block handles client requests. |
| [`root`][nginx-directive-root]             | `/srv/site`, `/var/www/site`      | The root directory for requests.                                                              |
| [`index`][nginx-directive-index]           | `index.html`                      | Define files that will be used as an index, i.e. served by default if there is no URL path.   |
| [`location`][nginx-directive-location]     | `/api`, `~* \.jpg$`               | Vary configuration based on the URL.                                                          |
| [`proxy_pass`][nginx-directive-proxy-pass] | `http://127.0.0.1:3000`           | Forward requests to another server or application, as a reverse proxy.                        |
| [`include`][nginx-include]                 | `proxy_params`, `snippets/x.conf` | Load another configuration file at this point.                                                |

## nginx configuration examples

Each of the following examples configures one site. Put it in a file of its own
in `/etc/nginx/sites-available`, enable it with a symbolic link in
`/etc/nginx/sites-enabled`, then check and reload nginx's configuration, as
described above.

### Static website configuration

This configuration tells nginx to serve the static files in the directory
`/srv/example` when a request arrives on port 80 for the domain `example.com`.
This demonstrates nginx's capabilities as a basic **web server**.

```nginx
server {
  listen 80;
  server_name example.com;
  root /srv/example;
  index index.html;

  # Instruct the browser to cache images, icons,
  # video and audio for 30 days, and do not log
  # requests for them.
  location ~* \.(?:jpg|jpeg|gif|png|ico|gz|svg|mp4|ogg|ogv|webm)$ {
    access_log off;
    add_header Cache-Control "max-age=2592000";
  }
}
```

{% note type: more %}

The `Cache-Control` header is sent to the client's browser to tell it that these
media files (`jpg`, `png`, etc) can be cached, i.e. there's no need to
redownload them the next time.

`access_log off` tells nginx not to record these requests in its access log,
`/var/log/nginx/access.log`, which would otherwise list every image of every
page.

{% endnote %}

### Reverse proxy configuration

This configuration tells nginx to forward any request on port 80 for the domain
`dynamic.example.com` to the application or server at address
`http://127.0.0.1:3000`, making it behave as a **reverse proxy**.

```nginx
server {
  listen 80;
  server_name dynamic.example.com;

  # Proxy requests for dynamic content to another server/application.
  location / {
    proxy_pass http://127.0.0.1:3000;
  }
}
```

{% note type: more %}

In this example, the `proxy_pass` address is a local address, but it could well
be the IP address of another server in an internal network.

{% endnote %}

#### When the application does not answer

nginx and the application it proxies to are separate processes. When the
application fails, nginx is still there to receive the request, and answers it
with an error of its own:

- **502 Bad Gateway** when nginx cannot get an answer from the application, for
  example because nothing listens at the address of `proxy_pass`: the
  application is stopped, or listens on another port.
- **504 Gateway Timeout** when the application accepts the connection, but takes
  too long to answer: 60 seconds by default.

nginx's error log, `/var/log/nginx/error.log`, says what went wrong. The
application the requests are proxied to is called the **upstream** there.

### Load balancing configuration

This configuration tells nginx to perform **load balancing** on incoming
requests on port 80 for the domain `big.example.com`. With the [`upstream`
directive][nginx-upstream], it defines a cluster of 4 servers among which to
distribute the load.

```nginx
# Cluster of applications or servers to handle requests.
upstream big_server_com {
  server 127.0.0.1:8000 weight=5; # local application
  server 127.0.0.1:8001 weight=5; # local application
  server 10.192.67.3:8000; # separate server
  server 10.192.56.12:8001; # separate server
}

server {
  listen 80;
  server_name big.example.com;

  # Proxy requests to the cluster.
  location / {
    proxy_pass http://big_server_com;
  }
}
```

{% note type: more %}

By default, nginx uses a [weighted round robin][weighted-round-robin] algorithm
to decide to which server each request is proxied. A `weight` parameter can be
specified to direct more requests to specific servers.

{% endnote %}

## Appendix: what the application sees

For the application behind it, nginx is a client like any other. Every request
the application receives comes from nginx, over a connection nginx opened. With
the [reverse proxy configuration](#reverse-proxy-configuration) above:

- The address of the client is `127.0.0.1`, nginx's own, not the address of the
  browser.
- The `Host` header is `127.0.0.1:3000`, the address of `proxy_pass`, not the
  name the browser was asked for.
- Nothing says whether the browser used HTTP or HTTPS.

An application that needs the original values, to record the address of its
visitors or to build links with its own name, must be told them. The
[`proxy_set_header`][nginx-proxy-set-header] directive adds or replaces a header
of the requests nginx forwards. Ubuntu's nginx package comes with a file that
sets the usual ones, `/etc/nginx/proxy_params`:

```nginx
proxy_set_header Host $host$is_request_port$request_port;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

- `Host` passes on the name the browser asked for.
- `X-Real-IP` and `X-Forwarded-For` give the address of the client. The latter
  is a list, which each proxy along the way adds to.
- `X-Forwarded-Proto` says whether the browser used `http` or `https`.

Include it in the `location` that proxies requests:

```nginx
location / {
  include proxy_params;
  proxy_pass http://127.0.0.1:3000;
}
```

The application still has to read these headers, and should only trust them
when the request comes from the proxy: any client can send an `X-Forwarded-For`
header of its own. Web frameworks usually have a setting for this, often called
"trust proxy".

## References

- [Proxy server][proxy]
  - [Tunneling proxy][tunneling-proxy]
  - [Open proxy][open-proxy]
  - [Reverse proxy][reverse-proxy]
    - [Load balancing][load-balancing]
    - [Scalability][scalability]
- [Nginx Documentation][nginx-docs]
  - [Nginx Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
  - [How nginx processes a request][nginx-request-processing]
- [Digital Ocean][digital-ocean]
  - [Understanding the Nginx Configuration File Structure and Configuration Contexts](https://www.digitalocean.com/community/tutorials/understanding-the-nginx-configuration-file-structure-and-configuration-contexts)

[digital-ocean]: https://www.digitalocean.com/
[load-balancing]: https://en.wikipedia.org/wiki/Load_balancing_(computing)
[nginx-directive-index]: https://nginx.org/en/docs/http/ngx_http_index_module.html#index
[nginx-directive-listen]: https://nginx.org/en/docs/http/ngx_http_core_module.html#listen
[nginx-directive-location]: https://nginx.org/en/docs/http/ngx_http_core_module.html#location
[nginx-directive-proxy-pass]: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass
[nginx-directive-root]: https://nginx.org/en/docs/http/ngx_http_core_module.html#root
[nginx-directives]: https://nginx.org/en/docs/dirindex.html
[nginx-docs]: https://nginx.org/en/docs/
[nginx-include]: https://nginx.org/en/docs/ngx_core_module.html#include
[nginx-proxy-set-header]: https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_set_header
[nginx-request-processing]: https://nginx.org/en/docs/http/request_processing.html
[nginx-server-names]: https://nginx.org/en/docs/http/server_names.html
[nginx-signals]: https://nginx.org/en/docs/control.html
[nginx-upstream]: https://nginx.org/en/docs/http/ngx_http_upstream_module.html
[open-proxy]: https://en.wikipedia.org/wiki/Open_proxy
[proxy]: https://en.wikipedia.org/wiki/Proxy_server
[reverse-proxy]: https://en.wikipedia.org/wiki/Reverse_proxy
[scalability]: https://en.wikipedia.org/wiki/Scalability
[tunneling-proxy]: https://en.wikipedia.org/wiki/Tunneling_protocol
[weighted-round-robin]: https://en.wikipedia.org/wiki/Weighted_round_robin
