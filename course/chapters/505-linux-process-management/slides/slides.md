---
title: Process Management on Linux
---

# Process Management on Linux

Architecture & Deployment <!-- .element: class="subtitle" -->

**Notes:**

Learn how processes are told to stop or reload with signals, and how systemd
starts, stops and restarts the processes of a Linux server.

---

## Signals

<img class="w-1/3" src="../images/kill-9.jpg" />

- A **notification** the kernel delivers to a process
- The process stops what it was doing, and runs a **handler**
- Its own handler, or the **default** one, which usually terminates it

**Notes:**

Sometimes a process has to be told something while it runs: to stop, or to read
its configuration again. Processes are isolated from each other, so another
process cannot reach into its memory to tell it. It asks the kernel instead,
with a system call, to send the process a **signal**. The kernel also sends
signals of its own.

A signal does to a process what [an interrupt]({% link
chapters/411-how-a-computer-works/slides/slides.md %}#the-machine-at-boot) does
to a processor. It can arrive at any moment, whatever the process is doing. The
process stops, and runs the code that handles that signal:

- If the program has registered a **signal handler** for it, that handler runs,
  and the process carries on where it stopped.
- Otherwise the **default handler** runs. For most signals, it terminates the
  process.

Each signal has a name starting with `SIG`, and most have a number. The `kill`
command sends a signal to a process, identified by its PID. It is called "kill"
because the default handler of most signals terminates the process.

---

## `Ctrl-C`

- The kernel turns `Ctrl-C` into a **`SIGINT`** signal
- It goes to the command running in the **foreground** of the terminal
- The program never sees the key

**Notes:**

You have been stopping programs with `Ctrl-C` since the start of the course. The
program does not read `Ctrl-C` as a key: the terminal is managed by the kernel,
which recognizes it and sends a **terminal interrupt signal**, or `SIGINT`, to
the processes running in the foreground of that terminal. When you stopped `npm
run dev`, both `npm` and the `node` process it had started received it.

Most programs handle `SIGINT` by terminating. A program can also handle it
itself and do something else, or nothing at all, which is why `Ctrl-C` does not
stop every program.

---

## Ask, then force

<table class="text-3xl">
  <thead>
    <tr>
      <th>Signal</th>
      <th>Means</th>
      <th>Can the process handle it?</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>SIGTERM</code></td>
      <td>Please terminate</td>
      <td>Yes: it can clean up first</td>
    </tr>
    <tr>
      <td><code>SIGKILL</code></td>
      <td>Terminated by the kernel</td>
      <td>No: none of its code runs</td>
    </tr>
  </tbody>
</table>

**Notes:**

`SIGTERM` is the signal `kill` sends by default. It asks the process to
terminate. A program may handle it to finish what it is doing first: answer the
requests in progress, finish writing a file, close its connection to a database.
It may also ignore it.

`SIGKILL`, sent with `kill -9` or `kill -s KILL`, cannot be handled or ignored.
The kernel does not deliver it to the process: it ends the process itself,
without running any more of its code. The program gets no chance to clean up.

This is why you ask first, and only force a process that does not stop.

---

## Hang up

<img class="w-1/2" src="../images/sighup-diagram.png" />

- Closing a terminal sends **`SIGHUP`** to its processes
- This is why your application **stops when you disconnect**
- Many services use it to **reload their configuration**

**Notes:**

`SIGHUP` originally meant that the modem connecting a terminal to the computer
had hung up. Terminals are no longer connected to computers by modem, but the
kernel still sends `SIGHUP` to the processes of a terminal that is closed. When
your SSH connection closes, the shell on the server and the programs it was
running in the foreground receive it, and terminate.

A program that runs in the background, without a terminal, never receives
`SIGHUP` that way. Many such programs, such as nginx and PostgreSQL, repurposed it:
when they receive a `SIGHUP`, they read their configuration again without
stopping.

---

## Managing processes

- Your application is **started by hand**, in your SSH session
- It **stops** when you disconnect
- It **does not come back** after a crash or a reboot

**Notes:**

So far, you have run your application yourself: you connected to your server,
started it in the foreground, and it held your terminal. When you disconnected,
the `SIGHUP` ended it. This is fine while you are trying something out, but not
for an application that other people use.

A server needs its processes to be **managed**: started when the server boots,
in the right order, and restarted if they crash. Some processes depend on
others: Guess It needs its PostgreSQL database to be running to load and save
the leaderboard, so the database has to start first.

---

## Process managers

<img class="w-2/5" src="../images/systemd.png" />

- A **process manager** starts, watches and restarts other processes
- The **init process**, PID 1, manages them all
- On Ubuntu, it is **systemd**

**Notes:**

A process manager is a process like any other, whose job is to start other
processes, watch them, and restart them when they stop.

The most important one is the first process of the machine. As you saw [when the
machine boots]({% link chapters/411-how-a-computer-works/slides/slides.md
%}#booting), the kernel starts a single program, the **init process**, with
process ID 1. Everything else the machine runs is started by the init process,
or by a process that it started.

On most Linux distributions, including Ubuntu, the init process is **systemd**.
Other operating systems have their own: launchd on macOS, the Service Control
Manager on Windows. Smaller process managers also exist to run a single
application, such as PM2 for Node.js programs.

---

## Describe, do not type

<table class="text-3xl">
  <thead>
    <tr>
      <th>What you did by hand</th>
      <th>What a unit file says</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Connect as your user</td>
      <td><code>User=</code></td>
    </tr>
    <tr>
      <td>Make sure the database runs</td>
      <td><code>After=</code></td>
    </tr>
    <tr>
      <td>Go to the application's directory</td>
      <td><code>WorkingDirectory=</code></td>
    </tr>
    <tr>
      <td>Set the environment variables</td>
      <td><code>EnvironmentFile=</code></td>
    </tr>
    <tr>
      <td>Run the command</td>
      <td><code>ExecStart=</code></td>
    </tr>
    <tr>
      <td><em>Nothing, when it crashed</em></td>
      <td><code>Restart=</code></td>
    </tr>
    <tr>
      <td><em>Nothing, when the server rebooted</em></td>
      <td><code>WantedBy=</code></td>
    </tr>
  </tbody>
</table>

**Notes:**

systemd does not run the commands you typed in your SSH session. You describe
the process it must manage in a configuration file, a **unit file**: what to
run, as which user, in which directory, after which other units, and when to
start and restart it. A unit file that describes a long-running process is a
**service**, named after its file: `guessit.service` describes the `guessit`
service.

The `systemctl` command (**system** **c**on**t**ro**l**) then asks systemd to
act on it: `enable` it so that it starts on boot, `start` it, `stop` it,
`restart` it, or show its `status`.

To stop a service, systemd asks before it forces, as you would: it sends the
process a `SIGTERM`, and if the process is still running 90 seconds later, a
`SIGKILL`.

---

## Restarting on failure

- A process **fails** when it exits with a status other than `0`
- Or when it is **killed** by a signal such as `SIGKILL`
- systemd can **restart** it, with a new PID

**Notes:**

An application that crashes stops on its own, and tells why only through its
[exit status]({% link chapters/408-unix-processes/subject.md %}#exit-status) or
the signal that ended it. With `Restart=on-failure`, systemd watches for this and
starts the application again. The new process has a new PID.

A process that exits with a status of `0`, or that is terminated by `SIGTERM`,
`SIGINT` or `SIGHUP`, is considered to have stopped as it was asked to, and is
not restarted.

systemd can only restart an application that actually exits. This is one reason
the application runs in production mode under systemd: in development mode,
`node --watch` [keeps waiting for a file to change]({% link
chapters/413-how-to-improve/subject.md %}) when the application crashes, so the
process never ends, and systemd never sees it fail.

---

## Logs

- A service has **no terminal**
- Its standard output and error go to the **journal**
- When a service misbehaves, **read its logs first**

**Notes:**

A process started from your shell writes to your terminal, because it inherits
its [standard streams]({% link chapters/408-unix-processes/subject.md
%}#standard-streams). A service started by systemd has no terminal: systemd
collects its standard output and standard error, and journald, one of the
services of systemd, records them in the **journal**, with the time of each
line.

The journal also records what systemd did to the service: when it started it,
stopped it or restarted it, and why. The `journalctl` command reads it. When a
service fails to start, keeps restarting or does not answer, its logs are
usually the most useful thing to read.
