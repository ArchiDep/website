# Tutor notes: 412 Watch your processes

## Starting point

- 411 How a computer works: every part of the exercise shows one of its ideas,
  and links the section of 411 that explains it. Its notes hold the vocabulary
  and the misconceptions this exercise practises against.
- 410 Deploy a web application with SFTP, finished: Guess It in `~/guessit-ex`
  on the server, with its `node_modules`, and PostgreSQL installed with the
  database initialized. Only "Climb the process tree" needs it.
- 408 Unix Processes: `ps` with `-f`, `-e` and `--forest`, the PPID, the init
  process, a `sleep` watched from a second SSH session, and the null device.
- 404 Run your own virtual server on Microsoft Azure: the student logs in to
  their server over SSH, with 1 CPU (`B1s`) or 2 (`B2ats_v2`), and added swap
  space, which "Describe your server" shows.
- 402 Unix Basics: `df -h`, under "Inspecting volumes".
- 104 Hello SSH: an SSH key on the student's own computer, which "Which
  computer runs this?" uses from there. On Windows, that is the WSL.

The page shows the student's own server details. Several parts need two or more
terminals connected to the server at the same time.

## Learning objectives

Seeing on the student's own server what 411 explains: a program is a file and a
process is that program running, with its own PID and memory; every process
hangs from the init process; processes are isolated and need a channel to share
anything; a command runs on one computer, in one process; the server has the
parts of the machine of 411; and a process uses the processor only while it has
instructions to execute, taking turns with others when there are more busy
processes than cores. The page's "What have I done?" states what the student
should understand afterwards.

The parts are independent of one another. Most ask for a prediction before a
command, and every answer is in a solution box shown on the page from the start,
followed by a paragraph explaining what the part showed. "Take turns on the
processor" is optional.

The commands are instruments: their other options are not in the course. In `ps`
output, the `-` of `-bash` marks a login shell, the one an SSH session starts.
PID 1 is systemd: its command shows as `/sbin/init`, the name of the traditional
init program, until systemd restarts itself during an upgrade, after which it
shows as `/usr/lib/systemd/systemd --system --deserialize=…`. `ps -f -u` also
lists `systemd --user` and `(sd-pam)` for the student: systemd's per-user
service manager, started at login.

`ls -lL /usr/bin/sleep` shows a file of about 11 MB with a link count of 116:
Ubuntu's coreutils, rewritten in Rust, is a single program that does the work of
every basic command, under 116 names (hard links) in
`/usr/lib/cargo/bin/coreutils/`, and acts according to the name it was started
with.

A `B2ats_v2` server's 2 CPUs are the two hardware threads of a single AMD EPYC
core (`Thread(s) per core: 2`, `Core(s) per socket: 1`), whose model name says
`64-Core` for the whole physical chip. The page calls them two cores, as the
kernel uses them.

Not in the exercise: signals, and what `Ctrl+C` does, which "Process Management
on Linux" explains; how the init process knows to start PostgreSQL at boot,
which "Manage a PHP application with systemd as a Process Manager" shows; the
two levels of `sshd-session` processes; the kernel threads below `kthreadd` (PID
2), beyond the page's one sentence; the per-user systemd; hard links, and how
one program serves many command names; shell quoting beyond whether `$` is
replaced inside double or single quotes; and what `sys` time counts inside the
kernel beyond "the kernel's instructions, on behalf of the process".

## Where it leads

The exercise is short and nothing later depends on what it leaves on the server,
an `answer.txt` in the home directory. What it shows is used in the chapters on
running applications:

- "How to improve our basic deployment" names the flaws of starting Guess It by
  hand and of development mode, `node --watch`, whose extra process "Climb the
  process tree" shows.
- "Process Management on Linux" explains `Ctrl+C`, and how to keep a program
  running after logout.
- "Manage a PHP application with systemd as a Process Manager" has the init
  process start the application at boot, as it starts PostgreSQL here.
- "Docker" runs processes isolated from those of the host.

## Key steps

- **"Watch a process start and die"**.
  Question before: "When `sleep` ends, what is left of it on the server?"
  Expected after: a `sleep 60` line in `ps -f -u` while it runs, none
  afterwards, and a different PID for the second `sleep`. PIDs differ from the
  page's.
  Question after: "`ls -lL /usr/bin/sleep` shows the same file before, during
  and after. Which of the two is the process?"
