---
title: Deploy Flood It, a Spring Boot (Java) & Angular (JavaScript) application with a PostgreSQL database
cloud_server: details
excerpt_separator: <!-- more -->
graded: true
published: true
---

The goal of this exercise is to put in practice the knowledge acquired during
previous exercises to deploy a new application from scratch on your server. The
application you must deploy is a small web game. Its code is [available on
GitHub][repo].

It has two components, [a backend and a frontend][frontend-and-backend]:

- The backend is a [Java][java] web application that handles data access
  (starting games, playing moves, etc) through a [JSON][json] [API][api]. It
  provides no [User Interface (UI)][ui].
- The frontend is an HTML, JavaScript & CSS [Single-Page Application (SPA)][spa]
  that provides the [Graphical User Interface (GUI)][gui]. It makes [AJAX
  requests][ajax] to the backend.

You do not need to know the specifics of these technologies. Your goal is only
to deploy the application as indicated by the instructions. You will not need to
modify it except for a very small change at the end to test your automated
deployment.

You must deploy the provided application in a similar way as the PHP todolist in
previous exercises:

- Install the language(s) and database necessary to run the application (which
  are different than for the PHP todolist).
- Run the application as a systemd service.
- Serve the application through nginx acting as a reverse proxy.
- Provision a TLS certificate for the application and configure nginx to use it.
- Set up an automated deployment via Git hooks for this application.

Additionally:

- The application **MUST** run in production mode (see its documentation).
- The application **MUST** restart automatically if your server is rebooted
  (i.e. your systemd service must be enabled).
- The application **MUST** be accessible **only through nginx**. It **MUST NOT**
  be exposed directly on a publicly accessible port. In the cloud servers used
  in this course, ports 3000 and 3001 should be open for testing. **DO NOT** use
  these ports in the final setup.
- Clients accessing the application over HTTP **MUST** be redirected to HTTPS.

As an optional bonus challenge:

- Create a dedicated Unix user (e.g. `floodit`) other than your personal user
  (e.g. `jde`) to run the application.
- This user must be a system user, not a login user. It must not be able to log
  in with a password, although you can set up SSH public key authentication for
  the automated deployment.
- Clone the project's repository with the dedicated user instead of your
  personal user.
- Configure systemd to run the application as the dedicated user instead of your
  personal user.
- Set up the automated deployment with the dedicated user instead of your
  personal user.
- Use the application's local configuration file instead of environment
  variables (see its documentation), and set up file/directory permissions so
  that only the dedicated user has access to the configuration file (the `root`
  user will of course have access as well).

<!-- more -->

## :exclamation: Getting started

{% callout type: exercise %}

