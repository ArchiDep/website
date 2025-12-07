---
title: Docker
excerpt_separator: <!-- more -->
---

Learn how to containerize your web applications with Docker.

**You will need**

- [Git][git]
- A [GitHub][github] account
- A [Docker][docker] account
- [Docker Desktop][docker-desktop] installed on your machine.

<!-- more -->

## Running existing Docker images

Before proceeding, ensure that you have installed **[Docker
Desktop][docker-desktop]**. This software includes everything you'll need to use
**Docker**. It's recommended to use the default settings.

The first step is to **download an image** from **Docker Hub** using the
[**`docker pull`**][docker-commands-pull] command.

In this example, we'll pull the [**official Ubuntu
image**][docker-images-ubuntu]. The download might take some time, but it's
**cached** for future use until a new version is released, assuming you're using
the latest version.

```bash
$> docker pull ubuntu
Using default tag: latest
latest: Pulling from library/ubuntu
005e2837585d: Pull complete
Digest: sha256:6042500cf4b44023ea1894effe7890666b0c5c7871ed83a97c36c76ae560bb9b
Status: Downloaded newer image for ubuntu:latest
docker.io/library/ubuntu:latest
```

To use a **specific version** of an image, append `:tag_name` to the image name.
For example, to pull Ubuntu 23.10 Mantic Minotaur, run `docker pull
ubuntu:mantic`. The default tag `latest` refers to the latest long-term support
release.

### Running a pre-built image

You can check the images available on your machine by running the [**`docker
images`**][docker-commands-images] command.

```bash
$> docker images
REPOSITORY     TAG       IMAGE ID       CREATED          SIZE
ubuntu         latest    da935f064913   4 weeks ago      69.3MB
```

An image downloaded from **Docker Hub** comes pre-built, which means you can
directly create a container from it using the [`docker run
[image_name]`][docker-commands-run] command.

The `run` command has a myriad of options. Our goal here is to create an
**interactive shell** from the image. Thus, we will use the `--interactive` and
`--tty` flags in our command (abbreviated to `-it`).

```bash
$> docker run -it ubuntu
root@bf545ce9cbdb:/#
```

As you can see, you can now interact with a containerized version of Ubuntu. Try
interacting with the filesystem using standard UNIX commands such as `cd` and
`ls`.

### Wait. I thought Docker containers did not contain an OS?

In a typical **Linux distribution**, you usually get:

- A **bootloader**, which loads a kernel
- A **kernel**, which manages the system and loads an init system
- An **init system**, which sets up and runs everything else
- **Everything else** (binaries, shared libraries, etc)

The **Docker Engine** replaces the kernel and init system, and the **container**
replaces "everything else".

An **Ubuntu Docker image** contains the minimal set of Ubuntu binaries and
shared libraries, as well as the `apt` package manager. For instance, `systemd`
is not included.

### Container management

You can manage Docker containers by using a host of commands:

| Command                                                          | Purpose                                                      |
| :--------------------------------------------------------------- | :----------------------------------------------------------- |
| [`docker run IMAGE`][docker-commands-run]                        | Create and start a container.                                |
| [`docker ps`][docker-commands-ps]                                | List running containers.                                     |
| [`docker stop CONTAINER_ID`][docker-commands-stop]               | Gracefully stops a running container.                        |
| [`docker start CONTAINER_ID`][docker-commands-start]             | Restart a stopped container.                                 |
| [`docker rm CONTAINER_ID`][docker-commands-rm]                   | Remove a container.                                          |
| [`docker exec -it CONTAINER_ID /bin/bash`][docker-commands-exec] | Provide shell access to a running container.                 |
| [`docker logs CONTAINER_ID`][docker-commands-logs]               | Display a container's logs.                                  |
| [`docker stats`][docker-commands-stats]                          | Show a live stream of container(s) resource usage statistics |

## Creating your own Docker images

If the goal is to package your applications into **portable and shareable
images**, then you must be able to do more than just use existing images from
Docker Hub.

Docker can build images by reading the instructions from a
[**Dockerfile**][dockerfile-reference]. A Dockerfile is a text document that
uses a specific syntax to contain all the instructions necessary to assemble an
image.

There are a few rules:

- A Dockerfile must be named **`Dockerfile`**, with no extension.
- A Docker image must be based on an **existing base image** from official
  repositories such as [`node`][docker-images-node].

```dockerfile
FROM node

WORKDIR /app

COPY . .

ENTRYPOINT node app.js
```

