---
title: Deploy a web application with SFTP
cloud_server: details
excerpt_separator: <!-- more -->
---

This guide describes how to deploy a [Node.js][node] application over
[SFTP][sftp] on a server with Node.js and [PostgreSQL][postgres] installed.

{% callout type: exercise %}

Connect to your cloud server with SSH for this exercise.

{% endcallout %}

<!-- more -->

## :exclamation: Make sure your Guess It is up to date

You will deploy [Guess It][guessit], with the three queries implemented and its
vulnerabilities fixed.

The original Guess It repository, [`ArchiDep/guessit-ex`][ex-repo], has changed
since you forked it. It now has the three queries, and the fixes for the
vulnerabilities we found during the [security analysis][security]. Your
application will be on the Internet, where anyone can attack it, so you must
deploy that fixed version.

- **If you have your own fork:** [Make sure your fork is up to
  date](#make-sure-your-fork-is-up-to-date).
- **If you do not have your own fork yet:** [Fork the
  repository](#fork-the-repository).
- **If you have a fork but prefer to start over from a clean state:** [Fork
  again](#fork-again).

### :question: Make sure your fork is up to date

If your group's fork belongs to you (it's under your own GitHub account), you
can update it with the latest changes.

Open a terminal and go into your local clone of the fork:

```bash
$> cd guessit-ex
$> git status
```

Make sure you are in a clean state on your `main` branch, with no uncommitted
changes. If you have uncommitted changes, commit them (or throw them away with
`git restore .`).

Add the original repository as a second remote, named `upstream`, fetch it, and
merge its `main` branch into yours:

```bash
$> git remote add upstream git@github.com:ArchiDep/guessit-ex.git

$> git fetch upstream

$> git merge upstream/main
```

Git will probably report a conflict in `server.js`: your group and the original
repository both implemented the same queries, and the original repository then
rewrote them to fix the vulnerabilities. Resolve each conflict by keeping the
original repository's version, the part between `=======` and
`>>>>>>> upstream/main`. Then finish the merge and push it:

```bash
# Mark the conflict as resolved
$> git add server.js

# Finish the merge
$> git commit

# Push the merge commit to your fork
$> git push
```

{% note type: tip %}

If Git reports no conflict, it has already finished the merge by itself: only
`git push` is left to do.

{% endnote %}

### :question: Fork the repository

If you do not have a fork of your own yet, either fork your group's repository
(**after** the owner has updated it), or fork the original
[`ArchiDep/guessit-ex` repository][ex-repo], using the **Fork** button:

![Fork button](images/fork.png)

Then clone your fork on your computer:

```bash
$> cd /path/to/projects
$> git clone git@github.com:YOUR_GITHUB_USERNAME/guessit-ex.git
$> cd guessit-ex
```

{% note type: troubleshooting %}

If `git clone` fails because `guessit-ex` already exists, see [:boom:
`destination path 'guessit-ex' already exists`][clone-exists].

{% endnote %}

### :question: Fork again

If you prefer to start again from the clean course repository, you can fork it
again. The new fork will not have your group's commits, but it will have the
working queries and the fixes of the vulnerabilities.

You can delete your own fork on GitHub, in the **Danger Zone** at the bottom of
the repository's **Settings**:

![Delete repository](images/repo-delete.png)

You can then fork [`ArchiDep/guessit-ex`][ex-repo] again:

![Fork button](images/fork.png)

Then clone your fork on your computer:

```bash
$> cd /path/to/projects
$> git clone git@github.com:YOUR_GITHUB_USERNAME/guessit-ex.git
$> cd guessit-ex
```

{% note type: troubleshooting %}

If `git clone` fails because `guessit-ex` already exists, see [:boom:
`destination path 'guessit-ex' already exists`][clone-exists].

{% endnote %}

## :exclamation: Install the dependencies

Make sure to install the dependencies in your Guess It fork, even if you had
already done it. The XSS vulnerability was fixed by adding the `mustache`
dependency to escape user input, so you need to install it.

```bash
$> npm ci
```

{% note type: more %}

This reinstalls all dependencies, including the new `mustache` dependency, in
the `node_modules` directory.

{% endnote %}

## :exclamation: Install PostgreSQL

Update your package lists and install the PostgreSQL database server:

```bash
$> sudo apt update

$> sudo apt install postgresql
```

{% note type: tip %}

APT may prompt you to restart some services. See the troubleshooting section
about [:boom: Daemons using outdated
libraries](#daemons-using-outdated-libraries) if necessary.

{% endnote %}

{% note type: more %}

[**A**dvanced **P**ackaging **T**ool (APT)][apt] is the [package
manager][package-manager] for Ubuntu (and some other Linux distributions). We
will not discuss this tool, but you can read more about it in the [installation
& upgrading section of the system administration
cheatsheet][sysadmin-cheatsheet-apt].

{% endnote %}

APT should automatically start PostgreSQL after installation. You can check this
with the following command:

```bash
$> sudo systemctl status postgresql
```

## :exclamation: Install Node.js

Guess It needs Node.js. The version that Ubuntu provides is too old, so install
Node.js 26 from [NodeSource][node-install] instead:

```bash
$> sudo apt-get install -y curl

$> curl -fsSL https://deb.nodesource.com/setup_26.x | sudo -E bash -

$> sudo apt-get install -y nodejs

$> node -v
v26.x.y
```

## :exclamation: Generate a password

The `schema.sql` file creates a `guessit` user with the password
`change-me-now`. Replace it with a random password. This command generates one,
made of 32 random hexadecimal digits:

```bash
$> openssl rand -hex 16
cc46a7fcd8dd9c0ce9bc6f0aaf63eb3a
```

A password made only of letters and digits can go into the connection URL of
`server.js` as it is. Put yours in `schema.sql`, in your copy of the repository,
in place of `change-me-now`. Keep it: you will need it again to configure the
application.

## :exclamation: Upload the application

**On your local machine**, use the SFTP application you set up in [Hello
SSH][hello-ssh-sftp] to upload the application to your server: [WinSCP][winscp]
on Windows, or [Cyberduck][cyberduck] on macOS. Configure a new connection the
same way, with two differences:

- The **host** is your server's public IP address.
- The **username** is your Unix username on your server.

Your private key is the same. On Windows, use the converted
`id_ed25519.ppk` key you saved for WinSCP, as described in [Give your key to
WinSCP][hello-ssh-winscp].

**[Screenshot to add: WinSCP's login window, configured for the student's
server.]**

{% note type: warning %}

When you connect for the first time, check the server's key fingerprint, as you
did when you first connected to your server with SSH.

{% endnote %}

Once you are connected to your server with your SFTP application, copy your
`guessit-ex` directory to `/home/jde/guessit` (replacing `jde` with your Unix
username). Copy the whole directory, including `node_modules`: the application
cannot run without its dependencies.

On Windows, your copy of the repository is in the WSL. In WinSCP's local panel,
type its path in the address bar, for example
`\\wsl.localhost\Ubuntu\home\jde\guessit-ex`, replacing `jde` with your Linux
username.

**[Screenshot to add: WinSCP uploading the `guessit-ex` directory to the
server.]**

You can simply drag-and-drop the directory from your machine to the server. You
can then rename it if necessary.

{% note type: tip %}

`node_modules` holds hundreds of small files, so the upload takes a while.

{% endnote %}

## :exclamation: Initialize the database

**Connect to your server** and go into the uploaded directory:

```bash
$> hostname
jde.archidep.ch

$> cd ~/guessit
```

Run the project's SQL file as the PostgreSQL superuser, `postgres`, to create
the user, the database and its table:

```bash
$> sudo -u postgres psql < schema.sql
CREATE ROLE
CREATE DATABASE
You are now connected to database "guessit" as user "postgres".
CREATE TABLE
ALTER TABLE
```

{% note type: more %}

This uses the [redirection operator `<`][unix-redirection] to send the contents
of the `schema.sql` file into the standard input stream of `psql`. When given
SQL queries on its input stream, `psql` connects to the PostgreSQL server,
executes them, then stops.

`sudo -u postgres` runs `psql` as the `postgres` user of your server, which is
allowed to connect to PostgreSQL as its superuser, also named `postgres`. That
user is not allowed to read your files, so it could not open `schema.sql`
itself: your shell opens it, and passes its content to `psql`.

{% endnote %}

{% callout type: more, id: database-users %}

It is good practice to create a different user and password for each application
that connects to a database server. That way, if one of the applications is
compromised, it cannot access or modify the databases of the other applications.

Notably, you should never connect an application to its database as the
superuser. On your server, only you, the system administrator, can become the
PostgreSQL superuser, with `sudo`.

{% endcallout %}

### :question: Optional: make sure it worked

To make sure everything worked, you can check that the table was created. Connect
to the `guessit` database as the superuser, and display the `game` table's
schema with `\d`:

```bash
$> sudo -u postgres psql guessit

guessit=# \d game
                          Table "public.game"
   Column   |           Type           | Collation | Nullable | Default
------------+--------------------------+-----------+----------+---------
 id         | text                     |           | not null |
 name       | text                     |           | not null |
 secret     | integer                  |           | not null |
 attempts   | integer                  |           | not null | 0
 found_at   | timestamp with time zone |           |          |
 created_at | timestamp with time zone |           | not null | now()
Indexes:
    "game_pkey" PRIMARY KEY, btree (id)
```

Everything went well if the table was created, since that is the last step of
the `schema.sql` file.

You may exit `psql` with `\q`.

## :exclamation: Update the configuration

Update the `DATABASE_URL` at the top of the `server.js` file **on the server**,
with the password you put in `schema.sql`:

```js
const DATABASE_URL =
  'postgresql://guessit:your-secret-password@localhost:5432/guessit';
```

If you ran PostgreSQL with Docker Desktop on your computer, your copy of
`server.js` uses port `5434`. On your server, PostgreSQL listens on its usual
port, `5432`.

{% note type: tip %}

The `server.js` file **on the server** must be modified. There are several ways
you can do this:

- Edit the file locally, then copy it to the server again with your SFTP
  application.
- Edit the file directly on the server with `nano` or `vim`.
- Your SFTP application can open a remote file in an editor. In WinSCP,
  right-click the file and choose **Edit**. In Cyberduck, right-click the file
  and choose **Edit With**, then your favorite editor. Make your changes and
  save the file: the application uploads it again.

{% endnote %}

## :exclamation: Run the application

Also in the uploaded directory on the server, start the application, as you did
on your computer:

```bash
$> npm run dev

> guessit@1.0.0 dev
> node --watch server.js

Guess It is listening on http://localhost:3000
```

You (and everybody else) should be able to access the application in a browser
at your server's IP address and port 3000 (e.g. `http://W.X.Y.Z:3000`).

**[Screenshot to add: Guess It's home page, opened at the server's IP address
and port 3000.]**

### :question: Optional: see who listens where

Despite what its message says, the application does not only listen on
`localhost`. In another SSH connection to your server, list the processes
listening for TCP connections with `ss`:

```bash
$> ss -tln
State  Recv-Q Send-Q Local Address:Port Peer Address:Port
LISTEN 0      200        127.0.0.1:5432      0.0.0.0:*
LISTEN 0      511                *:3000            *:*
LISTEN 0      200            [::1]:5432         [::]:*
...
```

PostgreSQL listens on port 5432 of the [loopback addresses][loopback],
`127.0.0.1` and its IPv6 equivalent `::1`: only programs running on your server
can connect to it. Guess It listens on port 3000 of `*`, all the addresses of
your server: anyone who can reach your server can connect to it.

## :checkered_flag: What have I done?

You have **deployed** an application to a server running in the Microsoft Azure
cloud. It is now publicly accessible by anyone on the Internet, at your server's
public IP address.

Along the way, you:

- Updated your fork with the fixes of the original repository.
- Installed PostgreSQL and Node.js on your server.
- Uploaded the application with SFTP, its dependencies included.
- Created its database, configured it, and started it.

Deploying an application means putting it on a computer where its users can
reach it, and running it there. Here, that took the same steps as on your own
computer: install what the application needs, create its database, configure
it, and start it. Only the computer has changed.

For Guess It, the files are the program. Node.js reads the JavaScript files as
they are, so copying them to the server is enough, as long as Node.js is
installed there. Its dependencies are files too, which is why you could copy
your `node_modules` directory instead of installing the dependencies on the
server.

PostgreSQL and Guess It are two separate programs, running side by side on your
server. Each is a server of its own, listening on its own port: 5432 for
PostgreSQL, 3000 for Guess It. Guess It is a client of PostgreSQL, and your
browser a client of Guess It.

A program chooses which of the computer's addresses it listens on. PostgreSQL
only listens on the loopback address, so it cannot be reached from the Internet,
only by programs on the same server. Guess It listens on all addresses, which is
what makes it public.

The application still has a user of its own in the database, as it had on your
computer. The superuser created that user and is not used again. The password
is random, because nobody has to remember it.

The application runs in your terminal, as a program you started yourself. Close
your SSH connection, and it stops.

Your deployment works, but it has flaws. We will discuss these flaws and improve
this deployment, one flaw at a time.

## :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="SFTP Deployment Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="SFTP Deployment Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: `destination path 'guessit-ex' already exists`

`git clone` refuses to clone your new fork:

```bash
$> git clone git@github.com:YOUR_GITHUB_USERNAME/guessit-ex.git
fatal: destination path 'guessit-ex' already exists and is not an empty directory.
```

You already have a `guessit-ex` directory where you are cloning, probably your
clone of your group's repository, or of your previous fork. Git will not clone
into a directory that already has files in it.

Move the old clone out of the way by renaming it, then clone again:

```bash
$> mv guessit-ex guessit-ex-old

$> git clone git@github.com:YOUR_GITHUB_USERNAME/guessit-ex.git
```

{% note type: tip %}

Your old clone is still there, in `guessit-ex-old`, if you need anything from
it.

{% endnote %}

### :boom: Daemons using outdated libraries

When you install a package with APT (e.g. PostgreSQL), it _may_ prompt you to
reboot and/or to restart outdated daemons (i.e. background services):

![Restart outdated daemons](images/apt-outdated-daemons.png)

Simply select "Ok" by pressing the Tab key, then press Enter to confirm.

{% callout type: more, id:unattended-upgrades %}

This happens because most recent Linux versions have [unattended
upgrades][linux-unattended-upgrades]: a tool that automatically installs daily
security upgrades on your server without human intervention. Sometimes, some of
the background services running on your server may need to be restarted for
these upgrades to be applied.

Since you are installing a new background service (the PostgreSQL server) which
must be started, APT asks whether you want to apply upgrades to other background
services by restarting them. Rebooting your server would also have the effect of
restarting these services and applying the security upgrades.

{% endcallout %}

### :boom: `Cannot find module`

The application stops as soon as it starts, with an error like this one:

```bash
$> npm run dev
...
Error: Cannot find module 'mustache'
Require stack:
- /home/jde/guessit/server.js
...
Failed running 'server.js'. Waiting for file changes before restarting...
```

The `node_modules` directory on your server is missing, or incomplete. Either
your copy did not have all the dependencies, or the upload did not finish. Run
`npm ci` in your copy of the repository, on your computer, then upload its
`node_modules` directory again.

### :boom: The leaderboard could not be loaded

The home page says that the leaderboard could not be loaded from the database.
Look at the terminal where the application runs, at the error below `Could not
load the leaderboard`:

```bash
Could not load the leaderboard: error: password authentication failed for user "guessit"
...
```

Then find that error below.

### :boom: `password authentication failed for user "guessit"`

The application cannot connect to PostgreSQL as the `guessit` user:

```bash
Could not load the leaderboard: error: password authentication failed for user "guessit"
```

The password in the `DATABASE_URL` at the top of `server.js` **on the server**
is not the one in the `schema.sql` file you ran. Put the same password in both.

If they are already the same, you may have run `schema.sql` more than once: see
[`role "guessit" already exists`](#role-guessit-already-exists). Or you may not
have run it at all: go back to [Initialize the
database](#initialize-the-database).

### :boom: `connect ECONNREFUSED`

The application cannot reach PostgreSQL at all:

```bash
Could not load the leaderboard: Error: connect ECONNREFUSED 127.0.0.1:5432
```

Nothing listens on port 5432 of your server: PostgreSQL is not running. Check
its status, and start it if it is stopped:

```bash
$> sudo systemctl status postgresql

$> sudo systemctl start postgresql
```

Also check that the `DATABASE_URL` in `server.js` on the server uses port
`5432`, and not the port you may have used on your computer.

### :boom: `role "guessit" already exists`

`psql` prints these errors when you run `schema.sql` a second time:

```bash
$> sudo -u postgres psql < schema.sql
ERROR:  role "guessit" already exists
ERROR:  database "guessit" already exists
You are now connected to database "guessit" as user "postgres".
ERROR:  relation "game" already exists
ALTER TABLE
```

The first run created the user, the database and the table. The second run
changed nothing: the user still has the password of the first run, even if you
have changed it in `schema.sql` since.

Give the `guessit` user the password of your `DATABASE_URL` (replacing
`my-new-password` with that password):

```bash
$> sudo -u postgres psql -c "ALTER USER guessit WITH PASSWORD 'my-new-password';"
ALTER ROLE
```

### :boom: `role "jde" does not exist`

`psql` refuses to connect:

```bash
$> psql < schema.sql
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: FATAL:  role "jde" does not exist
```

You ran `psql` as yourself. By default, `psql` connects as the PostgreSQL user
with the same name as your Unix user, and PostgreSQL has no such user. Run it as
the `postgres` user of your server, with `sudo -u postgres psql`.

### :boom: `Peer authentication failed for user "postgres"`

`psql` refuses to connect:

```bash
$> psql -U postgres < schema.sql
psql: error: connection to server on socket "/var/run/postgresql/.s.PGSQL.5432" failed: FATAL:  Peer authentication failed for user "postgres"
```

On Ubuntu, the PostgreSQL superuser, `postgres`, can only connect from the
`postgres` user of your server. Use `sudo -u postgres psql`, not
`psql -U postgres`.

[apt]: https://en.wikipedia.org/wiki/APT_(software)
[clone-exists]: #destination-path-guessit-ex-already-exists
[cyberduck]: https://cyberduck.io
[ex-repo]: https://github.com/ArchiDep/guessit-ex

[guessit]: {% link chapters/205-guessit/exercise.md %}
[hello-ssh-sftp]: {% link chapters/104-hello-ssh/exercise.md %}#copy-files-with-an-sftp-application
[hello-ssh-winscp]: {% link chapters/104-hello-ssh/exercise.md %}#give-your-key-to-winscp-windows-only
[linux-unattended-upgrades]: https://wiki.debian.org/UnattendedUpgrades
[loopback]: https://en.wikipedia.org/wiki/Loopback#Virtual_loopback_interface
[node]: https://nodejs.org
[node-install]: https://nodesource.com/products/distributions
[package-manager]: https://en.wikipedia.org/wiki/Package_manager
[postgres]: https://www.postgresql.org
[security]: {% link chapters/301-security/subject.md %}
[sftp]: https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol

[sysadmin-cheatsheet-apt]: {% link cheatsheets/sysadmin/cheatsheet.md %}#installing--upgrading
[unix-redirection]: {% link chapters/408-unix-processes/subject.md %}#stream-redirection
[winscp]: https://winscp.net
