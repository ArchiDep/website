---
title: Watch your processes
cloud_server: details
excerpt_separator: <!-- more -->
---

Small exercises on your cloud server to watch processes start, run and stop,
and to see how they can and cannot communicate.

{% callout type: exercise %}

Do these exercises on your cloud server, through SSH, except where a step says
to run a command on your own computer. Some of them need two terminals
connected to your server at the same time.

{% endcallout %}

<!-- more -->

[How a computer works][hcw] explained what a computer physically does when it
runs a program, and what the processes of your deployment are. Each part of this
page is a **separate, short exercise** that shows one of those ideas happening
on your own server. They do not depend on each other: if one goes wrong, you can
still do the next.

Most parts ask you to predict what will happen before you run a command. Make
your prediction, then run the command and check your answer. Each part ends with
an explanation of what it showed.

In the commands below, replace `jde` with your username, and `W.X.Y.Z` with
your server's public IP address.

## :exclamation: Watch a process start and die

Open **two terminals**, and connect both to your server.

In the first terminal, list your own processes:

```bash
$> ps -f -u jde
```

In the second terminal, run a `sleep` command, which does nothing for 60
seconds:

```bash
$> sleep 60
```

While it is running, list your processes again in the first terminal. Note the
PID of the `sleep` process.

Wait for the 60 seconds to pass, or stop `sleep` with `Ctrl+C`, then list your
processes once more. Is the `sleep` process still there?

Now run `sleep 60` again in the second terminal, and list your processes in the
first. Does the new `sleep` process have the same PID as the previous one?

{% solution title: "Check your answers", emoji: thinking, reveal: always %}

```bash
$> ps -f -u jde
UID          PID    PPID  C STIME TTY          TIME CMD
...
jde        12034   12033  0 14:02 pts/1    00:00:00 -bash
jde        12102   12034  0 14:05 pts/1    00:00:00 sleep 60
...
```

Once `sleep` has stopped, it is no longer in the list. The second `sleep` gets
a **different PID**: it is a new process, not the first one coming back.

{% endsolution %}

Finally, look at the file of the `sleep` program:

```bash
$> ls -lL /usr/bin/sleep
```

{% note type: more %}

`/usr/bin/sleep` is a symbolic link, a reference to another file. The `-L`
option makes `ls` describe the file it leads to, the program itself, instead of
the link.

{% endnote %}

It was there before you ran `sleep`, it was there while `sleep` was running, and
it is still there now.

That file is a **program**: inert instructions in the storage of your server.
Each time you ran `sleep`, the operating system copied that program into memory
and started executing it: a **process**, with its own PID and its own memory.
When the process ended, the kernel freed its memory, and nothing of it was left,
except the program's file, ready to be run again.

Running the same program twice gives two different processes. This is the
difference between the program and the process described in [How a computer
works][hcw-processes].

## :exclamation: Climb the process tree

Open **two terminals**, and connect both to your server.

In the second terminal, display every process as a tree:

```bash
$> ps -ef --forest
```

Find the `ps -ef --forest` command you just ran. Follow its parent process ID
(`PPID`) to its parent, then to its parent's parent, and so on. Where do you end
up?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```bash
$> ps -ef --forest
UID          PID    PPID  C STIME TTY          TIME CMD
root           2       0  0 09:12 ?        00:00:00 [kthreadd]
root           3       2  0 09:12 ?        00:00:00  \_ [pool_workqueue_release]
...
root           1       0  0 09:12 ?        00:00:03 /usr/lib/systemd/systemd --system --deserialize=99
...
root         888       1  0 09:12 ?        00:00:00 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
root       12020     888  0 14:01 ?        00:00:00  \_ sshd-session: jde [priv]
jde        12033   12020  0 14:01 ?        00:00:00  |   \_ sshd-session: jde@pts/1
jde        12034   12033  0 14:01 pts/1    00:00:00  |       \_ -bash
root       12390     888  0 14:08 ?        00:00:00  \_ sshd-session: jde [priv]
jde        12401   12390  0 14:08 ?        00:00:00      \_ sshd-session: jde@pts/2
jde        12402   12401  0 14:08 pts/2    00:00:00          \_ -bash
jde        12411   12402  0 14:09 pts/2    00:00:00              \_ ps -ef --forest
...
```

