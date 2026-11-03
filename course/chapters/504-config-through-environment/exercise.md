---
title: Configure a web application through environment variables
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to improve the configuration step of the [previous
exercise][git-deployment]: Guess It will take its configuration from environment
variables, instead of having it written in `server.js`.

<!-- more -->

At the end of the previous exercise, the `server.js` file of your deployment had
to contain the database password. If it was not already the right one, you
edited it on your server, and left it uncommitted. Either way, the password is
in the code.

The third factor of The Twelve-Factor App, [Config][12factor-config], asks for a
strict separation of the configuration from the code. The configuration is what
can change between deploys, such as the database password or the database port,
while the code stays the same. An application that reads its configuration from
environment variables can be deployed anywhere without changing a line of its
code.

## :exclamation: Requirements

Make sure you have completed the [previous exercise][git-deployment] first. You
will need its clone in `/srv/guessit`, and the `guessit-ex` directory of your
SFTP deployment, which still holds the password of the `guessit` database user.

## :exclamation: Stop the Git deployment

If Guess It is still running from the previous exercise, go to the terminal
where it runs, and press `Ctrl-C`. Only one program at a time can listen on port 3000.

If it is not running, there is nothing to stop: it stopped when the SSH
connection you had started it in was closed.

## :exclamation: Update the configuration

{% callout type: exercise %}

Do this part of the exercise on your computer, not on the server.

{% endcallout %}

Open the `guessit-ex` directory of your fork, on your computer, in your editor.
The configuration is at the top of `server.js`:

```js
// The port the application listens on.
const PORT = 3000;

// The URL used to connect to the PostgreSQL database. It has the shape
// postgresql://USER:PASSWORD@HOST:PORT/DATABASE. Change the password to match
// the one you set when you ran schema.sql.
const DATABASE_URL =
  'postgresql://guessit:change-me-now@localhost:5432/guessit';
```

Your `DATABASE_URL` may have another password, and another port, if you
configured it for your computer or for your server.

Modify these lines to take the configuration from the environment. In Node.js,
the environment variables of the process are in `process.env`. For example,
instead of:

```js
const PORT = 3000;
```

Use this:

```js
const PORT = process.env.PORT || 3000;
```

With this code, `PORT` is the value of the `PORT` environment variable if it is
set, or `3000` if it is not.

{% note type: more %}

The `||` operator returns its left side if it is truthy, and its right side
otherwise. An environment variable that is not set is `undefined` in
`process.env`, which is falsy.

{% endnote %}

Do the same for `DATABASE_URL`, with the `DATABASE_URL` environment variable.
Its default can be the same URL **without the password**:
`postgresql://guessit@localhost:5432/guessit`.

{% note type: warning %}

**Do not** put a password in the default value of `DATABASE_URL`. A password
must not be written in the code, as the [Config section of The Twelve-Factor
App][12factor-config] explains: anyone who can read your repository, or its
history, could read it.

{% endnote %}

Update the comments above both lines too, so that they say where the
configuration comes from: "Change the password to match…" is no longer true.

### :exclamation: Update the README

The `README.md` file of your fork explains how to set up Guess It. Its setup
step 2 still says to put the password in `server.js`:

```md
2. Set the same password in the `DATABASE_URL` at the top of `server.js`.
```

Replace that step with this one:

```md
2. Whenever you run the application, set the `DATABASE_URL` environment
   variable to the URL of the database, with the same password.
```

### :exclamation: Commit and push your changes

Check what you are about to commit:

```bash
$> git status
$> git diff server.js README.md
```

Your copy may have other changes that you have not committed, such as the
password you put in `schema.sql` during the [SFTP deployment][sftp]. Make sure
no password is left in `server.js`, then commit **only** `server.js` and
`README.md`, and push them to your fork on GitHub:

```bash
$> git add server.js README.md
$> git commit -m "Take the configuration from the environment"
$> git push
```

{% solution %}

The configuration at the top of `server.js` should look like this:

```js
// The port the application listens on, taken from the PORT environment
// variable if it is set.
const PORT = process.env.PORT || 3000;

// The URL used to connect to the PostgreSQL database, taken from the
// DATABASE_URL environment variable if it is set. It has the shape
// postgresql://USER:PASSWORD@HOST:PORT/DATABASE. The default has no password:
// a password must not be written in the code.
const DATABASE_URL =
  process.env.DATABASE_URL || 'postgresql://guessit@localhost:5432/guessit';
```

{% endsolution %}

{% note type: tip %}

To run Guess It on your computer from now on, give it your local configuration
in the environment, in the same way as on your server below: your local
password, and the port `5434` if you run PostgreSQL with Docker Desktop.

{% endnote %}

## :exclamation: Pull the latest version on the server

{% callout type: exercise %}

Connect to your server for the rest of the exercise.

{% endcallout %}

Go into your deployment, and check whether `server.js` has a change you have not
committed:

```bash
$> cd /srv/guessit

$> git status
```

If Git lists `server.js` as modified, you edited its password during the
previous exercise. You no longer need that change, since the configuration will
come from the environment. Discard it with `git restore`, which puts back the
version of the file from the last commit:

```bash
$> git restore server.js
```

The password is not lost: it is still in `~/guessit-ex/server.js`, in your SFTP
deployment.

{% note type: more %}

Git would not have let you pull with that change. The new commit changes
`server.js` too, so pulling would replace your version of the file and lose your
change, and Git never throws away a change you have not committed unless you ask
it to.

{% endnote %}

Then pull the latest version of the code from GitHub:

```bash
$> git pull origin main
...
Fast-forward
 README.md | ...
 server.js | ...
...
```

{% note type: tip %}

If Git does not know the remote `origin`, list your remotes with the
`git remote` command (or with `git remote -v` to also see their URLs), and use
the name it prints instead.

{% endnote %}

Your deployment should now have no uncommitted changes: `git status` should
print "nothing to commit, working tree clean".

```bash
$> git status
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

### :question: Optional: run the application without its configuration

Start Guess It as in the previous exercise, without any environment variable:

```bash
$> npm run dev

> guessit@1.0.0 dev
> node --watch server.js

Guess It is listening on http://localhost:3000
```

Open your server's IP address and port 3000 in your browser (e.g.
`http://W.X.Y.Z:3000`). The home page says that the leaderboard could not be
loaded, and the terminal shows:

```bash
Could not load the leaderboard: Error: SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string
```

The application started, and only failed when it tried to connect to the
database. Why could it not connect?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

`DATABASE_URL` is not set, so the application used its default URL, which has
no password. PostgreSQL asks the `guessit` user for one.

{% endsolution %}

Stop it with `Ctrl-C`.

## :exclamation: Run the application

Still in `/srv/guessit`, start the application again, but this time give it its
configuration through the environment. The database URL is the one of your SFTP
deployment, which has the password of the `guessit` database user:

```bash
$> grep guessit: ~/guessit-ex/server.js
const DATABASE_URL = 'postgresql://guessit:********************************@localhost:5432/guessit';
```

Set it for the `npm run dev` command (replacing the URL with yours):

```bash
$> DATABASE_URL='postgresql://guessit:********************************@localhost:5432/guessit' npm run dev

> guessit@1.0.0 dev
> node --watch server.js

Guess It is listening on http://localhost:3000
```

{% note type: tip %}

`NAME='value' command` runs a command with an additional environment variable.
You can set several at once: `EXAMPLE='value' ANOTHER='one' command`.

The single quotes around the value are optional if it contains no spaces or
special characters.

{% endnote %}

You do not need to set `PORT`: its default, `3000`, is the right port for your
server.

You (and everybody else) should be able to access the application in a browser
at your server's IP address and port 3000 (e.g. `http://W.X.Y.Z:3000`), and its
leaderboard should show the games won on your earlier deployments.

![Guess It's home page, at the server's IP address and port 3000](images/guessit.png)

{% note type: more %}

You set the variable for `npm`, but it is `server.js` that reads it. `npm` runs
`node --watch`, which runs `server.js` in another process. Each process gets a
copy of the environment of the process that started it, so the variable reaches
all of them.

{% endnote %}

## :checkered_flag: What have I done?

You have made Guess It configurable through the environment, as recommended in
the [Config section of The Twelve-Factor App][12factor-config].

The code no longer changes from one deploy to another. Your fork, your computer
and your server have the same `server.js`, and each deploy gives it its own
configuration when it starts it. A database on another port, or with another
password, needs no change to the code.

Your deployment is now exactly a commit of your repository, with nothing
modified. Git can pull a new version without a local change in its way.

Configuration can have default values, as long as they are not secrets. The port
and the database URL have one, but the database URL's has no password: a
password in the code would be in the repository's history, for anyone who can
read it. Not setting a default password also forces the person who deploys the
application to explicitly set one rather than rely on an insecure default.

An environment variable set for a command exists only in the process that
command starts, and in the processes it starts in turn. That is how
`DATABASE_URL` reached `server.js`, through `npm` and `node --watch`.

Your configuration now lives in the command you typed. You have to type it
again every time you start the application, and your shell keeps it in its
history, password included.

## :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise. It has not changed since [the
previous exercises][sftp-architecture]: you have neither created new processes
nor changed how they communicate. Only where Guess It gets its configuration
from is different.

{% include diagrams/410-running-app.html %}

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: `client password must be a string`

The home page says that the leaderboard could not be loaded, and the terminal
shows:

```bash
Could not load the leaderboard: Error: SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string
```

Guess It did not get a `DATABASE_URL`, and used its default URL, which has no
password. Make sure you typed it on the same line as `npm run dev`, before it,
as in [Run the application][run]. A variable set on a line of its own is a
variable of your shell, which the commands you run next do not get.

### :boom: `password authentication failed for user "guessit"`

The home page says that the leaderboard could not be loaded, and the terminal
shows:

```bash
Could not load the leaderboard: error: password authentication failed for user "guessit"
```

The password in your `DATABASE_URL` is not the one of the `guessit` database
user. Copy the URL from your SFTP deployment, in `~/guessit-ex/server.js`, as in
[Run the application][run].

If your previous deployments did not work either, see the [same problem in the
SFTP deployment][sftp-password].

### :boom: `Completed running 'server.js'`

The application says it is listening, then stops at once:

```bash
...
Guess It is listening on http://localhost:3000
Completed running 'server.js'. Waiting for file changes before restarting...
```

Another program already listens on port 3000, most likely one of your previous
deployments. Stop it as described in [Stop the Git deployment][stop-git], then
start Guess It again.

[12factor-config]: https://12factor.net/config
[run]: #run-the-application
[stop-git]: #stop-the-git-deployment

[git-deployment]: {% link chapters/501-git-clone-deployment/exercise.md %}
[sftp]: {% link chapters/410-sftp-deployment/exercise.md %}
[sftp-architecture]: {% link chapters/410-sftp-deployment/exercise.md %}#architecture
[sftp-password]: {% link chapters/410-sftp-deployment/exercise.md %}#password-authentication-failed-for-user-guessit
