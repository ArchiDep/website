---
title: Domain name configuration
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to set up a real domain name for your application.

{% callout type: exercise %}

You only need your favorite browser for this exercise, as long as you have
completed the previous exercises and Guess It is running on your server.

{% endcallout %}

<!-- more -->

## :exclamation: Requirements

Make sure you have completed the [previous exercise]({% link
chapters/506-systemd-deployment/exercise.md %}).

## :exclamation: Find your subdomain

In this exercise, you will configure actual subdomains in the worldwide DNS
system to point to your server.

You must use the subdomain that has been assigned to you for this course: the
**Hostname** shown on your cloud server's details card, on this page if you are
logged in, or on the [dashboard](/app). Make a note of it. For example, if your
hostname is `jde.archidep2.ch`:

- `archidep2.ch` is the domain you will select in Gandi.net.
- `jde` is the name you will give to your DNS records.

## :exclamation: Configure a DNS zone with Gandi.net

- Connect to [Gandi.net](https://gandi.net) with the user account provided to
  you by the teacher.
- Go under the "Domain" tab in the left menu and select the domain of the
  hostname you noted above.
- Go under the "DNS Records" tab in the domain's top menu.
- Add two new `A` records to map subdomains to **your server's public IP
  address**:
  1. Assuming your personal subdomain for the course is `jde.archidep2.ch`, use
     `jde` as the **name of the DNS record**.
  2. Then, create a wildcard subdomain using `*.jde` as the **name of the DNS
     record**, and the same IP address. This will direct any second-level
     subdomain like `foo.jde.archidep2.ch` to your server.

Assuming your server's IP address is `W.X.Y.Z` and your username is `jde`,
the domain's zone file must now contain the following DNS records (among
others):

```
*.jde 1800 IN A W.X.Y.Z
jde 1800 IN A W.X.Y.Z
```

## :exclamation: Access the domain name

Once you have configured it correctly, you (and everybody else) can reach Guess
It at `http://jde.archidep2.ch:3000` in a browser, instead of
`http://W.X.Y.Z:3000`. It is the same application, still listening on port 3000:
only the name in the address has changed.

{% note type: tip %}

You might have to wait a few minutes for the change to take effect, especially
if you make a mistake in configuring the DNS record and then fix it. This is
because DNS records are cached for a time (the TTL you configured), by all
intermediaries and also by your machine.

{% endnote %}

### :question: Optional: check the DNS resolution yourself

You can ask the DNS for the IP address of your domain name yourself, without a
browser. The `dig` command asks a DNS server and prints its answer:

```bash
$> dig jde.archidep2.ch
...
;; ANSWER SECTION:
jde.archidep2.ch.       1800    IN      A       W.X.Y.Z
...
```

The answer section must contain your server's public IP address. It is the
record you added in Gandi.net, in the same format as in the zone file above. The
number after the name is how many seconds the answer may still be cached: 1800
at most, the TTL of your record, and less if it was already in a cache.

A name under your wildcard record, such as `foo.jde.archidep2.ch`, must give the
same address.

{% note type: tip %}

If your shell says `dig: command not found`, run it on your server, over SSH.

{% endnote %}

You can also use `ping`, as you did to find Google's IP address in [Make TCP
connections][tcp-ping]. It prints the address the name resolves to on its first
line:

```bash
$> ping -c 1 jde.archidep2.ch
PING jde.archidep2.ch (W.X.Y.Z) 56(84) bytes of data.
```

What follows does not matter here. If your server does not answer `ping`, `ping`
reports `100% packet loss` after a few seconds: the name still resolved to your
server's address, which is what you are checking.

Finally, an online tool such as [Google's Dig][google-dig] asks the DNS from
Google's servers rather than from your machine. Its answer does not depend on
what your machine has cached, which is useful after you have fixed a mistake in
a record.

## :checkered_flag: What have I done?

You have created a mapping in the [domain name system][dns] between your custom
subdomain (e.g. `jde.archidep2.ch`) and the IP address of your server.

You have done this by modifying the [DNS zone file][dns-zone-file] for the
course's domain. When a computer requests to know the IP address for your
subdomain, the [DNS name servers][dns-name-server] of the domain provider
(gandi.net) will give them the IP address in the mapping you have configured.

This allows your applications and websites to be accessible through a
human-friendly domain name instead of an IP address.

### :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise. The only thing that has changed
compared to [the previous exercise][systemd-architecture] is that you are now
using a domain name instead of an IP address to reach your application. Step
through the diagram to see what happens when a browser requests the home page.

{% include diagrams/508-dns.html %}

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: I used the wrong IP address and then fixed it, but it doesn't work

DNS records are cached for a time (the TTL you configured). Your machine has
this cache, and all intermediary DNS servers also have it. When you change an
existing DNS entry that you have already consulted in your browser, you have to
wait for the TTL to expire on your machine and all intermediaries before the
changes take effect.

{% note type: tip %}

In the meantime, you can simply create a new DNS entry. For example, if you
created `jde.archidep2.ch`, you can create `jde2.archidep2.ch`. This new entry
will work immediately. The old one you fixed will work eventually once the cache
has cleared.

{% endnote %}

[dns]: https://en.wikipedia.org/wiki/Domain_Name_System
[dns-name-server]: https://en.wikipedia.org/wiki/Name_server
[dns-zone-file]: https://en.wikipedia.org/wiki/Zone_file
[google-dig]: https://toolbox.googleapps.com/apps/dig/

[tcp-ping]: {% link chapters/407-tcp/exercise.md %}#talk-dirty-http-to-google

[systemd-architecture]: {% link chapters/506-systemd-deployment/exercise.md %}#architecture