The [project's README][readme] explains how to set up and run the application.
That README is generic: it is not written specifically for this course or this
exercise.

The instructions on **this page** explain the exercise step-by-step.

The instructions in the project's README will be useful to you at various
points, but be careful not to blindly copy-paste and execute commands from it
without understanding what you are doing in the context of the exercise.

{% endcallout %}

{% callout type: more, id: floodit-technologies %}

What the hell are Spring Boot, Angular & PostgreSQL? Flood It uses the following
~~buzzword salad~~ technologies:

- The backend has been developed with [Spring Boot][spring-boot], a Java
  framework that makes it easy to create stand-alone, production-grade Spring
  based applications that you can "just run".
  - [Java][java] is a popular programming language and development platform. It
    reduces costs, shortens development timeframes, drives innovation, and
    improves application services. With millions of developers running more than
    60 billion Java Virtual Machines worldwide, Java continues to be the
    development platform of choice for enterprises and developers.
  - [Spring][spring] makes programming Java quicker, easier, and safer for
    everybody. Spring's focus on speed, simplicity, and productivity has made it
    the world's most popular Java framework.
- The frontend has been developed with [Angular][angular], a [JavaScript][js]
  application-design framework and development platform for creating efficient
  and sophisticated single-page apps. It also uses [Tailwind][tailwind], a
  utility-first CSS framework packed with classes that can be composed to build
  any design, directly in your markup.

- [PostgreSQL][postgres] is a powerful, open source object-relational database
  system with over 30 years of active development that has earned it a strong
  reputation for reliability, feature robustness, and performance.

{% endcallout %}

### :exclamation: Fork the repository

You must [fork][fork] the [application's repository][repo] to your own GitHub
account, because this exercise requires that you make changes to the application
later, after setting up the automated deployment with Git hooks.

{% note type: warning %}

On your local machine, use your **own** repository's **SSH** clone URL. This way
you will have push access to your repository.

On your Azure VM, use your **own** repository's **HTTPS** clone URL. Since the
repository is public, you will be able to clone it without authentication. You
will not need push access on your server.

{% endnote %}

### :exclamation: Install the requirements

Start by making sure you have installed all the requirements described in the
[project's README][readme] on your server:

- **How to install Java:** there are several methods to install Java. Java was
  originally developed by [Sun Microsystems][sun] and now by [Oracle][oracle],
  but there are also free, open source implementations. We suggest you use
  [OpenJDK][openjdk], one of the most popular open source implementations
  originally released by Sun.

  The OpenJDK publishes easy-to-install APT packages. You can list them with:

  ```bash
  $> apt search openjdk-
  ```

  You should install a package named `openjdk-<version>-jdk` where `<version>`
  is the Java version required by the Flood It application.

- **How to install Maven:** you can simply install it with APT as well:

  ```bash
  $> sudo apt install maven
  ```

{% note type: tip %}

If you prefer not to run a strange script from the Internet on your server, you
can also read [the
script](https://github.com/ArchiDep/floodit/blob/main/maven-install.sh) and
execute the commands yourself.

{% endnote %}

- **How to install Node.js:** there are several methods to install Node.js. One
  of the simplest is to use the [binary distributions provided by
  NodeSource][node-install]. You should look for installation instructions
  specific to Ubuntu, the Linux distribution used on your server. If possible,
  you should find instructions for the apt package manager (using the `apt` or
  `apt-get` command).
- **How to install PostgreSQL:** you can follow the official instructions on the
  Downloads page of the [PostgreSQL website][postgres]. You should look for
  installation instructions specific to Ubuntu, the Linux distribution used on
  your server.

#### :question: Optional: check that everything has been correctly installed

You can check that **Java has been correctly installed** by displaying the
version of the `java` command:

```bash
$> java --version
openjdk version "25" 2025-09-16
OpenJDK Runtime Environment (build 25+36-Ubuntu-124.04.2)
OpenJDK 64-Bit Server VM (build 25+36-Ubuntu-124.04.2, mixed mode, sharing)
```

{% note type: tip %}

It's not a problem if you don't have this exact version installed, as long as
you have a version compatible with the Flood It application's requirements.

{% endnote %}

You can check that **Maven has been correctly installed** by displaying the
version of the `mvn` command:

```bash
$> mvn --version
Apache Maven 3.8.7
Maven home: /usr/share/maven
Java version: 25, vendor: Ubuntu, runtime: /usr/lib/jvm/java-25-openjdk-amd64
Default locale: en_US, platform encoding: UTF-8
OS name: "linux", version: "6.14.0-1014-azure", arch: "amd64", family: "unix"
```

{% note type: tip %}

It's not a problem if you don't have this exact version installed, as long as
you have a version compatible with the Flood It application's requirements.

{% endnote %}

You can check that **Node.js has been correctly installed** by displaying the
version of the `node` command:

```bash
$> node --version
v24.11.0
```

{% note type: tip %}

It's not a problem if you don't have this exact version installed, as long as
you have a version compatible with the Flood It application's requirements.

{% endnote %}

You can also check that Node.js is working correctly by running the following
command:

```bash
$> node -e 'console.log(1 + 2)'
3
```

You can check that **PostgreSQL has been correctly installed** by displaying the
version of the `psql` command:

```bash
$> psql --version
psql (PostgreSQL) 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
```

{% note type: tip %}

It's not a problem if you don't have this exact version installed, as long as
you have a version compatible with the Flood It application's requirements.

{% endnote %}

You can also verify that PostgreSQL is running by showing the status of its
systemd service:

```bash
$> sudo systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
     Loaded: loaded (/usr/lib/systemd/system/postgresql.service; enabled; preset: enabled)
     Active: active (exited) since Thu 2025-11-20 18:20:52 UTC; 6 days ago
   Main PID: 1155 (code=exited, status=0/SUCCESS)
        CPU: 5ms

Nov 20 18:20:52 soy.archidep.ch systemd[1]: Starting postgresql.service - PostgreSQL RDBMS...
Nov 20 18:20:52 soy.archidep.ch systemd[1]: Finished postgresql.service - PostgreSQL RDBMS.
```

You can also verify that PostgreSQL is working by listing available databases,
also with the `psql` command:

```bash
$> sudo -u postgres psql -l
                              List of databases
   Name    |  Owner   | Encoding | Collate |  Ctype  |   Access privileges
-----------+----------+----------+---------+---------+-----------------------
 postgres  | postgres | UTF8     | C.UTF-8 | C.UTF-8 |
 template0 | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =c/postgres          +
           |          |          |         |         | postgres=CTc/postgres
 template1 | postgres | UTF8     | C.UTF-8 | C.UTF-8 | =c/postgres          +
           |          |          |         |         | postgres=CTc/postgres
(3 rows)
```

{% note type: more %}

Note that **PostgreSQL runs on port 5432 by default**, which you can verify
by checking the `port` setting in its configuration file:

```bash
$> cat /etc/postgresql/*/main/postgresql.conf | grep '^port'
port = 5432
```

{% endnote %}

### :exclamation: Perform the initial setup

You must perform the **initial setup** instructions indicated in the [project's
README][readme].

{% note type: warning %}

Since you will need to commit and push changes later, **DO NOT** use the
`https://github.com/ArchiDep/floodit.git` URL to clone the repository as
suggested in the README. That repository belongs to the course. **Use your own
fork's HTTPS clone URL**.

{% endnote %}

{% note type: tip %}

When you reach the step where you need to "Configure the application", you will
see that the Flood It application has two configuration mechanisms: environment
variables or a local configuration file. You can use either one of them. It does
not matter which you choose. Both are equally valid way of configuring the
application.

If you choose to use environment variables, you will need to provide these
environment variables through systemd later, as you have done with the PHP
todolist. The `export` sample commands provided in the README are only examples
and will only set the variables in the shell and SSH session where you run them.

{% endnote %}

{% callout type: more, id: floodit-techs %}

What sorcery is this? Read this section if you want to understand what you have
done/installed so far.

The backend of the Flood It application is written in Java. You are using the
Java Virtual Machine (JVM), Java Runtime Environment (JRE) and Java Development
Kit (JDK).

When you write a program in Java, your source code is compiled to produce [byte
code][java-bytecode] that can be run in a [Java Virtual Machine (JVM)][jvm].
This is what makes Java [cross-platform][cross-platform]: any system that has a
JVM can run Java byte code compiled on any other system. There are JVM
implementations for all major operating systems and processor architectures.

The [Java Runtime Environment (JRE)][java-jdk-jre] is a software package that
you can install on your favorite operating system (e.g. Linux, macOS, Windows)
that provides a JVM. It contains everything you need to run already compiled
Java programs (i.e. Java byte code, often distributed in the form of [JAR
files][jar]).

The [Java Development Kit (JDK)][jdk] is a software development kit that
includes the JRE but also everything you need to compile Java programs into Java
byte code. You will use it to compile the backend of the Flood It application.

**:books: The PostgreSQL `createuser` and `createdb` commands**

The setup instructions use the `createuser` and `createdb` commands. These
commands are binaries that come with the PostgreSQL server and can be used to
manage PostgreSQL users and databases on the command line:

- The **`createuser --interactive --pwprompt floodit` command** creates a
  PostgreSQL user named "floodit" and asks you to define a password for that
  user. The application will use this PostgreSQL username and password to
  connect to the database.
- The **`createdb --owner floodit floodit` command** creates an empty PostgreSQL
  database named "floodit" and owned by the "floodit" user. This is the database
  that the application will use.

  You can see this new database by listing all available databases:

  ```bash
  $> sudo -u postgres psql -l
                                              List of databases
    Name    |  Owner   | Encoding | Collate |  Ctype  | ICU Locale | Locale Provider |   Access privileges
  -----------+----------+----------+---------+---------+------------+-----------------+-----------------------
  floodit   | floodit  | UTF8     | C.UTF-8 | C.UTF-8 |            | libc            |
  ...
  ```

These database setup commands are equivalent to [part of the `todolist.sql`
script](https://github.com/ArchiDep/php-todo-ex/blob/e073e769c7c6eb0d8bf3c1fa7a55f174b5a262e4/todolist.sql#L1-L7)
you executed when first deploying the PHP todolist.

If you prefer using SQL, you could instead connect to the database as the
`postgres` user (equivalent to MySQL's `root` user) with `sudo -u postgres psql`
and run equivalent [`CREATE USER`](https://www.postgresql.org/docs/current/sql-createuser.html) and [`CREATE DATABASE`](https://www.postgresql.org/docs/current/sql-createdatabase.html)
queries.

Note that on the command line, PostgreSQL uses [peer
authentication](https://www.postgresql.org/docs/13/auth-peer.html) based on the
Unix username by default. This is why the commands are prefixed with `sudo -u postgres` to execute them as the `postgres` Unix user. This user was created
when you installed PostgreSQL and has administrative privileges on the entire
PostgreSQL cluster. You can verify the existence of this user with the command
`cat /etc/passwd | grep postgres`.

**:books: The `mvn` command**

The setup instructions use the **`mvn` command**. [Maven][mvn] is a software
project management tool for the [Java][java] ecosystem, much like
[Composer][composer] for [PHP][php] or [npm][npm] for [Node.js][node].

- A Maven project has one or several **P**roject **O**bject **M**odel (POM)
  files. These `pom.xml` files describe a project's dependencies and how to
  build it (you can look at the Flood It application's `backend/pom.xml` file as
  an example).
- The **`mvn clean install -Pskip-test` command** is used to:
  - Download all of the Flood It application's dependencies (i.e. the Java
    libraries it requires to work), like the [Spring Boot][spring-boot] web
    framework. Spring Boot is a web framework written in [Java][java] much
    like [Laravel][laravel] is a web framework written in [PHP][php].

    The dependencies are downloaded from [Maven Central][mvn-central], the main
    package registry for the Java ecosystem, and saved into the `~/.m2`
    directory (in your home directory).

  - Build the application (i.e. compile the Java source code into JVM bytecode).
  - Install the application into the local Maven repository.

**:books: Node.js**

[Node.js][node] is an open source, cross-platform JavaScript runtime
environment. Where JavaScript could traditionally only run in a browser, Node.js
allows you to run JavaScript code on any machine, like on your Azure VM, just
like you would any other dynamic programming language like PHP, Ruby or Python.

**:books: The `npm` command**

The setup instructions use the **`npm` command**. [npm][npm] is the world's
largest software registry for the [JavaScript][js] and [Node.js][node]
ecosystems. The `npm` command can be used to install and manage JavaScript
packages, much like [Composer][composer] for [PHP][php] or [Maven][mvn] for
[Java][java]

**:books: The configuration of the Flood It application**

The configuration you are instructed to perform either through environment
variables or through the `backend/config/application-default.local.yml` file is
equivalent to the [configuration of the PHP
todolist](https://github.com/ArchiDep/php-todo-ex/blob/e073e769c7c6eb0d8bf3c1fa7a55f174b5a262e4/index.php#L3-L14)
which you improved during the course using environment variables. It is not
uncommon for applications to provide multiple configuration mechanisms, letting
you choose which is more convenient for you.

{% endcallout %}

### :question: Optional: run the automated tests

The Flood It application includes an automated test suite. [Automated
tests][automated-tests] are programs that check that the application works by
simulating input and checking output. They are not a replacement for manual
testing by humans, but programs can test mundane, repetitive tasks much faster
and much more reliably than a human can.

The [project's README][readme] explains how to set up and run the automated
tests.

Running these tests is entirely optional, but it will make sure that everything
is working properly, including that:

- The application executes correctly with the Java Runtime Environment (JRE) you
  have installed.
- The application can successfully connect to and migrate the database.
- The application behaves as specified.

Running the tests might take a minute or two, then the following output should
be displayed, indicating that all tests were successful:

```
...
[INFO]
[INFO] Results:
[INFO]
[INFO] Tests run: 19, Failures: 0, Errors: 0, Skipped: 0
[INFO]
[INFO]
[INFO] --- jacoco-maven-plugin:0.8.8:report (jacoco-site) @ floodit ---
[INFO] Loading execution data file /home/jde/floodit/backend/target/jacoco.exec
[INFO] Analyzed bundle 'floodit' with 19 classes
[INFO]
[INFO] ------------------< ch.comem.archidep:floodit-parent >------------------
[INFO] Building floodit-parent 1.0.0                                      [2/2]
[INFO] --------------------------------[ pom ]---------------------------------
[INFO]
[INFO] --- maven-clean-plugin:2.5:clean (default-clean) @ floodit-parent ---
[INFO] ------------------------------------------------------------------------
[INFO] Reactor Summary:
[INFO]
[INFO] floodit 1.0.0-SNAPSHOT ............................. SUCCESS [ 34.216 s]
[INFO] floodit-parent 1.0.0 ............................... SUCCESS [  0.069 s]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  34.789 s
[INFO] Finished at: 2022-11-24T09:51:34Z
[INFO] ------------------------------------------------------------------------
```

{% note type: more %}

If you are curious, the source code for these tests is in [the
`backend/src/test`
directory](https://github.com/ArchiDep/floodit/tree/main/backend/src/test/java/ch/comem/archidep/floodit).

{% endnote %}

### :question: Optional: run the application in development mode

Before running the application in production mode and attempting to set up the
systemd service, nginx configuration and automated deployment, you can manually
run the application in development mode to make sure it works. The [project's
README][readme] explains how to do this. You will need two terminals connected
to your server: one to run the backend, and one to run the frontend.

You can run the frontend application on port `3001` for this simple test, as
that is one of the ports that should be open in your server's firewall. You must
also make it available to external clients. The [project's README][readme]
explains how to do this.

Once you have both backend and frontend running in your two terminals, you
should be able to visit http://W.X.Y.Z:3001 to check that the application works
(replacing `W.X.Y.Z` by your server's IP address). Stop both components by
typing `Ctrl-C` once you are done.

### :exclamation: Run the application in production mode

Follow the instructions in the [project's README][readme] to run the application
in production mode.

{% callout type: more, id: floodit-production-mode %}

To run a Maven project in production, you must install it (i.e. the `mvn clean
install` command), which will create a JAR file. This is basically a ZIP file of
the compiled Java application, which can be run by any Java Virtual Machine
(JVM). Once you have created that JAR file, you could copy it to any system that
has the Java Runtime Environment (JRE) and run it there. The Java Development
Kit (JDK) is only required to perform the compilation.

The `npm run build` command used in the instructions bundles the frontend's
files in production mode, compressing and digesting them. To "digest" a web
asset is to include a hash of its contents in the file name [for the purposes of
caching][webpack-caching]. This optimizes the delivery of web assets to browsers
especially when they come back to your website after having already visited
once.

You can list the `frontend/dist/browser` directory to see the digested assets:
`ls frontend/dist/browser`. Observe that a file named `main-CE7IO7ZI.js` (the
hash may differ) has appeared. The hash part of the file name (`CE7IO7ZI` in
this case) depends on the content. When the content changes, the hash changes.
This means you can instruct client browsers to cache web assets indefinitely,
since you know that an asset's name will not change as long as its content does
not change as well and, conversely, that an asset's name will always change if
it has been modified.

{% endcallout %}

## :exclamation: Create a systemd service

Create and enable a systemd unit file like in the [systemd exercise]({% link
_course/506-systemd-deployment/exercise.md %}). Make the necessary changes to
run the Flood It application instead of the PHP todolist.

{% note type: tip %}

You will find the correct command to run the application in [the project's
`README`][readme]. Remember that systemd requires absolute paths to commands.
You can use `which <command>` to determine where a command is.

{% endnote %}

{% note type: tip %}

You may need to set the `FLOODIT_SERVER_PORT` environment variable or the
`server.port` parameter in the local configuration file to choose the port on
which the application will listen. You can use the publicly accessible 3001 port
temporarily for testing, but you should use another free port that is not
exposed to complete the exercise, since one of the requirements is to expose the
application only through nginx.

{% endnote %}

Once you have enabled and started the service, it should start automatically the
next time you restart the server with `sudo reboot`.

{% note type: advanced %}

If you know what you are doing, you can already set up the automated deployment
project structure at this point, so that you can point your systemd
configuration to the correct directory. That way you will not have to modify it
later.

{% endnote %}

## :exclamation: Serve the application through nginx

Create an nginx proxy configuration to serve the application like in the [nginx
PHP-FPM exercise]({% link _course/512-nginx-php-fpm-deployment/exercise.md %}).

The [`root` directive][nginx-root] in your nginx configuration should point to
the directory that contains the static web assets of the application's compiled
frontend (this is documented in [the README][readme-production]).

{% note type: tip %}

Use an absolute path for the `root` directive. Do not follow steps related to
PHP-FPM, since they are only valid for a PHP application.

The `include` and `fastcgi_pass` directives used in the PHP-FPM exercise make no
sense for a non-PHP application. You should replace them with a [`proxy_pass`
directive](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass),
as [presented during the course]({% link _course/509-reverse-proxy/subject.md
%}#reverse-proxy-configuration).

Similarly to the [multi-component exercise]({% link
_course/511-revprod-deployment/exercise.md %}), you will need to define multiple
locations because the application is in two parts:

- A frontend with compiled static files. There is no port here; there are simply
  files to serve like in the [static deployment exercise]({% link
  _course/510-nginx-static-deployment/exercise.md %}). For this location, you
  might want to use the [`try_files` directive][nginx-try-files]:

  ```
  try_files $uri $uri/ /index.html =404;
  ```

- A backend which listens on a port (that you configured) and responds to
  requests under the `/api` path. This location is where you want to use
  `proxy_pass`.

{% endnote %}

{% note type: advanced %}

You can also point the nginx configuration directly to the automated deployment
structure. That way you will not have to modify it later.

{% endnote %}

## :exclamation: Provision a TLS certificate

Obtain and configure a TLS certificate to serve the application over HTTPS like
in the [certbot exercise]({% link _course/514-certbot-deployment/exercise.md
%}).

## :exclamation: Set up an automated deployment with Git hooks

Change your deployment so that the application can be automatically updated via
a Git hook like in the [automated deployment exercise]({% link
_course/602-git-automated-deployment/exercise.md %}).

Once you have set up the new directories, make sure to update your systemd unit
file and nginx configuration file to point to the correct directories.

Because the new directory is a fresh deployment, you may have to repeat part of
the [initial setup][initial-setup] you performed in the original directory. The
PostgreSQL user, database and extension have already been created, and your hook
will handle most of the rest of the setup. But if you used the
`backend/config/application-default.local.yml` configuration file, you must copy
it to the new deployment directory as well. You can use the `cp <source> <target>` command for this.

Complete the `post-receive` hook. Compared to the PHP todolist, there are
additional steps which must be performed in the script for the automated
deployment to work correctly:

- Frontend dependencies must be updated in case there are new or upgraded ones.
  The PHP todolist had no dependencies so you did not need to do this.

{% note type: more %}

The backend dependencies of the Flood It application must also be updated, but
Maven will do this for you automatically.

{% endnote %}

- The Angular frontend must be rebuilt in case changes were made to the
  frontend source files.
- The backend application must be rebuilt in case changes were made to the
  source files.
- The systemd service must be restarted with `systemctl`.

{% note type: more %}

Unlike PHP, code in most other languages is not reinterpreted on-the-fly; the
service must be restarted so that the program is reloaded into memory as a new
process).

{% endnote %}

The [project's README][readme] explains how to do all of this except restarting
the systemd service, which you can easily do with `sudo systemctl restart <service>`. You should run the appropriate commands in your `post-receive` hook
script.

### :question: Allowing your user to restart the service without a password

In order for the new `post-receive` hook to work, your user must be able to run
`sudo systemctl restart floodit` (assuming you have named your service
`floodit`) without entering a password, otherwise it will not work in a Git
hook.

{% note type: more %}

This is because a Git hook is not an interactive program. You are not running it
yourself, so you are not available to enter your password where prompted.

{% endnote %}

If you are using the administrator user account that came with your Azure VM to
run the application, it already has the right to use `sudo` without a password.

{% note type: more %}

This has been automatically configured for you in the
`/etc/sudoers.d/90-cloud-init-users` file.

{% endnote %}

### :space_invader: Allowing the dedicated `floodit` Unix user to control the systemd service

If you are trying to complete the bonus challenge, you will need to allow the
`floodit` user run the necessary `sudo systemctl ...` commands without a
password as well.

Make sure your default editor is `nano` (or whichever you are more comfortable
with):

```bash
$> sudo update-alternatives --config editor
```

When you created the `floodit` Unix user, your server created a corresponding
Unix group with the same name by default. Now you will add a file in the
`/etc/sudoers.d` directory to allow users in the `floodit` Unix group to run
some specific commands without a password.

```bash
$> sudo visudo -f /etc/sudoers.d/floodit
```

{% note type: more %}

The [`visudo` command][visudo] allows you to edit the sudoers file in a safe
fashion. It will refuse to save a sudoers file with a syntax error (which could
potentially corrupt your system or lock you out of your administrative
privileges).

{% endnote %}

Add the following line to the file:

```
%floodit ALL=(ALL:ALL) NOPASSWD: /bin/systemctl restart floodit, /bin/systemctl status floodit, /bin/systemctl start floodit, /bin/systemctl stop floodit
```

{% note type: more %}

This line allows any user in the `floodit` group to execute the listed commands
with `sudo` without having to enter a password (hence the `NOPASSWD` option).

{% endnote %}

Exit with `Ctrl-X` if you are using nano or with Esc then `:wq` if you are using
Vim.

{% note type: tip %}

If you are using nano, the file name you are asked to confirm will be
`/etc/sudoers.d/floodit.tmp` instead of `/etc/sudoers.d/floodit`. This is
normal, because `visudo` uses a temporary file to validate your changes before
saving the actual file. You may confirm without changes.

{% endnote %}

You can test that it works by first switching to the `floodit` user with `sudo
su - floodit` and then running `sudo systemctl status floodit`. It should run
the command without asking you for any password (only for the specific commands
listed in the file your created).

### :exclamation: Test the automated deployment

Clone your fork of the repository to your local machine, make sure you have
added a remote pointing to your server, then commit and push a change to test
the automated deployment.

Here's some visible changes you could easily make:

- Change the [navbar title in the
  `frontend/src/app/layout/navbar/navbar.component.html`
  file](https://github.com/ArchiDep/floodit/blob/04cf2bdad154aae574d974d7984d8d19e4dcb504/frontend/src/app/layout/navbar/navbar.component.html#L3).
- Change the [difficulty levels in the
  `frontend/src/app/pages/dashboard/dashboard.component.html`
  file](https://github.com/ArchiDep/floodit/blob/04cf2bdad154aae574d974d7984d8d19e4dcb504/frontend/src/app/pages/dashboard/dashboard.component.html#L7-L38).

## :checkered_flag: What have I done?

You have deployed a new backend/frontend web application to your server from
scratch, using the knowledge you acquired during previous deployment exercises.

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.
Note that some of these errors can happen in various situations:

- When running a command manually from your terminal.
- When systemd tries to start your service.
- When your `post-receive` Git hook executes.

### :boom: I see warnings when running Maven

If you see these warnings every time you run a `mvn` command:

```
WARNING: A terminally deprecated method in sun.misc.Unsafe has been called
WARNING: sun.misc.Unsafe::objectFieldOffset has been called by com.google.common.util.concurrent.AbstractFuture$UnsafeAtomicHelper (file:/usr/share/maven/lib/guava.jar)
WARNING: Please consider reporting this to the maintainers of class com.google.common.util.concurrent.AbstractFuture$UnsafeAtomicHelper
WARNING: sun.misc.Unsafe::objectFieldOffset will be removed in a future release
```

You can ignore them. This is due to an incompatibility between some internal
libraries used by the Flood It application. You don't have to worry about it and
it will not prevent the application from working.

### :boom: Daemons using outdated libraries

When you install a package with APT (e.g. MySQL), it _may_ prompt you to
reboot and/or to restart outdated daemons (i.e. background services):

![Restart outdated daemons](./images/apt-outdated-daemons.png)

Simply select "Ok" by pressing the Tab key, then press Enter to confirm.

{% callout type: more, id: apt-outdated-daemons %}

This happens because most recent Linux versions have [unattended
upgrades](linux-unattended-upgrades): a tool that automatically installs daily
security upgrades on your server without human intervention. Sometimes, some of
the background services running on your server may need to be restarted for
these upgrades to be applied.

Since you are installing a new background service (the MySQL server) which must
be started, APT asks whether you want to apply upgrades to other background
services by restarting them. Rebooting your server would also have the effect of
restarting these services and applying the security upgrades.

{% endcallout %}

### :boom: No plugin found for prefix 'spring-boot' in the current project

If you get an error similar to this when running the `mvn` command:

```
$> mvn spring-boot:run
[INFO] Scanning for projects...
Downloading from central: https://repo.maven.apache.org/maven2/org/codehaus/mojo/maven-metadata.xml
Downloading from central: https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-metadata.xml
Downloaded from central: https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-metadata.xml (14 kB at 26 kB/s)
Downloaded from central: https://repo.maven.apache.org/maven2/org/codehaus/mojo/maven-metadata.xml (21 kB at 36 kB/s)
[INFO] ------------------------------------------------------------------------
[INFO] BUILD FAILURE
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  1.467 s
[INFO] Finished at: 2022-11-24T11:27:45Z
[INFO] ------------------------------------------------------------------------
[ERROR] No plugin found for prefix 'spring-boot' in the current project and in the plugin groups [org.apache.maven.plugins, org.codehaus.mojo] available from the repositories [local (/home/jde/.m2/repository), central (https://repo.maven.apache.org/maven2)] -> [Help 1]
[ERROR]
[ERROR] To see the full stack trace of the errors, re-run Maven with the -e switch.
[ERROR] Re-run Maven using the -X switch to enable full debug logging.
[ERROR]
[ERROR] For more information about the errors and possible solutions, please read the following articles:
[ERROR] [Help 1] http://cwiki.apache.org/confluence/display/MAVEN/NoPluginFoundForPrefixException
```

It means that you are running the command in the wrong directory. Maven requires
a `pom.xml` file to know what to do. You must be sure to run the `mvn` command
in a directory that contains this `pom.xml` file, i.e. in the repository of the
Flood It application that you cloned.

### :boom: FATAL: password authentication failed for user "floodit"

If you see an error similar to this when starting the application or running the
automated tests:

```
SQL State  : 28P01
Error Code : 0
Message    : FATAL: password authentication failed for user "floodit"

        at org.flywaydb.core.internal.jdbc.JdbcUtils.openConnection(JdbcUtils.java:60) ~[flyway-core-8.5.13.jar:na]
        at org.flywaydb.core.internal.jdbc.JdbcConnectionFactory.<init>(JdbcConnectionFactory.java:75) ~[flyway-core-8.5.13.jar:na]
        at org.flywaydb.core.FlywayExecutor.execute(FlywayExecutor.java:147) ~[flyway-core-8.5.13.jar:na]
        at org.flywaydb.core.Flyway.migrate(Flyway.java:124) ~[flyway-core-8.5.13.jar:na]
        at org.springframework.boot.autoconfigure.flyway.FlywayMigrationInitializer.afterPropertiesSet(FlywayMigrationInitializer.java:66) ~[spring-boot-autoconfigure-2.7.4.jar:2.7.4]
        at org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.invokeInitMethods(AbstractAutowireCapableBeanFactory.java:1863) ~[spring-beans-5.3.23.jar:5.3.23]
        at org.springframework.beans.factory.support.AbstractAutowireCapableBeanFactory.initializeBean(AbstractAutowireCapableBeanFactory.java:1800) ~[spring-beans-5.3.23.jar:5.3.23]
        ... 18 common frames omitted
Caused by: org.postgresql.util.PSQLException: FATAL: password authentication failed for user "floodit"
        at org.postgresql.core.v3.ConnectionFactoryImpl.doAuthentication(ConnectionFactoryImpl.java:646) ~[postgresql-42.3.7.jar:42.3.7]
        at org.postgresql.core.v3.ConnectionFactoryImpl.tryConnect(ConnectionFactoryImpl.java:180) ~[postgresql-42.3.7.jar:42.3.7]
        at org.postgresql.core.v3.ConnectionFactoryImpl.openConnectionImpl(ConnectionFactoryImpl.java:235) ~[postgresql-42.3.7.jar:42.3.7]
        at org.postgresql.core.ConnectionFactory.openConnection(ConnectionFactory.java:49) ~[postgresql-42.3.7.jar:42.3.7]
        at org.postgresql.jdbc.PgConnection.<init>(PgConnection.java:223) ~[postgresql-42.3.7.jar:42.3.7]
        at org.postgresql.Driver.makeConnection(Driver.java:402) ~[postgresql-42.3.7.jar:42.3.7]
        at org.postgresql.Driver.connect(Driver.java:261) ~[postgresql-42.3.7.jar:42.3.7]
        at com.zaxxer.hikari.util.DriverDataSource.getConnection(DriverDataSource.java:138) ~[HikariCP-4.0.3.jar:na]
        at com.zaxxer.hikari.pool.PoolBase.newConnection(PoolBase.java:364) ~[HikariCP-4.0.3.jar:na]
        at com.zaxxer.hikari.pool.PoolBase.newPoolEntry(PoolBase.java:206) ~[HikariCP-4.0.3.jar:na]
        at com.zaxxer.hikari.pool.HikariPool.createPoolEntry(HikariPool.java:476) ~[HikariCP-4.0.3.jar:na]
        at com.zaxxer.hikari.pool.HikariPool.checkFailFast(HikariPool.java:561) ~[HikariCP-4.0.3.jar:na]
        at com.zaxxer.hikari.pool.HikariPool.<init>(HikariPool.java:115) ~[HikariCP-4.0.3.jar:na]
        at com.zaxxer.hikari.HikariDataSource.getConnection(HikariDataSource.java:112) ~[HikariCP-4.0.3.jar:na]
        at org.flywaydb.core.internal.jdbc.JdbcUtils.openConnection(JdbcUtils.java:48) ~[flyway-core-8.5.13.jar:na]
        ... 24 common frames omitted
```

It means that the Flood It application or its automated tests cannot connect to
the database:

- Are you sure that you followed all the setup instructions and performed all
  necessary configuration?
- Did you properly create the `floodit` PostgreSQL user and database?
- If you are attempting to run the application in development mode, did you
  properly configure the database connection with the `$FLOODIT_DATABASE_*`
  environment variable or via the `backend/config/application-default.local.yml`
  file?
- If you are attempting to run the automated tests, did you properly configure
  the database connection with the `$FLOODIT_TEST_DATABASE_*` environment
  variable or via the `backend/config/application-test.local.yml` file?
- Are you using the correct password?

{% note %}

Just like the PHP todolist required the correct configuration to successfully
connect to its MySQL database, the Flood It application also requires the
correct configuration to connect to its PostgreSQL database.

{% endnote %}

### :boom: Web server failed to start. Port 3000 was already in use.

If you see an error similar to this when running the application:

```
***************************
APPLICATION FAILED TO START
***************************

Description:

Web server failed to start. Port 3000 was already in use.

Action:

Identify and stop the process that's listening on port 3000 or configure this application to listen on another port.
```

It means that there is already an application or other process listening on the
port the Flood It backend is trying to listen on (port `3000` by default). You
should use the `$FLOODIT_SERVER_PORT` environment variable or the `server.port`
parameter in the local configuration file to change the port, for example if you
are trying to run the application in development mode:

```bash
$> FLOODIT_SERVER_PORT=3001 mvn spring-boot:run
```

### :boom: `remote: sudo: no tty present and no askpass program specified`

If you see an error message similar to this when your Git hook is triggered:

```
remote: sudo: no tty present and no askpass program specified
```

It means that you have created a dedicated Unix user but you have not performed
the following step correctly: [Allowing the dedicated `floodit` Unix user to
control the systemd
service](#space_invader-allowing-the-dedicated-floodit-unix-user-to-control-the-systemd-service).

Make sure that the list of authorized `systemctl` commands in the sudoers file
match the name of your service (if you named your systemd configuration file
something other than `floodit.service`, you must adapt the commands in the
`/etc/sudoers.d/floodit` file to use the correct service name).

{% callout type: more, id: sudo-systemctl-no-tty %}

This error occurs because ordinarily, a Unix user does not have the right to
execute `sudo systemctl restart floodit` without entering their password to gain
administrative rights. A Git hook is executed in a non-interactive context: it
can only print information, and you cannot interact with it (e.g. give it input)
while it is running. This means that it cannot ask for your password, so any
`sudo` command will fail by default.

This is what the error message indicates: `no tty present` means that there is
no interactive terminal (`tty` comes from the terminology of the 1970s: it means
a **t**ele**ty**pewriter, which was one of the first terminals).

The linked instructions above grant the user the right to execute specific
`sudo` commands (like `sudo systemctl restart floodit`) without having to enter
your password. Once that is done, these commands will work from the Git hook as
well.

{% endcallout %}

### :boom: `code=exited, status=200/CHDIR`

If you see an error message similar to this in your systemd service's status:

```
code=exited, status=200/CHDIR
```

It means that systemd failed to move into the directory you specified (`CHDIR`
means **ch**ange **dir**ectory). Check your systemd unit file to make sure that
the working directory you have configured is the correct one and really exists.

### :boom: `502 Bad Gateway`

If you get a [502 Bad Gateway][http-502] error in your browser when trying to
access an nginx site you have configured, it means that you have reached nginx,
but that nginx could not reach the proxy address you have configured. The proxy
address is defined with the [`proxy_pass` directive][nginx-proxy-pass] in that
site's configuration file.

Are you sure that your nginx configuration, namely the proxy address, is
correct? Check to make sure you are using the correct address and port. Is your
application actually listening on that port?

### :boom: I forgot to fork the Flood It repository and I have already cloned it

You may have cloned the exercise's repository directly:

```bash
$> git remote -v
origin  https://github.com/ArchiDep/floodit.git (fetch)
origin  https://github.com/ArchiDep/floodit.git (push)
```

Then you won't have push access because this repository does not belong to you.
[Fork][fork] the repository, then change your clone's remote URL by running this
command in your clone's directory on the server (replacing `MyGitHubUser` with
your GitHub username):

```bash
$> git remote set-url origin https://github.com/MyGitHubUser/floodit.git
```

### :boom: I don't remember the password I used for the `floodit` PostgreSQL user

You can change it with the following command:

```bash
$> sudo -u postgres psql -c '\password floodit'
```

### :boom: System debugging

You can display the last few lines of the logs of your `floodit` systemd
service with the following command:

```bash
$> sudo systemctl status floodit
```

If you need more details, you can display the full logs with the following
command:

```bash
$> sudo journalctl -u floodit
```

{% note type: tip %}

You can scroll in `journalctl` logs using the up/down arrow keys, jump directly
to the bottom with `Shift-G` (uppercase G), or back to the top with `G`
(lowercase g). Exit with `Q` or `Ctrl-C`.

{% endnote %}

If the application does not seem to work after running the systemd service,
there might be an error message in these logs that can help you identify the
issue.

### :boom: PostgreSQL debugging

You can list available databases with the following command:

```bash
$> sudo -u postgres psql -l
```

You can connect to a database with the following command:

```bash
$> sudo -u postgresql psql <database-name>
floodit=#
```

Note that the prompt has changed, because you are now connected to the
interactive PostgreSQL console. You can obtain help by typing the `\?` command
(`q` to exit the help page), or type SQL queries. For example, here's how to
list the tables in the current database and count the number of rows in the
`games` table:

```
floodit=# \d
                 List of relations
 Schema |         Name          |   Type   | Owner
--------+-----------------------+----------+--------
 public | flyway_schema_history | table    | floodit
 public | games                 | table    | floodit
 public | games_id_seq          | sequence | floodit
 public | moves                 | table    | floodit
 public | moves_id_seq          | sequence | floodit
(5 rows)

floodit=# select count(*) from games;
 count
-------
     2
(1 row)
```

Run the `exit` command when you are done to exit the PostgreSQL console.

### :boom: Updating your fork of the repository

If changes (e.g. bugfixes) are made to the original repository after you have
started the exercise, these changes will not automatically be included into your
fork of the repository. You can follow this procedure to update it.

**On your local machine:**

```bash
# Clone your fork of the Flood It repository on your local machine (replace
# MyGitHubUser by your GitHub username)
cd /path/to/projects
git clone git@github.com:MyGitHubUser/floodit.git
cd floodit

# Add a remote to the original repository
git remote add upstream https://github.com/ArchiDep/floodit.git

# Fetch the latest changes from all remotes
git fetch --all

# Merge the latest changes from the original repository into your local repository
git merge upstream/main

# Push the new version to your fork on GitHub
git push origin main
```

If you have already setup the automated deployment, you simply need to push to
your `archidep` remote again.

Otherwise if you have cloned the repository on your server, you should also
update it. **Connect to your server** and run the following commands:

```bash
# Move into the floodit repository you have cloned
cd floodit

# Pull the latest changes
git pull
```

### :boom: `Error creating new order :: too many certificates already issued for: archidep.ch`

If you see an error similar to this when attempting to obtain a Let's Encrypt
TLS certificate with Certbot:

```bash
$> sudo certbot --nginx
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator nginx, Installer nginx

Which names would you like to activate HTTPS for?
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
1: clock.jde.archidep.ch
2: floodit.jde.archidep.ch
3: todolist.jde.archidep.ch
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Select the appropriate numbers separated by commas and/or spaces, or leave input
blank to select all options shown (Enter 'c' to cancel): 2
Obtaining a new certificate
An unexpected error occurred:
There were too many requests of a given type :: Error creating new order :: too many certificates already issued for: archidep.ch: see https://letsencrypt.org/docs/rate-limits/
Please see the logfiles in /var/log/letsencrypt for more details.
```

It means that you are running into a [rate limit of the Let's Encrypt
service](https://letsencrypt.org/docs/rate-limits/): at most 50 certificates can
be requested per domain per week. With more than 50 students in both classes of
the architecture & deployment course, we may encounter this limit now and then.

Please notify the teachers immediately if you run into this issue.

[ajax]: https://en.wikipedia.org/wiki/Ajax_(programming)
[angular]: https://angular.io
[api]: https://en.wikipedia.org/wiki/API
[automated-tests]: https://en.wikipedia.org/wiki/Test_automation
[composer]: https://getcomposer.org
[cross-platform]: https://en.wikipedia.org/wiki/Cross-platform_software
[fork]: https://docs.github.com/en/get-started/quickstart/fork-a-repo
[frontend-and-backend]: https://en.wikipedia.org/wiki/Frontend_and_backend
[gui]: https://en.wikipedia.org/wiki/Graphical_user_interface
[http-502]: https://httpstatuses.com/502
[initial-setup]: https://github.com/ArchiDep/floodit#initial-setup
[jar]: https://en.wikipedia.org/wiki/JAR_(file_format)
[java]: https://www.oracle.com/java/
[java-bytecode]: https://en.wikipedia.org/wiki/Java_bytecode
[java-jdk-jre]: https://en.wikipedia.org/wiki/Java_(software_platform)#Java_Development_Kit
[jdk]: https://en.wikipedia.org/wiki/Java_Development_Kit
[js]: https://en.wikipedia.org/wiki/JavaScript
[json]: https://en.wikipedia.org/wiki/JSON
[jvm]: https://en.wikipedia.org/wiki/Java_virtual_machine
[laravel]: https://laravel.com
[linux-unattended-upgrades]: https://wiki.debian.org/UnattendedUpgrades
[mvc]: https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller
[mvn]: https://maven.apache.org
[mvn-central]: https://search.maven.org
[nginx-proxy-pass]: http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass
[nginx-root]: https://nginx.org/en/docs/http/ngx_http_core_module.html#root
[nginx-try-files]: https://nginx.org/en/docs/http/ngx_http_core_module.html#try_files
[node]: https://nodejs.org
[node-install]: https://nodesource.com/products/distributions
[node-lts]: https://nodejs.org/en/about/releases/
[npm]: https://www.npmjs.com
[openjdk]: https://openjdk.org
[oracle]: https://www.oracle.com
[orm]: https://en.wikipedia.org/wiki/Object%E2%80%93relational_mapping
[php]: https://www.php.net
[postgres]: https://www.postgresql.org
[spa]: https://en.wikipedia.org/wiki/Single-page_application
[spring]: https://spring.io
[spring-boot]: https://spring.io/projects/spring-boot
[readme]: https://github.com/ArchiDep/floodit#readme
[readme-production]: https://github.com/ArchiDep/floodit#run-the-application-in-production-mode
[repo]: https://github.com/ArchiDep/floodit
[sun]: https://en.wikipedia.org/wiki/Sun_Microsystems
[tailwind]: https://tailwindcss.com
[ui]: https://en.wikipedia.org/wiki/User_interface
[url]: https://en.wikipedia.org/wiki/URL#Syntax
[visudo]: https://linux.die.net/man/8/visudo
[webpack]: https://webpack.js.org
[webpack-caching]: https://webpack.js.org/guides/caching/
