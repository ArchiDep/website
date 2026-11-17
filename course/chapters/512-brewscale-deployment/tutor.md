# Tutor notes: 512 Horizontally scale a web application with nginx as a load balancer

## Starting point

- 511 Deploy a web application with nginx as a reverse proxy: nginx in front of
  Guess It with `proxy_pass`, and the `502 Bad Gateway` error when nothing
  listens at its address.
- 510 Deploy a static site with nginx: a site's configuration in
  `sites-available`, its link in `sites-enabled`, `nginx -t` and the reload.
- 509 Reverse Proxying: the load balancing example, with its `upstream` block,
  and vertical against horizontal scaling.
- 508 Domain name configuration: the `*.jde` wildcard, so
  `brewscale.jde.archidepN.ch` needs no new record.
- 506 Manage a web application with systemd as a Process Manager: a unit file,
  a dedicated system user, and a directory opened to its group with `chown` and
  `chmod 750`.
- 503 Unix Environment Variables, and 504 Configure a web application through
  environment variables: configuration in environment variables.
- 501 Deploy a web application with Git: a deployment directory in `/srv`, owned
  by the student.
- 411 How a computer works: processes taking turns on a core, and the "Two
  queues, one coffee machine" slides on concurrency and parallelism.
- 406 Unix Networking: the loopback address `127.0.0.1`.
- 205 Guess It: Docker Desktop on the student's computer, which was optional
  there and is needed here to run Locust.

Most of the exercise is done on the server over SSH; the load tests are run from
the student's computer, in a second terminal, with Locust's web interface at
`http://localhost:8089`. The page's examples use the user `jde` and the hostname
`jde.archidepN.ch`. Guess It, PostgreSQL, nginx and the clock still run on the
server.

## Learning objectives

Deploying Brewscale, a Java application in which each instance, a barista,
serves one request at a time and takes a second for each order; measuring with
Locust that under load the wait is the queue, not the brewing; then scaling it
horizontally to three instances started from one systemd unit template and
grouped in a target, with nginx balancing the requests among them through an
`upstream` block. It is also the first deployment of the course with a build
step: Maven compiles the code into a jar on the server. The page's "What have I
done?" states what the student should understand afterwards, including why
scaling works here and when it would not.

The exercise gives every file in full; the student does not write any
configuration of their own. Not in it: what a container or an image is (only the
`docker run` options used are explained), writing a locustfile, Python (Locust
is written in it; the course does not teach it), Maven beyond `mvn package`, JVM
options beyond `-Xmx`, load-balancing methods other than taking the servers in
turn, `weight`, health checks, sticky sessions, and balancing among several
servers, which the page only mentions. The "Not the solution to all your
problems" callout is optional reading.

## Where it leads

Little of the course relies on this exercise directly; its concepts of
horizontal scaling and load balancing come back when the course runs
applications in containers. In particular:

- "Deploy a PHP application with Docker Compose" scales an application to three
  containers with one command, and contrasts it with this exercise's unit
  template and `upstream` block.

## Key steps

- **"Meet Brewscale"**. The class's café at `https://brewscale.archidep.ch` has
  three baristas; reloading shows different barista numbers and colours.
- **"Requirements"**. Expected: `java -version` prints version 25; `mvn
-version` prints Maven 3.9 and Java 25.
- **"Build the application"**.
  Question before: "Guess It ran with `node` straight from the repository. Why
  can't Brewscale run straight from its repository?" (Java must be compiled
  first.)
  Expected after: `Tests run: 95, Failures: 0`, `Building jar:
/srv/brewscale/target/brewscale.jar` and `BUILD SUCCESS`, after a long first
  build.
- **"Create a dedicated user"**.
  Expected after: `drwxr-x--- … jde brewscale … /srv/brewscale`.
  Question after: "Which permission does the `brewscale` user need on the jar,
  and why does it not need more?" (Read; it only runs it.)
- **"Run a barista with systemd"**.
  Question before: "Why can't Brewscale keep its default port, 3000?" (Guess It
  listens on it.)
  Question after: "Why is it safe to put this configuration in the unit file,
  which every user can read, unlike Guess It's?" (There is no secret in it.)
  Expected after: `active (running)`, then `The barista listening on
127.0.0.1:4200, brewing in 1s` in the last lines.
- **"Serve the café through nginx"**: the steps of 511.
  Expected: `syntax is ok` and `test is successful`.
- **"Order a coffee"**.
  Expected: the drink after about a second; `journalctl -u brewscale -n 1`
  prints `The barista brewed … in 1.00…s`.
