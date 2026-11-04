# Tutor notes: 503 Unix Environment Variables

## Scope

The slides and the subject page cover different things. The slides are about
**environments** in the deployment sense: a development environment on the
developer's computer and a production environment on a server, the stages in
between in industrial use, and continuous delivery moving a program from one to
the next. They do not mention environment variables. The page is about
**environment variables**, and does not cover deployment environments.

The page defines an environment variable as a named value that can affect the
way running processes behave, with `HOME`, `LANG`, `TMPDIR` and `PATH` as
examples, and presents them as a way to configure a program without changing
its code.

Its largest part is managing them: reading one with `echo $NAME`, listing them
with `env`, checking what a program receives with `printenv NAME`, and the three
lifetimes of a variable set for one command (`NAME=value command`), for the
shell session (`export`), and in the shell configuration file (`.bashrc`,
evaluated again with `source`), then removing one with `unset`. Between them,
the difference between a shell variable and an environment variable, and that
every process receives a copy of its parent's environment.

It ends with a table of how ten languages read a variable, Node.js's
`process.env.FOO` among them, and with the fact that a value is always a string,
shown in Node.js with `parseInt` and `JSON.parse`.

## Left out

Taught later:

- Reading the configuration of a deployed application from the environment, and
  giving it to the application on the command line: "Configure a web application
  through environment variables".
- Giving a service its environment from a file, with systemd's
  `EnvironmentFile`: "Process Management on Linux" names the option, and "Manage
  a web application with systemd as a Process Manager" uses it.
- Setting environment variables in a hosting platform's web interface:
  "Platform-as-a-Service (PaaS)".

Not in the course: `.env` files and the libraries that load them, `env -i` and
`env NAME=value command`, `/etc/environment` and other system-wide settings, the
difference between login and non-login shells (`.profile`, `.bash_profile`), how
`PATH` is searched, and quoting rules beyond the examples' single quotes.

## Key concepts and vocabulary

- **Environment** (slides): the computer system a program is deployed and
  executed in, such as a **development** or a **production** environment.
- **Environment variable**: a named value in the environment of a process, which
  the program may read to decide how to behave.
- **Shell variable**: a variable the shell knows but does not pass to the
  programs it runs. An assignment without `export` sets one.
- **`export`**: puts a variable into the shell's environment, so that the
  processes it starts receive it.
- **Inheritance**: every process receives a copy of its parent's environment,
  and changes to it do not reach the parent.
- **Lifetime**: one command (`NAME=value command`), the shell session
  (`export`), or every new shell (an `export` line in `.bashrc`).
- **`printenv NAME`**: a separate program, so it shows what a program receives.
  `echo $NAME` shows what the shell knows.

## Misconceptions

- **Misconception:** `echo $FOO` shows what a program will receive.
  **Correction:** the shell replaces `$FOO` before `echo` runs, so `echo` shows
  the shell's value, shell variables included. `printenv FOO` shows what a
  program receives.
  Question that reveals it: "After `BAZ=qux`, why does `echo $BAZ` print `qux`
  but `printenv BAZ` nothing?"
- **Misconception:** `FOO=bar echo $FOO` prints `bar`.
  **Correction:** it prints an empty line. The shell replaces `$FOO` first,
  before the assignment applies to `echo`.
- **Misconception:** a variable set on a line of its own is given to the
  commands that follow.
  **Correction:** without `export`, it is a shell variable, which programs do
  not receive. Only `NAME=value command`, on one line, or `export` passes it on.
- **Misconception:** adding an `export` to `.bashrc` sets the variable in the
  current shell.
  **Correction:** `.bashrc` is read when a shell starts. The current shell needs
  `source ~/.bashrc`.
- **Misconception:** a program can set a variable for the shell that started it.
  **Correction:** a process gets a copy of its parent's environment, and nothing
  it changes goes back up.
- **Misconception:** `export MEANING_OF_LIFE=42` gives a program a number.
  **Correction:** every value is a string. In Node.js, adding `2` to it gives
  `'422'`.
- **Misconception:** `printenv $FOO` prints the value of `FOO`.
  **Correction:** the shell replaces `$FOO` first, so `printenv` looks for a
  variable named after its value.

## Used in

The course configures every application it deploys through environment
variables from here on. Exercises that lean on particular parts:

- "Configure a web application through environment variables" reads `PORT` and
  `DATABASE_URL` with `process.env`, sets `DATABASE_URL` for one command, and
  explains that it reaches `server.js` through `npm` and `node --watch` by
  inheritance. Its troubleshooting relies on the difference between a shell
  variable and an environment variable.
- "Manage a web application with systemd as a Process Manager" moves the
  variables into a file that systemd reads before starting the application.
- "Deploy a multi-component web application with nginx" and "Horizontally scale
  a web application with nginx as a load balancer" configure their applications
  through environment variables in systemd unit files.
- "Set up an automated deployment with Git hooks" sets `GIT_DIR` and
  `GIT_WORK_TREE` for Git.
