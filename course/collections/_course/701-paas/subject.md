---
title: Platform-as-a-Service (PaaS)
excerpt_separator: <!-- more -->
---

Learn to deploy web applications on Platform-as-a-Service (PaaS) cloud
application platforms such as [GitHub Pages][github-pages], [Netlify][netlify]
and [Render][render].

**You will need**

- [Git][git]
- A free [GitHub][github] account

**Recommended reading**

- [Command line]({% link _course/101-command-line/subject.md %})
- [Git]({% link _course/201-git/subject.md %}), [Git branching]({% link
  _course/202-git-branching/slides.md %}), [Collaborating with Git]({% link
  _course/203-git-collaborating/slides.md %}), [Git hooks]({% link
  _course/601-git-hooks/subject.md %})

<!-- more -->

## What is PaaS?

**Platform-as-a-Service (PaaS)** is a **cloud deployment** service model where
the developer deploys applications without the complexity of building and
maintaing the infrastructure.

[Heroku][heroku], one of the first cloud platforms, has been in development
since June 2007, when it supported only the Ruby programming language, but now
supports Java, **Node.js**, Scala, Clojure, Python, PHP, and Go. Today there are
many alternatives such as [Netlify][netlify], [Fly][fly] or [Render][render].

### Cloud service models

Cloud-computing providers offer their services according to **different
models**, some of which are listed below:

| Service models                      | What they provide         | Examples                                 |
| :---------------------------------- | :------------------------ | :--------------------------------------- |
| [Infrastructure as a Service][iaas] | Servers, virtual machines | Amazon EC2, Azure (Microsoft), Rackspace |
| [_Platform as a Service_][paas]     | _Runtime environments_    | Heroku, OpenShift, Netlify, Fly, Render  |
| [Software as a Service][saas]       | Online services           | Gmail                                    |
| [Functions as a Service][faas]      | Serverless environments   | Amazon Lambda, OpenWhisk (IBM)           |

### Infrastructure as a Service (IaaS)

With traditional cloud providers, you have to **set up, maintain and operate**
the **infrastructure** on which your applications are run:

![Infrastructure-as-a-Service (IaaS)](./images/iaas.png)

You'll often need a professional **system administrator** to do that for sizable
projects.

### Platform as a Service (PaaS)

The goal of PaaS platforms is to get **straight to building applications**.

![Platform-as-a-Service (PaaS)](./images/paas.png)

- Higher-level programming
- Reduced complexity
- Effective deployment with built-in infrastructure
- Easier maintenance
- Scaling

It's also a part of the [DevOps][devops] movement where software **dev**elopers
increasingly step into the world of **op**eration**s** and vice-versa.

### How does a PaaS platform work?

PaaS platforms usually run your applications inside **containers** on a fully
**managed runtime environment**.

As a developer, you will deploy your **code** written with your favorite
programming language and framework to a **build system** which automatically
performs the necessary steps to build and deploy your application.

The various other components required to run and deploy your applications, such
as the **database** and **reverse proxy** are installed and configured for you.
The **system and language** stacks are **monitored, patched, and upgraded**, so
it's always ready and up-to-date.

### Is it magic?

A PaaS platform will often assume you are following the **conventions** of the
language or framework you're using. For example, when deploying a Node.js
application, many PaaS platforms assume:

- You are using npm, the Node.js Package Manager, and have a `package.json`
  file.
- The dependencies for your application can be installed by executing `npm
install`.
- Your application can be run by executing `npm start`.

Similar conventions exist for each language supported by Heroku (e.g. using
Maven for Java, Composer for PHP, Bundler for Ruby).

As for automation, it is usually achieved through [Git hooks][git-hooks]. New
versions of your application will be **automatically deployed every time you
push your latest commits**.

### How do I use a PaaS platform?

You will usually **deploy by pushing your commits to a remote Git repository**,
hosted either directly on the PaaS platform you are using, or on GitHub (or your
favorite hosting service) if the PaaS platform supports it.

Many PaaS platforms offer **free plans with restrictions**. For example, Render
lets you use one free PostgreSQL database for 90 days. You can of course whip
out your credit card and pay to use it longer, or to have more
storage/power/etc.

When you need to **configure your application**, PaaS platforms will usually
allow you to define [environment variables][env-vars] through a web interface.
These variables will be provided to your application when it is deployed.

Some PaaS platforms provide **command line tools** to help make and manage your
deployments. For example, there is the [Heroku CLI][heroku-cli] and the [Netlify
CLI][netlify-cli].

[devops]: https://en.wikipedia.org/wiki/DevOps
[env-vars]: https://en.wikipedia.org/wiki/Environment_variable
[faas]: https://en.wikipedia.org/wiki/Function_as_a_Service
[fly]: https://fly.io
[git]: https://git-scm.com
[git-hooks]: https://git-scm.com/book/gr/v2/Customizing-Git-Git-Hooks
[github]: https://github.com
[github-pages]: https://pages.github.com
[heroku]: https://www.heroku.com/home
[heroku-cli]: https://devcenter.heroku.com/articles/heroku-cli
[iaas]: https://en.wikipedia.org/wiki/Cloud_computing
[netlify]: https://www.netlify.com
[netlify-cli]: https://docs.netlify.com/cli/get-started/
[paas]: https://en.wikipedia.org/wiki/Platform_as_a_service
[render]: https://render.com
[saas]: https://en.wikipedia.org/wiki/Software_as_a_service
