---
title: How to improve our basic deployment
excerpt_separator: <!-- more -->
---

The basic SFTP deployment of the PHP TodoList has several flaws which we will
fix during the rest of the course:

- Transfering files manually through SFTP is slow and error-prone. We will use
  **Git** to reliably transfer files [from our central
  codebase][12factor-codebase] and easily keep our deployment up-to-date over
  time.
- [Hardcoding configuration is a bad practice][12factor-config]. We will use
  **environment variables** so that our application can be dynamically
  configured and deployed in any environment without changing its source code.
- Starting our application manually is not suitable for a production deployment.
  We will use a **process manager** to manage the lifecycle of our application:
  starting it automatically when the server boots, and restarting it
  automatically if it crashes.
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
- The [PHP Development Server][php-dev-server] is not meant to deploy
  applications in production environments. We will use the [**FastCGI Process
  Manager**][php-fpm] to perform a production-grade deployment, making our
  application more resilient and able to serve more clients concurrently.

[12factor-codebase]: https://12factor.net/codebase
[12factor-config]: https://12factor.net/config
[apache]: https://httpd.apache.org
[nginx]: https://www.nginx.com
[php-dev-server]: https://www.php.net/manual/en/features.commandline.webserver.php
[php-fpm]: https://www.php.net/manual/en/install.fpm.php
