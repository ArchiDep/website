---
title: Unix Environment Variables
---

# Unix Environment Variables

Architecture & Deployment <!-- .element: class="subtitle" -->

**Notes:**

Learn about environment variables, a powerful way to configure applications and
processes in Unix-like operating systems.

**You will need**

- A Unix CLI

**Recommended reading**

- [Unix Processes]({% link _course/406-unix-processes/subject.md %})

---

## Environment

<img class='w80' src='images/environments.png' />

---

### What is an environment?

A computer system or set of systems in which a program or component is
**deployed and executed**.

<div class="flex gap-4">
  <div class="flex flex-col items-center gap-4">
    <img class='h-42' src='images/development-server.png' />
    <p>
      Local <strong>development</strong> environment
    </p>
  </div>

  <div class="flex flex-col items-center gap-4">
    <img class='h-42' src='images/web-server.png' />
    <p>
      Server <strong>production</strong> environment
    </p>
  </div>
</div>

---

### Industrial deployment

Environments vary to suit different needs.

<p class='center'><img class='w85' src='images/deployment.png' /></p>

**Notes:**

In industrial use, the **development environment** (where changes are originally
made) and **production environment** (what end users use) are separated, often
with several stages in between.

The configuration of each environment may vary to suit the requirements of
development, testing, production, etc.

---

### Continuous delivery/deployment (CD)

<img class='w-1/2' src='images/release-management-cycle.jpg' />

**Notes:**

When using [agile software development][agile], teams are seeing much higher
quantities of software releases.

[Continuous delivery][cd] and [DevOps][devops] are processes where a program is
packaged and "moved" from one environment to the other (i.e. deployed) until it
reaches the production stage.

Modern software development teams use automation to speed up this process.

[agile]: https://en.wikipedia.org/wiki/Agile_software_development
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[cd]: https://en.wikipedia.org/wiki/Continuous_delivery
[devops]: https://en.wikipedia.org/wiki/DevOps
[env]: https://en.wikipedia.org/wiki/Deployment_environment
[env-var]: https://en.wikipedia.org/wiki/Environment_variable
[path]: https://en.wikipedia.org/wiki/Path_(computing)
