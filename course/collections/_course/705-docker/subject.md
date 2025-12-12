---
title: Docker
excerpt_separator: <!-- more -->
---

Learn how to containerize your web applications with Docker.

<!-- more -->

## A Docker primer

The following sections introduce the main Docker concepts by showing you how to
create and run containers based on images, commit changes to images, and manage
containers.

### Install Docker

You need to have Docker installed on your machine. To do so, install [Docker
Desktop][docker-desktop] and use the recommended settings.

### Make sure Docker is working

Run a `hello-world` container to make sure everything is installed correctly:

```bash
$> docker run hello-world

Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
198f93fd5094: Pull complete
95ce02e4a4f1: Download complete
Digest: sha256:d4aaab6242e0cace87e2ec17a2ed3d779d18fbfd03042ea58f2995626396a274
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

If your output is similar, it means Docker is working correctly on your machine.
Read the displayed message carefully, as it explains what just happened.

You can move on to the next section.

### Run a container from an image

There are many official and community images available on the [Docker
Hub][hub-explore]. For this tutorial, start by pulling the [official `ubuntu`
image][hub-ubuntu] from the hub:

```bash
$> docker pull ubuntu
Using default tag: latest
latest: Pulling from library/ubuntu
97dd3f0ce510: Pull complete
588d79ce2edd: Download complete
Digest: sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
Status: Downloaded newer image for ubuntu:latest
docker.io/library/ubuntu:latest
```

{% note type: more %}

The `ubuntu` image contains a headless [Ubuntu operating system][ubuntu] with
only minimal packages installed.

{% endnote %}

{% callout type: more, id: docker-container-os %}

Wait. I thought Docker containers did not contain an OS? In a typical Linux
distribution, you usually get:

- A **bootloader**, which loads a kernel
- The **kernel**, which manages the system and loads an init system
- An **init system**, which sets up and runs everything else
- **Everything else** (binaries, shared libraries, etc)

The **Docker Engine** replaces the kernel and init system, and the **container**
replaces "everything else".

The `ubuntu` Docker image contains the minimal set of Ubuntu binaries and shared
libraries, as well as the `apt` package manager. For instance, `systemd` is not
included.

{% endcallout %}

You can list available images with `docker images`:

```bash
$> docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE
hello-world:latest   d4aaab6242e0       22.5kB         10.2kB
ubuntu:latest        c35e29c94501        141MB         30.8MB
```

Run a **container** based on that image with `docker run <image> [command...]`.
The following command runs an Ubuntu container:

```bash
$> docker run ubuntu echo "hello from ubuntu"
hello from ubuntu
```

Running a container means **executing the specified command**, in this case
`echo "hello from ubuntu"`, **in an isolated container started from an image**,
in this case the Ubuntu image. The `echo` binary that is executed is the one
provided by the Ubuntu OS in the image, not your machine.

If you list running containers with `docker ps`, you will see that the container
we just ran is **not running**. A container **stops as soon as the process
started by its command is done**. Since `echo` is not a long-running command,
the container stopped right away:

```bash
$> docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

You can see the stopped container with `docker ps -a`, which lists all
containers regardless of their status:

```bash
$> docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED              STATUS                          PORTS     NAMES
cbcf66e72043   ubuntu        "echo 'hello from ub…"   23 seconds ago       Exited (0) 22 seconds ago                 compassionate_tu
5827fb3b9354   hello-world   "/hello"                 About a minute ago   Exited (0) About a minute ago             tender_diffie
```

You can remove a stopped container or containers with `docker rm`, using either
its ID or its name:

```bash
$> docker rm compassionate_tu 5827fb3b9354
compassionate_tu
5827fb3b9354

$> docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

You can also add the `--rm` option to `docker run` to run a container and
automatically remove it when it stops:

```bash
$> docker run --rm ubuntu echo "hello from ubuntu"
hello from ubuntu
```

No new container should appear in the list:

```bash
$> docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

### Container isolation

Docker containers provide many [security][docker-security] features. When you
start a container with `docker run`, you get:

- **Process isolation:** processes running within a container cannot see, and even less
  affect, processes running in another container, or in the host system.

  See the difference between running `ps -e` and `docker run --rm ubuntu ps -e`,
  which will show you all running processes on your machine, and the same as
  seen from within a container, respectively.

- **File system isolation:** a container has its own file system separate from
  your machine's. See the difference between running the following commands:
  - `ls -la /` and `docker run --rm ubuntu ls -la /`, which will show you all
    files at the root of your file system, and all files at the root of the
    container's file system, respectively.
  - `bash --version` and `docker run --rm ubuntu bash --version`, which will
    show you that the Bash shell on your machine is (probably) not the exact
    same version as the one in the image.
  - `uname -a` and `docker run --rm ubuntu uname -a`, which will show you your
    machine's operating system and the container's, respectively.

- **Network isolation:** a container doesn't get privileged access to the
  sockets or interfaces of another container. Of course, containers can interact
  with each other through their respective network interface, just like they can
  interact with external hosts. We will see examples of this later.

### Run multiple commands in a container

You can run commands more complicated than `echo`. For example, let's run a
[Bash shell][bash].

Since this is an interactive command, add the `-i` (interactive) and `-t`
(pseudo-TTY) options to `docker run`:

```bash
$> docker run -it ubuntu bash
root@e07f81d7941d:/#
```

This time you are running a Bash shell, which is a **long running comman**d. The
process running the shell will not stop until you manually type `exit` in the
shell, so the **container is not stopping** either.

You should have a new command line prompt (`root@e07f81d7941d:/#` in this
example), indicating that you are within the container:

```bash
root@e07f81d7941d:/#
```

You can now run any command you want within the running container:

```bash
root@e07f81d7941d:/# date
Fri Apr 20 13:20:32 UTC 2018
```

You can make changes to the container. Since this is an Ubuntu container, you
can install packages. Update of the package lists first with `apt update`:

```bash
root@e07f81d7941d:/# apt update
Get:1 http://archive.ubuntu.com/ubuntu xenial InRelease [247 kB]
...
Fetched 37.3 MB in 6s (6670 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
All packages are up to date.
```