### Dockerfile instructions

| Instruction            | Purpose                                                               |
| :--------------------- | :-------------------------------------------------------------------- |
| `FROM image_name`      | Specify the base image to use for the new image.                      |
| `WORKDIR /some/path`   | Set the working directory for the instructions that follow.           |
| `COPY <src> <dest>`    | Copy files or directories from the build context to the image.        |
| `RUN <command>`        | Execute commands in the shell during image builds.                    |
| `EXPOSE <port>`        | Port(s) Docker will be listening on at runtime.                       |
| `ENV KEY=VALUE`        | Set environment variables.                                            |
| `ARG KEY=VALUE`        | Define build time variables.                                          |
| `USER user`            | Set user and group ID.                                                |
| `CMD <command>`        | The default command to execute when the container starts.             |
| `ENTRYPOINT <command>` | Similar as `CMD`, but cannot be overriden without an explicit option. |

To see a full list of Dockerfile instructions, see the [Dockerfile
reference][dockerfile-reference].

### Building the image

To build an image, use the `docker build <context>` command followed by a **PATH
or URL**. This specifies the build context, which is necessary if you need to
copy files from a folder into the container.

It's also recommended to tag your image with a name using the `-t` flag. The
example below builds an image from a Dockerfile present in the current working
directory.

```bash
$> docker build -t hello-docker .
+ Building 1.3s (9/9) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 94B
 => [internal] load .dockerignore
 => => transferring context: 2B
 => [internal] load metadata for docker.io/library/node:latest
 => [auth] library/node:pull token for registry-1.docker.io
 => [1/3] FROM docker.io/library/node@sha256:73a9c498369c6e6f864359979c8f4895f28323c07411605e6c870d696a0143fa
 => [internal] load build context
 => => transferring context: 56B
 => CACHED [2/3] WORKDIR /app
 => CACHED [3/3] COPY . .
 => exporting to image
 => => exporting layers
 => => writing image sha256:9cc4ea715ff536e18366516d5b5bb403a5633297fab9fb1cd489d1e789a18cd7
 => => naming to docker.io/library/hello-docker
```

### Run a container based on the custom image

Check the image has been created with `docker images`:

```bash
$> docker images
REPOSITORY     TAG       IMAGE ID       CREATED       SIZE
hello-docker   latest    9cc4ea715ff5   5 hours ago   1.1GB
```

And create a container from it with `docker run`:

```bash
$> docker run hello-docker
Hello Docker!
```

A Docker container operates by running a specific **process, defined by the
`CMD` or `ENTRYPOINT` in your Dockerfile**. This process keeps the container
alive. The container will remain active as long as this process is running. In
our example, the container is running a Node.js script that logs "Hello Docker!"
to the console. Once this script finishes executing and the Node.js runtime
exits, the container will also stop running. Running `docker ps` will therefore
not display the container you just executed:

```bash
$> docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

[docker]: https://www.docker.com/
[docker-commands-build]: https://docs.docker.com/engine/reference/commandline/build/
[docker-commands-exec]: https://docs.docker.com/engine/reference/commandline/exec/
[docker-commands-images]: https://docs.docker.com/engine/reference/commandline/images/
[docker-commands-logs]: https://docs.docker.com/engine/reference/commandline/logs/
[docker-commands-pull]: https://docs.docker.com/engine/reference/commandline/pull/
[docker-commands-ps]: https://docs.docker.com/engine/reference/commandline/ps/
[docker-commands-rm]: https://docs.docker.com/engine/reference/commandline/rm/
[docker-commands-run]: https://docs.docker.com/engine/reference/commandline/run/
[docker-commands-start]: https://docs.docker.com/engine/reference/commandline/start/
[docker-commands-stats]: https://docs.docker.com/engine/reference/commandline/stats/
[docker-commands-stop]: https://docs.docker.com/engine/reference/commandline/stop/
[docker-desktop]: https://www.docker.com/products/docker-desktop/
[docker-images-node]: https://hub.docker.com/_/node
[docker-images-ubuntu]: https://hub.docker.com/_/ubuntu
[dockerfile-reference]: https://docs.docker.com/engine/reference/builder/
[git]: https://git-scm.com
[github]: https://github.com
[google-artifact-registry]: https://cloud.google.com/artifact-registry
[render]: https://render.com
[stack-overflow-survey]: https://survey.stackoverflow.co/2023/
