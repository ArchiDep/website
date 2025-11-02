---
title: Domain Name Configuration
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to set up a real domain name for your application.

<!-- more -->

## :exclamation: Requirements

Make sure you have completed the [previous exercise]({% link
_course/506-systemd-deployment/exercise.md %}).

## :exclamation: Find your subdomain

In this exercise, you will configure actual subdomains in the worldwide DNS
system to point to your server.

You must use the subdomain that has been assigned to you for this course. If you
are logged in, you can copy the **Hostname** from your cloud server's details
card on this page, or from the [dashboard](/app).

## :exclamation: Configure a DNS zone with Gandi.net

- Connect to [Gandi.net](https://gandi.net) with the user account provided to
  you by the teacher.
- Go under the "Domain" tab in the left menu and select the correct domain
  depending on your assigned subdomain.
- Go under the "DNS Records" tab in the domain's top menu.
- Add two new `A` records to map subdomains to **your server's public IP
  address**:
  1. Assuming your personal subdomain for the course is `jde.archidep.ch`,
     you should use `jde` as the **name of the DNS record**.
  2. Then, create a wildcard subdomain using `*.jde` as the **name of the
     DNS record**, and the same IP address. This will direct any second-level
     subdomain like `foo.jde.archidep.ch` to your server.

Assuming your server's IP address is `W.X.Y.Z` and your username is `jde`,
you should have the following DNS records (among others) in the domain's zone
file:

```
*.jde 1800 IN A W.X.Y.Z
jde 1800 IN A W.X.Y.Z
```

## :exclamation: Access the domain name

Once you have configured it correctly, you (and everybody else) should be able
to access the todolist application at http://jde.archidep.ch:3000 in
your browser (if you have completed the previous exercises).

{% note type: tip %}

You might have to wait a few minutes for the change to take effect.
especially if you make a mistake in configuring the DNS record and then fix
it. This is because DNS records are cached for a time (the TTL you
configured), by all intermediaries and also by your machine.

{% endnote %}

## :checkered_flag: What have I done?

You have created a mapping in the [domain name system][dns] between your custom
subdomain (e.g. `jde.archidep1.ch`) and the IP address of your server.

You have done this by modifying the [DNS zone file][dns-zone-file] for the
course's domain. When a computer requests to know the IP address for your
subdomain, the [DNS name servers][dns-name-server] of the domain provider
(gandi.net) will give them the IP address in the mapping you have configured.

This allows your applications and websites to be accessible through a
human-friendly domain name instead of an IP address.

### :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise. The only thing that has changed
compared to [the previous exercise]({% link
_course/506-systemd-deployment/exercise.md %}#architecture) is that you are now
using a domain name instead of an IP address to reach your application.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="PHP Todolist Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="PHP Todolist Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

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
created `jde.archidep1.ch`, you can create `jde2.archidep1.ch`. This new entry
will work immediately. The old one you fixed will work eventually once the cache
has cleared.

{% endnote %}

[dns]: https://en.wikipedia.org/wiki/Domain_Name_System
[dns-name-server]: https://en.wikipedia.org/wiki/Name_server
[dns-zone-file]: https://en.wikipedia.org/wiki/Zone_file
[systemd]: https://en.wikipedia.org/wiki/Systemd
