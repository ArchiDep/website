---
title: Make TCP connections
cloud_server: details
---

This exercise guides you through establishing a raw TCP connection between two
servers and manually sending an HTTP request to a web server, illustrating how
network protocols work in practice.

## :exclamation: Establish a bi-directional TCP connection

{% callout type: exercise %}

You need to find a partner for this part of the exercise, since the goal is to
establish a TCP connection between two of the servers you have set up for the
course.

Let's call you and your partner **Bob** and **Alice**.

Alice will need to know the public IP address of Bob's server. We will refer to
it as `W.X.Y.Z`.

{% endcallout %}

### :exclamation: **Bob:** listen for TCP clients

Bob should run the `nc` command on his server to listen for TCP connections on
port 3000:

```bash
$> nc -l 3000
```

{% note type: more %}

At this point, `nc` will start **l**istening on port 3000 and take over the
console, waiting for a TCP client to connect.

{% endnote %}

### :exclamation: **Alice:** connect to Bob's server

Alice should run the `nc` command on her server to connect to TCP port 3000 on
Bob's server:

```bash
$> nc W.X.Y.Z 3000
```

{% note type: more %}

Here, `nc` is acting as a client, connecting to the listening `nc` process on
Bob's server.

{% endnote %}

### :exclamation: **Bob** and **Alice**: communicate!

{% cols %}

Bob should type "Hello" and press `Enter` to send this text:

```bash
$> nc -l 3000
Hello
```

<!-- col -->

It should be immediately displayed in Alice's terminal:

```bash
$> nc W.X.Y.Z 3000
Hello
```

{% endcols %}

Similarly, if Alice types "World" after that and presses `Enter`, it should
immediately appear in Bob's terminal:

{% cols %}

```bash
$> nc W.X.Y.Z 3000
Hello
World
```

<!-- col -->

```bash
$> nc -l 3000
Hello
World
```

{% endcols %}

You have a two-way raw TCP connection running.

Once you're done, you can close the connection with `Ctrl-C`.

## :exclamation: Talk ~~dirty~~ HTTP to Google

{% callout type: exercise %}

You can do the rest of this exercise individually.

{% endcallout %}

Let's do something that your browser does every day: an HTTP request.

Find out Google's IP address (`O.P.Q.R` in this example) using the [`ping`
command][ping]:

```bash
$> ping -c 1 google.com
PING google.com (O.P.Q.R) 56(84) bytes of data.
64 bytes from google.com (O.P.Q.R): icmp_seq=1 ttl=53 time=0.890 ms
...
```

Open a TCP connection to the Google IP address you found:

```bash
$> nc O.P.Q.R 80
```

Now, talk to this Google server, but not in English or French, in the [HTTP
protocol][http]. Type **exactly** the following text:

```bash
GET / HTTP/1.1
Host: www.google.com
```

Then press `Enter` twice and you should receive the HTML for Google's home page.

{% note type: tip %}

Be sure to type **exactly** the text above. Your request must be a valid HTTP
request or Google's server will not be able to interpret it correctly. If you
have made a mistake, exit with `Ctrl-C`, re-run the same `nc` command and try
again.

{% endnote %}

Once you're done, you can close the connection with `Ctrl-C`.

If you open your browser, visit `http://www.google.com` and display the source
code of the page, you should see the same result.

{% note type: more %}

By sending this text over the TCP connection, you are communicating in the HTTP
protocol, a text protocol: you are sending an HTTP request to retrieve (`GET`)
the resource at path `/` of host `www.google.com` (the landing page of the
Google website), using version `1.1` of the HTTP protocol.

{% endnote %}

## :checkered_flag: What have I done?

Like the pioneers of the 1970s who developed TCP/IP, you connected two machines
across the Internet and exchanged a few (hopefully nice) words. Then you did by
hand what your browser does every time you open a page: you asked a web server
for it.

A TCP connection always starts the same way: one process **listens** on a port
and waits, and another **connects** to an address and that port. The one that
connects is the client, the one that listens is the server. Bob's `nc` was the
server and Alice's the client, yet both of you could type: once the connection
is open, it carries data in both directions.

To reach Bob's `nc`, three things had to be right. Alice needed the **public**
address of Bob's server, the one you connect to with SSH, and not the private
one that `ip address` prints on the server itself. Azure's firewall had to let
port 3000 through, which is why you opened it when you created your server. And
a process had to be listening on that port: an open port with nothing behind it
is refused.

Talking to Google showed the layers working together, each relying on the one
below it:

- **IP** (layer 3) brought your packets to an address. That is why you first
  turned the name `google.com` into an address with `ping`.
- **TCP** (layer 4) gave you a connection to port 80 at that address, exactly
  like the one between Bob and Alice. `nc` does not know what a web server is.
- **HTTP** (layer 7) is what the browser and the web server say to each other
  over that connection. Google answered because what you typed was a valid
  request.

Your request had two lines. The first asked to `GET` the page at path `/`. The
second, `Host`, named the site you wanted, although you had connected to an
address: one address can serve many sites, so the request has to say which. The
empty line after them, your second `Enter`, told the server that the request
was complete. Its response had the same shape: a status line, headers, an empty
line, then the page itself.

You could type the request because the version you used, HTTP/1.1, is text over
TCP. Newer versions keep the same requests and responses but send them
differently: HTTP/2 encodes them in binary, and HTTP/3 does not use TCP at all.
Your browser uses them when the server supports them. The course uses HTTP/1.1
because you can read it, and what a request means has not changed.

Later in the course, your own application will listen on a port of your server
and your browser will connect to it, as Alice did to Bob. And when a single
server hosts several sites, the `Host` line is what decides which one answers.

### :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow during this exercise:

{% include diagrams/407-tcp.html %}

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: `400 Bad Request`

If you get a `400 Bad Request` response, it means that your HTTP request is
invalid. You probably did not type exactly the text above.

### :boom: I don't get a response

If you don’t get a response, it may be because you took too long to type the
text, and the request has timed out. Try again a little faster.

[http]: https://en.wikipedia.org/wiki/HTTP
[nc]: https://en.wikipedia.org/wiki/Netcat
[ping]: https://en.wikipedia.org/wiki/Ping_(networking_utility)
