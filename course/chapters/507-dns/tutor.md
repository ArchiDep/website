# Tutor notes: 507 Domain Name System (DNS)

## Scope

The subject page and the slides hold different parts, with little overlap.

The slides hold the DNS as a tree: the root, written as a single dot; top-level
domains such as `ch`, `com` and `org`, which ICANN delegates to organizations
that run them; second-level domains, delegated to whoever bought them; and
third-level domains created by that manager. A name is read from right to left,
and the rest of a name is always its parent. A side note gives the fee to apply
for a generic top-level domain of one's own.

The slides then show a zone as the part of the tree delegated to one manager,
and a zone file: one resource record per line, with its five fields, names
relative to the zone's domain, and `@` for the domain itself. Their last slide
maps names to addresses with `@`, `jde` and the wildcard `*.jde`, and explains
why both `jde` and `*.jde` are needed.

The subject page holds the fields of a record, a table of seven record types
(`A`, `AAAA`, `CNAME`, `MX`, `NS`, `SOA`, `TXT`), two example records read field
by field, and how a name is resolved: the computer asks a resolver, which asks a
root name server, then the name servers of the top-level domain, then the
authoritative name servers of the zone, with every answer cached for its TTL. It
ends with buying a domain at Gandi.net.

## Left out

Taught later:

- Telling several sites on one IP address apart by the name in the `Host` header
  (name-based virtual hosting): "Reverse Proxying".
- Certificates issued for domain names, wildcard certificates, and DNS
  validation as proof of control of a zone: "TLS/SSL Certificates".

Not in the course: running a DNS server (BIND or any other), `/etc/hosts`,
reverse DNS and `PTR` records, DNSSEC, glue records, the difference between a
registry and a registrar, the record types of the table beyond their one-line
description, the `SOA` fields, how resolvers are chosen or configured on a
machine, and DNS over HTTPS.

## Key concepts and vocabulary

- **Domain Name System (DNS)**: the hierarchical, decentralized system that
  translates names into IP addresses, among other things.
- **Root**, **top-level domain (TLD)**, **second-level domain**, **third-level
  domain**: the levels of the tree, read from right to left in a name.
- **Delegation**: each manager hands responsibility for part of the tree under
  it to another manager. ICANN manages the root.
- **DNS zone**: the part of the tree one manager is responsible for.
- **Zone file**: the text file describing a zone, one **resource record** per
  line.
- **Record fields**: name, TTL, class, type, data. Names are relative to the
  zone's domain; `@` is the domain itself. `IN` (Internet) is the only class the
  course meets.
- **`A` record**: maps a name to an IPv4 address. The other types are named, and
  only `A` is used in the exercises.
- **Wildcard**: `*.jde` maps every name under `jde` that has no record of its
  own, but not `jde` itself.
- **TTL** (time to live): how many seconds an answer may be kept in a cache.
- **DNS resolver**: the server a computer asks, usually run by the Internet
  provider or the organization of the network, which finds the answer.
- **Authoritative name servers**: the ones that answer for a zone from its zone
  file. `NS` records in the parent zone name them.

## Misconceptions

- **Misconception:** a DNS record can send a name to a port, or the port is part
  of a domain name.
  **Correction:** an `A` record maps a name to an IPv4 address, and nothing
  else. The port stays in the address the browser is given.
  Question that reveals it: "Your record points `jde` to your server. Which port
  does the browser connect to at `http://jde.archidep2.ch`?"
- **Misconception:** a changed record "propagates" across the Internet, pushed
  from server to server.
  **Correction:** nothing is pushed. Caches keep the old answer until its TTL
  runs out, then ask again. A name nobody has looked up yet is in no cache and
  works at once.
  Question that reveals it: "You fixed a wrong record a minute ago. Why does a
  new name work straight away when the fixed one does not?"
- **Misconception:** the TTL is how long the record exists.
  **Correction:** it is how long an answer may be cached. The record stays in
  the zone file until its manager removes it.
- **Misconception:** `*.jde` also covers `jde`.
  **Correction:** a wildcard maps only the names under it. `jde` needs a record
  of its own.
- **Misconception:** a name is read from left to right, or two names that
  start alike, such as `www.microsoft.com` and `www.heig-vd.ch`, are related.
  **Correction:** a name is read from right to left. Its parent is the rest of
  the name after the first label.
- **Misconception:** the name of a record must be the full domain name.
  **Correction:** names in a zone file are relative to the zone's domain: `jde`
  in the zone of `example.com` is `jde.example.com`.
- **Misconception:** the browser asks the zone's own name servers directly, or
  every lookup goes all the way up to the root.
  **Correction:** the computer asks a resolver, which walks down the tree only
  for what it has not cached. The resolver and the computer both cache answers.
- **Misconception:** buying a domain name gives you a server, or a website.
  **Correction:** it gives you the right to manage a zone. Its records point
  wherever its manager wants, for example to a server rented elsewhere.

## Used in

From "Domain name configuration" on, every exercise run on the student's server
reaches it by name rather than by IP address. In particular:

- "Domain name configuration" adds the `jde` and `*.jde` `A` records of the
  student's hostname to the course's zone at Gandi.net, with a TTL of 300
  seconds, and checks them with `dig` or `ping`.
- "Reverse Proxying" explains that all the names of the sites on one server
  have the same IP address, so the name in the `Host` header is the only thing
  that tells them apart.
- "Deploy a static site with nginx", "Deploy a web application with nginx as a
  reverse proxy" and "Horizontally scale a web application with nginx as a load
  balancer" give each site a name under the student's hostname, such as
  `clock.jde.archidepN.ch`, with no new record thanks to the wildcard.
- "TLS/SSL Certificates" names domains in certificates, including wildcard
  certificates, and shows DNS validation as proof of control of a zone file.