- **"Climb the process tree"**, the first tree.
  Question before: "Who started your shell?"
  Expected after: dozens of kernel threads in square brackets at the top, below
  `kthreadd`; then `ps` under `-bash`, under two `sshd-session` lines, under
  `sshd`, under PID 1, in the middle of the tree rather than at its bottom.
- **"Climb the process tree"**, Guess It and PostgreSQL.
  Question before: "How many processes will `npm run dev` create, and what will
  they be called?"
  Expected after: four, from `npm run dev` to `/usr/bin/node server.js`, below
  the student's shell; PostgreSQL's `postgres` processes below PID 1, under the
  `postgres` user.
  Question after: "Why does Guess It stop when you log out, and PostgreSQL
  not?"
- **"Two shells, two memories"**.
  Question before: "Where does the shell keep `answer`?"
  Expected after: an empty line in the second terminal, two `-bash` lines with
  different PIDs, and `42` from `cat answer.txt`.
  Question after: "Which channel did the value go through, and which program
  wrote it, which read it?"
- **"Which computer runs this?"**, on the student's own computer.
  Expected: two different names from `hostname`, then the student's own home
  directory with double quotes and `/home/` plus their course username with
  single quotes.
  Question before the solution: "Which shell sees `$HOME` first, and when?"
  Question after: "How many shells, on how many computers, took part in each
  command?"
- **"Describe your server"**.
  Question before: "Which of these figures is the memory, and which the disk?"
  Expected after: `x86_64`, 1 or 2 CPUs, a hypervisor vendor of `Microsoft`,
  less than 1 GiB of `Mem`, 2 GiB of `Swap`, and a disk of about 30 GB. A
  `B2ats_v2` server has an AMD processor, whose model name gives no speed, and 2
  CPUs that share one core.
  Question after: "Guess It and PostgreSQL fit in less than 1 GiB. Where are
  their files?"
- **"Where does the time go?"**.
  Question before `sleep`: "`sleep` takes 2 seconds. How long does the
  processor work for it?"
  Expected after: `user` and `sys` close to 0 for `sleep`; `user` close to
  `real` for `sha256sum`, with `sys` a small fraction of it; `sys` as large as
  `user` or larger for `ls -R /usr`, and, on a first run, a `real` of several
  seconds, mostly spent waiting for the disk (15 s on a `B1s`).
  Question after: "Guess It is running and nobody plays. How much processor does
  it use?" (None while it waits.)
- **"Take turns on the processor"** (optional).
  Question before: the page's own prediction, with the number of cores in mind.
  Expected after: `real` still 10 seconds for each; `user` about half of a
  single command's with two commands on one core, about two thirds with three
  on two cores.
  Question after: "What would `user` be with as many commands as cores?" (About
  as long as `real`: they run in parallel.)

## Common pitfalls

- **`cd ~/guessit-ex` fails, or `npm run dev` finds no `package.json`**: the
  application was uploaded somewhere else in 410, or not at all. Hint: where
  did your SFTP application put the files?
- **No `postgres` processes in the tree**: PostgreSQL was not installed on this
  server, or the student searched for `postgresql`. Hint: the page says what to
  look for.
- **The second terminal prints `42`**: both commands ran in the same shell, or
  `answer=42` was typed in both. Question that leads to it: "What PID does
  `echo $$` print in each terminal?"
- **`cat answer.txt` says `No such file or directory`**: the two shells are in
  different directories. Hint: what does `pwd` print in each?
- **`ssh jde@W.X.Y.Z hostname` asks for a password, or says `Permission
denied (publickey)`**: the command ran on the server, which has no key to log
  in to itself, or, on Windows, in PowerShell instead of the WSL. Hint: what did
  the first `hostname` print?
- **Both `$HOME` commands print the same path**: the student's own computer is a
  Linux or WSL machine whose home directory happens to have the same path as on
  the server. The part's point still shows with a value that differs, such as
  `ssh jde@W.X.Y.Z "echo $(hostname)"` against the same command in single
  quotes.
- **The `Swap` line shows `0B`**: the swap step of 404 was skipped, or its
  `/etc/fstab` line did not survive the reboot. The other figures, and the
  rest of the exercise, do not depend on it.
- **A second `time ls -R /usr` is much faster**: the kernel keeps the
  directories it has just read in memory, the `buff/cache` column of `free -h`,
  so it no longer reads them from the disk.
- **In "Take turns on the processor", `user` is well above half**: the commands
  were started several seconds apart, so they ran alone part of the time, or
  the server has more cores than the student counted. Question that leads to
  it: "For how many of the 10 seconds were all the commands running at once?"
