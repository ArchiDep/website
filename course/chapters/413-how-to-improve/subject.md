---
title: How to improve our basic deployment
---

The basic SFTP deployment of Guess It has several flaws which we will fix during
the rest of the course.

<!-- more -->

- Transfering files manually through SFTP is slow and error-prone, all the more
  so with the hundreds of files of `node_modules`. We will use **Git** to
  reliably transfer files [from our central codebase][12factor-codebase] and
  easily keep our deployment up-to-date over time. The dependencies will be
  installed on the server instead of being uploaded.
- [Hardcoding configuration is a bad practice][12factor-config]. We will use
  **environment variables** so that our application can be dynamically
  configured and deployed in any environment without changing its source code.
- Starting our application manually is not suitable for a production deployment.
  We will use a **process manager** to manage the lifecycle of our application:
  starting it automatically when the server boots, and restarting it
  automatically if it crashes.
- We started the application with `npm run dev`, the same command as on our
  computer. It runs the application in **development mode**, with `node
--watch`, which restarts it whenever one of its files changes. That is
  convenient while you are editing the code, but not on a server. Every change
  to a file causes an **unplanned downtime**, however short, while the
  application restarts, at a moment nobody chose. A file changing halfway
  through an upload restarts the application on a half-updated version of its
  code, which may not work, or not start at all. If it crashes, it stays down
  until another file changes. We will run it in **production mode** instead,
  with `node server.js`, so that it only restarts when we decide to.
- Accessing a web application through an IP address is not user-friendly. We
  will obtain a domain and configure its DNS zone file so that our application
  is accessible with a human-readable **domain name**.
- Using a non-standard port is not user-friendly either. We will run the
  application on **port 80 or 443** so that the end user does not have to
  specify a port in the browser's address bar.
- Running our application server directly on port 80 or 443 will cause a
  problem: only one process can listen on a given port at the same time. We need
  another tool to support **multiple production deployments on the same
  server**. That will be the job of a reverse proxy like [Apache][apache] or
  [nginx][nginx].
- Our application is not secure as indicated by the browser, because it is
  served over HTTP and not HTTPS. We will obtain a **TLS/SSL certificate**
  signed by a trusted certificate authority so that our application can be
  served over HTTPS and recognized as secure by browsers.
- We deployed and ran the application with our own user account, which [can run
  any command as `root` with `sudo`, without a password][meet-your-server-sudo].
  An attacker who found a vulnerability letting them run commands through the
  application would run them as us, so they could become `root` and take over
  the whole server. We will deploy the application with a **dedicated user**
  which has no `sudo` access, and can only touch what the application needs.

[12factor-codebase]: https://12factor.net/codebase
[12factor-config]: https://12factor.net/config
[apache]: https://httpd.apache.org
[nginx]: https://www.nginx.com

[meet-your-server-sudo]: {% link chapters/405-meet-your-server/exercise.md %}#ask-sudo-what-you-may-do
