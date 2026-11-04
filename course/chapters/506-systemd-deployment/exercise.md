---
title: Manage a web application with systemd as a Process Manager
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to have [systemd][systemd], the process manager of
your server, run Guess It for you: start it when the server boots, restart it
when it fails, and keep it running when you log out. You will also run it in
production mode, as a user of its own, with its configuration in a file that
only `root` can read.

{% callout type: exercise %}

Connect to your cloud server with SSH for this exercise.

{% endcallout %}

<!-- more -->

At the end of the [previous exercise][env-deployment], you started Guess It by
typing a command, with its configuration in it. It runs as long as that SSH
connection stays open, and no longer: when the connection closes, the
application receives a [`SIGHUP` signal][sighup] and stops. If it crashes, or if
the server reboots, nothing starts it again until you type the command once
more.

## :exclamation: Requirements

Make sure you have completed the [previous exercise][env-deployment] first. You
will need its clone in `/srv/guessit`, with the commit that takes the
configuration from the environment, and the database URL with the password of
the `guessit` database user, which is in `~/guessit-ex/server.js`.

## :exclamation: Stop the previous deployment

If Guess It is still running from the previous exercise, go to the terminal
where it runs, and press `Ctrl-C`. It sends a [`SIGINT` signal][sigint] to the
processes running in the foreground of your terminal, which stop.

If it is not running, there is nothing to stop: it stopped when you closed the
SSH connection.

## :exclamation: Meet a process that refuses to stop

`Ctrl-C` works with Guess It because Guess It does what most programs do when
they receive `SIGINT`: it stops. A program can decide otherwise. Run the script
of [Trapping signals][trapping-signals] on your server:

```bash
$> curl -fsSL https://tinyurl.com/archidep-trap | sh
Hi, I'm running with PID 12345
Try and kill me!
```

Press `Ctrl-C`.

The script refuses to stop and still holds your terminal. Open a second SSH
connection to your server, in another terminal, and send the script signals with
the `kill` command, using the PID it printed (replacing `12345` with it). Look
at the first terminal after each command:

```bash
$> kill 12345
$> kill -s HUP 12345
$> kill -s KILL 12345
```

`Ctrl-C`, `kill` and `kill -s HUP` did not stop the script, but `kill -s KILL`
did. Can you guess why?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

The first terminal shows:

```
Hi, I'm running with PID 12345
Try and kill me!
^CNice try, I am ignoring your SIGINT signal
Nice try, I am ignoring your SIGTERM signal
Nice try, I am ignoring your SIGHUP signal
Killed                     curl -fsSL https://tinyurl.com/archidep-trap | sh
```

The script [registers a **signal handler**][trap-script-handler] for every
signal it can: It prints "Nice try, I am ignoring your SIG… signal", with the
name of the signal, and does nothing else: it does not exit.

`Ctrl-C` sends the script `SIGINT`, `kill` without an option sends it `SIGTERM`,
and `kill -s HUP` sends it `SIGHUP`. Each time, the handler prints its message
and returns, and the script goes back to what it was doing: waiting, forever.

`SIGKILL` is the one signal a program cannot handle. The kernel ends the process
itself, without running any more of its code, so the script cannot even print a
message. `Killed` is printed by your shell, which tells you how the command it
was running ended.

{% endsolution %}

You can close the second SSH connection. You will use `SIGKILL` again on Guess
It later in this exercise.

## :question: What this exercise improves

systemd can run Guess It for you, so that you do not have to start it manually
every time. In addition to setting up systemd, you will also make three
improvements:

- Run Guess It with a **dedicated user** instead of your own user. This protects
  your server if an attacker finds a way to run commands through the
  application.
- Run Guess It in [**production mode**][guessit-production] instead of
  [development mode][guessit-development]. This avoids unintended downtime due
  to restarts when pulling updates.
- Put the **configuration in a file** instead of in the command line. This
  prevents the database password from being visible to other users of the server
  in the process list, and from being stored in your shell's history.

## :exclamation: Create a dedicated user

