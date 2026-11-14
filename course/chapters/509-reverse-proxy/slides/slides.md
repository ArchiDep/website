---
title: Reverse Proxying
---

# Reverse Proxying

Architecture & Deployment <!-- .element: class="subtitle" -->

---

## What is a proxy?

<img class="w-10/12" src="./images/proxy.svg" alt="A client connects to a proxy, which connects to the server on the client's behalf" />

A [**proxy server**][proxy] is a computer or application that acts as an
**intermediary** for requests from clients seeking resources from other servers.

---

## Types of proxy servers

There are 3 main kinds:

- [**Tunneling proxy**][tunneling-proxy] or [**gateway**][gateway]
- [**Forward proxy**][open-proxy]
- [**Reverse proxy**][reverse-proxy]

---

## Tunneling proxy

<img class="w-10/12" src="./images/tunneling-proxy.svg" alt="An SSH connection from a client in network A passes through a tunneling proxy, unchanged, to a server in network B" />

A [tunneling proxy][tunneling-proxy] can pass **unmodified requests and
responses** from one network to another.

**Notes:**

It can also be used to encapsulate a protocol into another, such as running IPv6
over IPv4. For example, an SSH connection may be relayed by a proxy server to a
different target server. The proxy server simply passes the packets through,
with no ability to compromise the security of the communication.

[**Virtual private networks (VPN)**][vpn] use tunneling protocols, usually with
an additional layer of encryption.

---

## Forward proxy

<img class="w-10/12" src="./images/forward-proxy.svg" alt="Three clients of a private network connect to a forward proxy in the same network, which connects to servers on the Internet on their behalf" />

A **forward proxy** retrieves data from a server on behalf of a client. It is
said to be [**open**][open-proxy] if it is accessible by any Internet user.

**Notes:**

A forward proxy works for its clients. It sits on their side, often in their own
network, and they go through it to reach any server on the Internet.

---

### Anonymous forward proxy

<img class="w-10/12" src="./images/anonymous-proxy.svg" alt="A client connects to an anonymous proxy, which connects to the server; the server sees only the proxy" />

Conceals the identity of the client.

**Notes:**

An **anonymous forward proxy** reveals its identity as a server but conceals
that of the client. Since the target server does not know who the original
client is, it can be used to protect privacy. [VPNs][vpn] are often used in
combination with this type of proxy server.

---

### Transparent forward proxy

<img class="w-10/12" src="./images/transparent-proxy.svg" alt="In a school network, a client's requests go through a transparent proxy without the client having configured anything; the server sees both the proxy and the client" />

Intercepts the client's requests without the client having to configure
anything, and does not hide the client.

**Notes:**

A **transparent forward proxy** is transparent to its clients: they do not
configure it, and may not even know it is there. The network they are connected
to sends their requests through it. Schools and companies often use this kind of
proxy to cache websites, or to restrict access to particular websites (e.g.
Facebook).

It does not hide the clients: it usually tells the server who the original
client is, through HTTP headers.

The word is not used consistently. Some only mean a proxy that reveals the
original client, whether the client configured it or not.

When many clients go through the same forward proxy server, its IP address may
get banned, since the target server only sees one computer (the proxy) making
too many requests at the same time.

---

## Reverse proxy

<img class="w-10/12" src="./images/reverse-proxy.svg" alt="Three clients on the Internet connect to a reverse proxy in the servers' private network, which forwards their requests to the servers behind it" />

A [**reverse proxy**][reverse-proxy] is an **internal-facing proxy** used to
control and protect access to servers in a **private network**.

**Notes:**

A reverse proxy **appears to clients to be an ordinary server**, but actually
**transmits their requests to** one or more **other servers in an internal
private network** which handle the requests.

It is the mirror image of a forward proxy: it works for the servers, and sits
on their side.

---

### What the client sees

<img class="w-10/12" src="./images/reverse-proxy-client-view.svg" alt="A client connects to example.com, which is the reverse proxy; the web server behind it, in the internal network, is out of the client's sight" />

The client only sees the proxy server.

**Notes:**

The response from the private server is returned as if it was coming from the
proxy server itself, leaving the client with no knowledge of the structure of
the internal network.

---

### What the server sees

The server only sees the proxy.

**Notes:**

For the server behind it, the reverse proxy is a client like any other. Every
connection it receives comes from the proxy, not from the original client.

If the server needs to know who the original client is, for example to record
their IP address, the proxy has to tell it, by adding HTTP headers to the
requests it forwards. The [appendix of the subject][what-the-application-sees]
shows how.

---

## Why use a reverse proxy?

<!-- slide-front-matter class: center, middle -->