- **"Run Locust with Docker Desktop"**.
  Question after: "Which computer is `localhost` in `http://localhost:8089`, and
  where does Locust listen?" (The student's own, forwarded to the container.)
  Expected: `docker ps` lists the `locust` container with
  `127.0.0.1:8089->8089/tcp`; `docker logs locust` shows `Starting web
interface`.
- **"Send one customer, then two"**.
  Expected: about 0.5 requests per second with one user, and about 1 with two,
  with a response time of about a second.
  Question before two users: "How many requests per second do you expect with
  two customers?" (About 1.)
- **"Send ten customers"**.
  Question before: "With ten customers and one barista, what will happen to the
  requests per second, and to the response time?" (They stay at about 1 per
  second; the response time grows.)
  Expected after: about 1 request per second, and an average response time of
  about 9 seconds.
- **"Join the queue"**. The page asks why the student waited so much longer than
  the brewing, and explains it right after.
  Expected: about ten seconds to load the form, as long again for the drink, and
  a message such as "Brewed in 1.0s … You waited 9.8s".
  Question after: "Why did you wait twice?" (The page itself is a request in
  the queue.)
- **"What to do?"**. The page asks how to make the queue move faster, and
  answers it.
  Question after: "A barista brewing uses no CPU. Why does that matter for
  running three on one server?" (The processor runs another barista in the
  meantime.)
- **"Hire more baristas"**.
  Question before visiting the café once the service is stopped: "What will
  nginx answer?" (`502 Bad Gateway`.)
- **"Turn the unit file into a template"**.
  Question after: "Which port will barista 2 listen on? And barista 12?" (4202;
  42012, since `%i` is replaced as text.)
- **"Group the baristas in a target"**.
  Expected after: the target `active`; `brewscale@1` `active (running)` and
  `static`, with `Barista 1 listening on 127.0.0.1:4201`.
  Question after: "What does the café show now, before you change nginx, and
  why?" (`502 Bad Gateway`: nginx still forwards to port 4200.)
- **"Put the barista behind an nginx upstream"**.
  Expected: the café in another colour, served by barista 1.
- **"Load test a single barista again"**.
  Question before: "Do you expect different numbers from the first test?" (No,
  there is still one barista.)
- **"Hire two more baristas"**.
  Expected: three barista statuses listening on 4201, 4202 and 4203;
  `ps -f -u brewscale` shows three `java` processes as `brewsca+`, with a PPID
  of 1.
  Question after: "Why do the Locust charts not change yet?" (nginx does not
  know the new baristas.)
- **"Configure nginx to balance the load among the baristas"**.
  Question before: "How many requests per second do you expect now?" (About 3.)
  Expected after: about 3 requests per second, a 50th percentile of about a
  second and a 95th of several seconds; reloads show different baristas, not in
  order.
  Question after: "Why do some customers still wait several seconds?" (Barista
  1's old queue; a "more" note explains it.)
- **"Not the solution to all your problems"**. Optional.
  Question after: "If every drink had to be ground on the café's only grinder,
  would three baristas help?" (No, they would queue at the grinder.)
- **"Stop Locust"**. Expected: `docker stop locust` prints `locust`, and
  `docker ps` no longer lists it.

## Common pitfalls

- **`mvn package` was run with `sudo`**: the build works, but `target` belongs
  to `root`, and the next build as the student fails. Hint: who owns
  `/srv/brewscale/target`, according to `ls -ld`? Hint: why does the page give
  you the directory first?
- **`systemctl start brewscale@.service` says the unit name is missing the
  instance name**: a template is never started itself, only its instances or
  the target. Hint: which unit does the page start?
- **Only barista 1 runs after editing `brewscale.target`, and `systemctl` warns
  that a unit file changed on disk**: `daemon-reload` was skipped, so systemd
  still has the target that requires one barista. Hint: what does systemd know
  of a file you changed, until you tell it to reload?
- **`nginx -t` says `"upstream" directive is not allowed here`**: the
  `upstream` block is inside the `server` block. Hint: in the page's file, what
  is the `upstream` block inside of?
- **`docker run` says the name `/locust` is already in use, or that port 8089 is
  already allocated**: Locust is already running from an earlier `docker run`.
  Hint: what does `docker ps` list?
- **`docker ps` does not list `locust` right after `docker run`**: the container
  stopped at once, and `--rm` removed it, often because the command was run
  outside the clone, where there is no `locustfile.py`. Hint: in which directory
  did you run `docker run`, and what does `ls` show there?
- **Every Locust request fails, in the Failures tab**: the Host is not the
  café's name over plain HTTP, for example `https://…`, the server's IP address,
  or `http://localhost:4200`. Hint: which computer is `localhost` for Locust,
  which runs on yours? Hint: which name did you type in your browser to see the
  café?
- **The student wants to run more users, or many baristas, to see what
  happens**: the page warns that too many users can bring the server down or be
  taken for a DoS attack by Azure, and each barista takes memory beside Guess
  It, PostgreSQL and nginx.