The PIDs on your server are different, but the chain is the same. In this
example, your `ps`, PID 12411, has the PPID 12402: it was started by your shell
(`-bash`). The shell's PPID, 12401, leads to your SSH session, which is two
`sshd-session` processes, 12401 and its parent 12390. The PPID of 12390 is 888,
the SSH server (`sshd`), whose own PPID is 1: **the init process, PID 1**. On
Ubuntu, the init process is systemd: its line may show `/sbin/init` instead, the
traditional name of the init program.

The names in square brackets at the top of the tree, below PID 2 (`kthreadd`),
are not programs: they are parts of the kernel itself, which it runs as
processes of its own.

{% endsolution %}

Now, in the first terminal, start Guess It, as you did in the [SFTP
deployment][sftp-run]:

```bash
$> cd ~/guessit-ex
$> npm run dev
```

In the second terminal, display the tree again. Which processes did running
Guess It create? Then find PostgreSQL in the tree (look for `postgres`). Who
started it?

{% solution title: "Check your answers", emoji: thinking, reveal: always %}

```bash
$> ps -ef --forest
...
jde        12034   12033  0 14:01 pts/1    00:00:00  |       \_ -bash
jde        12305   12034  0 14:12 pts/1    00:00:00  |           \_ npm run dev
jde        12316   12305  0 14:12 pts/1    00:00:00  |               \_ sh -c node --watch server.js
jde        12317   12316  0 14:12 pts/1    00:00:01  |                   \_ node --watch server.js
jde        12328   12317  0 14:12 pts/1    00:00:00  |                       \_ /usr/bin/node server.js
...
postgres     951       1  0 09:12 ?        00:00:00 /usr/lib/postgresql/.../bin/postgres -D /var/lib/postgresql/...
postgres     960     951  0 09:12 ?        00:00:00  \_ postgres: ...: checkpointer
postgres     961     951  0 09:12 ?        00:00:00  \_ postgres: ...: background writer
...
```

`npm run dev` is not one process but several: `npm` starts a shell (`sh`), which
starts Node.js, which starts another Node.js process to run `server.js` and
start it again whenever the file changes. None of them is called "Guess It": the
program that runs is Node.js, and Guess It's JavaScript is data that Node.js
reads.

PostgreSQL was not started by you, but by the init process (PID 1): when you
installed it, and again each time your server boots. It is several processes
too.

{% endsolution %}

Stop Guess It with `Ctrl+C` once you are done.

Every program running on your server was started by another process, which is
its parent. Climbing the tree always ends at **the init process, PID 1**: the
first process the kernel starts once it has [booted][hcw-booting]. It starts the
services of the server, such as the SSH server and PostgreSQL, which start
others in turn.

What you start yourself hangs below your shell, which hangs below your SSH
connection. That is why Guess It stops when you press `Ctrl+C` or disconnect,
while PostgreSQL keeps running.

## :exclamation: Two shells, two memories

Open **two terminals**, and connect both to your server.

In the first terminal, create a shell variable named `answer`, and display it:

```bash
$> answer=42
$> echo $answer
42
```

What will the same `echo` command display in the second terminal?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```bash
$> echo $answer

```

Nothing: an empty line. The second shell has no variable named `answer`.

{% endsolution %}

List your processes with `ps -f -u jde`. How many `bash` processes do you see?
Which one holds the variable `answer`?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```bash
$> ps -f -u jde
UID          PID    PPID  C STIME TTY          TIME CMD
jde        12010       1  0 14:01 ?        00:00:00 /usr/lib/systemd/systemd --user
jde        12012   12010  0 14:01 ?        00:00:00 (sd-pam)
jde        12033   12020  0 14:01 ?        00:00:00 sshd-session: jde@pts/1
jde        12034   12033  0 14:01 pts/1    00:00:00 -bash
jde        12401   12390  0 14:20 ?        00:00:00 sshd-session: jde@pts/2
jde        12402   12401  0 14:20 pts/2    00:00:00 -bash
jde        12450   12402  0 14:21 pts/2    00:00:00 ps -f -u jde
```

Two `bash` processes, one per terminal, with different PIDs. Only the shell of
the first terminal holds `answer`, in its own memory.

{% endsolution %}

To get the value from the first shell to the second, write it to a file in the
first terminal:

```bash
$> echo $answer > answer.txt
```

Then read the file in the second terminal:

```bash
$> cat answer.txt
42
```

Both terminals run the same program, Bash, as two separate processes. Each one
has **its own memory**, which the operating system gives it, and no process can
read or write the memory of another. A shell variable lives in the memory of one
shell, so the other shell cannot see it.