<img class='w50' src='images/proxy-word-cloud.jpg' />

---

### One port, one process

Only **one process** can listen on a given port.

**Notes:**

A port is a number the kernel uses to hand incoming data to the one process
listening on it. If two processes could listen on the same port, the kernel
would not know which of them to hand the data to. So it refuses to let a second
process listen on a port that is already taken.

When an address has no port, browsers connect to port 80 for HTTP, and 443 for
HTTPS. If an application listens on port 80 itself, no other application on the
same server can be reached without a port in its address.

---

### Sharing a port

<img class="w-10/12" src="./images/reverse-proxy-port.svg" alt="Two browsers ask for guessit.example.com and other.example.com; the reverse proxy, alone on port 80, forwards each request to the application listening on a port of its own, 3000 or 3001" />

The reverse proxy listens on port 80 **for every site**, and forwards each
request to the right application **by the name of the site**.

**Notes:**

A reverse proxy is one more process between the browser and the application,
with a connection on each side. It is the only process listening on port 80.
Each application listens on a port of its own, which nobody needs to type.

The DNS gives all the names of the sites on the server the same IP address, so
the name is the only thing that tells the sites apart. The browser sends it in
the `Host` header of every HTTP request, and the reverse proxy forwards the
request to the application configured for that name. This is called
[**name-based virtual hosting**][name-based-virtual-hosting].

---

### Hiding internal architecture

<img class="w-10/12" src="./images/reverse-proxy-hide-origin.svg" alt="A client reaches one reverse proxy at one public IP address, which forwards requests to three different servers of its private network" />

Reverse proxies can **hide the existence and characteristics of an internal
network's private servers**.

**Notes:**

Since the client only sees the proxy server, it is unaware of the complexity of
the internal architecture and does not have to worry about it.

In a scenario where you have only a single public IP address available, a
reverse proxy allows you to make multiple private servers accessible on that IP
address through the proxy server.

---

### Hiding multi-component websites

<img class="w-10/12" src="./images/reverse-proxy-cors.svg" alt="Without a reverse proxy, the browser talks to the frontend at www.example.com and to the backend at api.example.com, two origins; with a reverse proxy, the browser talks to example.com only, which forwards to both" />

**Notes:**

Modern websites can be complex applications, often with a **separate frontend
and backend** developed by different teams with different technologies. Putting
a reverse proxy in front can make it **appear as one single website** on a
single domain name, avoiding [CORS][cors] issues.

---

### SSL/TLS termination or authentication

<img class="w-10/12" src="./images/reverse-proxy-ssl.svg" alt="The browser talks HTTPS to the reverse proxy, which talks plain HTTP to the application in its private network" />

A reverse proxy can be the **secure endpoint** with all the SSL/TLS
certificates, then **forwarding unencrypted requests** to other servers in the
private network.

**Notes:**

Managing SSL/TLS certificates to provide websites over HTTPS is rather complex.
It can be hard to configure some frameworks or tools to ensure they are only
using secure communications.

Similarly, a reverse proxy could also require **authentication** before letting
a client access an insecure application, adding security without having to
modify the application itself.

---

### Scalability

<img class="w-10/12" src="./images/horizontal-vs-vertical-scaling.svg" alt="Vertical scaling makes one server bigger; horizontal scaling adds more servers of the same size" />

[Scalability][scalability] is the capability of a computer system to handle a
growing amount of work (e.g. client requests).

**Notes:**

There are [2 broad ways][horizontal-and-vertical-scaling] of adding more
resources for a particular application.

**Vertical scaling** consists in using a more powerful computer, with more CPU,
RAM, throughput, etc. The added power will allow the server to serve more
clients.

**Horizontal scaling** means adding more computers to handle the same work. For
example, 3 instances of a web application can probably handle 3 times as many
clients at the same time. Computers or applications can be combined in
[clusters][cluster] to improve performance.

---

#### Load balancing

<img class="w-10/12" src="./images/load-balancing.svg" alt="The requests of three clients reach one load balancer, which spreads them across three instances of the same application" />

A common function of reverse proxies is to perform [**load
balancing**][load-balancing], i.e. the distribution of workloads across multiple
servers to achieve **horizontal scaling**.

**Notes:**

As multiple clients arrive simultaneously, the reverse proxy will distribute
requests to different servers, spreading the load between them.

---

### Other uses

- [Web acceleration][web-acceleration]
- On-the-fly compression
- Spoon-feeding
- [Denial-of-service (DoS)][dos] protection
- [A/B testing][ab-testing]

**Notes:**

