# Tutor notes: 406 Unix Networking

## Scope

The slides hold the concepts; the subject page holds only the commands.

The slides open with where the Internet comes from: the first internetworked
TCP connection in 1977, ARPANET, and the OSI and TCP/IP models as two ways of
describing the same layers.

They then cover IP addresses: IPv4 and IPv6 as numbers written in decimal and
hexadecimal, which calls back the reminder of bases in 402; the network prefix
and the host identifier; how addresses are handed out worldwide by IANA and the
regional registries, and divided locally into subnets; netmasks and CIDR
notation as two ways of writing a prefix; the three private ranges; loopback
and `localhost`; `0.0.0.0` as "all addresses"; and NAT, which hides a private
network behind one public address.

The last part is about ports: what a port is, TCP and UDP as the transport
protocols that use them, how many connections can share one address, the
registered ports students meet, and the well-known ports that only `root` may
listen on.

The subject page shows four commands with sample output: `ip address`, `ping`,
`ss -tlpn` and `nc`, with what their options stand for in "more" callouts.

The sample outputs on the subject page come from another cloud provider. The
private address of a student's Azure server is not the page's `172.31.39.219`,
and its `ss -tlpn` shows neither MySQL nor any database at this point.

## Left out

Taught later:

- Domain names, which `ping` resolves on the subject page: "Domain Name System
  (DNS)" and "Domain name configuration".
- Serving several applications behind ports 80 and 443 with one program:
  "Reverse Proxying".
- HTTPS and what happens on port 443: "TLS/SSL Certificates".
- Subnets of containers, and port mappings: "Docker Isolation".

Not in the course: routing and routing tables, subnet arithmetic beyond reading
a prefix length, the layers below IP (Ethernet, MAC addresses, the `link/ether`
line of `ip address`), how TCP works inside (handshake, sequence numbers,
retransmission), UDP beyond its name, HTTP/2 and HTTP/3, IPv6 address
shortening, firewalls on the server itself (`ufw`, `iptables`), and how Azure
implements the translation between the public and private address of a server.
The only firewall in the course is the Azure network security group configured
in 404.

## Key concepts and vocabulary

- **IP address**: the address of a machine on an IP network. **IPv4** is 32
  bits, written as four numbers from 0 to 255 (**dotted decimal**). **IPv6** is
  128 bits, written as eight groups of four hexadecimal digits. Both are one
  number written in a base humans can read, as in 402.
- **Network prefix** and **host identifier**: the first bits of an address name
  the network, the rest the machine in it. **CIDR** notation writes the length
  of the prefix: `172.16.254.1/16` has a 16-bit prefix, `172.16`. A
  **netmask** says the same as 32 bits, ones for the prefix then zeros:
  `255.255.0.0` is `/16`.
- **Subnet**: a smaller network inside a larger one, for structure or security.
- **Public address**: reachable from the Internet. **Private address**: in one
  of three reserved ranges, `10.0.0.0/8`, `172.16.0.0/12` and
  `192.168.0.0/16`, reused in every private network and not reachable from the
  Internet directly.
- **NAT** (network address translation): a router translates between private
  addresses and a public one. The Internet sees the router's public address.
  This is why the student's server shows a private address in `ip address`
  while they connect to a public one (the last question of 405).
- **Network interface**: `lo`, the **loopback** interface, and `eth0`, the
  Ethernet interface with the machine's address in its local network.
- **Loopback**: `127.0.0.1` (`::1` in IPv6), named **`localhost`**: always the
  machine the program runs on, without using the network hardware. The whole
  `127.0.0.0/8` range is reserved for it.
- **`0.0.0.0`** (`::` in IPv6): not an address to connect to. As the address a
  program listens on, it means all the addresses of the machine.
- **Port**: a number from 0 to 65,535 that, together with an IP address and a
  transport protocol (**TCP** or **UDP**), names one endpoint of
  communication. One machine, one address, many ports.
- **Socket**: the endpoint of one connection as a program holds it: an address
  and a port.
- **Listen** and **connect**: a server process listens on a port; a client
  connects to that address and port. One process listens on a given port and
  address at a time.
- **Well-known ports**, 0 to 1023: only `root` may listen on them. The ports
  students meet: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5432 (PostgreSQL), and 3000
  and 3001, which the course's applications use before they sit behind nginx,
  since they need no `root`.
- **Layers**: IP (layer 3) carries packets from one address to another; TCP
  (layer 4) carries a connection between two ports; HTTP (layer 7) is what a
  browser and a web server say to each other. A layer serves the one above.
