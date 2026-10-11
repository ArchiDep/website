# Tutor notes: 408 Unix Processes

## Scope

The slides hold the concepts, with no commands run on them; the subject page
holds the same concepts with commands and their output.

The first part is about processes, kept brief: a process is a running program,
identified by its PID, and a program started from the shell holds the terminal
until it ends. The slides stop there. The page adds parent processes and the
PPID, PID 0 and the init process, `ps` with `-f`, `-e` and `--forest`, a
`sleep` watched from a second SSH session, and `htop` and `free`. The `sleep`
example ends on its own: the page does not explain `Ctrl-C`.

The second part is the exit status: a number from 0 to 255 that a process
gives when it ends, `0` for success and anything else for failure, kept by the
shell in `$?`. Its meaning beyond that is up to each program. The page shows
`ls`'s, and how PHP, Java and Node.js read the exit status of a program they
run.

The third part, the largest, is the standard streams and redirection: why
streams replaced device-specific input and output, the three streams and their
file descriptors, that all three are connected to the terminal by default and
inherited by child processes (a stepped diagram from the SSH connection to the
shell and its commands), and the operators `<`, `>`, `>>`, `2>` and `&>`. The
running example is `grep -r PasswordAuthentication /etc/ssh`, which writes
lines to the standard output and `Permission denied` errors to the standard
error in the same run.

The last part is pipelines and the Unix philosophy: `ls -1 | wc -l`, `ps -ef |
grep sshd` (which finds `grep` itself), and a longer pipeline counting file
extensions. That pipeline is an illustration: its `sed` and `grep -E`
expressions are not explained.

Optional appendices on the page: discarding a stream into `/dev/null`,
redirecting one output stream to another (`i>&j`), here documents (`<<`), and
`procs` and `btm` as modern alternatives to `ps` and `htop`.

## Left out

Taught later:

- What a process is inside the machine, and why processes are isolated from
  each other: "How a computer works", then "Watch your processes".
- Signals, `kill`, and what `Ctrl-C` does: "Process Management on Linux". The
  page names signals only in a note saying they come later.
- Keeping a program running after logout, and reading a service's standard
  output and error with `journalctl`: "Process Management on Linux" and "Manage
  a PHP application with systemd as a Process Manager".

Not in the course: job control (`&`, `bg`, `fg`, `Ctrl-Z`, `nohup`), `2>&1`
and the order of redirections, file descriptors above 2, named pipes, process
substitution, `tee` beyond its use as a recipe in 404, `xargs`, regular
expressions, output buffering (the page states its effect on the order of
`&>`'s lines without naming it), zombie and orphan processes, process
priorities, and threads.

## Key concepts and vocabulary

- **Process**: a running instance of a program. A **program** is instructions
  in a file on disk; each run creates a new process.
- **PID**: the number identifying a process while it runs; PIDs may be reused
  later. **PPID**: the PID of the parent process, the one that started it. The
  **init process**, PID 1, is the ancestor of most processes.
- **Foreground**: a program started from the shell holds the terminal; the
  prompt comes back when it ends.
- **Exit status** (also called exit code or error level): `0` is success,
  anything else is failure, its meaning documented per program. **`$?`** holds
  the exit status of the last command only.
- **Standard streams**: **standard input** (`stdin`, file descriptor `0`),
  **standard output** (`stdout`, `1`) for data, **standard error** (`stderr`,
  `2`) for errors and diagnostics. A **stream** is an ordered sequence of bytes,
  text or binary, read until **EOF**.
- **Inheritance**: a child process gets its parent's streams. That is why a
  command run in an SSH session writes to the student's terminal.
- **Redirection**: the shell connects a stream to a file before starting the
  program. `>` (same as `1>`) replaces the file's contents, `>>` appends, `2>`
  redirects the standard error, `&>` both output streams, `<` the standard
  input. The shell creates the file if it does not exist.
- **Pipe** (`|`): connects the standard output of one process to the standard
  input of the next. A **pipeline** is a chain of them; its processes run at
  the same time. The standard error of each stays on the terminal.
- **Unix philosophy**: programs that do one thing well, work together, and
  handle text streams.
- **Null device**, `/dev/null` (appendix): discards everything written to it.

## Misconceptions

- **Misconception:** the program redirects its own output, or has to support
  redirection.
  **Correction:** the shell connects the stream before the program starts, and
  the program does not know. `grep` writes to its standard output as usual.
  Question that reveals it: "Did `grep` need an option to write into
  `found.txt`?"
- **Misconception:** `sudo command > /etc/file` writes the file as `root`.
  **Correction:** the shell that runs `sudo` opens the file, as the student,
  before `sudo` starts. This is why 404 writes root's files with `| sudo tee`,
  and why `psql`, run as `postgres` in "Deploy a web application with SFTP",
  can read `schema.sql` given with `<`: the student's shell opens it.
- **Misconception:** what appears in the terminal is all one output, so `>`
  should capture everything.
  **Correction:** the terminal shows two streams mixed. `>` takes only the
  standard output; the errors keep reaching the terminal.
  Question that reveals it: "After `> found.txt`, why is something still
  printed?"
- **Misconception:** a command that printed results succeeded; one that printed
  nothing failed.
  **Correction:** the exit status is a separate answer. `grep -r` can print
  matches and exit with `2` because it also met errors; `grep` finding nothing
  exits with `1` without printing anything; many successful commands print
  nothing.
- **Misconception:** `$?` belongs to a particular command and can be checked
  any time later.
  **Correction:** it is replaced by every command, including `echo $?` itself:
  a second `echo $?` prints `0`.
- **Misconception:** in a pipeline, each command finishes before the next
  starts, with the data stored in between.
  **Correction:** all the processes of a pipeline run at the same time, the data
  flowing between them. That is why `ps -ef | grep sshd` lists `grep` itself.
- **Misconception:** errors go through the pipe with the data.
  **Correction:** only the standard output is piped. The errors of each command
  still go to the terminal.
- **Misconception:** `>` adds to a file.
  **Correction:** `>` replaces its contents; `>>` adds to the end.
- **Misconception:** an exit status other than `0` always means the same kind of
  error.
  **Correction:** only `0` has a shared meaning. `grep` uses `1` for "nothing
  found", which is not an error, and `2` for an error; `ls` uses `1` and `2` for
  minor and serious problems.

## Used in

Every deployment from here on runs programs on the student's server and reads
what they print, so the course relies on processes and streams from now on.
Parts that exercises lean on in particular:

- "Unix plumbing" practises redirection, exit statuses and pipelines on the
  student's server.
- "Deploy a web application with SFTP" starts the application in the
  foreground, where it holds the terminal and its output appears in the SSH
  session; loads the database schema with `psql < schema.sql`; and compares
  `ls node_modules | wc -l` on the server and the student's computer.
- "Process Management on Linux" and "Manage a PHP application with systemd as
  a Process Manager" read the standard output and error of a service with
  `journalctl`.
- "Deploy a static site with nginx" and "Deploy a PHP website with nginx and
  the FastCGI process manager" filter a command's output with `| grep`.
