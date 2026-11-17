# Tutor notes: 508 Domain name configuration

## Starting point

- 506 Manage a web application with systemd as a Process Manager: Guess It runs
  as the `guessit` systemd service, listening on port 3000, and is reached at
  `http://W.X.Y.Z:3000`, the server's public IP address.
- 404 Run your own virtual server on Microsoft Azure: ports 80, 443, 3000 and
  3001 open in the Azure network security group.
- 507 Domain Name System (DNS): zones, records, names relative to the zone, the
  wildcard, and the TTL.
- 406 Unix Networking: the server's public address against the private one
  `ip address` shows.

The exercise is done in a browser, in the Gandi.net account the teacher
provides. Its domain is the course's, such as `archidep2.ch`, and every student
of the class adds records to the same zone. The student's hostname, such as
`jde.archidep2.ch`, is on their cloud server's details card on the page and on
the dashboard; the page's examples use `jde`.

## Learning objectives

Giving the server a name with two `A` records, `jde` and `*.jde`, in a zone the
student does not own but may add records to, and seeing that the name changes
nothing else: the browser connects to the same address and the same port. The
page's "What have I done?" states what the student should understand
afterwards, including that the DNS does not solve the port problem.

The student does not buy a domain, does not write a zone file by hand, and does
not touch the server. Not in the exercise: other record types, IPv6 records,
configuring how the server or the computer resolves names, and `nslookup`.

The architecture diagram is 506's with one step added: the browser looks up the
name before it connects.

## Where it leads

Every later exercise on the student's server reaches it by name. In particular:

- "Deploy a static site with nginx" puts the clock at `clock.jde.archidepN.ch`,
  with no new record thanks to the `*.jde` wildcard.
- "Deploy a web application with nginx as a reverse proxy" puts Guess It at
  `guessit.jde.archidepN.ch`, which removes the `:3000` this exercise leaves in
  the address.
- "Horizontally scale a web application with nginx as a load balancer" uses
  `brewscale.jde.archidepN.ch`.
- "Provision an SSL certificate using Certbot by Let's Encrypt" gets
  certificates for the names of the student's sites, which must resolve to the
  server.

## Key steps

- **"Find your subdomain"**.
  Question before: "In `jde.archidep2.ch`, which part is the zone's domain, and
  which part is the name of your record?"
- **"Configure a DNS zone with Gandi.net"**.
  Question before: "Which of your server's addresses goes in the record: the one
  `ip address` prints on the server, or the one you connect to with SSH? Why?"
  (The public one. The private one is not reachable from the Internet.)
  Question before: "Why two records, and not only `*.jde`?" (A wildcard does
  not map the name it is under.)
  Expected after: Gandi.net's "Advanced View" shows `jde 300 IN A W.X.Y.Z` and
  `*.jde 300 IN A W.X.Y.Z` among the other students' records.
  Question after: "Why a TTL of 300 rather than Gandi.net's default?"
- **"Access the domain name"**.
  Question before: "Will `http://jde.archidep2.ch`, without `:3000`, show Guess
  It? Why?" (No. The DNS gives an address, not a port; the browser connects to
  port 80, where nothing listens yet.)
  Expected after: Guess It's home page with its leaderboard at
  `http://jde.archidep2.ch:3000`.
- **"Optional: check the DNS resolution yourself"**.
  Expected: `dig` prints the server's public IP address in its answer section,
  after a number of at most 300; `ping -c 1` prints it on its first line;
  `foo.jde.archidep2.ch` gives the same address.
  Question after: "Why is the number before `IN` sometimes less than 300?" (The
  answer came from a cache, where it has already spent part of its TTL.)

## Common pitfalls

- **The name does not resolve at all, while the record is in the zone**: the
  record's name is the full `jde.archidep2.ch`, which Gandi.net reads as
  `jde.archidep2.ch.archidep2.ch`. Hint: in the zone file, what full name does
  a record named `jde` stand for? Hint: compare your lines with the other
  students' in the "Advanced View".
- **The name resolves, but the browser waits and then gives up**: the record has
  the server's private address, such as `10.0.0.4`, which `dig` shows. Hint:
  which address do you type in `ssh`? Hint: is the address `dig` prints in one
  of the private ranges of 406?
- **The name resolves to the right address, but the browser cannot connect**:
  the address has no `:3000`, or Guess It is not running. Hint: which port does
  a browser use when the address has none? Hint: what does
  `sudo systemctl status guessit` print on the server?
- **The browser shows a security error, or an address starting with
  `https://`**: some browsers try HTTPS first for a name, and nothing listens on
  port 443 yet. Hint: what does the address bar show, exactly?
- **`foo.jde.archidep2.ch` works but `jde.archidep2.ch` does not, or the other
  way round**: one of the two records is missing. Hint: which of your two
  records maps each of those names?
- **A classmate's name stops working**: a student changed or deleted a record
  that was not theirs, since the whole class shares the zone. Hint: whose
  username is in the name of the record you changed?
