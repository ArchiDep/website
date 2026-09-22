# Tutor notes: 101 Command Line

## Scope

The subject page is the reference. Only its slides have:

- "Terminal, shell, command": three separate programs.
- "Where things are": the filesystem tree on Linux and the WSL (`/home`) and on
  macOS (`/Users`).
- A history of computer interfaces, and why the command line is still used.

On the page:

- "How to use the CLI": the prompt, arguments, options and values, escaping
  spaces, `Tab` completion, `--help`, `man`, quitting a pager with `q`, and
  reading usage syntax (`[]`, `|`, `...`, `<value>`).
- "Using the filesystem": `pwd`, `ls -a`, `cd` with relative and absolute
  paths, `.`, `..`, `~`, `mkdir -p`, `touch`, `echo` with `>` and `>>`, `cat`,
  and stopping a command with `Ctrl-C`.
- "Nano": opening, saving and quitting; "Setting nano as the default editor".
- "Vim": only how to get out (`Esc`, `:q!`, `Enter`).
- "The `PATH` variable": how the shell finds a command, `which`, running a file
  by its path (`./hello`), and adding a directory to the `PATH` in the shell's
  configuration file.
- Windows: installing the WSL, Windows drives under `/mnt/c`, copy and paste
  with `Ctrl-Shift-C` and `Ctrl-Shift-V`.

Optional: the appendices "Unleash your terminal" and "Vim".

The appendix "Installing the WSL step by step" is a reference for Windows users
rather than optional reading. It walks the installation with screenshots, and
answers two things the official instructions do not:

- **How to open the WSL again** once it is installed — the Ubuntu application in
  the start menu, not PowerShell and not the installation command. A student who
  does not know this is stuck before the exercises, at home or at the start of
  the next session.
- **The machine whose firmware has virtualization disabled**, which stops the
  installation of Ubuntu outright. The Task Manager's Performance tab, CPU,
  `Virtualization` line is how a student checks it; enabling it is a trip into
  the firmware settings, so a student in that state is not going to be typing
  commands for the rest of the session.

`cp`, `mv`, `rm`, `less` and `find` are not on the page. Hello Shell has
students look them up in the Command Line cheatsheet.

## Left out

Taught later, so do not explain them here beyond what the page does:

- Permissions (`chmod +x` is given as a recipe): "Unix Basics", "Unix
  Permissions".
- `sudo` and the system directories (`/etc`, `/usr/bin`): "Unix Basics".
- Processes, signals (what `Ctrl-C` sends), pipes and redirection other than
  `>` and `>>`: "Unix Processes", "Unix Pipeline".
- Environment variables in general, `export` and `source`: "Unix Environment
  Variables". Until then, the course applies a configuration change by opening
  a new terminal.

Not in the course: wildcards, quoting beyond escaping spaces, shell
configuration beyond one `export` line, `cmd` and PowerShell. There is no
subject on shell scripting; the Shell Scripting cheatsheet is the reference.

## Key concepts and vocabulary

- **Terminal, shell, command**: the terminal is the window (text and
  keystrokes); the shell (Bash, Zsh) reads the line and starts the command; a
  command is another program, a file on disk (`ls` is `/bin/ls`).
- **Prompt**: the course writes it `$>`, and it is not typed. When it is gone,
  a program is running and receives what is typed, not the shell.
- **Arguments** are separated by spaces. **Options** (`-a`, `--help`) say how,
  **values** say what; an option can take a value (`-n 5`).
- **One tree** rooted at `/`, with no drive letters. The **home directory** is
  `~`, the **working directory** is where you are, and files whose name starts
  with `.` are **hidden**.
- A **relative path** starts from the working directory; an **absolute path**
  starts with `/` or `~`.
- **`PATH`**: a list of directories, separated by `:`, searched in order; the
  first match wins. A first word starting with `/`, `~/`, `./` or `../` is run
  as a file instead.
- **Shell configuration file**: `~/.bashrc` (Bash, the WSL, Linux) or
  `~/.zshrc` (Zsh, macOS), read when a shell starts.
- **Placeholders**: `/path/to/projects`, `<value>`, `VALUE`, and `jde` for the
  student's username are replaced, never typed.

## Misconceptions

- **Misconception:** commands are built into the terminal.
  **Correction:** they are programs the shell finds through the `PATH`, which
  is why any executable put there becomes a command.
- **Misconception:** the terminal and the Finder or Explorer show different
  files.
  **Correction:** it is the same filesystem, reached another way.
- **Misconception:** the `PATH` holds programs.
  **Correction:** it holds the directories that contain them.
- **Misconception:** a change to `~/.bashrc` or `~/.zshrc` applies at once.
  **Correction:** only a shell started afterwards reads it.
- **Misconception:** the terminal is frozen.
  **Correction:** a program that has the keyboard is still running: `Ctrl-C`
  stops it, `q` quits a pager, and Vim needs `Esc`, `:q!`, `Enter`.
- **Misconception:** `Ctrl-C` copies.
  **Correction:** in a terminal, it stops the running command.

## Used in

The whole course: every later exercise is done at the command line, on the
student's computer and, in most exercises after Hello SSH, on a server too.
Parts that exercises lean on in particular:

- Hello Shell plays all of it on the student's own computer, and adds a
  directory to the `PATH`.
- Hello SSH shows that each machine has its own files and its own `PATH`.
- nano is how files are edited on the server, from "Run your own virtual server
  on Microsoft Azure" on.