To share anything, isolated processes need a channel that the operating system
provides. A file is one: one process writes it, and another reads it. [How a
computer works][hcw-channels] lists the others. You have already used two of
them: a pipe, in a shell pipeline, and a socket, when you connected two `nc`
processes over the network in [Make TCP connections][tcp]. Guess It and
PostgreSQL use a socket too.

## :exclamation: Which computer runs this?

This part starts **on your own computer**, not on your server. Open a terminal
without connecting to your server, and display the name of the computer:

```bash
$> hostname
```

Then ask your server for its name, through SSH:

```bash
$> ssh jde@W.X.Y.Z hostname
```

Every user has a home directory, whose path is in the variable `HOME`. Display
it through SSH with these two commands, which look almost the same, one with
double quotes and one with single quotes:

```bash
$> ssh jde@W.X.Y.Z "echo $HOME"
/Users/jdoe

$> ssh jde@W.X.Y.Z 'echo $HOME'
/home/jde
```

The first command displays the home directory **on your own computer** (here, on
a Mac), and the second the one **on your server**. Yet `echo` ran on your server
both times. Can you guess why? Think of the processes involved in each command,
and of the computer each one runs on.

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

Two shells took part in each command, on two different computers. Your shell, on
your computer, read the command first and started `ssh`. The `ssh` process then
had your server start a shell of its own, which ran `echo`.

Inside double quotes, your shell replaces `$HOME` with its own value **before**
it even starts `ssh`. The server received `echo /Users/jdoe`, and displayed it
faithfully. Inside single quotes, your shell leaves `$HOME` as it is, so the
server's shell received `echo $HOME`, and replaced it with its own value.

{% endsolution %}

Both shells are processes with their own memory, on their own computer, with
their own value for `HOME`. Whenever you run a command, ask [which computer it
runs on, and when][hcw-place].

## :exclamation: Describe your server

Back on your server, ask for a description of its processor with `lscpu`
(**l**i**s**t **CPU**), which only displays information:

```bash
$> lscpu
```

Then display its memory with `free -h` and its disk space with `df -h /`, as you
did in [Unix Basics][unix-basics-df] and when you [ran your virtual
server][swap]:

```bash
$> free -h
$> df -h /
```

These commands display a lot of information. Find the following figures in their
output, and say which part of the machine of [How a computer
works][hcw-processes] each one is about (the processor, its cores, its caches,
the memory, the storage or the firmware):

- `Architecture` and `CPU(s)`, in the output of `lscpu`.
- The lines starting with `L1d`, `L2` and `L3`, in the output of `lscpu`.
- `Hypervisor vendor`, in the output of `lscpu`.
- The `Mem` and `Swap` lines of `free -h`.
- The `Size` of `df -h /`.

{% solution title: "Check your answers", emoji: thinking, reveal: always %}

```bash
$> lscpu
Architecture:             x86_64
  CPU op-mode(s):         32-bit, 64-bit
  ...
CPU(s):                   1
  ...
  Model name:             Intel(R) Xeon(R) Platinum 8370C CPU @ 2.80GHz
  ...
Virtualization features:
  Hypervisor vendor:      Microsoft
  Virtualization type:    full
Caches (sum of all):
  L1d:                    48 KiB (1 instance)
  L1i:                    32 KiB (1 instance)
  L2:                     1.3 MiB (1 instance)
  L3:                     48 MiB (1 instance)
...

$> free -h
               total        used        free      shared  buff/cache   available
Mem:           835Mi       271Mi       192Mi        18Mi       409Mi       563Mi
Swap:          2.0Gi        24Mi       2.0Gi

$> df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        28G  5.1G   23G  18% /
```

Your figures may differ, depending on the size of the server you chose and on
the machine Azure runs it on.

- `x86_64` is the processor's instruction set, the one of most cloud servers. It
  is a **64-bit** processor: its registers, and its addresses, are 64 bits wide,
  where [the machine of the presentation][hcw-instruction-set] had 8-bit values
  and 4-bit addresses.
- `CPU(s)` is the number of **cores** the kernel can give work to: 1 or 2 on the
  servers of this course. On a server with 2, `Thread(s) per core: 2` means that
  they are two halves of one physical core, which executes the instructions of
  two processes at once by interleaving them. The kernel uses them as two cores,
  and so does this exercise.
- If the model name says `64-Core`, that is the processor of the machine Azure
  runs your server on, shared with many other virtual machines.
- If the model name ends with a speed in GHz, it is the speed of the processor's
  **clock**: 2.8 billion ticks per second here.
- `L1d`, `L2` and `L3` are the processor's **caches**, small and fast memories
  inside the processor's chip that keep copies of recently used memory.
