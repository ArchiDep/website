# Tutor notes: 506 Manage a web application with systemd as a Process Manager

## Starting point

- 504 Configure a web application through environment variables: the clone in
  `/srv/guessit` at the commit that reads `PORT` and `DATABASE_URL` from the
  environment, with no local change, owned by the student.
- 410 Deploy a web application with SFTP: the `guessit` database user, and its
  password in the `DATABASE_URL` of `~/guessit-ex/server.js`, the URL this
  exercise copies into the configuration file.
- 505 Process Management on Linux: signals, `kill`, the trap script, unit files,
  the `[Service]` options, `Restart=on-failure`, `systemctl` and `journalctl`.
  Its notes hold the vocabulary and the misconceptions this exercise practises
  against.
- 403 Permissions: `chown`, `chmod` with octal modes, and how owner, group and
  other apply. 405 Meet your server: the student's passwordless `sudo`, and the
  system users in `/etc/passwd`.
- "How to improve our basic deployment": the flaws this exercise fixes, the
  process manager, development mode and the user with `sudo`.

Two parts need a second SSH connection to the server, and one reboots it.

## Learning objectives

Handing the application over to the init process: a unit file describes how to
run it instead of a typed command, so systemd starts it at boot, restarts it
when it fails, and keeps it running after logout, because it is a child of
systemd with no terminal and receives no `SIGHUP`. Along the way, a program can
handle every signal but `SIGKILL`, which systemd counts as a failure. The
application runs in production mode, as a dedicated user without `sudo` that can
read its code but not change it, with its configuration in a file only `root`
can read, which systemd reads before switching user. The page's "What have I
done?" states what the student should understand afterwards.

The student writes the unit file themselves, from the options each subsection of
"Create a systemd unit file" asks for and the "Recap" table. The page withholds
the complete file until the class has covered the exercise, so a student working
on it does not have it. The production command is in the Guess It repository's
README, which the page links. The predictions and questions of "Meet a process
that refuses to stop", "Let the application read its code", "Enable and start
the Guess It service" and "Log out and come back" are answered in solution boxes
shown on the page from the start.

The architecture diagram is stepped through with captions: starting the service
with `systemctl`, systemd starting Guess It as `guessit`, logging out, coming
back, and rebooting, after which systemd starts PostgreSQL then Guess It without
anyone logged in.

Not in the exercise: `Environment=`, which the page names only to say that unit
files are readable by everyone; `systemctl edit` and drop-in files; `Type=`,
`Requires=` and `Wants=`; the restart limits behind `Start request repeated too
quickly`, beyond the page's explanation; hardening options such as
`ProtectSystem=`; and `useradd` options beyond the two used.

## Where it leads

Every later application deployed on the student's server runs as a systemd
service, and this is the exercise that teaches it:

- "Domain name configuration" starts from this deployment, reached by a domain
  name instead of an IP address.
- "Deploy a multi-component web application with nginx" and "Horizontally scale
  a web application with nginx as a load balancer" write unit files of their
  own, by the same steps, with their configuration in environment variables.
- "Reverse Proxying" puts nginx, itself a systemd service, in front of
  applications run this way, so that they no longer need a port of their own in
  the browser.

## Key steps

- **"Stop the previous deployment"**. Only needed if Guess It still runs.
- **"Meet a process that refuses to stop"**. The page asks students to run the
  script first, then asks why only `kill -s KILL` stopped it.
  Expected: one "Nice try" line per signal in the first terminal, then
  `Killed`. The PID differs from the page's.
- **"Create a dedicated user"**.
  Expected after: `id guessit` shows a user and a group of the same name, with
  a user ID below 1000.
  Question after: "Which `guessit` does the application connect to PostgreSQL
  as, and which runs its process?"
- **"Let the application read its code"**.
  Question before: the page's three predictions.
  Expected after: `drwxr-x--- … jde guessit … /srv/guessit`, then `head`
  printing three lines, `touch` and `rm` refused.
  Question after: "Which permission would the `guessit` user need to create a
  file in `/srv/guessit`?" (`w` on the directory.)
- **"Put the configuration in a file"**.
  Expected after: `-rw------- 1 root root` for `/etc/guessit/guessit.env`, and
  one `DATABASE_URL=…` line in it.
  Question before writing it: "Why `chmod` the file before putting the password
  in it?"
- **"Create a systemd unit file"**, with its three sections.
  Question before `After`: "Which service must already run for Guess It to
  work?"
  Question before `ExecStart`: "Why not `npm run dev`?"
  Expected after: a file at `/etc/systemd/system/guessit.service` with a
  `Description` and the seven options of the "Recap" table.
- **"Enable and start the Guess It service"**.
  Expected after: `active (running)`, a main PID shown as `node-MainThread`,
  `Guess It is listening` in the last lines; `ps -f -u guessit` shows the process
  with a PPID of 1 and `?` as its TTY; the leaderboard of the earlier
  deployments.
  Question after: the page's question of how the application got its password.
- **"Log out and come back"**. Expected: the application still answers.
  Question after: the page's question of why it did not stop.
- **"Kill your application"**.
  Question before: "Will systemd count `SIGKILL` as a failure?"
  Expected after: `active (running)` again, a new main PID, and the four log
  lines from `code=killed, status=9/KILL` to `Started`.
- **"Reboot and try again"**. Expected: after about a minute, the application
  answers, and `systemctl status` says it started at boot.

## Common pitfalls

- **`systemctl start` says `Unit guessit.service not found`, or the status
  shows the old version after an edit**: the file has another name or
  location, or `daemon-reload` was not run after editing it. Hint: what does
  `ls /etc/systemd/system` list?
- **`systemctl status` shows `inactive (dead)` and `disabled`**: the service was
  enabled but not started, or neither. Hint: which of the two commands did you
  run?
- **The application runs, but stops at the reboot and does not come back**:
  the service was started but not enabled, or `WantedBy` is missing, or the
  `[Install]` section was changed after enabling it. Question that leads to it:
  "What does the `Loaded:` line of `systemctl status` say after the path?"
- **`ExecStart` uses `npm run dev`, `npm start` or `node --watch`**: the
  service may look fine, but a crash is never seen as a failure, and every `git
pull` restarts the application. Hint: which command does the README give for
  production mode?
- **The student runs `cat /etc/guessit/guessit.env` without `sudo`, gets
  `Permission denied`, and loosens the file's permissions**: that is the file
  working as intended. Hint: who reads the file, systemd or Guess It?
- **`sudo -u guessit head` fails with `Permission denied`**: the `chown
:guessit` or `chmod 750` step was skipped or mistyped, so the directory is
  closed to the `guessit` group too. Hint: what group and permissions does `ls
-ld /srv/guessit` show?
- **`kill -s KILL` without `sudo` says `Operation not permitted`**: the process
  belongs to the `guessit` user. The page says why `sudo` is needed.
- **Right after `sudo reboot`, `ssh` times out or says `Connection refused`**:
  the server has not finished booting. Waiting a minute and connecting again
  works.
