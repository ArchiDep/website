---
title: Guess It
excerpt_separator: <!-- more -->
---

Make an incomplete application work as a team: install what it needs, run it,
and each implement one of its missing database queries.

<!-- more -->

**You will need**

- [Git][git]
- Your group's fork of Guess It on [GitHub][github], [cloned on your
  computer](#get-your-groups-repository)
- [Node.js][node] 26
- A [PostgreSQL][postgres] server, version 14 or newer
- A Unix CLI

**Recommended reading**

- [Collaborating with Git]({% link chapters/203-git-collaborating/subject.md %})

The application is [Guess It][ex-repo], a guess-the-number game with a
leaderboard. It is written in JavaScript for [Node.js][node] and stores its
games in a [PostgreSQL][postgres] database. All its code is in one file,
`server.js`, and three of its database queries are missing.

Each member of the group works on their own computer, at their own pace. You
share your work through GitHub: whenever a push is refused, pull first.

Later in the course, each of you will deploy this application from a fork of
your own, which you will make from your group's fork, so keep it. If your
group's application does not work by then, you will be given a working version
to start from instead.

## :exclamation: Get your group's repository

Each member of the group needs a clone of the group's fork of Guess It, and must
be allowed to push to it.

If your group has done [Hello GitHub][hello-github], you already have both: go
on to the next step. Otherwise, do these steps of Hello GitHub first, then come
back here:

1. [Form your group][hg-group]
2. [Everyone: check your SSH key on GitHub][hg-ssh]
3. [Alice: fork the repository][hg-fork]
4. [Alice: invite Bob (and Chuck)][hg-invite]
5. [Bob (and Chuck): accept the invitation][hg-accept]
6. [Everyone: configure `git pull`][hg-pull]
7. [Everyone: clone the fork][hg-clone]

The rest of Hello GitHub is not needed for this exercise.

## :exclamation: Install Node.js

Check whether you have Node.js 26:

```bash
$> node --version
v26.x.y
```

If the command is not found, or prints a version older than 22, install Node.js 26
by following the instructions of its [download page][node-download] for your
system. On Windows, install it **in the WSL**, with the Linux instructions.

## :exclamation: Install PostgreSQL

The application needs a PostgreSQL server, version 14 or newer. It connects to
it at `localhost`, on port 5432: that is the address in its connection URL. On
Windows, the application runs in the WSL, so the server must answer in the WSL.

You may already have a PostgreSQL server, installed for another course. Check
before you install anything: two PostgreSQL servers on the same computer both
want port 5432, and only one of them can have it.

## :exclamation: Check what you already have

First, check whether a server already answers on port 5432. Run this in your
terminal on macOS, or in the WSL on Windows:

```bash
$> nc -zv localhost 5432
Connection to localhost (127.0.0.1) 5432 port [tcp/postgresql] succeeded!
```

The message ends with `succeeded!` if a server answers, and with
`Connection refused` if none does. It is slightly different on macOS, but it
ends the same way.

Then check which PostgreSQL servers are installed, and follow the table for your
system.

**In the WSL, or on Linux:**

```bash
$> pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
16  main    5432 online postgres /var/lib/postgresql/16/main /var/log/postgresql/postgresql-16-main.log
```

This lists the servers installed with `apt`, Ubuntu's package manager. If the
command is not found, there is none.

| `nc`         | `pg_lsclusters`                  | Next step                               |
| :----------- | :------------------------------- | :-------------------------------------- |
| `succeeded!` | a server on port 5432, `online`  | [Connect as a superuser][pg-connect]    |
| `succeeded!` | not found, or no server `online` | [Connect as a superuser][pg-connect]    |
| `refused`    | a server on port 5432, `down`    | [Start your server][pg-start]           |
| `refused`    | not found                        | [Install PostgreSQL in the WSL][pg-wsl] |

In the second row, the server that answers was not installed with `apt`: it is
another server, for example one installed on Windows, which some WSL network
settings make visible in the WSL.

{% note type: tip %}

A PostgreSQL server installed on Windows itself usually does **not** answer in
the WSL: you are in the last row. This is expected. The WSL has its own
`localhost`, separate from Windows'. You can install another server in the WSL:
the two do not interfere with each other.

{% endnote %}

**On macOS:**

```bash
$> ls -d /Applications/Postgres.app   # Postgres.app
$> brew list | grep postgresql        # PostgreSQL installed with Homebrew
$> ls /Library/PostgreSQL             # the installer of postgresql.org
```

`No such file or directory`, or no output, means that it is not installed.
`brew: command not found` means that you do not have Homebrew.

| `nc`         | Installed                                        | Next step                               |
| :----------- | :----------------------------------------------- | :-------------------------------------- |
| `succeeded!` | anything                                         | [Connect as a superuser][pg-connect]    |
| `refused`    | Postgres.app, or PostgreSQL in Homebrew          | [Start your server][pg-start]           |
| `refused`    | nothing, or only the installer of postgresql.org | [Install PostgreSQL on macOS][pg-macos] |

## :question: Start your server

Start the server you already have:

- **Installed with `apt`, in the WSL or on Linux:**

  ```bash
  $> sudo service postgresql start
  ```

  Some WSL installations do not start services by themselves. If the server is
  stopped again after you restart your computer, start it again the same way.

- **Postgres.app:** open it, and click `Start`.
- **Homebrew:** start the version that `brew list` printed, for example
  `postgresql@17`:

  ```bash
  $> brew services start postgresql@17
  ```

Run `nc -zv localhost 5432` again: it must now succeed. Then [connect as a
superuser][pg-connect].

## :question: Install PostgreSQL in the WSL

Follow the [Install PostgreSQL][wsl-postgres] section of Microsoft's guide to
databases in the WSL, up to and including `sudo service postgresql start`. You
do not need to give the `postgres` user a password, as the guide then suggests.

On Linux without the WSL, follow [PostgreSQL's instructions for
Ubuntu][postgres-ubuntu]: `apt install postgresql` is enough.

Run `nc -zv localhost 5432` again: it must now succeed. Then [connect as a
superuser][pg-connect].

## :question: Install PostgreSQL on macOS

Check whether you have [Homebrew][homebrew]:

```bash
$> brew --version
Homebrew 5.0.0
```

- **If you have Homebrew**, install [PostgreSQL 18][brew-postgres] with it, and
  start it:

  ```bash
  $> brew install postgresql@18
  $> brew services start postgresql@18
  ```

  At the end of its output, `brew install` says that `postgresql@18 is
keg-only`, and gives an `echo 'export PATH=...' >> ~/.zshrc` command below.
  Run that command, then open a new terminal: it makes the `psql` command
  available.

- **Otherwise**, install [Postgres.app][postgres-app] by following the steps on
  its home page. Do the step that configures your `$PATH`, even though the page
  says that it is optional: you will need the `psql` command. Then open a new
  terminal.

Run `nc -zv localhost 5432` again: it must now succeed. Then [connect as a
superuser][pg-connect].

## :exclamation: Connect as a superuser

To create the application's database in the next step, you will connect to your
server as a PostgreSQL superuser. The command depends on where your server
comes from:

| Your server                               | Superuser command                        |
| :---------------------------------------- | :--------------------------------------- |
| Installed with `apt`, in the WSL or Linux | `sudo -u postgres psql`                  |
| Postgres.app, or Homebrew                 | `psql postgres`                          |
| Any other server                          | `psql -h localhost -U postgres postgres` |

With any other server, `psql` asks for the password of the `postgres` user,
which was chosen when that server was installed. If `psql` is not found in the
WSL, install it with `sudo apt install postgresql-client`.

Use your command to check the version of your server:

```bash
$> sudo -u postgres psql -c 'SHOW server_version;'
            server_version
---------------------------------------
 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
(1 row)
```

It must be 14 or newer. With `apt`, you get the version of your Ubuntu: 14 on
Ubuntu 22.04, 16 on 24.04, 18 on 26.04. If yours is older, use the [PostgreSQL
Apt Repository][postgres-ubuntu] to install a newer one.

{% note type: tip %}

`sudo -u postgres psql` may also print
`could not change directory to "/home/jde/guessit-ex": Permission denied`. It
runs `psql` as the `postgres` user of your system, which is not allowed in your
directory. You can ignore this warning.

Postgres.app may ask whether your terminal is allowed to connect to it the
first time. Allow it.

{% endnote %}

## :exclamation: Create the database

The repository has a `schema.sql` file, which creates the database user, the
database and its table. Open it, and **change the password** it gives the user,
`change-me-now`. Choose a password made only of letters, digits and dashes: it
goes into a URL in the next step, where other characters would have to be
encoded. It is simpler if everyone in the group uses the same one.

Then run it with your [superuser command][pg-connect], giving it the file with
`<`. For example:

```bash
$> sudo -u postgres psql < schema.sql   # installed with apt
$> psql postgres < schema.sql           # Postgres.app, or Homebrew
```

{% note type: more %}

With `<`, your shell reads the file and passes its content to `psql`. With
`sudo -u postgres`, `psql` runs as another user, which is not allowed to read
your files, so it could not open the file itself.

{% endnote %}

## :exclamation: Configure and start the application

Open your `guessit-ex` directory in your editor. At the top of `server.js`, put
the password you chose into `DATABASE_URL`, in place of `change-me-now`:

```js
const DATABASE_URL =
  'postgresql://guessit:change-me-now@localhost:5432/guessit';
//                      ^^^^^^^^^^^^^
//                       change this
```

If the application is still running from the [optional step of Hello
GitHub][hg-run], it has restarted by itself when you saved `server.js`.
Otherwise, install its dependencies, and start it:

```bash
$> npm ci
$> npm run dev
Guess It is listening on http://localhost:3000
```

Open [http://localhost:3000](http://localhost:3000) in your browser and you
should see the application running with an empty leaderboard:

![Guess It home page](images/guessit-home.png)

{% note type: tip %}

`npm run dev` restarts the application automatically whenever you save
`server.js`. Stop it with `Ctrl-C`.

{% endnote %}

The game starts, but it does not work yet: the leaderboard stays empty, guesses
are not counted, and giving up does not delete the game. The queries that do
these are missing.

{% note type: troubleshooting %}

If the leaderboard could not be loaded from the database, then you either missed
or misconfigured something from the previous steps. Look at the error below
`Could not load the leaderboard` in the terminal where the application runs,
and find it in [Troubleshooting](#troubleshooting). If you are still stuck, ask
for help.

![Guess It home page with broken leaderboard](images/guessit-no-db.png)

{% endnote %}

{% note type: more %}

`npm ci` downloads the dependencies listed in `package-lock.json` into a
`node_modules` directory. The repository's `.gitignore` ignores that directory,
so that you do not commit it, as you learned in [Hello Git]({% link
chapters/202-hello-git/exercise.md %}#ignore-a-secret).

{% endnote %}

## :exclamation: Implement the missing queries

Three queries in `server.js` are missing. Each is marked with an
`// IMPLEMENT ME` comment, with a description of what it must do above it:

- The **leaderboard**, on the home page: the games that have been won, fewest
  attempts first, and among equals the one found first. Only the top ten.
- **Recording a guess**: add one to the game's attempts, and record when the
  number was found if the guess is right.
- **Giving up**: delete the game.

Each member of the group implements at least one of them. In a group of two, one
member implements two.

The queries are given below. Try to write yours first if you want to practice
your SQL, and use the solution to check it. Or take it as it is, if you prefer:
this exercise is about working together with Git, not about SQL. Either way, the
commit is yours.

{% solution title: "The leaderboard query", reveal: always %}

```js
const leaderboardQuery =
  'SELECT name, attempts, found_at FROM game WHERE found_at IS NOT NULL ORDER BY attempts ASC, found_at ASC LIMIT 10';
```

{% endsolution %}

{% solution title: "The guess query", reveal: always %}

```js
const updateQuery = `UPDATE game SET attempts = attempts + 1, found_at = CASE WHEN secret = ${guess} THEN NOW() ELSE found_at END WHERE id = '${game.id}'`;
```

{% endsolution %}

{% solution title: "The give-up query", reveal: always %}

```js
const deleteQuery = `DELETE FROM game WHERE id = '${game.id}'`;
```

{% endsolution %}

Check that your query works in your browser, then commit it and push it to the
group's repository. Pull the others' work as they push theirs.

{% callout type: exercise %}

By the next session, your group's repository on GitHub must hold a working
application:

- A game can be played until the number is found, or given up.
- The leaderboard lists the games that have been won, fewest attempts first.
- Each member of the group has made at least one of these commits, on their own
  computer, with their own name and email address.

{% endcallout %}

## :checkered_flag: What have I done?

You have installed what a Node.js application needs to run on your computer: the
Node.js runtime, the application's dependencies, and a PostgreSQL server with a
database of its own.

You have configured the application to connect to that database, and made it
work, each member of the group with commits of your own, shared through GitHub.

## :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="Guess It Local Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="Guess It Local Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

## :boom: Troubleshooting

Here are a few tips about problems you may encounter during this exercise. For
problems with Git and GitHub, see the [troubleshooting of Hello
GitHub][hg-troubleshooting].

### :boom: `password authentication failed for user "guessit"`

The password in the `DATABASE_URL` at the top of `server.js` is not the one you
set in `schema.sql` when you created the database. Put the same password in
both.

### :boom: `connect ECONNREFUSED`

The home page says that the leaderboard could not be loaded, and the terminal
where the application runs shows `ECONNREFUSED` in the error below
`Could not load the leaderboard`. The application cannot reach PostgreSQL on
port 5432: your PostgreSQL server is either not running or is not reachable on
that port. [Check what you have][pg-check] again, and start your server if it is
stopped.

### :boom: `psql: command not found`

On macOS, the `psql` command of Postgres.app and of Homebrew's PostgreSQL is not
available until you configure your `$PATH`, as described in [Install PostgreSQL
on macOS][pg-macos]. Open a new terminal after doing it.

### :boom: `Peer authentication failed for user "postgres"`

Your server was installed with `apt`. Its `postgres` user can only connect from
the `postgres` user of your system: use `sudo -u postgres psql`, not
`psql -U postgres`.

### :boom: `role "jde" does not exist`

Your server was installed with `apt`, and you ran `psql` as yourself. Use
`sudo -u postgres psql`, as in [Connect as a superuser][pg-connect].

### :boom: Your server no longer starts after you restart your Mac

After you restart your Mac, Postgres.app says that port 5432 is already in use,
or `brew services list` shows an `error` for your PostgreSQL. Or `nc` succeeds,
but you can no longer connect as a superuser.

You have an older PostgreSQL server, from the installer of postgresql.org, which
started first and took port 5432. Uninstall it with the uninstaller in its
`/Library/PostgreSQL/<version>/` directory, then [start your server][pg-start]
again.

[ex-repo]: https://github.com/ArchiDep/guessit-ex
[brew-postgres]: https://formulae.brew.sh/formula/postgresql@18
[git]: https://git-scm.com
[github]: https://github.com

[hello-github]: {% link chapters/204-hello-github/exercise.md %}
[hg-accept]: {% link chapters/204-hello-github/exercise.md %}#bob-and-chuck-accept-the-invitation
[hg-clone]: {% link chapters/204-hello-github/exercise.md %}#everyone-clone-the-fork
[hg-fork]: {% link chapters/204-hello-github/exercise.md %}#alice-fork-the-repository
[hg-group]: {% link chapters/204-hello-github/exercise.md %}#form-your-group
[hg-invite]: {% link chapters/204-hello-github/exercise.md %}#alice-invite-bob-and-chuck
[hg-pull]: {% link chapters/204-hello-github/exercise.md %}#everyone-configure-git-pull
[hg-run]: {% link chapters/204-hello-github/exercise.md %}#everyone-run-the-application
[hg-ssh]: {% link chapters/204-hello-github/exercise.md %}#everyone-check-your-ssh-key-on-github
[hg-troubleshooting]: {% link chapters/204-hello-github/exercise.md %}#troubleshooting
[homebrew]: https://brew.sh
[node]: https://nodejs.org
[node-download]: https://nodejs.org/en/download
[pg-check]: #check-what-you-already-have
[pg-connect]: #connect-as-a-superuser
[pg-macos]: #install-postgresql-on-macos
[pg-start]: #start-your-server
[pg-wsl]: #install-postgresql-in-the-wsl
[postgres]: https://www.postgresql.org
[postgres-app]: https://postgresapp.com
[postgres-ubuntu]: https://www.postgresql.org/download/linux/ubuntu/
[wsl-postgres]: https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-database#install-postgresql