Install the `fortune` package:

```bash
root@e07f81d7941d:/# apt install -y fortune
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Note, selecting 'fortune-mod' instead of 'fortune'
The following additional packages will be installed:
  fortunes-min librecode0
Suggested packages:
  fortunes x11-utils bsdmainutils
The following NEW packages will be installed:
  fortune-mod fortunes-min librecode0
0 upgraded, 3 newly installed, 0 to remove and 0 not upgraded.
Need to get 707 kB of archives.
After this operation, 2397 kB of additional disk space will be used.
Get:1 http://ports.ubuntu.com/ubuntu-ports noble/main arm64 librecode0 arm64 3.6-26 [621 kB]
...
Fetched 707 kB in 0s (1458 kB/s)
...
```

The [`fortune`][fortune] command prints a quotation/joke such as the ones found in fortune cookies
(hence the name):

```bash
root@e07f81d7941d:/# /usr/games/fortune
Your motives for doing whatever good deed you may have in mind will be
misinterpreted by somebody.
```

Let's create a **fortune clock script** that tells the time and a fortune every
5 seconds.

The `ubuntu` container image is very minimal, as most images are, and doesn't
provide any editor such as `nano` or `vim`. Install one now:

```bash
root@e07f81d7941d:/# apt install nano  # or vim
```

Open a new file `/usr/local/bin/clock.sh` with your favorite editor:

```bash
root@e07f81d7941d:/# nano /usr/local/bin/clock.sh
```

Paste the following script into the file:

```bash
#!/bin/bash
trap "exit" SIGKILL SIGTERM SIGHUP SIGINT EXIT
while true; do
  echo It is $(date)
  /usr/games/fortune
  echo
  sleep 5
done
```

Make the script executable:

```bash
root@e07f81d7941d:/# chmod +x /usr/local/bin/clock.sh
```

Make sure it works. Since the `/usr/local/bin` directory is in the PATH by
default on Linux, you can simply execute `clock.sh` without using its absolute
path:

```bash
root@e07f81d7941d:/# clock.sh
It is Mon Apr 23 08:47:37 UTC 2018
You have no real enemies.

It is Mon Apr 23 08:47:42 UTC 2018
Beware of a dark-haired man with a loud tie.

It is Mon Apr 23 08:47:47 UTC 2018
If you sow your wild oats, hope for a crop failure.
```

Use Ctrl-C to stop the clock script. Then use `exit` to stop the Bash shell:

```bash
root@e07f81d7941d:/# exit
```

Since the Bash process has exited, the container has stopped as well:

```bash
$> docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED         STATUS                      PORTS     NAMES
e07f81d7941d   ubuntu    "bash"    6 minutes ago   Exited (130) 1 second ago             sweet_euclid
```

### Commit a container's state to an image manually

Retrieve the name or ID of the previous container, in this example `sweet_euclid`.
You can **create a new image based on that container's state** with the `docker
commit <container> <repository:tag>` command:

```bash
$> docker commit sweet_euclid fortune-clock:1.0
sha256:407daed1a864b14a4ab071f274d3058591d2b94f061006e88b7fc821baf8232e
```

You can see the new image in the list of images:

```bash
$> docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE
fortune-clock:1.0    2e94440daea5        351MB         94.8MB
hello-world:latest   d4aaab6242e0       22.5kB         10.2kB
ubuntu:latest        c35e29c94501        141MB         30.8MB
```

That image contains the `/usr/local/bin/clock.sh` script we created, so we can run it directly with
`docker run <image> [command...]`:

```bash
$> docker run --rm fortune-clock:1.0 clock.sh
It is Mon Apr 23 08:55:54 UTC 2018
You will have good luck and overcome many hardships.

It is Mon Apr 23 08:55:59 UTC 2018
While you recently had your problems on the run, they've regrouped and
are making another attack.
```

Again, our `clock.sh` script is a long-running command (due to the `while`
loop). The container will keep running until the script is stopped. Use Ctrl-C
to stop it (the container will stop and be removed automatically thanks to the
`--rm` option).

That's nice, but let's create a fancier version of our clock. Run a new Bash
shell based on our `fortune-clock:1.0` image:

```bash
$> docker run -it fortune-clock:1.0 bash
root@4b38e523336c:/#
```

This new container is **based off of our `fortune-clock:1.0` image**, so it
already contains what we've done done so far, i.e. the `fortune` command is
already installed and the `clock.sh` script is where we put it:

```bash
root@4b38e523336c:/# /usr/games/fortune
You are working under a slight handicap.  You happen to be human.

root@4b38e523336c:/# cat /usr/local/bin/clock.sh
#!/bin/bash
trap "exit" SIGKILL SIGTERM SIGHUP SIGINT EXIT
while true; do
  echo It is $(date)
  /usr/games/fortune
  echo
  sleep 5
done
```

Install the `cowsay` package:

```bash
root@4b38e523336c:/# apt-get install -y cowsay
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libgdbm-compat4t64 libgdbm6t64 libperl5.38t64 libtext-charwidth-perl perl perl-modules-5.38
Suggested packages:
  filters cowsay-off gdbm-l10n perl-doc libterm-readline-gnu-perl | libterm-readline-perl-perl make libtap-harness-archive-perl
The following NEW packages will be installed:
  cowsay libgdbm-compat4t64 libgdbm6t64 libperl5.38t64 libtext-charwidth-perl perl perl-modules-5.38
0 upgraded, 7 newly installed, 0 to remove and 0 not upgraded.
Need to get 8193 kB of archives.
After this operation, 52.5 MB of additional disk space will be used.
Get:1 http://ports.ubuntu.com/ubuntu-ports noble-updates/main arm64 perl-modules-5.38 all 5.38.2-3.2ubuntu0.2 [3110 kB]
...
Fetched 8193 kB in 3s (3197 kB/s)
...
```

Edit the clock script with your favorite editor:

```bash
root@4b38e523336c:/# nano /usr/local/bin/clock.sh  # or vim
```

Modify the line calling `fortune` to pipe into the `cowsay` command:

```bash
/usr/games/fortune | /usr/games/cowsay
```

The final script should look like this:

```bash
#!/bin/bash
trap "exit" SIGKILL SIGTERM SIGHUP SIGINT EXIT
while true; do
  echo It is $(date)
  /usr/games/fortune | /usr/games/cowsay
  echo
  sleep 5