- `Hypervisor vendor: Microsoft` says that your server is a **virtual machine**:
  Azure's software, not a chip on a motherboard, provides its firmware and its
  hardware.
- `Mem` is the **memory** (RAM): less than 1 GiB in total. `Swap` is the swap
  space you created on the disk, where the kernel moves parts of the memory when
  it runs out.
- `Size` is the **storage**, where the programs and files stay when the server
  is turned off: about 30 GB, more than thirty times the memory.

{% endsolution %}

Every figure of a computer's description belongs to one part of the machine: the
processor, with its instruction set, word size, clock, cores and caches; the
memory; the storage. Your server has all of these parts, like your laptop, only
smaller.

Compare the size of the memory with the size of the disk. Every program running
on your server, Guess It and PostgreSQL included, has to fit in less than 1 GiB
of memory, while its files sit on the much larger disk. That is the difference
between the program in the storage and the process in memory, once again.

## :exclamation: Where does the time go?

Put `time` in front of a command, and the shell reports how long it took when it
is done. Try it on `sleep`:

```bash
$> time sleep 2
```

`time` reports three durations. `real` is the time that passed on a clock. What
do you think `user` and `sys` are, and why are they so small?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```bash
$> time sleep 2

real    0m2.003s
user    0m0.001s
sys     0m0.002s
```

`user` and `sys` are the time **the processor spent running the process**.
`sleep` waited for 2 seconds, and a process that waits does not use the
processor at all.

{% endsolution %}

Now give the processor some work. The following command basically performs
computations during 10 seconds, and then stops. Time it:

```bash
$> time timeout 10 sha256sum /dev/zero
```

{% note type: more %}

The `sha256sum` command computes a SHA-256 fingerprint of the data it reads, the
same kind of fingerprint SSH showed you for your server's key. `/dev/zero` is a
device that gives an endless supply of zero bytes, so `sha256sum` would compute
forever: `timeout 10` stops it after 10 seconds.

{% endnote %}

How does `user` compare with `real` this time?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```bash
real    0m10.006s
user    0m9.678s
sys     0m0.304s
```

`user` is almost as long as `real`: the processor was busy executing this
process for the whole time.

{% endsolution %}

Finally, time a command that lists every file under `/usr`, and throws the list
away into the [null device][null]. It may take several seconds:

```bash
$> time ls -R /usr > /dev/null
```

How does `sys` compare with `user` this time? And `real` with both of them?

{% solution title: "Check your answers", emoji: thinking, reveal: always %}

```bash
real    0m14.900s
user    0m0.241s
sys     0m0.518s
```

This time, `sys` is as large as `user`, or larger, where it was a small fraction
of `user` for `sha256sum`. And `real` is much longer than both put together, at
least the first time you run the command.

{% endsolution %}

`real` is how long you waited. `user` and `sys` are how long the processor
worked for the process, and they only count while it does:

- `user` is the time the processor spent executing **the program's own
  instructions**, such as the calculations of `sha256sum`. Computing a
  fingerprint is arithmetic on the bytes it reads, repeated in a loop: like [the
  multiplication of the presentation][hcw-program], it comes down to
  instructions that compute, and jumps.
- `sys` is the time the processor spent executing **the kernel's instructions**,
  on behalf of the process. `ls` cannot read a disk by itself: it asks the
  operating system, with [system calls][hcw-os], to read every directory under
  `/usr`, and the kernel does the work.
- The rest of `real` is time when the process **waited**, and the processor did
  something else, or nothing. `sleep` only waited, and `ls` spent most of its
  time waiting for the disk to answer.

This is what the process boxes of an architecture diagram hide. A process that
is "running", such as Guess It waiting for a request, mostly waits, and uses no
processor until something happens.

## :question: Take turns on the processor

