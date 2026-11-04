---
title: Unix Environment Variables
excerpt_separator: <!-- more -->
---

Learn about environment variables, a powerful way to configure applications and
processes in Unix-like operating systems, and how to manage them.

<!-- more -->

**You will need**

- A Unix CLI

**Recommended reading**

- [Unix Processes]({% link chapters/408-unix-processes/subject.md %})

## What is an environment variable?

An environment variable is a **named value that can affect the way running
processes will behave** on a computer.

When a process runs on a Unix system, it may query variables such as:

- `HOME` - The home directory of the user running the process.
- `LANG` - The default locale.
- `TMPDIR` - The directory in which to store temporary files.
- And more.

Another common example is the [`PATH`][path], an environment variable that
indicates in which directories to look for binaries to execute when typing
commands in a shell.

### What are they for?

Environment variables can **affect the behavior of programs without modifying
them**.

If a program bases some of its behavior on an environment variable, you can
simply change the value of the variable before running it, allowing you to
customize it without changing one line of code.

Environment variables can be used as a dynamic means of configuration, an
alternative to configuration files or hardcoded values.

## Managing environment variables

Getting them, listing them, setting them, deleting them.

### Getting an environment variable

To display the current value of an environment variable, use the `echo` command.
A variable can be referenced by its name prefixed with a dollar sign (`$`):

```bash
$> echo $USER
ubuntu

$> echo $HOME
/home/ubuntu

$> echo $SHELL
/bin/bash

$> echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

If a variable is not set, nothing will be displayed:

```bash
$> echo $FOO
```

### Listing all environment variables

The `env` command prints all environment variables currently set in your shell,
and their values:

```bash
$> env
LC_ALL=en_US.utf-8
LS_COLORS=rs=0:di=01;34:...
LANG=C.UTF-8
USER=ubuntu
PWD=/home/ubuntu
HOME=/home/ubuntu
LC_CTYPE=UTF-8
SSH_TTY=/dev/pts/0
MAIL=/var/mail/ubuntu
TERM=xterm-256color
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

### Setting an environment variable

There are multiple ways to set an environment variable. The lifetime of the
variable depends on how you set it:

- You can set it for one command.
- You can set it for the current shell session.
- You can set it in your shell configuration file (e.g. `.bashrc`).

To check what a program receives, use the `printenv` command. It prints the
value of the environment variable you name, or nothing if it is not set:

```bash
$> printenv PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

$> printenv FOO
```

`printenv` is a separate program run by your shell, so it shows the environment
that the shell gave it, like any other program you run. `echo $FOO` cannot do
that: the shell replaces `$FOO` by its value **before** `echo` runs, so it shows
what the shell knows, not what a program receives.

{% note type: tip %}

Give `printenv` the name of the variable, without the dollar sign. With
`printenv $FOO`, the shell replaces `$FOO` by its value first, and `printenv`
looks for a variable named after that value instead.

{% endnote %}

#### Setting a variable for one command

You can prefix a command by an environment variable assignment:

```bash
$> FOO=bar printenv FOO
bar
```

This only sets the variable **for the process executed by that command**. As you
can see, the variable is still not set if we check later, even in the same shell
session:

```bash
$> printenv FOO
```

{% note type: more %}

This is also why `FOO=bar echo $FOO` prints an empty line: the shell has already
replaced `$FOO` by its value, which is empty, before the assignment applies to
`echo`.

{% endnote %}

#### Setting a variable for a shell session

The `export` command exports an environment variable to all the child processes
running in the current shell session:

```bash
$> export FOO=bar

$> printenv FOO
bar

$> printenv FOO
bar
```

As you can see, the variable remains set.

However, if you close the shell and reopen a new one, the variable is no longer
set:

```bash
$> printenv FOO
```

#### Shell variables and environment variables

Without `export`, an assignment such as `BAZ=qux` only sets a **shell
variable**. The shell knows it, but does not pass it to the programs it runs:

```bash
$> BAZ=qux

$> echo $BAZ
qux

$> printenv BAZ
```