done
```

Test your improved clock script:

```bash
root@4b38e523336c:/# clock.sh
It is Mon Apr 23 09:02:21 UTC 2018
 ____________________________________
/ Look afar and see the end from the \
\ beginning.                         /
 ------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||

It is Mon Apr 23 09:02:26 UTC 2018
 _______________________________________
/ One of the most striking differences  \
| between a cat and a lie is that a cat |
| has only nine lives.                  |
|                                       |
| -- Mark Twain, "Pudd'nhead Wilson's   |
\ Calendar"                             /
 ---------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Much better. Exit Bash to stop the container:

```bash
root@4b38e523336c:/# exit
```

You should now have two stopped containers. The one in which we created the
original clock script, and the newest one we just stopped:

```bash
$> docker ps -a
CONTAINER ID   IMAGE               COMMAND   CREATED          STATUS                                PORTS     NAMES
4b38e523336c   fortune-clock:1.0   "bash"    3 minutes ago    Exited (130) Less than a second ago             peaceful_turing
e07f81d7941d   ubuntu              "bash"    12 minutes ago   Exited (130) 6 minutes ago                      sweet_euclid
```

Let's create an image from that latest container, in this case `peaceful_turing`:

```bash
$> docker commit peaceful_turing fortune-clock:2.0
sha256:92bfbc9e4c4c68a8427a9c00f26aadb6f7112b41db19a53d4b29d1d6f68de25f
```

As before, the image is available in the list of images:

```bash
$> docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE
fortune-clock:1.0    2e94440daea5        351MB         94.8MB
fortune-clock:2.0    bc673d466633        420MB          107MB
hello-world:latest   d4aaab6242e0       22.5kB         10.2kB
ubuntu:latest        c35e29c94501        141MB         30.8MB
```

You can run it:

```bash
$> docker run --rm fortune-clock:2.0 clock.sh
It is Mon Apr 23 09:06:21 UTC 2018
 ________________________________________
/ Living your life is a task so          \
| difficult, it has never been attempted |
\ before.                                /
 ----------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Use Ctrl-C to stop the script (and the container).

Your **previous image is still available** under the `1.0` tag. You can run it
again:

```bash
$> docker run --rm fortune-clock:1.0 clock.sh
It is Mon Apr 23 09:08:04 UTC 2018
You attempt things that you do not even plan because of your extreme stupidity.
```

Use Ctrl-C to stop the script (and the container).

### Run containers in the background

Until now we've only run a container command **in the foreground**, meaning that
Docker takes control of our console and forwards the script's output to it.

You can run a container command **in the background** by adding the `-d` or
`--detach` option. Let's also use the `--name` option to give it a specific name
instead of using the default randomly generated one:

```bash
$> docker run -d --name clock fortune-clock:2.0 clock.sh
06eb72c218051c77148a95268a2be45a57379c330ac75a7260c16f89040279e6
```

This time, the `docker run` command simply prints the ID of the container it has
launched, and exits immediately. But you can see that the container is indeed
running with `docker ps`, and that it has the correct name:

```bash
$> docker ps
CONTAINER ID   IMAGE               COMMAND      CREATED         STATUS         PORTS     NAMES
06eb72c21805   fortune-clock:2.0   "clock.sh"   6 seconds ago   Up 6 seconds             clock
```

### Access container logs

You can use the `docker logs <container>` command to see the **output of a
container running in the background**:

```bash
$> docker logs clock
It is Mon Apr 23 09:12:06 UTC 2018
 _____________________________________
< Excellent day to have a rotten day. >
 -------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
...
```

Add the `-f` option to keep following the log **output in real time**:

```bash
$> docker logs -f clock
It is Mon Apr 23 09:13:36 UTC 2018
 _________________________________________
/ I have never let my schooling interfere \
| with my education.                      |
|                                         |
\ -- Mark Twain                           /
 -----------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Use Ctrl-C to stop. Note that the container still keeps running in the
background. You simply stopped following the logs.

### Stop and restart containers

You may **stop a container running in the background** with the `docker stop`
command:

```bash
$> docker stop clock
clock
```

You can check that is has indeed stopped:

```bash
$> docker ps -a
CONTAINER ID   IMAGE               COMMAND      CREATED              STATUS                        PORTS     NAMES
06eb72c21805   fortune-clock:2.0   "clock.sh"   About a minute ago   Exited (137) 3 seconds ago              clock
4b38e523336c   fortune-clock:1.0   "bash"       7 minutes ago        Exited (130) 3 minutes ago              peaceful_turing
e07f81d7941d   ubuntu              "bash"       16 minutes ago       Exited (130) 10 minutes ago             sweet_euclid
```

You can **restart** it with the `docker start <container>` command. This will
**re-execute the command** that was originally given to `docker run <container>
[command...]`, in this case `clock.sh`:

```bash
$> docker start clock
clock
```

It's running again:

```bash
CONTAINER ID   IMAGE               COMMAND      CREATED         STATUS         PORTS     NAMES
06eb72c21805   fortune-clock:2.0   "clock.sh"   2 minutes ago   Up 3 seconds             clock
```

You can follow its logs again:

```bash
$> docker logs -f clock
It is Mon Apr 23 09:14:50 UTC 2018
 _________________________________
< So you're back... about time... >
 ---------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Stop following the logs with Ctrl-C.

You can **stop and remove** a container in one command by adding the `-f` or
`--force` option to `docker rm`. Beware that it will _not ask for confirmation_:

```bash
$> docker rm -f clock
clock
```

No containers should be running any more:

```bash
$> docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

### Run multiple containers

