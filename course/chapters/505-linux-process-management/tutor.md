# Tutor notes: 505 Process Management on Linux

## Scope

The slides hold the concepts, each in a few lines with speaker notes; the
subject page holds the same concepts in more detail, with the commands, their
tables and the trap script.

The first part, signals, is the largest on the page. A signal is an asynchronous
notification the kernel delivers to a process, sent by another process through a
system call or by the kernel itself; the process runs its own handler for it or
the default one, which for most signals terminates it. It is compared to an
interrupt on a processor, from "How a computer works". The page has a table of
eight common signals with their numbers and default handlers, explains `Ctrl-C`
as the kernel sending `SIGINT` to the foreground command, and the `kill` command
with `-s NAME`, `-NAME` and `-NUMBER`. A script that traps every signal it can,
run with `curl … | sh`, shows a program ignoring `SIGINT`, `SIGTERM`, `SIGHUP`,
`SIGQUIT` and `SIGUSR1`, then dying of `SIGKILL`, which the kernel carries out
without running the program's code. `SIGTERM` first, `SIGKILL` as the last
resort, because a killed process cannot clean up. `SIGHUP` is what an
application started in an SSH session receives when the session closes, and what
nginx and PostgreSQL use to reload their configuration.

The second part is process management: why a server needs its processes started
in order, watched and restarted; a process manager as a process like any other;
the init process, PID 1, as the process manager of the whole system; the
built-in process managers of macOS, Windows, Linux and System V; and lightweight
ones for a single application (PHP-FPM, PM2, Supervisor). The slides put it
before systemd and after signals; the page puts it first.

The third part is systemd: the init process on Ubuntu, a unit file with its
`[Unit]` and `[Install]` sections (`After`, `WantedBy=multi-user.target`), the
`[Service]` section with five options (`ExecStart`, `WorkingDirectory`, `User`,
`EnvironmentFile`, `Restart`), what `Restart=on-failure` counts as a failure,
the two directories of unit files, the `systemctl` operations, that stopping a
service sends `SIGTERM` then `SIGKILL` 90 seconds later, and reading a service's
logs with `journalctl -u` and `-f`. The slides add a table mapping what was done
by hand to the option that does it, and that under `node --watch` a crashed
application never exits, so systemd would never see it fail.

Optional on the page: the "more" notes on signal numbers that vary between
systems, systemd replacing System V init, and `/lib` being a link to `/usr/lib`.

## Left out

Taught later:

- Writing a unit file, running an application as a dedicated user, and reading
  the configuration from an environment file: "Manage a web application with
  systemd as a Process Manager".
- Reloading nginx with `systemctl reload`: "Reverse Proxying".
- PHP-FPM as the process manager of a PHP application: "Deploy a PHP website
  with nginx and the FastCGI process manager".

Not in the course: job control (`&`, `bg`, `fg`, `Ctrl-Z`, `nohup`, `disown`),
`screen` and `tmux`, `pkill` and `killall`, writing a signal handler, signal
masks and real-time signals, core dumps beyond the table's mention, unit types
other than `service`, targets beyond `multi-user.target`, `Type=`, `Requires=`
and `Wants=`, socket activation, user services (`systemctl --user`), cgroups,
and the configuration of journald.

## Key concepts and vocabulary

- **Process management**: starting processes in the right order, stopping and
  restarting them, and restarting them when they crash. **Dependency**: a
  process that needs another to run first, as Guess It needs PostgreSQL.
- **Process manager**: a process that starts, watches and restarts others. The
  **init process**, PID 1, is the process manager of the whole system; on
  Ubuntu, it is **systemd**.
- **Signal**: an asynchronous notification, always delivered by the kernel. A
  **signal handler** is the code a program registers for a signal; without one,
  the **default handler** runs.
- **`SIGINT`** (2): `Ctrl-C`. **`SIGTERM`** (15): "please terminate", the
  default of `kill`. **`SIGKILL`** (9): carried out by the kernel, cannot be
  handled. **`SIGHUP`** (1): the terminal was closed; for services, "reload
  your configuration".
- **Unit file**: the description of something systemd manages. A **service** is
  a unit that runs a long-running process, named after its file
  (`guessit.service`, service `guessit`).
- **Enable** / **start**: enabling makes a unit start automatically, as its
  `[Install]` section says; starting runs it now. Neither implies the other.
- **Failure**, for `Restart=on-failure`: an exit status other than 0, or being
  killed by a signal such as `SIGKILL`. A status of 0, or `SIGTERM`, `SIGINT` or
  `SIGHUP`, is a stop that was asked for.
- **Journal**: where systemd's journald keeps the standard output and error of
  services, timed, with what systemd did to them. **`journalctl`** reads it.

## Misconceptions

- **Misconception:** `Ctrl-C` is a key the program reads and chooses to obey.
  **Correction:** the kernel, which manages the terminal, turns it into
  `SIGINT`. The program never sees the key; it can still handle the signal and
  carry on.
- **Misconception:** `kill` kills.
  **Correction:** it sends a signal, `SIGTERM` by default. Most default
  handlers terminate the process, hence the name, but a program can handle
  them.
- **Misconception:** `kill -9` is the normal way to stop a process.
  **Correction:** it is the last resort. `SIGKILL` gives the process no chance
  to finish writing files, answer requests or close its connections.
- **Misconception:** a process sends a signal directly to another.
  **Correction:** processes are isolated. A process asks the kernel, with a
  system call, and the kernel delivers it.
- **Misconception:** an application started over SSH stops at logout because
  the connection "takes it down" or the server stops it.
  **Correction:** the kernel sends `SIGHUP` to the processes of the terminal
  that was closed, and their default handler terminates them.
  Question that reveals it: "Why does PostgreSQL keep running when you log out,
  and the application you started not?"
- **Misconception:** `systemctl` starts and stops services itself.
  **Correction:** it asks systemd, which starts the process, or sends it
  `SIGTERM`, then `SIGKILL` if it is still running 90 seconds later.
- **Misconception:** enabling a service starts it, or starting it makes it come
  back after a reboot.
  **Correction:** enabling sets it to start at boot; starting runs it now. A
  new service needs both.
- **Misconception:** `Restart=on-failure` restarts a service however it stops.
  **Correction:** a stop that was asked for, by `SIGTERM` (as `systemctl stop`
  sends) or with a status of 0, is not a failure, and is not restarted.
- **Misconception:** a service's errors appear in the terminal, as when it was
  run by hand.
  **Correction:** a service has no terminal. Its output is in the journal.
- **Misconception:** systemd runs the commands of a unit file in a shell.
  **Correction:** a unit file describes the process; systemd does not
  understand shell syntax, and does not look for programs as the shell does.

## Used in

Every later deployment on the student's server runs its long-running processes
as systemd services, so the course relies on this chapter from here on.
Exercises that lean on particular parts:

- "Manage a web application with systemd as a Process Manager" runs the trap
  script, sends signals with `kill`, writes Guess It's unit file with the five
  `[Service]` options, `After` and `WantedBy`, kills the application with
  `SIGKILL` to see `Restart=on-failure` at work, and reads the service's logs.
- "Deploy a multi-component web application with nginx" and "Horizontally scale
  a web application with nginx as a load balancer" write unit files of their
  own, and the latter edits one, with `daemon-reload` and `restart`.
- "Reverse Proxying" and "Deploy a static site with nginx" reload nginx's
  configuration with `systemctl reload`.
- "Deploy a PHP website with nginx and the FastCGI process manager" runs
  PHP-FPM, a lightweight process manager, as a systemd service.
