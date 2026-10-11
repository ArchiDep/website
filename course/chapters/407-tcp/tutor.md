# Tutor notes: 407 Make TCP connections

## Starting point

- 404 Run your own virtual server on Microsoft Azure, finished: the student
  logs in to their server over SSH, and its security group allows port 3000
  (the "Port3000" rule). The first part needs a partner whose server is in the
  same state.
- 406 Unix Networking: public and private addresses, ports, listening and
  connecting, `ping` and `nc`, and the layers IP, TCP and HTTP.
- 405 Meet your server ended on why `ip address` shows a private address rather
  than the public one; 406 answers it with NAT. The address Alice needs is the
  public one.

The page shows the student's own server details, including its public address.
Bob's address `W.X.Y.Z` is the one Bob uses to log in over SSH, which Bob gives
to Alice.

## Learning objectives

A TCP connection made by hand: one process listens on a port, another connects
to it, and once connected both can send. Then the same thing with a web server
on the other end, where the text sent has to be HTTP: in HTTP/1.1, the version
the course uses, a request is plain text carried by TCP to an IP address. 406's
notes say how the newer versions differ. The page's "What have I done?" states
what the student should understand afterwards.

Both `nc` processes hold their terminal until `Ctrl-C`, used here as a recipe;
"Process Management on Linux" explains it. The "Architecture" section steps
through a diagram of the two `nc` processes and the connection between them.

Not in the exercise: how TCP works inside (handshake, packets,
acknowledgements), HTTPS (TLS cannot be typed by hand, which is why the request
goes to port 80), HTTP beyond the two lines of the request (methods, status
codes and headers in general), and UDP.

## Where it leads

The exercise is short and nothing later depends on what it leaves on the
server. What it shows is used throughout the deployments:

- "Deploy a web application with SFTP" runs the application on port 3000 of the
  server. The student's browser connects to it as Alice's `nc` connected to
  Bob's, and sends an HTTP request like the one typed to Google.
- The `Host` line of the request comes back with nginx in "Reverse Proxying":
  `server_name` chooses which site answers by the name in that line, since one
  address may serve many sites (virtual hosting, seen in 401).
- "TLS/SSL Certificates" explains what changes on port 443.

## Key steps

- **"Bob: listen for TCP clients".**
  Question before: "Which of your addresses does Alice need: the one `ip
address` prints, or the one you connect to with SSH? Why?"
  Expected after: `nc -l 3000` prints nothing and holds the terminal.
  Question after: "What would `ss -tlpn` show on your server now, in another
  terminal?" (A `LISTEN` line on port 3000, for `nc`.)
- **"Alice: connect to Bob's server".**
  Question before: "What has to be true on Bob's server for this to work?" (A
  process listening on port 3000, and port 3000 allowed in Azure.)
  Expected after: no message on either side; Alice's terminal is held too.
  Question after: "Which of you is the client and which the server?"
- **"Bob and Alice: communicate!"**
  Expected: each line appears on the other side when Enter is pressed.
  Question after: "Alice opened the connection. Does that limit who can send?"
  (No: once open, a TCP connection carries data both ways.)
- **"Talk ~~dirty~~ HTTP to Google"**, the `ping` command.
  Question before: "Why find an address when you already know the name
  `google.com`?" (IP connects to addresses; the name is resolved first.)
  Expected after: the address on the first line of `ping`'s output. Students
  get different addresses: Google has many.
- **"Talk ~~dirty~~ HTTP to Google"**, the request.
  Question before: "How is this connection different from the one with your
  partner?" (At the TCP level it is not; the other end is a web server that
  expects HTTP.)
  Question before: "You connected to an address. Why does the request still
  name `www.google.com`?" (One address may serve many sites; `Host` says which.)
  Expected after the second Enter: a status line such as `HTTP/1.1 200 OK`,
  header lines, a blank line, then a long block of HTML and JavaScript.
  Question after: "Which part of what you did is HTTP, which TCP, which IP?"

## Common pitfalls

- **Alice's `nc` hangs, then may print `Connection timed out`**: the packets
  get no answer. Either the address is wrong (the private address from `ip
address`, or Alice's own), or Bob's security group does not allow port 3000.
  Hint: which address does Bob use to log in over SSH? Then: does Bob's
  security group have the rule for port 3000? The fix for a missing rule is in
  404's troubleshooting section, under "I forgot to open some (or all) of the
  ports in the firewall".
- **Alice's `nc` prints `Connection refused`** right away: Bob's server
  answered, but nothing listens on port 3000. Bob's `nc` has not started yet,
  has ended, or uses another port, or both students ran the same command.
  Question that leads to it: "What is the difference between no answer and a
  refusal?" (A refusal means the machine was reached.)
- **Bob's `nc -l 3000` prints `Address already in use`**: another process
  already listens on port 3000 of Bob's server, such as an `nc` left running in
  another SSH session. Hint: `ss -tlpn` shows which process holds the port.
- **Typed text does not appear on the other side**: the line is sent when Enter
  is pressed, not letter by letter. Expected.
- **`nc: command not found`, or Bob's `nc -l` gets no connection although
  everything looks right**: the commands ran on the student's own computer
  instead of the server. A laptop on a school or home network has a private
  address behind NAT, which a classmate's server cannot reach. Hint: what does
  `hostname` print?
- **No partner available**: two SSH sessions to the student's own server work,
  `nc -l 3000` in one and `nc 127.0.0.1 3000` in the other. The connection then
  never leaves the server, so neither the public address nor the Azure firewall
  is involved.
- **`ping` prints its first line, then no replies**: the address in parentheses
  on the first line is all the step needs; `Ctrl-C` stops `ping`.
- **Nothing comes back after the request**: the request ends with an empty
  line. Question that leads to it: "How does the server know that your request
  is complete?" (The page's troubleshooting covers a request typed too slowly.)
- **The answer ends but `nc` does not return to the prompt**: expected. The
  connection stays open after the response until Google closes it or the
  student presses `Ctrl-C`, as the page says.
- **The response looks like garbage**, with short hexadecimal numbers between
  blocks of text: it is Google's page, minified HTML and JavaScript, sent in
  pieces each preceded by its length. The status line and headers at the top
  are what matters.
