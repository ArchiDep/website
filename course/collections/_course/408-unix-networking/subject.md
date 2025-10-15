---
title: Unix Networking
excerpt_separator: <!-- more -->
---

Learn the basics of Unix networking and how to make TCP connections.

**You will need**

- A Unix CLI
- An Ubuntu server with a public IP address to connect to

**Recommended reading**

- [Unix Basics & Administration]({% link _course/404-unix-basics/subject.md %})
- [Unix Processes]({% link _course/406-unix-processes/subject.md %})

<!-- more -->

## Useful commands

Useful commands for unix networking

### The `ip` command

The [**`ip`** command][ip-command] is used to manipulate and display IP network
information:

```bash
$> ip address
1: `lo`: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue ...
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet `127.0.0.1`/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 `::1`/128 scope host
       valid_lft forever preferred_lft forever
2: `eth0`: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 ...
    link/ether 06:5f:44:85:36:92 brd ff:ff:ff:ff:ff:ff
    inet `172.31.39.219`/20 brd 172.31.47.255 scope global dynamic eth0
       valid_lft 2665sec preferred_lft 2665sec
    inet6 `fe80::45f:44ff:fe85:3692`/64 scope link
       valid_lft forever preferred_lft forever
```

In this sample output, there are **two network interfaces**:

- The [virtual **lo**opback interface][loopback] (`lo`) through which
  applications can communicate on the computer itself without actually hitting
  the network