This part reuses the `sha256sum` command of [Where does the time
go?](#where-does-the-time-go). Check how many cores your server has: it is the
`CPU(s)` line of `lscpu`, as in [Describe your server](#describe-your-server).

Open **one more terminal than your server has cores**: two terminals if it has
one core, three if it has two. Connect all of them to your server.

**Before you run anything**, predict: if you start the command in all of these
terminals at the same time, how will their `real` and `user` durations compare
with the ones you measured for a single command?

Then run the command in every terminal, starting them as close together as you
can:

```bash
$> time timeout 10 sha256sum /dev/zero
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

On a server with one core, running two commands:

```bash
real    0m10.005s
user    0m5.007s
sys     0m0.159s
```

`real` is still 10 seconds, since `timeout` stops each command after 10 seconds.
But `user` is about **half** of what it was for a single command. On a server
with two cores running three commands, it is about two thirds instead.

{% endsolution %}

A core executes the instructions of one process at a time. With more busy
processes than cores, the kernel makes them **take turns**: it switches the core
from one process to another many times per second, so that all of them seem to
run at once. This is **concurrency**, like two queues at a single coffee machine
in [the presentation][hcw-taking-turns]. Each command ran for 10 seconds, but
only got the processor for its share of them, and spent the rest waiting for its
turn: it computed less in the same time.

With as many cores as busy processes, they would run **in parallel**, one per
core, and each would get the processor for the whole 10 seconds. More cores only
help when there is work for each of them.

## :checkered_flag: What have I done?

You watched the ideas of [How a computer works][hcw] happen on your own server,
with commands you already knew.

**None of these ideas is specific to Linux.** They are how computers work,
whatever their operating system: your own computer runs programs as isolated
processes in its memory, started one from another since it booted, in the same
way. macOS and Windows do the same things, sometimes under other names and with
other tools. Both list their processes with their PIDs, in the Activity Monitor
on macOS and the Task Manager on Windows. On macOS, the init process is called
`launchd`; on Windows, several programs share its job.

A program is a file in the storage. A process is that program copied into memory
and being executed, with its own PID. When the process ends, the kernel frees
its memory, and only the file is left. Running the same program again gives a
new process, with a new PID.

Every process was started by another one. Climbing the process tree always ends
at the init process, PID 1, which the kernel starts at the end of the boot.
Services such as PostgreSQL hang from it. What you run yourself, such as Guess
It, hangs from your shell, and stops with it.

Each process has its own memory, which no other process can read. Two shells
running the same program do not share their variables. Isolated processes can
only communicate through channels the operating system provides: files, pipes,
sockets, or shared memory. Guess It and PostgreSQL talk through a socket.

A command does not run "somewhere": it runs on one computer, in the memory of a
process, at one moment. With SSH, two shells on two computers were involved,
each with its own `HOME`, and the quotes decided which one read `$HOME`.

Your server is a computer like the one in the presentation, only much faster: a
64-bit processor with its cores, clock and caches, a memory of less than 1 GiB,
and a disk far larger than the memory. It is a virtual machine, whose hardware
Azure's software provides.

A process only uses the processor while it has instructions to execute: its own
(`user`), or the kernel's working for it through system calls (`sys`). A process
that waits uses no processor at all.

## :boom: Troubleshooting

### :boom: `answer: command not found`

You put spaces around the `=` sign. A shell variable is created with no spaces:
`answer=42`, not `answer = 42`.

### :boom: My `sleep` process is not in the list

Check that both terminals are connected to the same server, with `hostname`, and
that you replaced `jde` with your own username in the `ps` command.

### :boom: `Error: listen EADDRINUSE: address already in use :::3000`

Guess It is already running, in another terminal. Use that one, or stop it with
`Ctrl+C` in the terminal where it is running before you start it again.

[hcw]: {% link chapters/411-how-a-computer-works/subject.md %}
[hcw-booting]: {% link chapters/411-how-a-computer-works/subject.md %}#booting
[hcw-channels]: {% link chapters/411-how-a-computer-works/subject.md %}#isolated-processes-communicate-through-channels
[hcw-os]: {% link chapters/411-how-a-computer-works/subject.md %}#what-the-operating-system-does
[hcw-place]: {% link chapters/411-how-a-computer-works/subject.md %}#a-particular-place-at-a-particular-time
[hcw-processes]: {% link chapters/411-how-a-computer-works/subject.md %}#programs-and-processes
[hcw-instruction-set]: {% link chapters/411-how-a-computer-works/slides/slides.md %}#the-instruction-set
[hcw-program]: {% link chapters/411-how-a-computer-works/slides/slides.md %}#from-program-to-instructions
[hcw-taking-turns]: {% link chapters/411-how-a-computer-works/slides/slides.md %}#taking-turns
[null]: {% link chapters/408-unix-processes/subject.md %}#the-devnull-device
[sftp-run]: {% link chapters/410-sftp-deployment/exercise.md %}#run-the-application
[swap]: {% link chapters/404-run-virtual-server/exercise.md %}#add-swap-space-to-your-virtual-server
[tcp]: {% link chapters/407-tcp/exercise.md %}
[unix-basics-df]: {% link chapters/402-unix-basics/subject.md %}#inspecting-volumes
