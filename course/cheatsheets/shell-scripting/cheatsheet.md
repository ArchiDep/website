---
title: Shell Scripting Cheatsheet
sidebar_title: Shell Scripting
---

Anything you can type in your terminal, you can put in a file and have the
machine do for you, the same way every time. That file is a script, and this is
how you write one with [Bash][bash]. Most of it also works in other POSIX
shells like [`sh`][sh] and [Zsh][zsh].

The companion to this page is the [Command Line Cheatsheet]({% link
cheatsheets/command-line/cheatsheet.md %}), which covers the commands you put
_in_ a script.

## What is a script?

A file that can be executed is one of two things: a **binary file**, containing
machine code compiled from source, or a **script**, a text file that an
interpreter reads and runs.

The first line of a script, the **shebang**, names that interpreter:

```bash
#!/bin/bash
```

This one says the file should be run by [Bash][bash]. There must be no space
between `#!` and the path.

A script whose interpreter is a shell is a **shell script**. A script whose
interpreter is PHP is a PHP script: still a script, but not a shell script.
What you may write inside depends entirely on the interpreter — in a Bash
script, anything you could type at a Bash prompt.

| Shebang             | Script contents             |
| :------------------ | :-------------------------- |
| `#!/bin/sh`         | [Bourne shell][sh] commands |
| `#!/bin/bash`       | [Bash shell][bash] commands |
| `#!/bin/zsh`        | [Z shell][zsh] commands     |
| `#!/usr/bin/node`   | [Node.js][node] code        |
| `#!/usr/bin/php`    | [PHP][php] code             |
| `#!/usr/bin/python` | [Python][python] code       |
| `#!/usr/bin/ruby`   | [Ruby][ruby] code           |

{% note %}

The path must be where the interpreter actually is on the machine, which may
differ from this table. `which bash` says where Bash is.

{% endnote %}

## Writing and running a script

### Create a script (`printf`, `nano`)

Write the whole thing in one command:

```bash
$> printf '#!/bin/bash\necho Hello World\n' > test.sh
```

{% note type: more %}

The `printf` (**print** **f**ormat) command is similar to the `echo` command but
it has better support for special characters like new lines (`\n`).

{% endnote %}

Or open an editor and type it in:

```bash
$> nano test.sh
```

### Run a script (`chmod +x`, `./script`)

A file you have just created is not executable. Make it so, then run it by its
path:

```bash
$> chmod +x test.sh
$> ./test.sh
Hello World
```

{% note type: tip %}

The `./` matters: without it, the shell looks for `test.sh` in the directories
of your `PATH` instead of in the current directory. See [make a file
executable]({% link cheatsheets/command-line/cheatsheet.md
%}#make-a-file-executable-chmod-x) and [run a program]({% link
cheatsheets/command-line/cheatsheet.md %}#run-a-program-program).

{% endnote %}

### Know where the script runs (`cd`)

A script starts in the directory it was run **from**, not the one it lives in.
Use `cd` to move around:

```bash
#!/bin/bash
pwd
cd /home
pwd
```

Run from `/some/where/over/the/rainbow`, this prints:

```
/some/where/over/the/rainbow
/home
```

## Variables

### Use a variable

No spaces around the `=`:

```bash
#!/bin/bash
FOO=bar
echo "$FOO"   # prints "bar"
```

Quote the variable when you declare it and when you use it, so that a value
containing whitespace (spaces, new lines, etc) stays one value:

```bash
#!/bin/bash
FOO="bar baz"
echo "$FOO"   # prints "bar baz"
```

### Store the output of a command (`$(...)`)

```bash
#!/bin/bash
FILES=$(ls -1)
NUMBER_OF_FILES=$(echo "$FILES" | wc -l)
echo "There are $NUMBER_OF_FILES files"
```

This script would print `There are 10 files` if there are 10 files in the
current directory.

{% note type: more %}

You will also see the older backtick form, `` FILES=`ls -1` ``. It does the same
thing, but unlike backticks, `$(...)` can be nested.

{% endnote %}

### Read and set environment variables (`export`)

Environment variables are ordinary variables in a script:

```bash
#!/bin/bash
echo "$PATH"
```

Set one the way you would in any shell:

```bash
#!/bin/bash
export FOO=bar
```

{% note %}

`$FOO` will only be set for this script and the programs it starts. The shell
you ran the script from is unchanged.

{% endnote %}

### Use the arguments the script was given (`$1`, `$@`)

Bash has a number of [special variables][bash-special-vars] which are always
available:

| Variable | Description                                                     |
| :------- | :-------------------------------------------------------------- |
| `$0`     | Name of the command being executed.                             |
| `$1`     | First argument passed on the command line (then `$2`, `$3`...). |
| `$@`     | All arguments passed.                                           |
| `$?`     | Exit value of the last executed command.                        |

For example, this script says hello to the name passed as the first argument:

```bash
#!/bin/bash
echo "Hello $1"
```

```bash
$> ./hello.sh World
Hello World
```

## Logic

### Test a condition (`if`)

Bash has a classic `if/then/else` construct:

```bash
#!/bin/bash
FOO="bar"

if [[ "$FOO" == "foo" ]]; then
  echo "FOO is foo"
elif [[ "$FOO" == "bar" ]]; then
  echo "FOO is bar"
else
  echo "FOO is something else"
fi
```

{% note type: warning %}

`==` compares **strings**, `-eq` compares **numbers**. Comparing two strings
with `-eq` compares 0 to 0, so the first branch always matches.

{% endnote %}

{% note type: more %}

The `[[  ]]` syntax is a Bash [test construct][bash-test-constructs]. Also see
Bash [other comparison operators][bash-comparison-operators].

{% endnote %}

### Test a file or an empty variable (`test`)

The `test` built-in command is another way to write some conditions:

```bash
#!/bin/bash

EMPTY_VAR=
FULL_VAR="full"
FILE="/path/to/some/file"

if test -z "$EMPTY_VAR"; then
  echo "variable is empty"
fi

if test -n "$FULL_VAR"; then
  echo "variable is not empty"
fi

if test -f "$FILE"; then
  echo "file exists"
else
  echo "file does not exist"
fi
```

{% note type: more %}

See Bash [file test operators][bash-file-test-operators] and [other comparison
operators][bash-comparison-operators].

{% endnote %}

### Repeat something (`for`)

```bash
for item in one two three; do
  echo "$item"
done
```

The above code would print:

```
one
two
three
```

{% note type: more %}

Bash also has `while` and `until`. See [loops & branches][bash-loops].

{% endnote %}

### Reuse a piece of code (functions)

Isolate a piece of code in a function. Inside it, `$1`, `$2` and so on are the
**function's** arguments, not the script's:

```bash
#!/bin/bash

print_hello() {
  echo "Hello $1"
}

print_hello World
```

This script would print `Hello World`.

### Keep a variable inside a function (`local`)

Normal Bash variables have no scope: one set anywhere is visible in the whole
file and in every function. Use the `local` keyword to limit one to the function
it is declared in:

```bash
#!/bin/bash

print_hello() {
  local name="$1"
  echo "Hello $name"
}

print_hello World
echo "$name"
```

This script would print `Hello World` and an empty line, since `$name` is only
defined within the `print_hello` function.

## When it goes wrong

### Stop on the first error (`set -e`)

A script keeps going after a command fails, which is **not** what you usually
want. `set -e` aborts it instead:

```bash
#!/bin/bash
set -e
echo Hello World
cat file-that-does-not-exist
echo Done
```

```
Hello World
cat: file-that-does-not-exist: No such file or directory
```

`Done` is never printed.

### See what the script is doing (`set -x`)

`set -x` prints each command, with a leading `+`, before running it:

```bash
#!/bin/bash
set -x
echo Hello World
```

```
+ echo Hello World
Hello World
```

Combine the two with `set -ex`.

{% note type: more %}

`-e` and `-x` are POSIX options and work in `sh` and Zsh too. See Bash [option
flags][bash-option-flags] for the rest.

{% endnote %}

## References

- [Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Advanced Bash Scripting Guide](https://www.tldp.org/LDP/abs/html/)
  - [Test Constructs][bash-test-constructs]
  - [File Test Operators][bash-file-test-operators]
  - [Other Comparison Operators][bash-comparison-operators]
  - [Loops & Branches][bash-loops]
  - [Local Variables][bash-locals]
  - [Special Shell Variables][bash-special-vars]
  - [Starting Off With a Sha-Bang][bash-shebang]
- [Shell Script][shell-script]

[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[bash-comparison-operators]: https://www.tldp.org/LDP/abs/html/comparison-ops.html
[bash-file-test-operators]: https://www.tldp.org/LDP/abs/html/fto.html
[bash-locals]: https://www.tldp.org/LDP/abs/html/localvar.html
[bash-loops]: https://www.tldp.org/LDP/abs/html/loops.html
[bash-option-flags]: https://www.tldp.org/LDP/abs/html/options.html#OPTIONSREF
[bash-shebang]: https://tldp.org/LDP/abs/html/sha-bang.html
[bash-special-vars]: https://tldp.org/LDP/abs/html/refcards.html#AEN22402
[bash-test-constructs]: https://www.tldp.org/LDP/abs/html/testconstructs.html
[node]: https://nodejs.org
[php]: http://php.net
[python]: https://www.python.org
[ruby]: https://www.ruby-lang.org
[sh]: https://en.wikipedia.org/wiki/Bourne_shell
[shell-script]: https://en.wikipedia.org/wiki/Shell_script
[zsh]: https://en.wikipedia.org/wiki/Z_shell