Since containers have isolated processes, networks and file systems, you can of course run more than
one at the same time:

```bash
$> docker run -d --name old-clock fortune-clock:1.0 clock.sh
25c9016ce01f93c3e073b568e256ae7f70223f6abd47bb6f4b31606e16a9c11e

$> docker run -d --name new-clock fortune-clock:2.0 clock.sh
4e367ffdda9829482734038d3eb71136d38320b6171dda31a5b287a66ee4b023
```

You can see that both are indeed running:

```bash
$> docker ps
CONTAINER ID   IMAGE               COMMAND      CREATED         STATUS         PORTS     NAMES
4e367ffdda98   fortune-clock:2.0   "clock.sh"   3 seconds ago   Up 3 seconds             new-clock
25c9016ce01f   fortune-clock:1.0   "clock.sh"   8 seconds ago   Up 8 seconds             old-clock
```

Each container is running based on the correct image, as you can see by their output:

```bash
$> docker logs old-clock
It is Mon Apr 23 09:39:18 UTC 2018
Too much is just enough.
                -- Mark Twain, on whiskey
...

$> docker logs new-clock
It is Mon Apr 23 09:40:36 UTC 2018
 ____________________________________
/ You have many friends and very few \
\ living enemies.                    /
 ------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
...
```

### Image layers

A Docker **image** is built up from a series of **layers**. Each layer contains
a set of differences from the layer before it:

![Docker: Image Layers](./images/layers.jpg)

You can list those layers by using the `docker inspect` command with an image
name or ID. Let's see what layers the `ubuntu` image has:

```bash
$> docker inspect ubuntu
...
  "RootFS": {
    "Type": "layers",
    "Layers": [
      "sha256:a8777d7885428f109ae6a59eec92d9aad13dd105afe5c44aadc1fcad90550610"
    ]
  },
...
```

Each layer is identified by a hash based on previous layer's hash and the state when the layer was
created. This is similar to commit hashes in a Git repository.

Let's check the layers of our first `fortune-clock:1.0` image:

```bash
$> docker inspect fortune-clock:1.0
...
  "RootFS": {
    "Layers": [
      "sha256:a8777d7885428f109ae6a59eec92d9aad13dd105afe5c44aadc1fcad90550610",
      "sha256:f144e7fc5f9b65143a8e22419e39bf947fbe343a42510e1b862cfcf36817d295"
    ],
    "Type": "layers"
  },
...
```

Note that the layers are the same as the `ubuntu` image, with an additional one
at the end (starting with `f144e7fc5`). This additional layer contains the
changes we made compared to the original `ubuntu` image, i.e.:

- Update the package lists with `apt update`
- Install the `fortune` package with `apt install`
- Install `nano` or `vim`
- Create the `/usr/local/bin/clock.sh` script

The new hash (starting with `f144e7fc5`) is based both on these changes and the
previous hash (starting with `a8777d788`), and it **uniquely identifies this
layer**.

Take a look at the layers of our second `fortune-clock:2.0` image:

```bash
$> docker inspect fortune-clock:2.0
...
  "RootFS": {
    "Layers": [
      "sha256:a8777d7885428f109ae6a59eec92d9aad13dd105afe5c44aadc1fcad90550610",
      "sha256:f144e7fc5f9b65143a8e22419e39bf947fbe343a42510e1b862cfcf36817d295",
      "sha256:8549c8f7e09546a3c750575e1eb27984c435d903d4286ba890beda628cb2a77e"
    ],
    "Type": "layers"
  },
...
```

Again, we see the same layers, including the `f144e7fc5` layer from the
`fortune-clock:1.0` image, and an additional layer (starting with `8549c8f7e`).
This layer contains the following changes we made based on the
`fortune-clock:1.0` image:

- Install the `cowsay` package with `apt install`
- Overwrite the `/usr/local/bin/clock.sh` script

### The top writable layer of containers

When you create a new container, you add a new **writable layer** on top of the
image's underlying layers. All changes made to the running container (i.e.
creating, modifying, deleting files) are written to this thin writable container
layer. When the container is deleted, the writable layer is also deleted, unless
it was committed to an image.

The layers belonging to the image used as a base for your container are never
modified–they are **read-only**. Docker uses a [union file system][union-fs] and
a [copy-on-write strategy][cow] to make it work:

- When you read a file, the union file system will look in all layers, from
  newest to oldest, and return the first version it finds.
- When you write to a file, the union file system will look for an older
  version, copy it to the top writable layer, and modify that copied version.
  Previous version(s) of the file in older layers still exist, but are "hidden"
  by the file system; only the most recent version is seen.

Multiple containers can therefore use the same read-only image layers, as they
only modify their own writable top layer:

![Docker: Sharing Layers](./images/sharing-layers.jpg)

### Total image size

What we've just learned about layers has several implications:

- You **cannot delete files from previous layers to reduce total image size**.
  Assume that an image's last layer contains a 1GB file. Creating a new
  container from that image, deleting that file, and saving that state as a new
  image will not reclaim that gigabyte. The total image size will still be the
  same, as the file is still present in the previous layer.

  This is also similar to a Git repository, where committing a file deletion
  does not reclaim its space from the repository's object database (as the file
  is still referenced by previous commits in the history).

