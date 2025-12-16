---
title: Docker Compose
excerpt_separator: <!-- more -->
---

Learn the basics of [Docker Compose][docker-compose], a tool for defining and
running **multi-container applications**.

**Recommended reading**

- [Docker]({% link _course/801-docker/subject.md %})

<!-- more -->

## The Docker Compose command line

Docker Compose is also a **Docker subcommand**. Based on a Compose file, it can:

- Start, stop, and rebuild services:
  - [`docker compose up [service]`][docker-compose-up]
  - [`docker compose stop [service]`][docker-compose-stop]
  - [`docker compose build [service]`][docker-compose-build]
- View the status of running services:
  - [`docker compose ps [service]`][docker-compose-ps]
- Stream the log output of running services:
  - [`docker compose logs [--follow] [service]`][docker-compose-logs]

{% note type: more %}

Read the [`docker compose` command reference][docker-compose-cli] or run `docker
compose help` for a complete list of commands and options.

{% endnote %}

## Other Compose concepts

[**Networks**][docker-networking] are the layer that allow services to
communicate with each other. Compose lets you [configure named
networks][compose-networks] that can be reused across multiple services for
greater control and security.

[**Volumes**][docker-volumes] are persistent data stores implemented by the
container engine. Compose offers a neutral way for services to [mount
volumes][compose-volumes], and configuration parameters to allocate them to
infrastructure.

You will use these concepts in the following exercise.

## Going further

The following tools are (completely) out of scope for this course, but
interesting to learn about if you want to go further with Docker:

- [Traefik][traefik] and [Caddy][caddy] are **reverse proxies developed to
  integrate with microservices** such as Docker Compose services. Using it, you
  can get rid of nginx and its site configuration files. For example, Traefik
  can interrogate the Docker Daemon about running containers and [configure
  itself automatically](https://doc.traefik.io/traefik/providers/docker/).
- [Docker Swarm][swarm] can network a cluster of Docker engines together across
  multiple servers, allowing you to **aggregate separate machines into one giant
  pool of resources**. You can then simply deploy Compose services to the swarm
  and containers will be automatically spawned on one of the cluster's machines.

  With a swarm, you can also use more advanced Compose features like:
  - [**Configs**][compose-configs] allow services to adapt their behaviour
    without the need to rebuild a Docker image. Services can only access configs
    when explicitly granted in the Compose file. Configs are mounted as files
    into the file system of a service's container.
  - [**Secrets**][compose-secrets] are a flavor of Configs focusing on sensitive
    data, with specific constraint for this usage. Services can only access
    secrets when explicitly granted in the Compose file. Secrets are either read
    from files or from the environment.

- If you want to go even further into large-scale Docker deployments, look at
  [Kubernetes][k8s], an open-source system for **automating deployment, scaling,
  and management of containerized applications**. It groups containers that make
  up an application into logical units for easy management and discovery.

## References

- [Docker Compose][docker-compose]
- [Containers philosophy](https://dev.to/iblancasa/containers-philosophy-2714)
- [The First Thing You Should Know When Learning About Docker Containers](https://medium.com/factualopinions/the-first-thing-you-should-know-when-learning-about-docker-containers-e0de29ddb6c3)

[caddy]: https://caddyserver.com
[docker]: https://www.docker.com
[docker-compose]: https://docs.docker.com/compose/
[docker-compose-build]: https://docs.docker.com/reference/cli/docker/compose/build/
[docker-compose-cli]: https://docs.docker.com/reference/cli/docker/compose/
[docker-compose-logs]: https://docs.docker.com/reference/cli/docker/compose/logs/
[docker-compose-ps]: https://docs.docker.com/reference/cli/docker/compose/ps/
[docker-compose-stop]: https://docs.docker.com/reference/cli/docker/compose/stop/
[docker-compose-up]: https://docs.docker.com/reference/cli/docker/compose/up/
[docker-desktop]: https://www.docker.com/products/docker-desktop/
[docker-networking]: https://docs.docker.com/engine/network/
[docker-volumes]: https://docs.docker.com/engine/storage/volumes/
[compose-configs]: https://docs.docker.com/reference/compose-file/configs/
[compose-networks]: https://docs.docker.com/reference/compose-file/networks/
[compose-secrets]: https://docs.docker.com/compose/how-tos/use-secrets/
[compose-volumes]: https://docs.docker.com/reference/compose-file/volumes/
[k8s]: https://kubernetes.io
[swarm]: https://docs.docker.com/engine/swarm/
[traefik]: https://traefik.io
[yaml]: https://yaml.org