- **HTTP versions**: the course uses HTTP/1.1, in which a request is text sent
  over a TCP connection, which is why 407 can type one by hand. HTTP/2 sends
  the same requests and responses encoded in binary, still over TCP. HTTP/3
  runs over QUIC, on UDP. The meaning of requests and responses (methods,
  paths, headers, status codes) is the same in every version; the course shows
  HTTP/1.1 over TCP as the simplest case of it.
- **Commands**: `ip address` lists interfaces and their addresses; `ping` tests
  whether a host answers and measures the round-trip time, with **ICMP**, a
  layer 3 protocol with no port; `ss -tlpn` lists the TCP ports processes
  listen on; `nc` opens a TCP connection, listens for one (`-l`), or checks
  whether a port is open (`-zv`).

## Misconceptions

- **Misconception:** the server knows the public address the student connects
  to, so `ip address` should show it.
  **Correction:** on Azure the server has only a private address. The public
  address belongs to Azure's network, which translates it to the private one
  (NAT).
  Question that reveals it: "Which address would your server print, and which
  one would a classmate use to reach it?"
- **Misconception:** `localhost` or `127.0.0.1` means the server.
  **Correction:** it means the machine where the program using it runs. In the
  student's browser, `http://localhost:3000` is their own computer; on the
  server, it is the server.
  Question that reveals it: "You type `localhost:3000` in your browser. Which
  machine receives the request?"
- **Misconception:** a process listening on `127.0.0.1` can be reached from
  outside, or `0.0.0.0` is an address one can connect to.
  **Correction:** listening on `127.0.0.1` accepts only programs on the same
  machine. Listening on `0.0.0.0` accepts connections on every address of the
  machine, including the one reachable from outside.
  Question that reveals it: "In `ss -tlpn`, a database listens on
  `127.0.0.1:5432`. Can a classmate's server connect to it?"
- **Misconception:** opening a port in the Azure security group starts
  something on that port, or a process listening on a port is reachable
  whatever the firewall says.
  **Correction:** both are needed. The firewall only lets traffic through; a
  process still has to listen on the port.
- **Misconception:** if `ping` gets no answer, the machine is down; if it
  answers, a website on it works.
  **Correction:** `ping` uses ICMP, which has no ports. A machine may ignore
  pings and still accept TCP connections, or answer pings with nothing
  listening on port 80. `nc -zv` tests a port.
- **Misconception:** `/16` means 16 addresses.
  **Correction:** it means a 16-bit network prefix, leaving 16 bits for hosts:
  65,536 addresses.
- **Misconception:** a private address is unique worldwide, like a public one.
  **Correction:** the same private ranges are reused in every private network.
  Two machines in different private networks may have the same private
  address.
- **Misconception:** HTTP and TCP are the same thing, or HTTP is something
  only a browser can produce.
  **Correction:** HTTP is a protocol of its own, carried by a transport
  protocol. In HTTP/1.1, the version the course uses, a request is text over a
  TCP connection, and 407 has the student type one by hand.
- **Misconception:** every HTTP request is text sent over TCP, as in 407.
  **Correction:** that is HTTP/1.1. HTTP/2 encodes its messages in binary, and
  HTTP/3 does not use TCP. Browsers use the newer versions when the server
  supports them.
- **Misconception:** a port is something physical, or a whole machine has a
  single port.
  **Correction:** a port is a number in the address of a connection's
  endpoint. A machine has 65,536 TCP ports per address, and many connections
  can be open at once.

## Used in

Every exercise from here on runs network services on the student's server and
has to get addresses and ports right. Parts that exercises lean on in
particular:

- "Make TCP connections" connects two servers with `nc` on port 3000, then
  types an HTTP request to Google on port 80.
- "Deploy a web application with SFTP" runs the application on port 3000 of all
  addresses, reached in the browser at the server's public address, and
  PostgreSQL on port 5432 of `127.0.0.1` only, checked with `ss -tln`.
- "Deploy a PHP application with Git", "Configure a PHP application through
  environment variables" and "Manage a PHP application with systemd as a
  Process Manager" run `php -S 0.0.0.0:3000`, reached at the server's public
  address and port 3000.
- "Domain Name System (DNS)" and "Domain name configuration" give the public
  address a name.
- "Reverse Proxying" and the nginx deployments put nginx on port 80 in front of
  an application on `127.0.0.1`, and use `ss -tlpn` to see who listens where.
  "Deploy a PHP website with nginx and the FastCGI process manager" restricts
  PHP-FPM to `127.0.0.1`.
- "TLS/SSL Certificates" and "Provision an SSL certificate using Certbot by
  Let's Encrypt" add port 443.
- "Docker Isolation" shows containers' networks as subnets, in CIDR notation
  with the netmask beside it, and ports mapped from `0.0.0.0` of the host into
  a container.