- Since layers are read-only and incrementally built based on previous layers,
  **the size of common layers shared by several images is only taken up once**.

  If you take a look at the output of `docker images`, naively adding the
  displayed sizes adds up to ~232MB, but that is **not** the size that is
  actually occupied by these images on your file system.

  ```bash
  $> docker images
  IMAGE                ID             DISK USAGE   CONTENT SIZE
  fortune-clock:1.0    2e94440daea5        351MB         94.8MB
  fortune-clock:2.0    bc673d466633        420MB          107MB
  hello-world:latest   d4aaab6242e0       22.5kB         10.2kB
  ubuntu:latest        c35e29c94501        141MB         30.8MB
  ```

  Let's add the `-s` or `--size` option to `docker ps` to display the size of
  our containers' file systems:

  ```bash
  $> docker ps -as
  CONTAINER ID   IMAGE               COMMAND      CREATED          STATUS                        PORTS     NAMES              SIZE
  4e367ffdda98   fortune-clock:2.0   "clock.sh"   9 minutes ago    Up 9 minutes                            new-clock          4.1kB (virtual 314MB)
  25c9016ce01f   fortune-clock:1.0   "clock.sh"   9 minutes ago    Up 9 minutes                            old-clock          4.1kB (virtual 256MB)
  4b38e523336c   fortune-clock:1.0   "bash"       19 minutes ago   Exited (130) 15 minutes ago             peaceful_turing    58.6MB (virtual 315MB)
  e07f81d7941d   ubuntu              "bash"       27 minutes ago   Exited (130) 21 minutes ago             sweet_euclid       146MB (virtual 256MB)
  ```

  The `SIZE` column shows the size of the top writable container layer, and the
  total virtual size of all the layers (including the top one) in parentheses.
  If you look at the virual sizes, you can see that:
  - The virtual size of the `sweet_euclid` container is 256MB, which corresponds
    to the size of the `fortune-clock:1.0` image, since we committed that image
    based on that container's state.
  - Similarly, the virtual size of the `peaceful_turing` container is 315MB,
    which corresponds to the size of the `fortune-clock:2.0` image.
  - The `old-clock` and `new-clock` containers also have the same respective
    virtual sizes since they are based on the same images.

  Taking a look at the sizes of the top writable container layers, we can see
  that:
  - The size of the `sweet_euclid` container's top layer is 146MB. This
    corresponds to the space taken up by the package lists, the `fortune` and
    `nano/vim` packages and their dependencies, and the `clock.sh` script.

    The virtual size of 256MB corresponds to the uncompressed size of the
    `ubuntu` base image, plus the 146MB of the top layer. As we've seen above,
    this is also the size of the `fortune-clock:1.0` image.

    You can check the uncompressed size of the `ubuntu` image by running a new
    container based on it with `docker run --name tmp-ubuntu ubuntu` and then
    running `docker ps -as` again:

    ```bash
    $> docker ps -as
    1d49f97ef21d  ubuntu  "/bin/bash"  2 seconds ago  Exited (0) 2 seconds ago  tmp-ubuntu  4.1kB (virtual 110MB)
    ...
    ```

  - The size of the `peaceful_turing` container's top layer is 58.6MB. This
    corresponds to the space taken up by the `cowsay` package and its
    dependencies, and the new version of the `clock.sh` script.

    The virtual size of 315MB corresponds to the 256MB of the
    `fortune-clock:1.0` base image, plus the 58.6MB of the top layer. As we've
    seen above, this is also the size of the `fortune-clock:2.0` image.

  - The size of the `old-clock` and `new-clock` containers' top layers is 4.1kB,
    since almost no file was modified in these containers. Their virtual size
    correspond to their base images' size.

  Using all that we've learned, we can determine the total size taken up on your
  machine's file system:
  - The 110MB of the `ubuntu` image's layer, even though they are used by 3
    images (the `ubuntu` image itself and the `fortune-clock:1.0` and
    `fortune-clock:2.0` images), are taken up only once.
  - Similarly, the 16MB of the `fortune-clock:1.0` image's additional layer
    are taken up only once, even though the layer is used by 2 images (the
    `fortune-clock:1.0` image itself and the `fortune-clock:2.0` image).
  - Finally, the 58.6MB of the `fortune-clock:2.0` image's additional layer are
    also taken up once.

  Therefore, all these containers based on the `ubuntu`, `fortune-clock:1.0` and
  `fortune-clock:2.0` images take up only 184.6MB of space on your file system,
  not 232MB. Basically, it's the same size as the `fortune-clock:2.0` image,
  since it re-uses the `fortune-clock:1.0` and `ubuntu` images' layers, and the
  `fortune-clock:1.0` image also re-uses the `ubuntu` image's layers.

  The `hello-world` image takes up some additional space on your file system,
  since it has no layers in common with any of the other images.

## Dockerfile

Manually starting containers, making changes and committing images is all well
and good, but is **prone to errors and not reproducible**.

Docker can build images automatically by reading the instructions from a
[Dockerfile][dockerfile]. A Dockerfile is a text document that contains all the
commands a user could call on the command line to assemble an image. Using the
`docker build` command, users can create an **automated build** that executes
several command line instructions in succession.

### The `docker build` command

This `docker build <context>` command builds an image from a **Dockerfile** and
a **context**. The build's context is the set of files at a specified path on
your file system. For example, running `docker build /foo` would expect to find
a Dockerfile at the path `/foo/Dockerfile`, and would use the entire contents of
the `/foo` directory as the build context.

The build is run by the Docker daemon, not by the CLI. The first thing a build
process does is **send the entire context (recursively) to the daemon**. In most
cases, it's best to start with an empty directory as context and keep your
Dockerfile in that directory. Add only the files needed for building the
Dockerfile.

{% note type: warning %}

Do not use your root directory, `/`, as the build context as it causes the build
to transfer the entire contents of your hard drive to the Docker daemon.

{% endnote %}

To ignore some files in the build context, use a [`.dockerignore`
file][docker-ignore] (similar to a `.gitignore` file).

### Format

The format of a Dockerfile is:

```
# Comment
INSTRUCTION arguments...
INSTRUCTION arguments...
```

You can find all available instructions, such as `FROM` and `RUN`, in the
[Dockerfile reference][dockerfile]. Many correspond to arguments or options of
the Docker commands that we've used. For example, the `FROM` instruction
corresponds to the `<image>` argument of the `docker run IMAGE [command...]`
command, and specifies what base image to use.

### Build an image from a Dockerfile

Here's what a Dockerfile for the previous tutorial would look like:

```bash
FROM ubuntu

RUN apt update
RUN apt install -y fortune
RUN apt install -y cowsay

COPY clock.sh /usr/local/bin/clock.sh

RUN chmod +x /usr/local/bin/clock.sh
```

It basically **replicates what we have done manually** with Dockerfile
instructions:

- The [`FROM ubuntu` instruction][dockerfile-from] starts the build process from
  the `ubuntu` base image.
- The [`RUN apt update` instruction][dockerfile-run] executes the `apt update`
  command like we did before.
- The next two `RUN` instructions install the `fortune` and `cowsay` packages,
  also like we did before.
- The [`COPY <src> <dest>` instruction][dockerfile-copy] copies a file from the
  build context into the file system of the container. In this case, we copy the
  `clock.sh` file in the build context to the `/usr/local/bin/clock.sh` path in
  the container.
- The final `RUN` instruction makes the script executable.

Create a `fortune-clock` directory in your projects folder and add the above
Dockerfile to it. Also copy the final version of the `clock.sh` script into that
directory:

```bash
#!/bin/bash
trap "exit" SIGKILL SIGTERM SIGHUP SIGINT EXIT
while true; do
  echo It is $(date)
  /usr/games/fortune | /usr/games/cowsay
  echo
  sleep 5
done
```

Run the following build command. The `-t` or `--tag REPO:TAG` option indicates
that we want to tag the image like we did when we were using the `docker commit`
command. The last argument, `.`, indicates that the build context is the current
directory:

```bash
$> docker build -t fortune-clock:3.0 .
[+] Building 10.0s (11/11) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile:
 => [internal] load metadata for docker.io/library/ubuntu:latest
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [1/6] FROM docker.io/library/ubuntu:latest@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
 => => resolve docker.io/library/ubuntu:latest@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
 => [internal] load build context
 => => transferring context: 195B
 => [2/6] RUN apt update
 => [3/6] RUN apt install -y fortune
 => [4/6] RUN apt install -y cowsay
 => [5/6] COPY clock.sh /usr/local/bin/clock.sh
 => [6/6] RUN chmod +x /usr/local/bin/clock.sh
 => exporting to image
 => => exporting layers
 => => exporting manifest sha256:6a9d66d1460597beb1bbf3976874b6652359c98f5ea51c340ac255bf0322178f
 => => exporting config sha256:75052aa282f3633d112575c446a085caa4b3701ad27f9e2f0a1e9a56dcf50acb
 => => exporting attestation manifest sha256:1facac2fda70bb65fbbdd502185203404382caaa657d708f815f20c6df0ed248
 => => exporting manifest list sha256:8e96de510874be5de6274118d287871451724708f50d6b4e43500a294d43d1e4
 => => naming to docker.io/library/fortune-clock:3.0
 => => unpacking to docker.io/library/fortune-clock:3.0
```

As you can see, Docker:

- **Uploaded to build context** (i.e. the contents of the `fortune-clock` directory) to the Docker
  deamon.
- **Ran each instruction** in the Dockerfile **one by one**, creating an intermediate container each
  time, based on the previous state.
- **Created an image** with the final state, and the specified tag (i.e. `fortune-clock:3.0`).

You can see that new image in the list of images:

```bash
$> docker images
IMAGE                ID             DISK USAGE   CONTENT SIZE
fortune-clock:1.0    2e94440daea5        351MB         94.8MB
fortune-clock:2.0    bc673d466633        420MB          107MB
fortune-clock:3.0    8e96de510874        315MB         83.6MB
hello-world:latest   d4aaab6242e0       22.5kB         10.2kB
ubuntu:latest        c35e29c94501        141MB         30.8MB
```

You can also run a container based on it like we did before:

```bash
$> docker run --rm fortune-clock:3.0 clock.sh
It is Mon Apr 23 12:10:16 UTC 2018
 _____________________________________
/ Today is National Existential Ennui \
\ Awareness Day.                      /
 -------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Use Ctrl-C to stop it.

Let's take a look at that new image's layers:

```bash
$> docker inspect fortune-clock:3.0
...
  "RootFS": {
    "Type": "layers",
    "Layers": [
      "sha256:a8777d7885428f109ae6a59eec92d9aad13dd105afe5c44aadc1fcad90550610",
      "sha256:dd2eebdf8c20b51a1ee4b923c34e681eb5252f00afca3c8f078db60cd51a1597",
      "sha256:21c6522005259f7fc68fe1d9941e0cb41ad218f3716e7b0905317423a3e87c92",
      "sha256:556fa4e762a5df67dfc881aaeba2a2da1060bb843cd3cea0a58fbe826056e7c8",
      "sha256:d7e894b8bb9e80185191d0bd29e9df2d08dce1f17824cd2c5500c1226df11410",
      "sha256:cd53e0d8f4e9712cf99cedbf542e01ac63f3b7a4b60ce8537c24f781414f6267"
    ]
  },
...
```

The first layer (starting with `a8777d788`) is the same as before, since it is
the `ubuntu` image's base layer. The last 5 layers, however, are new.

Basically, Docker created **one layer for each instruction in the Dockerfile**.
Since we have 4 `RUN` instructions and 1 `COPY` instruction in the Dockerfile we
used, there are 5 additional layers.

### Build cache

Re-run the same build command:

```bash
$> docker build -t fortune-clock:3.0 .
[+] Building 0.1s (11/11) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 197B
 => [internal] load metadata for docker.io/library/ubuntu:latest
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [1/6] FROM docker.io/library/ubuntu:latest@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
 => => resolve docker.io/library/ubuntu:latest@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
 => [internal] load build context
 => => transferring context: 30B
 => CACHED [2/6] RUN apt update
 => CACHED [3/6] RUN apt install -y fortune
 => CACHED [4/6] RUN apt install -y cowsay
 => CACHED [5/6] COPY clock.sh /usr/local/bin/clock.sh
 => CACHED [6/6] RUN chmod +x /usr/local/bin/clock.sh
 => exporting to image
 => => exporting layers
 => => exporting manifest sha256:6a9d66d1460597beb1bbf3976874b6652359c98f5ea51c340ac255bf0322178f
 => => exporting config sha256:75052aa282f3633d112575c446a085caa4b3701ad27f9e2f0a1e9a56dcf50acb
 => => exporting attestation manifest sha256:37824dba0bfdaa09e8d189379e343583a841cfe0787fed76a7245931e413109e
 => => exporting manifest list sha256:45719f4dd1e4607c2638e52aca8a586582e3c903a6b142e447740c2bd44babba
 => => naming to docker.io/library/fortune-clock:3.0
 => => unpacking to docker.io/library/fortune-clock:3.0