- A physical **Eth**ernet interface (`eth0`) which has the private IP address
  `172.31.39.219` (i.e. the computer's address in its local network)

### The `ping` command

The [`ping` command][ping] tests the reachability of a host on an IP network. It
measures the **r**ound-**t**rip **t**ime (`rtt`) for messages sent to a computer
and echoed back. The name comes from [active sonar][ping-sonar] terminology that
sends a pulse of sound and listens for the echo to detect objects under water.

It uses the [**I**nternet **C**ontrol **M**essage **P**rotocol (ICMP)][icmp], a
**network layer** protocol (OSI layer 3).

```bash
$> ping -c 1 google.com
PING `google.com` (`172.217.21.238`) 56(84) bytes of data.
64 bytes from 172.217.21.238: icmp_seq=1 ttl=53 time=`1.12 ms`

--- google.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.125/1.125/1.125/0.000 ms
```

In this example, you can see that the domain name `google.com` was translated to the public IP address `172.217.21.238` by the Domain Name System,
and that the round-trip to that computer took about 1.12 milliseconds.

{% note type: tip %}

The `-c 1` (or **c**ount) option tells ping to send only one ping. Remove it to
keep pinging once per second.

{% endnote %}

### The `ss` command

The [**s**ocket **s**tatistics (`ss`) command][ss] (or the older `netstat` command) displays information about the open [**network sockets**][socket] on the computer.

A **socket** is the software representation of a network communication's
endpoint. For a TCP connection in an IP network, it corresponds to a connection
made on an IP address and port number.

```bash
$> ss -tlpn
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       80          127.0.0.1:3306       0.0.0.0:*     mysqld...
LISTEN  0       128     127.0.0.53%lo:53         0.0.0.0:*     systemd-resolve...
LISTEN  0       128           0.0.0.0:22         0.0.0.0:*     sshd...
LISTEN  0       128              [::]:22            [::]:*     sshd...
```

The above command lists the processes listening for TCP connections. In this
example, we can see that there is a MySQL database listening on port 3306, a DNS
resolver on port 53, and an SSH server on port 22.

{% note type: more %}

On some systems, you may need to add the `-e` (**e**xtended) option to display
process information. You can remove the `-n` (or `--numeric`) option to see
service names (e.g. `ssh` instead of `22`). The other options are `-t` for
**T**CP, `-l` to only display listening sockets, and `-p` to show the
**p**rocesses.

{% endnote %}

### The `nc` command

The [**n**et**c**at (`nc`) command][nc] can read from and write to network
connections using TCP or UDP.

```bash
$> nc -zv -w 2 google.com 80
Connection to google.com 80 port [tcp/http] succeeded!
$> nc -zv -w 2 google.com 81
nc: connect to google.com port 81 (tcp) timed out: Operation now in progress
nc: connect to google.com port 81 (tcp) failed: Network is unreachable
$> nc -zv -w 2 google.com 443
Connection to google.com 443 port [tcp/http] succeeded!
```

For example, the above two commands check whether ports 80, 81 and 443 are open
on the computer reached by resolving the domain name `google.com`.

{% note type: more %}

The `-z` (**z**ero bytes) option tells netcat to close the connection as soon as
it opens, the `-v` option enables more **v**erbose output, and the `-w 2` tels
netcat to **w**ait at most 2 seconds before giving up.

{% endnote %}

## References

- [Internet Protocol][ip]
  - [IP address](https://en.wikipedia.org/wiki/IP_address)
    - [IPv4][ipv4] & [IPv6][ipv6]
    - [Subnetworks][subnet]
    - [Network Address Translation (NAT)][nat]
  - [Ports][port]
    - [List of TCP and UDP port numbers][registered-ports]
- [Ops School Curriculum](http://www.opsschool.org)
  - [Networking 101](http://www.opsschool.org/networking_101.html)
  - [Networking 202](http://www.opsschool.org/networking_201.html)
- [Unix Networking Basics for the Beginner](https://www.networkworld.com/article/2693416/unix-networking-basics-for-the-beginner.html)
- [Unix Top Networking Commands and What They Tell You](https://www.networkworld.com/article/2697039/unix-top-networking-commands-and-what-they-tell-you.html)
- [What happens when you type google.com into your browser and press enter?](https://github.com/alex/what-happens-when)

[0000]: https://en.wikipedia.org/wiki/0.0.0.0
[arpanet]: https://en.wikipedia.org/wiki/ARPANET
[cidr]: https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing
[curl]: https://curl.haxx.se
[dns]: https://en.wikipedia.org/wiki/Domain_Name_System
[ephemeral-ports]: https://en.wikipedia.org/wiki/Ephemeral_port
[ftp]: https://en.wikipedia.org/wiki/File_Transfer_Protocol
[gateway]: https://en.wikipedia.org/wiki/Gateway_(telecommunications)
[godaddy]: https://www.godaddy.com
[gtld]: https://en.wikipedia.org/wiki/Generic_top-level_domain
[hex]: https://en.wikipedia.org/wiki/Hexadecimal
[http]: https://en.wikipedia.org/wiki/HTTP
[http-200]: https://httpstatuses.com/200
[http-301]: https://httpstatuses.com/301
[http-content-type]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
[http-headers]: https://en.wikipedia.org/wiki/List_of_HTTP_header_fields
[http-methods]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
[http-req]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages#HTTP_Requests
[http-res]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Messages#HTTP_Responses
[https]: https://en.wikipedia.org/wiki/HTTPS
[iana]: https://www.iana.org
[iana-ipv4]: https://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.xhtml
[iana-ipv6]: https://www.iana.org/assignments/ipv6-address-space/ipv6-address-space.xhtml
[iana-ports]: https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml
[icann]: https://en.wikipedia.org/wiki/ICANN
[icmp]: https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol
[infomaniak]: https://www.infomaniak.com
[internet-standard]: https://en.wikipedia.org/wiki/Internet_Standard
[iot]: https://en.wikipedia.org/wiki/Internet_of_things
[ip]: https://en.wikipedia.org/wiki/Internet_Protocol
[ip-command]: https://man7.org/linux/man-pages/man8/ip.8.html
[ipv4]: https://en.wikipedia.org/wiki/IPv4
[ipv6]: https://en.wikipedia.org/wiki/IPv6
[isp]: https://en.wikipedia.org/wiki/Internet_service_provider
[loopback]: https://en.wikipedia.org/wiki/Loopback#Virtual_loopback_interface
[mongodb]: https://www.mongodb.com
[mtr]: https://en.wikipedia.org/wiki/MTR_(software)
[multiplexing]: https://en.wikipedia.org/wiki/Multiplexing
[mysql]: https://www.mysql.com
[nat]: https://en.wikipedia.org/wiki/Network_address_translation
[nc]: https://en.wikipedia.org/wiki/Netcat
[osi]: https://en.wikipedia.org/wiki/OSI_model
[ping]: https://en.wikipedia.org/wiki/Ping_(networking_utility)
[ping-sonar]: https://en.wikipedia.org/wiki/Sonar#Active_sonar
[port]: https://en.wikipedia.org/wiki/Port_(computer_networking)
[postgresql]: https://www.postgresql.org
[proxy]: https://en.wikipedia.org/wiki/Proxy_server
[registered-ports]: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
[registrar]: https://en.wikipedia.org/wiki/Domain_name_registrar
[reserved-ip-addresses]: https://en.wikipedia.org/wiki/Reserved_IP_addresses
[rir]: https://en.wikipedia.org/wiki/Regional_Internet_registry
[socket]: https://en.wikipedia.org/wiki/Network_socket
[ss]: http://man7.org/linux/man-pages/man8/ss.8.html
[ssh]: https://en.wikipedia.org/wiki/Secure_Shell
[smtp]: https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol
[subnet]: https://en.wikipedia.org/wiki/Subnetwork
[tcp]: https://en.wikipedia.org/wiki/Transmission_Control_Protocol
[tcp-ip]: https://en.wikipedia.org/wiki/Internet_protocol_suite
[tld]: https://en.wikipedia.org/wiki/Top-level_domain
[traceroute]: https://en.wikipedia.org/wiki/Traceroute
[udp]: https://en.wikipedia.org/wiki/User_Datagram_Protocol
