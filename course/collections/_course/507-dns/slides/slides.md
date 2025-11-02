---
title: Domain Name System (DNS)
---

# Domain Name System (DNS)

Architecture & Deployment <!-- .element: class="subtitle" -->

**Notes:**

Learn the basics of the [Domain Name System (DNS)][dns] and configure a domain name for your server with [Gandi.net][gandi].

**You will need**

- A server with a public IP address
- A Gandi account that is the administrator or technical contact for a domain

**Recommended reading**

- [Unix Networking](../unix-networking/)

---

## What is the Domain Name System?

![Domain Name System](images/dns.gif)

---

### Domain name system

![Domain Name System](images/dns.jpg)

**Notes:**

The [**Domain Name System (DNS)**][dns] is a hierarchical decentralized naming
system for computers connected to the Internet or a private network. Most
prominently, it **translates human-readable domain names** (like `google.com`)
**to numerical IP addresses** (like `40.127.1.70`) needed for locating computers
with the underlying network protocols. The Domain Name System has been an
essential component of the functionality of the Internet since 1985.

---

### DNS hierarchy

<p class='center'><img class='w80' src='images/dns-hierarchy.png' /></p>

[ICANN][icann] manages [top-level domains (TLDs)][tld].

**Notes:**

Second-level domains are delegated to other organizations.

You can buy your own [generic top-level domain][gtld] since 2012 for $185,000.

---

### DNS zone

![DNS Zone](./images/dns-zone.png)

**Notes:**

A [DNS zone][dns-zone] is a subset of the domain name space for which
administrative responsibility has been delegated to a single manager.

For example, Microsoft has purchased the rights to manage the `microsoft.com`
domain and all its subdomains from the manager of the `.com` [top-level domain
(TLD)][tld]. Once they have those rights, they can create any number of
subdomains for their business needs.

You can also purchase a domain name as an individual, giving you the right to
manage that portion of the DNS hierarchy.

[dns]: https://en.wikipedia.org/wiki/Domain_Name_System
[dns-zone]: https://en.wikipedia.org/wiki/DNS_zone
[gandi]: https://www.gandi.net/
[gtld]: https://en.wikipedia.org/wiki/Generic_top-level_domain
[icann]: https://en.wikipedia.org/wiki/ICANN
[tld]: https://en.wikipedia.org/wiki/Top-level_domain