```

It was much faster this time. As you can see by the `CACHED` indications in the
output, Docker is keeping a **cache of the previously built layers**. Since you
have not changed the instructions in the Dockerfile or any file in the build
context, it assumes that the result will be the same and reuses the same already
committed layer.

Make a change to the `clock.sh` script in the `fortune-clock` directory. For
example, add a new line or a comment:

```bash
#!/bin/bash
trap "exit" SIGKILL SIGTERM SIGHUP SIGINT EXIT

# TODO: add new lines or a comment here!

# Print the date and a fortune every 5 seconds.
while true; do
  echo It is $(date)
  /usr/games/fortune | /usr/games/cowsay
  echo
  sleep 5
done
```

Re-run the same build command:

```bash
$> docker build -t fortune-clock:3.0 .
[+] Building 0.2s (11/11) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 197B
 => [internal] load metadata for docker.io/library/ubuntu:latest
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [1/6] FROM docker.io/library/ubuntu:latest@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
 => => resolve docker.io/library/ubuntu:latest@sha256:c35e29c9450151419d9448b0fd75374fec4fff364a27f176fb458d472dfc9e54
 => [internal] load build context
 => => transferring context: 239B
 => CACHED [2/6] RUN apt update
 => CACHED [3/6] RUN apt install -y fortune
 => CACHED [4/6] RUN apt install -y cowsay
 => [5/6] COPY clock.sh /usr/local/bin/clock.sh
 => [6/6] RUN chmod +x /usr/local/bin/clock.sh
 => exporting to image
 => => exporting layers
 => => exporting manifest sha256:ae6f815ae1dd4e3a36687693c4ade928063cb5e24b7daa56d3d64c48e629d665
 => => exporting config sha256:691befbaa4723f128977ae914b150501ba8584ef69717ee8382c0383aead0860
 => => exporting attestation manifest sha256:9046974209454baa51a1854f2ea138e54c08d403fc9cf364be7d64b790ef6a67
 => => exporting manifest list sha256:5847c0c87acfb215f0f127d5c59f5c2ffe32e456fd7dde69fe795c8693222b22
 => => naming to docker.io/library/fortune-clock:3.0
 => => unpacking to docker.io/library/fortune-clock:3.0
```

Docker is still using its cache for the first 3 commands (the `apt update` and
the installation of the `fortune` and `cowsay` packages), since they are
executed before the `clock.sh` script is copied, and are therefore not affected
by the change. Therefore the build is still nearly instantaneous.

The `COPY` instruction is executed **without cache**, however, since Docker
detects that **the `clock.sh` script has changed**.

Consequently, **all further instructions** after that `COPY` **cannot use the
cache**, since the state upon which they are based has changed. Therefore, the
last `RUN` instruction also does not use the cache.

## Debugging containers

A very useful command to debug containers is `docker exec <command...>`. It
executes a command **in a running container**.

For example, let's say you want to check what's in the `/usr/local/bin`
directory in the `new-clock` container (assuming it's still running):

```bash
$> docker exec new-clock ls /usr/local/bin
total 12
drwxr-xr-x 1 root root 4096 Dec 12 08:59 .
drwxr-xr-x 1 root root 4096 Oct 13 16:06 ..
-rwxr-xr-x 1 root root  158 Dec 12 08:59 clock.sh
```

You can execute any available command, including a full shell (if there is one
in your container's file system). For example, let's run a shell in the
`new-clock` container:

```bash
$> docker exec -it new-clock bash
root@4e367ffdda98:/#
```

You're now in the container! You can run any command you want:

```bash
root@4e367ffdda98:/# echo hello from $(hostname)
hello from 4e367ffdda98

root@4e367ffdda98:/# /usr/games/fortune
Do nothing unless you must, and when you must act -- hesitate.
```

Run `exit` once you're done:

```bash
root@4e367ffdda98:/# exit
```

### Ephemeral containers

You could make changes to a running container using `docker exec`, but that's
considered a bad practice.

Containers produced by your Dockerfiles should be as **ephemeral** as possible.
By "ephemeral", we mean that they can be **stopped and destroyed** and a **new
one built and put in place** with an **absolute minimum of setup and
configuration**. You shouldn't have to perform additional manual changes in a
container once it's started.

You may want to take a look at the [Processes][12factor-processes] section of
the [12 Factor app methodology][12factor] to get a feel for the motivations of
running containers in such a stateless fashion.

## Dockerfile tips

The following tips suggest various best practices for writing Dockerfiles.

### Using smaller base images

Many popular Docker images these days have an Alpine variant. This means that
the image is based on the [official `alpine` image][hub-alpine] on Docker hub,
based on the [Alpine Linux][alpine] distribution. Alpine Linux is much smaller
than most distribution base images (~5MB), and thus leads to much slimmer images
in general.

```
FROM node:24-alpine
```

Here we use the `node:24-alpine` tag instead of simply `node:24`.

These variants are highly recommended when final image size being as small as
possible is desired.

The main caveat to note is that Alpine Linux uses [musl libc][musl-libc] instead
of [glibc and friends][glibc-etc], so certain software might run into
compilation issues depending on the depth of their libc requirements. However,
most software doesn't have an issue with this, so this variant is usually a very
safe choice. See this [Hacker News comment thread][alpine-size] for more
discussion of the issues that might arise and some pro/con comparisons of using
Alpine-based images.

To minimize image size, it's uncommon for additional related tools (such as Git
or Bash) to be included in Alpine-based images. Using this image as a base, add
the things you need in your own Dockerfile (see the [alpine image
description][hub-alpine] for examples of how to install packages if you are
unfamiliar).

### Labeling images

Labels are metadata attached to images and containers. They can be used to
influence the behavior of some commands, such as `docker ps`. You can add labels
from a Dockerfile with the `LABEL` instruction.

A popular convention is to add a `org.opencontainers.image.authors` label to
provide an author (and potential maintenance contact e-mail):

```
LABEL org.opencontainers.image.authors="mei-admin@heig-vd.ch"
```

You may see the labels of an image or container with `docker inspect`.

You may also filter containers by label. For example, to see all running
containers that have the `foo` label set to the value `bar`, you can use the
following command:

```bash
docker ps -f label=foo=bar
```

### Environment variables

The `ENV` instruction allows you to set environment variables. Many applications
change their behavior in response to some variables. The to-do application
example is an [Express][express] application, so it runs in production mode if
the `$NODE_ENV` variable is set to `production`. Additionally, it listens on the
port specified by the `$PORT` variable.

The application should be run in production if you intend to deploy it, and it's
good practice to explicitly set the port rather than relying on the default
value, so we set both variables:

```
ENV NODE_ENV=production \
    PORT=3000