So far, Guess It has run as your user, which [can run any command as `root` with
`sudo`, without a password][meet-your-server-sudo]. An attacker who found a way
to run commands through the application would run them as you, so they could
become `root` and take over the whole server. This is one of the flaws listed in
[How to improve our basic deployment][improve].

Create a **system user** to run the application:

```bash
$> sudo useradd --system --shell /usr/sbin/nologin guessit

$> id guessit
uid=994(guessit) gid=994(guessit) groups=994(guessit)
```

Its user ID will probably be different on your server.

- `--system` creates a user for a service rather than for a person, like the
  [system users][system-users] you found in `/etc/passwd`.
- `--shell /usr/sbin/nologin` makes it start `nologin` instead of a shell, which
  refuses every login. It has no password either, so nobody can log in as
  `guessit`.
- `useradd` also created a `guessit` group, of which the user is the only
  member.

The `guessit` user is not in the `sudo` group: it cannot become `root`.

{% note %}

**There are now two users called `guessit`.** The one you have just created is
a **Unix user** of your server, which runs processes. The one you created with
`schema.sql` in the [SFTP deployment][sftp] is a **PostgreSQL user**, which
exists only in the database, and which the application connects as. They have
the same name because they belong to the same application, as do the
`/srv/guessit` directory, the `guessit` database, and the `/etc/guessit`
directory and `guessit` service you will create below.

{% endnote %}

## :exclamation: Let the application read its code

Look at the permissions of your deployment:

```bash
$> ls -ld /srv/guessit
drwxr-xr-x 4 jde jde 4096 Nov  5 09:14 /srv/guessit
```

Every user of the server can read and enter it (`r-x`). The application needs to
read its code, but nobody else does. Give the directory to the `guessit` group,
and close it to every other user:

```bash
$> sudo chown :guessit /srv/guessit

$> chmod 750 /srv/guessit

$> ls -ld /srv/guessit
drwxr-x--- 4 jde guessit 4096 Nov  5 09:14 /srv/guessit
```

{% note type: more %}

`chown :guessit`, with nothing before the colon, changes only the group: you
stay the owner, and the group becomes `guessit`. Only `root` may give a file to
a group you are not a member of, hence `sudo`. The directory is yours, so you
can change its permissions yourself, without `sudo`.

{% endnote %}

You still own the directory (`rwx`). The members of the `guessit` group, that is
the `guessit` user, can read and enter it (`r-x`). Every other user can do
nothing with it (`---`).

The files inside have not changed:

```bash
$> ls -l /srv/guessit
total 72
-rw-r--r--  1 jde jde  2247 Nov  5 09:15 README.md
drwxrwxr-x 83 jde jde  4096 Nov  5 09:16 node_modules
-rw-r--r--  1 jde jde 36900 Nov  5 09:15 package-lock.json
-rw-r--r--  1 jde jde   484 Nov  5 09:15 package.json
-rw-r--r--  1 jde jde  1336 Nov  5 09:15 schema.sql
-rw-r--r--  1 jde jde 14259 Nov  5 09:20 server.js
```

Predict what the `guessit` user may do here. Can it read `package.json`? Can it
create a new file in `/srv/guessit`? Can it delete `server.js`?

`sudo -u guessit` runs a command as the `guessit` user. Check your predictions
(if `rm` asks you a question, answer `y`):

```bash
$> sudo -u guessit head -n 3 /srv/guessit/package.json

$> sudo -u guessit touch /srv/guessit/hacked.js

$> sudo -u guessit rm /srv/guessit/server.js
```

{% solution title: "Check your predictions", emoji: thinking, reveal: always %}

```bash
$> sudo -u guessit head -n 3 /srv/guessit/package.json
{
  "name": "guessit",
  "version": "1.0.0",

$> sudo -u guessit touch /srv/guessit/hacked.js
touch: cannot touch '/srv/guessit/hacked.js': Permission denied

$> sudo -u guessit rm /srv/guessit/server.js
rm: remove write-protected regular file '/srv/guessit/server.js'? y
rm: cannot remove '/srv/guessit/server.js': Permission denied
```