- [Web acceleration][web-acceleration] is the caching of static content and
  dynamic content to reduce load on internal servers.
- Optimize content by transparently compressing it to speed up loading times.
- _Spoon-feeding_ is a technique where the reverse proxy temporarily stores a
  dynamically generated page, then serves it to the client a little bit at a
  time. This avoids the internal server having to wait for slow clients such as
  mobile applications.
- And [more][reverse-proxy-uses]

---

## nginx

<!-- .element: class="hidden" -->

<img class='w-7/10' src='images/nginx.png' />

---

### What is nginx?

<img class='w-8/10' src='images/apache-vs-nginx.png' />

[nginx][nginx] is a competitor of the well-known [Apache HTTP server][apache],
first released in 2004 to solve the [C10k problem][c10k].

**Notes:**

[nginx][nginx] is an HTTP and reverse proxy server, and one of the most used
web servers in the world. It was developed to solve the [C10k problem][c10k],
i.e. the capability of a computer system to handle ten thousand concurrent
connections, thanks to its [event-driven architecture][nginx-performance]. It
also has [many other features][nginx-features] to serve modern web
applications.

---

### How nginx runs

<img class="w-10/12" src="./images/nginx-processes.svg" alt="A master process, running as root, holds port 80 and starts worker processes, running as www-data" />

A **master** process, started as `root`, opens the ports. **Worker** processes,
running as an unprivileged user, handle the requests.

**Notes:**

On Linux, only `root` may listen on a port below 1024, such as 80 or 443. An
application that listened on port 80 itself would have to run as `root`, and so
would anyone who found a vulnerability in it.

nginx starts as `root` only to open its ports. Its master process then starts
worker processes, usually one per processor core, which run as an unprivileged
user, `www-data` on Ubuntu, and handle all the requests. Each worker can handle
many connections at once. The applications behind nginx listen on ports above
1024, which any user may do, so each can run as a dedicated user of its own.

The master process also reacts to signals. When it receives the `HUP` signal, it
reads its configuration again, starts new workers with it, and lets the old ones
finish the requests they are handling. The configuration changes without nginx
ever stopping listening. If the new configuration has an error, nginx keeps the
old one.

---

#### Apache vs. nginx

<p class='center'><img class='w60' src='images/nginx-market-share.png' /></p>

**Notes:**

nginx is used by more websites than Apache, and by more high-traffic websites.
In November 2026, [W3Techs][w3techs-web-servers] found nginx on 30.0% of the
websites whose web server it knows, and Apache on 20.9%.

Cloudflare Server, used by even more websites (33.8%), is not a server you
install: it is Cloudflare's own network of reverse proxies, which many websites
put in front of their own servers.

[ab-testing]: https://en.wikipedia.org/wiki/A/B_testing
[apache]: https://httpd.apache.org/
[c10k]: https://en.wikipedia.org/wiki/C10k_problem
[cluster]: https://en.wikipedia.org/wiki/Computer_cluster
[cors]: https://en.wikipedia.org/wiki/Cross-origin_resource_sharing
[dos]: https://en.wikipedia.org/wiki/Denial-of-service_attack
[gateway]: https://en.wikipedia.org/wiki/Gateway_(telecommunications)
[horizontal-and-vertical-scaling]: https://en.wikipedia.org/wiki/Scalability#Horizontal_and_vertical_scaling
[load-balancing]: https://en.wikipedia.org/wiki/Load_balancing_(computing)
[name-based-virtual-hosting]: https://en.wikipedia.org/wiki/Virtual_hosting#Name-based
[nginx]: https://nginx.org/
[nginx-features]: https://nginx.org/en/#basic_http_features
[nginx-performance]: https://blog.nginx.org/blog/inside-nginx-how-we-designed-for-performance-scale
[open-proxy]: https://en.wikipedia.org/wiki/Open_proxy
[proxy]: https://en.wikipedia.org/wiki/Proxy_server
[reverse-proxy]: https://en.wikipedia.org/wiki/Reverse_proxy
[reverse-proxy-uses]: https://en.wikipedia.org/wiki/Reverse_proxy#Uses_of_reverse_proxies
[scalability]: https://en.wikipedia.org/wiki/Scalability
[tunneling-proxy]: https://en.wikipedia.org/wiki/Tunneling_protocol
[vpn]: https://en.wikipedia.org/wiki/Virtual_private_network
[w3techs-web-servers]: https://w3techs.com/technologies/overview/web_server
[web-acceleration]: https://en.wikipedia.org/wiki/Web_accelerator

[what-the-application-sees]: {% link chapters/509-reverse-proxy/subject.md %}#appendix-what-the-application-sees