```

#### Non-root users

All commands run by a Dockerfile (`RUN` and `CMD` instructions) are **run by the
`root` user** of the container by default. This is not a good idea as any
security flaw in your application may give root access to the entire container
to an attacker.

The security impact of this would be mitigated since the container is isolated
from the host machine, but it could still be a **severe security issue**
depending on your container's configuration.

Therefore, it is good practice to create an **unprivileged user** to run your
application even in the container. Here we use Alpine Linux's `addgroup` and
`adduser` commands to create a user, and make sure that your application's
directory, e.g. `/app`, where you copy the application is owned by that user:

```
RUN addgroup -S app && \
    adduser -S -G app app && \
    mkdir -p /app && \
    chown app:app /app
```

(Note that these commands are specific to Alpine Linux. You would use `groupadd`
and `useradd` on Ubuntu, for example, which use different options.)

Finally, we use the `USER` instruction to make sure that all further commands
run in this Dockerfile (by `RUN` or `CMD` instructions) are executed as the new
user instead of the root user:

```
USER app:app
```

When using the `COPY` command, you can use the `--chown=app:app` flag to copy
files and set their ownership in one go.

### Speeding up builds

The following pattern is popular to speed up builds of applications that use a
package manager (e.g. npm, RubyGems, Composer).

Installing packages is often one of the slowest command to run for small
applications, so we want to take advantage of Docker's build cache as much as
possible to avoid running it every time. Suppose you did this like in the
example Dockerfile of the todo-application:

```
COPY ./ /app/
WORKDIR /app
RUN npm ci
```

Every time you make the slightest change in any of the application's files, the
`COPY` instruction's cache, and all further commands' caches will be
invalidated, including the cache for the `RUN npm ci` instruction. Therefore,
any change will trigger a full installation of all dependencies from scratch.

To improve this behavior, you can split the installation of your application in
the container into two parts. The first part is to copy only the package
manager's files (in this case `package.json` and `package-lock.json`) into the
application's directory, and to run an `npm ci` command like before:

```
COPY --chown=app:app package.json package-lock.json /app/
WORKDIR /app
RUN npm ci
```

Now, if a change is made to the `package.json` or `package-lock.json` files, the
cache of the `RUN npm ci` instruction will be invalidated like before, and the
dependencies will be re-installed, which we want since the change was probably a
dependency update. However, changes in any other file of the application will
not invalidate the cache for those 3 instructions, so the result of the `RUN npm
ci` instruction will remain cached.

The second part of the installation process is to copy the rest of your
application into the directory:

```
COPY --chown=todo:todo . /app/
```

Now, if any file in your application changes, the cache of further instructions
will be invalidated, but since the `RUN npm ci` instruction comes before, it
will remain in the cache and be skipped at build time (unless you modify the
`package.json` or `package-lock.json` files).

### Documenting exposed ports

The `EXPOSE` instruction informs Docker that the container listens on the
specified network ports at runtime.

```
EXPOSE 3000
```

The `EXPOSE` instruction does not actually publish the port. It functions as a
type of documentation between the person who builds the image and the person who
runs the container, about which ports are intended to be published. To actually
publish the port when running the container, use the `-p` option on `docker run`
to publish and map one or more ports, or the `-P` option to publish all exposed
ports and map them to high-order ports.

## References

- [What is Docker?][what-is-docker]
- [What is a Container?][what-container]
- [Docker Security][docker-security]
- [Dockerfile Reference][dockerfile]
  - [Best Practices for Writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
  - [Trapping Signals in Docker Containers](https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86)
- [The Twelve-Factor App][12factor]

[12factor]: https://12factor.net
[12factor-processes]: https://12factor.net/processes
[alpine]: https://alpinelinux.org
[alpine-size]: https://news.ycombinator.com/item?id=10782897
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[cow]: https://en.wikipedia.org/wiki/Copy-on-write
[docker-desktop]: https://www.docker.com/products/docker-desktop/
[docker-ignore]: https://docs.docker.com/engine/reference/builder/#dockerignore-file
[docker-security]: https://docs.docker.com/engine/security/security/
[dockerfile]: https://docs.docker.com/engine/reference/builder/
[dockerfile-copy]: https://docs.docker.com/reference/dockerfile/#copy
[dockerfile-from]: https://docs.docker.com/reference/dockerfile/#from
[dockerfile-run]: https://docs.docker.com/reference/dockerfile/#run
[fortune]: https://en.wikipedia.org/wiki/Fortune_(Unix)
[glibc-etc]: http://www.etalabs.net/compare_libcs.html
[hub]: https://hub.docker.com
[hub-alpine]: https://hub.docker.com/_/alpine/
[hub-explore]: https://hub.docker.com/explore/
[hub-ubuntu]: https://hub.docker.com/_/ubuntu/
[musl-libc]: http://www.musl-libc.org
[ubuntu]: https://www.ubuntu.com
[union-fs]: https://en.wikipedia.org/wiki/UnionFS
[what-container]: https://www.docker.com/resources/what-container/
[what-is-docker]: https://docs.docker.com/get-started/docker-overview/