The `guessit` user enters `/srv/guessit` as a member of its group, which has
`r-x`: it can list it and get into it, but not create or delete files in it,
which would need `w` on the directory. The files inside are yours, with your
group, so it reaches them as "other", which may read them (`r--`) but not modify
them.

The question `rm` asked comes from `rm` itself, not from the permission system:
it warns you before deleting a file you may not write. Answering `y` only lets
`rm` try, and the system refuses.

{% endsolution %}

The application can read its code, but not change or delete it. You still own
everything in `/srv/guessit`, so you will keep updating the deployment as
yourself, with `git pull` and `npm ci`.

## :exclamation: Put the configuration in a file

In the previous exercise, you set `DATABASE_URL` in front of the command that
starts Guess It. systemd has an equivalent, the `Environment` option, which sets
a variable in the unit file you will write below. But every user of the server
can read unit files, so they are no place for a password. You will put the
configuration in a file that only `root` can read instead, and tell systemd to
read the variables from it, with its `EnvironmentFile` option.

By convention, configuration lives in the `/etc` directory. Create a directory
for Guess It's:

```bash
$> sudo mkdir /etc/guessit
```

Create the configuration file in it, empty for now. It will hold the database
password, so before you write anything in it, make it readable and writable by
its owner, `root`, only:

```bash
$> sudo touch /etc/guessit/guessit.env

$> sudo chmod 600 /etc/guessit/guessit.env

$> ls -l /etc/guessit/guessit.env
-rw------- 1 root root 0 Nov  5 09:30 /etc/guessit/guessit.env
```

Then edit it with `nano` (or `vim`), preceded with `sudo`, since only `root` can
write in it:

```bash
$> sudo nano /etc/guessit/guessit.env
```

Write one variable per line, as `NAME=value`, with the same database URL as in
the previous exercise (replacing it with yours):

```
DATABASE_URL=postgresql://guessit:********************************@localhost:5432/guessit
```

You do not need to set `PORT`: its default, `3000`, is the right port.

Only `root` can read this file: not the other users of the server, not the
`guessit` user, and not even you without `sudo`. You will see below how the
application gets its configuration anyway.

## :question: What you have done so far to run your application

If we try to summarize what you have done so far to run Guess It on your server
during previous exercises, it basically consists of these steps:

- Connect to the server with SSH as your user, e.g. `jde`:

  ```bash
  $> ssh jde@W.X.Y.Z
  ```

- _The first time,_ install PostgreSQL and check that it is running:

  ```bash
  $> sudo apt install postgresql
  $> sudo systemctl status postgresql
  ```

- Move into the application directory:

  ```bash
  $> cd /srv/guessit
  ```

- Run the application with its configuration in the environment:

  ```bash
  $> DATABASE_URL='postgresql://guessit:********************************@localhost:5432/guessit' npm run dev
  ```

## :exclamation: Create a systemd unit file

Now you want systemd to run the application automatically for you. You need to
tell systemd how to do it. But you cannot simply tell systemd to execute the
commands above, because it does not understand Bash commands or Bash syntax. It
uses configuration files in a certain format.

You must write a **systemd unit file** which describes how and when to run the
application (the "unit" in systemd terminology). You can see examples of
existing unit files by looking at the ones for the SSH and PostgreSQL servers
running on your server:

```bash
$> cat /usr/lib/systemd/system/ssh.service
$> cat /usr/lib/systemd/system/postgresql@.service
```

You will not use exactly the same options, but it shows you what a complete unit
file can look like.

Create your own unit file for Guess It at `/etc/systemd/system/guessit.service`.
Edit it with `sudo nano`, since the `/etc/systemd/system` directory is only
writable by `root`.

You may find the following documentation useful to write your unit file:

- [`[Unit]` section
  options](https://www.freedesktop.org/software/systemd/man/systemd.unit.html#%5BUnit%5D%20Section%20Options)
- [`[Service]` section
  options](https://www.freedesktop.org/software/systemd/man/systemd.service.html#Options)
  - [Execution environment
    options](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
    (for the `EnvironmentFile`, `User` and `WorkingDirectory` options)
- [`[Install]` section
  options](https://www.freedesktop.org/software/systemd/man/systemd.unit.html#%5BInstall%5D%20Section%20Options)

### :exclamation: The `[Unit]` section

You should briefly document what your service is with a `Description` option.

You may want to use an `After` option. What other service needs to already be
running for Guess It to work? If there is one, your application should start
after it.

{% note type: tip %}

You can use the `ls /usr/lib/systemd/system` command to list other system
services.

{% endnote %}

### :exclamation: The `[Service]` section

You must tell systemd what command to run your application with using the
`ExecStart` option.

Do not use `npm run dev`. It runs the application in [development
mode][guessit-development], with `node --watch`, which is one of the flaws
listed in [How to improve our basic deployment][improve]. It restarts the
application whenever one of its files changes, so every `git pull` would cause
an unintended downtime while it restarts, at a moment you did not choose. And
when the application crashes, `node --watch` does not exit: it waits for a file
to change, and starts the application again then. A process manager restarts a
process when it ends, so it would never see that Guess It had failed. Use the
command of Guess It's [production mode][guessit-production] instead.

{% note type: tip %}

Write the absolute path of the program in `ExecStart`, here `node`. systemd does
not run the command in a shell, and does not look for programs in the same
places as yours.

You can find the path to any program with the `which <command>` command.

{% endnote %}

You must tell systemd where to execute the command (in which directory) with
the `WorkingDirectory` option. This must be an absolute path.

You must tell systemd which user must run the command with the `User` option:
the `guessit` user you created, not your own.

You must tell systemd to read environment variables from the file you created
with the `EnvironmentFile` option, giving it the absolute path of the file.

In case your application crashes due to a bug or a server issue, you must
configure the `Restart` option so that systemd automatically restarts it when
there is a problem. Use the `on-failure` policy, described in [Service unit
file][service-unit-file]. You will test it below.

### :exclamation: The `[Install]` section

You must set the `WantedBy` option to tell systemd to automatically start your
application when the server boots. Use the value `multi-user.target` for this
option.

{% note type: more %}

`multi-user.target` means that the operating system has reached the multi-user
[runlevel](https://en.wikipedia.org/wiki/Runlevel). In other words, it means
that user management and networking have been initialized. This is typically
when you want to start running other processes which depend on users and/or
networking, like web applications.

{% endnote %}

### :question: Recap

Here's another way to look at this information:

| Things you do to run the application                  | How to do it manually             | How to tell systemd to do it                                                    |
| :---------------------------------------------------- | :-------------------------------- | :------------------------------------------------------------------------------ |
| Run commands as a user                                | Connect as `jde` with SSH         | `User=guessit` in the `[Service]` section                                       |
| Make sure a service is started                        | `sudo systemctl status <service>` | `After=<service>` in the `[Unit]` section                                       |
| Move into a directory                                 | `cd <path>`                       | `WorkingDirectory=<path>` in the `[Service]` section                            |
| Set environment variables                             | `KEY=value <command>`             | `EnvironmentFile=<path>` in the `[Service]` section                             |
| Execute a command                                     | `<command> <arg1> <arg2>`         | `ExecStart=<absolute-path-to-command> <arg1> <arg2>` in the `[Service]` section |
| Restart the application automatically when it crashes | _Cannot be done manually_         | `Restart=<policy>` in the `[Service]` section                                   |
| Have the application start automatically on boot      | _Cannot be done manually_         | `WantedBy=<target>` in the `[Install]` section                                  |

{% note type: tip %}

You should put comments in your unit file to explain what each option is for.
This can help you if you come back later and do not remember what you did or
why. Any line starting with `#` is considered a comment.

{% endnote %}

## :exclamation: Enable and start the Guess It service

Enable and start your new service.

{% note type: tip %}

The systemd control command (`systemctl`) allows you to manipulate services:
`sudo systemctl <operation> <service-name>`.

The operations to enable and start are simply `enable` and `start`. The name of
the service is the name of your unit file without the ".service" extension. For
example, if the unit file is "guessit.service", the name of your service is
"guessit".

{% endnote %}

Check that the service is running properly and that there were no errors:

```bash
$> sudo systemctl status guessit
● guessit.service - Guess It
     Loaded: loaded (/etc/systemd/system/guessit.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-11-05 09:42:26 UTC; 2s ago
 Invocation: 18b7056929db4b30934b999add258574
   Main PID: 10292 (node-MainThread)
      Tasks: 7 (limit: 9444)
     Memory: 32.5M (peak: 32.5M)
        CPU: 129ms
     CGroup: /system.slice/guessit.service
             └─10292 /usr/bin/node server.js

Nov 05 09:42:26 jde.archidep.ch systemd[1]: Started guessit.service - Guess It.
Nov 05 09:42:26 jde.archidep.ch node[10292]: Guess It is listening on http://localhost:3000
```

The service is `active (running)`. Its **main PID** is the process ID of the
application, which systemd started. The last lines are the most recent lines of
its logs: what systemd did, and what the application printed.

{% note type: tip %}

To see the complete logs, you can use the `sudo journalctl -u <service-name>`
command. Pay attention to the timestamps at the beginning of each line, which
will let you know _when_ each event occurred.

{% endnote %}

You (and everybody else) should be able to access the application in a browser
at your server's IP address and port 3000 (e.g. `http://W.X.Y.Z:3000`), and its
leaderboard should show the games won on your earlier deployments.

Look at the application's process:

```bash
$> ps -f -u guessit
UID          PID    PPID  C STIME TTY          TIME CMD
guessit    10292       1  0 09:42 ?        00:00:00 /usr/bin/node server.js
```

It runs as `guessit`. Its parent process is PID 1, systemd, the init process.
Its terminal (`TTY`) is `?`: it has none.

The `guessit` user cannot read `/etc/guessit/guessit.env`, yet the application
has its database password. How do you think it got it?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

systemd is reading the `/etc/guessit/guessit.env` configuration file, not Guess
It. systemd runs as `root`, so it can read any file. It reads it before starting
the application, then starts Guess It as the `guessit` user with the variables
of the file in its environment. The application never reads the file: it finds
`DATABASE_URL` in `process.env`, as when you typed it in front of the command.

{% endsolution %}

## :exclamation: Log out and come back

Close your SSH connection:

```bash
$> exit
```

Reload Guess It in your browser. Is it still running? Why, when your earlier
deployments all stopped as soon as you logged out?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

It is still running. Your earlier deployments were started by your shell, in the
terminal of your SSH connection. When the connection closed, the kernel sent
`SIGHUP` to the processes of that terminal, and they stopped. Guess It is now
started by systemd, which is not attached to any terminal: closing your
connection sends it nothing, and it keeps running.

{% endsolution %}

Reconnect to your server for the rest of the exercise.

## :exclamation: Kill your application

The `Restart=on-failure` option asks systemd to restart the application when it
fails, for example when it crashes. You cannot easily make Guess It crash, but
you can do the equivalent: kill it with `SIGKILL`, as you did the script at the
start of this exercise. A process killed with `SIGKILL` does not get to stop by
itself: for systemd, it is the same as a crash.

Find the main PID of Guess It in the status of its service:

```bash
$> sudo systemctl status guessit
...
   Main PID: 10292 (node-MainThread)
...
```

The process belongs to the `guessit` user, and you can only send signals to your
own processes, so use `sudo` (replacing `10292` with the PID of your
application):

```bash
$> sudo kill -s KILL 10292
```

Check the status of the service again, and reload Guess It in your browser:

```bash
$> sudo systemctl status guessit
● guessit.service - Guess It
     Loaded: loaded (/etc/systemd/system/guessit.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-11-05 09:54:48 UTC; 1s ago
 Invocation: 52f3e48d59084b29bce6b567d338a976
   Main PID: 10363 (node-MainThread)
...
Nov 05 09:54:48 jde.archidep.ch systemd[1]: guessit.service: Main process exited, code=killed, status=9/KILL
Nov 05 09:54:48 jde.archidep.ch systemd[1]: guessit.service: Failed with result 'signal'.
Nov 05 09:54:48 jde.archidep.ch systemd[1]: guessit.service: Scheduled restart job, restart counter is at 1.
Nov 05 09:54:48 jde.archidep.ch systemd[1]: Started guessit.service - Guess It.
Nov 05 09:54:48 jde.archidep.ch node[10363]: Guess It is listening on http://localhost:3000
```

Guess It is running again, but look at its main PID: it has changed. The process
you killed is gone, and systemd has started a new one to replace it, with a new
PID. Its logs tell the story: the main process was killed by signal 9,
`SIGKILL`, systemd counted it as a failure, and `Restart=on-failure` started the
application again at once.

## :exclamation: Reboot and try again

If you have configured your unit file correctly, your application should restart
automatically if the server is rebooted.

Try to reboot your server:

```bash
$> sudo reboot
```

Your SSH connection closes while the server restarts. Wait a minute, then reload
Guess It in your browser: the application should be running again. Connect to
your server again and check the status of the service, which says when it was
started.

{% solution %}

The `/etc/systemd/system/guessit.service` file on your server should look
something like this:

```
[Unit]
Description=Guess It

# Guess It should start after PostgreSQL, since it stores its games in the
# database.
After=postgresql.service

[Service]

# Run the application in production mode.
ExecStart=/usr/bin/node server.js

# Run it in the directory of the deployment.
WorkingDirectory=/srv/guessit

# Run it as the dedicated user, which cannot modify its code or use sudo.
User=guessit

# Read the configuration, including the database password, from a file that
# only root can read.
EnvironmentFile=/etc/guessit/guessit.env

# Restart it if it crashes.
Restart=on-failure

[Install]

# Automatically start on boot.
WantedBy=multi-user.target
```

{% endsolution %}

## :checkered_flag: What have I done?

You have configured your server's process manager, systemd, to run Guess It for
you. You described in a unit file how to run it, instead of typing a command.
systemd starts it when the server boots, restarts it when it fails, and keeps it
running whether you are connected or not.

The application is now a child of systemd, the init process, not of your shell.
It has no terminal, so closing your SSH connection sends it no `SIGHUP`. What it
prints goes to the journal, where `journalctl` reads it.

A program can decide what most signals do to it: the script you started first
handled `SIGINT`, `SIGTERM` and `SIGHUP` by printing a message, and carried on.
`SIGKILL` is the exception, which the kernel carries out without asking the
program.

A process killed with `SIGKILL` did not stop by itself, so for systemd it has
failed, exactly as if it had crashed. `Restart=on-failure` replaces it with a
new process, with a new PID.

The application runs as a dedicated user, which can read its code but not modify
it, and has no `sudo`. A vulnerability in the application now gives an attacker
only what that user can do. You still own the code, and deploy it as yourself.

The database password is in a file that only `root` can read, and no longer in
the commands you type or in your shell's history. systemd reads the file as
`root`, then starts the application as `guessit` with the variables in its
environment. The unit file is readable by every user, which is why the password
is not in it.

One name, `guessit`, now stands for several things: a directory, a Unix user and
its group, a configuration directory, a service, and a database user and a
database in PostgreSQL.

## :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="Systemd Deployment Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="Systemd Deployment Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: My systemd service is not running

If `sudo systemctl status guessit` indicates a problem with your unit file, you
should fix the problem in your unit file. Then, be sure to run `sudo systemctl
daemon-reload` to take the changes into account. You may also need to run `sudo
systemctl restart guessit` to restart your application.

If the status command does not give you enough information, you can get more of
your service's logs with the `sudo journalctl -u guessit` command.

### :boom: `Start request repeated too quickly`

The logs of your service end like this:

```bash
$> sudo journalctl -u guessit
...
Nov 05 09:33:56 jde.archidep.ch systemd[1]: guessit.service: Scheduled restart job, restart counter is at 5.
Nov 05 09:33:56 jde.archidep.ch systemd[1]: guessit.service: Start request repeated too quickly.
Nov 05 09:33:56 jde.archidep.ch systemd[1]: guessit.service: Failed with result 'exit-code'.
Nov 05 09:33:56 jde.archidep.ch systemd[1]: Failed to start guessit.service - Guess It.
```

With `Restart=on-failure`, systemd restarts an application that fails. When it
fails again and again repeatedly, systemd gives up after a few attempts. Look
further up in the logs for the error that made it fail, and fix it, then run
`sudo systemctl restart guessit`.

### :boom: `code=exited, status=200/CHDIR`

If you see an error like this when getting the status of your service:

```bash
$> sudo systemctl status guessit
× guessit.service - Guess It
     Loaded: loaded (/etc/systemd/system/guessit.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Thu 2026-11-05 09:33:56 UTC; 708ms ago
   Duration: 15ms
 Invocation: 349612bf5ba34faaa86c6c250b4ea88f
    Process: 10638 ExecStart=/usr/bin/node server.js (code=exited, status=200/CHDIR)
   Main PID: 10638 (code=exited, status=200/CHDIR)
...
```

It means that systemd failed to move into the directory you specified with the
`WorkingDirectory` key. The logs say why:

```bash
$> sudo journalctl -u guessit
...
Nov 05 09:33:54 jde.archidep.ch (node)[10629]: guessit.service: Changing to the requested working directory failed: Permission denied
...
```

- `No such file or directory`: the directory does not exist. Make sure it is
  `/srv/guessit`, the directory you were moving into before running the
  application manually in previous exercises.
- `Permission denied`: the `guessit` user cannot enter the directory. Check that
  `ls -ld /srv/guessit` shows the `guessit` group with `r-x`, as in [Let the
  application read its code][read-code].

### :boom: `code=exited, status=203/EXEC`

If you see an error like this when getting the status of your service:

```bash
$> sudo systemctl status guessit
× guessit.service - Guess It
     Loaded: loaded (/etc/systemd/system/guessit.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Thu 2026-11-05 09:33:54 UTC; 841ms ago
   Duration: 13ms
 Invocation: d57c4fe8b6004895bccbee61a2234b76
    Process: 10593 ExecStart=/usr/local/bin/node server.js (code=exited, status=203/EXEC)
   Main PID: 10593 (code=exited, status=203/EXEC)
...
```

It means that systemd failed to run the command you specified with the
`ExecStart` key. Make sure you are running the command of Guess It's [production
mode][guessit-production], with the correct path to the program (`which node`
prints it), and that you are using `ExecStart` with the correct syntax.

Look at the [documentation for `ExecStart`][systemd-exec-start], look at
[service examples in the documentation][systemd-service-examples], and look at
existing unit files (e.g. `/usr/lib/systemd/system/ssh.service`) to determine
what you might have done wrong.

### :boom: `code=exited, status=217/USER`

If you see an error like this when getting the status of your service:

```bash
$> sudo systemctl status guessit
× guessit.service - Guess It
     Loaded: loaded (/etc/systemd/system/guessit.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Thu 2026-11-05 09:33:58 UTC; 835ms ago
   Duration: 7ms
 Invocation: 68b70ec7f1f0400ab2210fd2b5e9e93e
    Process: 10679 ExecStart=/usr/bin/node server.js (code=exited, status=217/USER)
   Main PID: 10679 (code=exited, status=217/USER)
...
```

It means that the user you specified with the `User` key does not exist. Make
sure it is `guessit`, and that `id guessit` shows the user, as in [Create a
dedicated user][dedicated-user].

### :boom: `Failed to load environment files`

If the status of your service shows `Result: resources`, and its logs say:

```bash
$> sudo journalctl -u guessit
...
Nov 05 09:33:59 jde.archidep.ch systemd[1]: guessit.service: Failed to load environment files: No such file or directory
...
```

systemd cannot find the file you specified with the `EnvironmentFile` key. Make
sure that it is the path of the file you created: `ls -l
/etc/guessit/guessit.env` should show the file.

### :boom: `Deactivated successfully` right after it started

The application says it is listening, then stops at once, and systemd does not
restart it:

```bash
$> sudo journalctl -u guessit
...
Nov 05 09:34:22 jde.archidep.ch systemd[1]: Started guessit.service - Guess It.
Nov 05 09:34:22 jde.archidep.ch node[10914]: Guess It is listening on http://localhost:3000
Nov 05 09:34:22 jde.archidep.ch systemd[1]: guessit.service: Deactivated successfully.
```

Another program already listens on port 3000, most likely one of your previous
deployments, still running in another terminal. Guess It prints its message even
when it cannot listen, then exits with the status 0, which systemd does not
count as a failure. Stop the other program as described in [Stop the previous
deployment][stop-previous], then run `sudo systemctl restart guessit`.

### :boom: `client password must be a string`

The home page says that the leaderboard could not be loaded, and the logs of the
service show:

```bash
Could not load the leaderboard: Error: SASL: SCRAM-SERVER-FIRST-MESSAGE: client password must be a string
```

The application did not get a `DATABASE_URL`, and used its default URL, which
has no password. Make sure your unit file has the `EnvironmentFile` option, and
that the variable is written `DATABASE_URL` in the file, as in [Put the
configuration in a file][configuration-file].

### :boom: `password authentication failed for user "guessit"`

The home page says that the leaderboard could not be loaded, and the logs of the
service show:

```bash
Could not load the leaderboard: error: password authentication failed for user "guessit"
```

The password in the `DATABASE_URL` of `/etc/guessit/guessit.env` is not the one
of the `guessit` database user. Copy the URL from your SFTP deployment, in
`~/guessit-ex/server.js`, as in [Put the configuration in a
file][configuration-file], then run `sudo systemctl restart guessit`: the
application only reads its environment when it starts.

If your previous deployments did not work either, see the [same problem in the
SFTP deployment][sftp-password].

[configuration-file]: #put-the-configuration-in-a-file
[dedicated-user]: #create-a-dedicated-user
[guessit-development]: https://github.com/ArchiDep/guessit-ex#run-in-development-mode
[guessit-production]: https://github.com/ArchiDep/guessit-ex#run-in-production-mode
[read-code]: #let-the-application-read-its-code
[stop-previous]: #stop-the-previous-deployment
[systemd]: https://en.wikipedia.org/wiki/Systemd
[trap-script-handler]: https://gist.github.com/AlphaHydrae/162f28e3e2bd9355a95914e04cd4dd0c/7ae3f17844809bee9423c412ef02390834221ee8#file-trap-sh-L3-L15
[systemd-exec-start]: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#ExecStart=
[systemd-service-examples]: https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Examples

[env-deployment]: {% link chapters/504-config-through-environment/exercise.md %}
[improve]: {% link chapters/413-how-to-improve/subject.md %}
[meet-your-server-sudo]: {% link chapters/405-meet-your-server/exercise.md %}#ask-sudo-what-you-may-do
[service-unit-file]: {% link chapters/505-linux-process-management/subject.md %}#service-unit-file
[sftp]: {% link chapters/410-sftp-deployment/exercise.md %}
[sftp-password]: {% link chapters/410-sftp-deployment/exercise.md %}#password-authentication-failed-for-user-guessit
[sighup]: {% link chapters/505-linux-process-management/subject.md %}#unix-signals-in-the-real-world
[sigint]: {% link chapters/505-linux-process-management/subject.md %}#the-terminal-interrupt-signal-sigint
[system-users]: {% link chapters/405-meet-your-server/exercise.md %}#the-accounts-of-the-server
[trapping-signals]: {% link chapters/505-linux-process-management/subject.md %}#trapping-signals