Every process receives a copy of the environment of its [parent
process]({% link chapters/408-unix-processes/subject.md %}#parent-processes).
`export` is what puts a variable into the environment of the shell, so that the
processes it starts receive it. A program you run, such as a web application,
can only read the variables that were exported to it.

#### Setting a variable in the shell configuration file

If you add the `export` command to your shell configuration file (`.bashrc` for
[Bash][bash], `.zshrc` for Zsh), it will be run every time you start a new
shell:

```bash
$> echo 'export FOO=bar' >> ~/.bashrc

$> tail -n 1 ~/.bashrc
export FOO=bar
```

This will not immediately take effect in the current shell, as the configuration
file is only evaluated when the shell starts. But you can evaluate it with the
`source` command:

```bash
$> source ~/.bashrc

$> printenv FOO
bar
```

The variable will still be set if you close this shell and launch another one:

```bash
$> printenv FOO
bar
```

### Removing an environment variable

The `unset` command removes a variable from the environment:

```bash
$> printenv FOO
bar

$> unset FOO

$> printenv FOO
```

{% note type: tip %}

Of course, if the variable is exported in your shell configuration file, this
will only remove it for the current shell session. You must remove the export
from the configuration file to remove the variable from future shells.

{% endnote %}

### Getting environment variables from code

Every programming language has a simple way of retrieving the value of environment variables:

| Language | Code                                                                                                                                      |
| :------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| C        | [`getenv("PATH")`](http://man7.org/linux/man-pages/man3/getenv.3.html)                                                                    |
| Elixir   | [`System.get_env("FOO")`](https://hexdocs.pm/elixir/System.html#get_env/2)                                                                |
| Erlang   | [`os.get_env("FOO")`](http://erlang.org/doc/man/os.html#getenv-1)                                                                         |
| Go       | [`os.Getenv("FOO")`](https://golang.org/pkg/os/#Getenv)                                                                                   |
| Java     | [`System.getenv("FOO")`](https://docs.oracle.com/en/java/javase/12/docs/api/java.base/java/lang/System.html#getenv%28java.lang.String%29) |
| Node.js  | [`process.env.FOO`](https://nodejs.org/api/process.html#process_process_env)                                                              |
| PHP      | [`getenv("FOO")`](https://www.php.net/manual/en/function.getenv.php)                                                                      |
| Python   | [`os.getenv("FOO")`](https://docs.python.org/3/library/os.html#os.getenv)                                                                 |
| Ruby     | [`ENV["FOO"]`](https://ruby-doc.org/core-2.6.5/ENV.html#method-c-5B-5D)                                                                   |
| Rust     | [`env::var("FOO")`](https://doc.rust-lang.org/std/env/fn.var.html)                                                                        |

### Environment variables are always strings

You may put whatever kind of value you want into an environment variable:

```bash
export MEANING_OF_LIFE=42  # A number
export PERSON='{"name":"John Doe","age":24}'  # Serialized JSON
```

In your programming language of choice, however, the value will **always** be a
character string. It's up to you to parse it if you want to use it as another
type, for example in Node.js:

```js
> console.log(process.env.MEANING_OF_LIFE);
42
*> process.env.MEANING_OF_LIFE + 2
*'422'
> typeof process.env.MEANING_OF_LIFE
string
> parseInt(process.env.MEANING_OF_LIFE, 10) + 2
44

> process.env.PERSON.name
undefined
> JSON.parse(process.env.PERSON).name
'John Doe'
```

## References

- [Environment Variable][env-var]
- [Linux/Unix list of common environment variables](https://www.cyberciti.biz/howto/question/general/linux-unix-list-common-environment-variables.php)
- [All you need to know about Unix environment variables](https://www.networkworld.com/article/3215965/unix/all-you-need-to-know-about-unix-environment-variables.html)

[agile]: https://en.wikipedia.org/wiki/Agile_software_development
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[cd]: https://en.wikipedia.org/wiki/Continuous_delivery
[devops]: https://en.wikipedia.org/wiki/DevOps
[env]: https://en.wikipedia.org/wiki/Deployment_environment
[env-var]: https://en.wikipedia.org/wiki/Environment_variable
[path]: https://en.wikipedia.org/wiki/Path_(computing)
