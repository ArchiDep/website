---
title: Command Line
---

Learn what a command line interface is and learn the basics of navigating and
manipulating your filesystem in a Unix shell.

## Back to the command line

[Command line interfaces][cli] are still in wide use today.

### What is a Command Line Interface (CLI)?

A CLI is a tool that allows you to use your computer by **writing** what you
want to do (i.e. **commands**), instead of clicking on things.

It's been installed on computers for a long time, but it has evolved ["a
little"][building-the-future-of-the-command-line] since then. It usually looks
something like this:

![CLI](images/cli.jpg)

### Why use it?

A CLI is not very user-friendly or visually appealing but it has several advantages:

- It requires very **few resources** (e.g. memory),
  which is convenient where resources are scarce
  (e.g. embedded systems, web servers).
- It can be easily **automated** through scripting.
- Is is ultimately **more powerful and efficient** than any GUI for many computing tasks.

For these reasons, a lot of tools, **especially development tools**,
don't have any GUI and are only usable through a CLI.
Or they have a limited GUI that does not have as many options as the CLI.

**Thus, using a CLI is a requirement for any developer today.**

### Open a CLI

**CLIs are available on every operating system.**

{% cols %}

On **Unix-like** systems _(like macOS or Linux)_, it's an application called the **Terminal**.

You can use it right away, as it's the _de-facto_ standard.

<!-- col -->

On **Windows**, the default CLI is called **cmd** (or **Invite de commandes** in
French) However, it does not use the same syntax as Unix-like CLIs _(plus, it's
bad)_.

You also have [PowerShell][powershell] which is
better, but is not a Unix-like CLI either.

**You'll need to install an alternative.**

{% endcols %}

{% note type: more %}

Software terminals are an emulation of old physical terminals like [TTYs][tty]
or the [VT100][vt100]. You will still find references to the term "TTY" in the
documentation of some modern command line tools.

{% endnote %}

### Install WSL (Windows users only)

You're going to install the [**Windows Subsystem for Linux (WSL)**][wsl], a tool
that allows you to run a Linux environment on your Windows machine, without
using a virtual machine or setting up a dual boot.

![WSL](images/wsl-ubuntu.jpg)

Follow [the installation instructions for the WSL][wsl-install]. The default
Linux distribution installed will be Ubuntu, which is perfect for the purposes
of this course.

It will ask you for a **username** and a **password**. We suggest you use the
same username as for the rest of the course, and that you use the same password
as your Windows user account's.

## How to use the CLI

When you open the CLI you will find a blank screen that looks like this:

```bash
$>
```

These symbols represent **the prompt** and are used to indicate that you have
the lead. **The computer is waiting for you to type something** for it to
execute.

{% note %}

The prompt is not always `$>`.

For example, on earlier macOS versions, it used to be `bash3.2$`, indicating the
name of the shell ([Bash][bash]) and its version.

On more recent macOS versions using [the Z shell (Zsh)][zsh], the prompt might
indicate your computer's name, your username and the current directory, e.g.
`MyComputer:~ root#`.

<div class="grid grid-cols-2 gap-4">
  <div><img src='images/bash-prompt.png' class="w-full !my-0" /></div>
  <div><img src='images/zsh-prompt.png' class="w-full !my-0" /></div>
</div>

{% endnote %}

**For consistency, we will always use `$>` to represent the prompt.**

### Work in progress...

{% cols %}

When the computer is working, the prompt disappear and you no longer have
control.

![Sleep](images/sleep.png)

<!-- col -->

When the computer is done working, it will indicate that you are back in control
by showing the prompt again.

![Sleep done](images/sleep-done.png)

{% endcols %}

{% note %}

The `sleep` command tells the computer to do nothing for the specified number
of seconds.

{% endnote %}

### Writing commands

A command is a **word** that you have to type in the CLI that will **tell the computer what to do**.

The syntax for using commands looks like this:

```bash
$> name arg1 arg2 arg3 ...
```

Note the use of **spaces** to separate the differents **arguments** of a command.

- `name` represents the **command** you want to execute.
- `arg1 arg2 arg3 ...` represent the **arguments of the command**, each of them **separated by a space**.

### Options vs. values

There are two types of arguments to use with a command (if needed):

**Options** usually specify **how** the command will behave.
By convention, they are preceded by `-` or `--`:

```bash
$> ls -a -l
```

We use the `ls` command to **l**i**s**t the content of the current directory.
The options tell `ls` **how** it should do so:

- `-a` tells it to print **a**ll elements (including hidden ones).
- `-l` tells it to print elements in a **l**ist format, rather than on one line.

**Values** not preceded by anything usually specify **what** will be used by the
command:

```bash
$> cd /Users/Batman
```

Here, we use the `cd` command to move to another directory (or **c**hange
**d**irectory).

And the argument `/Users/Batman` tells the command **what** directory we want to
move to.

#### Options with values

**Values** can also be linked to an option:

```bash
$> tar -c -v -f compressed.tar.gz file-to-compress
```

The [`tar` (**t**ape **ar**chive)][tar] command bundles and compresses files. In
this example, it takes **three options**:

- `-c` tells it to **c**ompress (instead of uncompressing).
- `-v` tells it to be **v**erbose (print more information to the CLI).
- `-f` tells it where to store the compressed **f**ile; this is followed
  **immediately** by `compressed.tar.gz` which is the **value** of that option.

It then takes **one value**:

- `file-to-compress` is the file (or directory) to compress

There are two values in this example: one linked to the `-f` option, and one
used by the overall command.

### Naming things when using CLI

You should avoid the following characters in directories and file names you want to manipulate with the CLI:

- **spaces** _(they're used to separate arguments in command)_.
- **accents** (e.g. `é`, `à`, `ç`, etc).

They can cause **errors** in some scripts or tools, and will inevitably complicate using the CLI.
If you have a `Why So Serious` directory, this **WILL NOT work**:

```bash
$> ls Why So Serious
```

This command will be interpreted as a call to the `ls` command with **three arguments**: `Why`, `So` and `Serious`.

You **can** use arguments containing spaces, but you have to **escape** them first, either with **quotation marks** or **backslashes**:

{% cols %}

```bash
$> ls "Why So Serious"
```

<!-- col -->

```bash
$> ls Why\ So\ Serious
```

{% endcols %}

### Auto-completion

It's not fun to type directory names, especially when they have spaces you must escape in them,
so the CLI has **auto-completion**. Type the first few characters of the file or directory you
need, then hit the `Tab` key:

<div class="flex flex-col sm:flex-row items-center gap-4">
  <div class="grow">
    <img src='images/auto-complete.png' class="w-full !m-0" />
  </div>
  <kbd class="kbd shrink-0 hidden sm:inline-flex animate-pulse">- Tab -></kbd>
  <kbd class="kbd shrink-0 sm:hidden animate-pulse">v Tab v</kbd>
  <div class="grow">
    <img src='images/auto-complete-tab.png' class="w-full !m-0" />
  </div>
</div>

If there are multiple files or directories that begin with the **same characters**,
pressing `Tab` will not display anything.
You need hit `Tab` **a second time** to display the list of available choices:

![Multiple Files Autocompletion](images/auto-complete-multiple.png)

You can type just enough characters so that the CLI can determine which one you want (in this case `c` or `w`),
then hit `Tab` again to get the full path.

### Getting help

You can get help on most advanced commands by executing them with the `--help` option.
As the option's name implies, it's designed to **give you some help** on how to use the command:

![Tar Command Help](images/tar-help.png)

Some commands don't have the `--help` option, but there are alternative sources
of information depending on what operating system you're on:

- On Linux or macOS, use `man ls` to display the **manual** for the `ls` command.
- On Windows, use `help cd` to display help for the `cd` command;
  you can also type `help` to list available commands (only system commands).
- If you have [Node.js and npm][node] installed, there is also [tldr
  pages][tldr-pages]: a cross-platform tool that provides simplified and
  community-driven manual pages.

#### Interactive help pages

Some help pages or commands will take over the screen to display their content, hiding the prompt and previous interactions.

Usually, it means that there is content that takes more than one screen to be shown.
You can "scroll" up and down line-by-line using the arrow keys or the `Enter` key.

To quit these interactive documentations, use the `q` (**q**uit) key.

![Interactive Help](images/interactive-help.png)

#### Unix Command Syntax

When reading a command's manual or documentation,
you may find some strange syntax that make little sense to you, like:

```bash
cd [-L|[-P [-e]] [-@]] [dir]
ls [-ABCFGHLOPRSTUW@abcdefghiklmnopqrstuwx1] [file ...]
```

Here are some explanations:

- `[]`: Whatever's inside is **optional** (ex: `[-e]`).
- `|`: You have to **choose between** options (ex: `-L|-P`).
- `...`: Whatever's before can be **repeated** (ex: `[file ...]`).

Depending on the documentation, you will also see symbols like this:

- `<value>`
- `--option=VALUE`

**DON'T WRITE `<value>` or `VALUE`**.
Replace it by an appropriate value for that option or argument.

## Using the filesystem

### The `pwd` command

When you open a CLI, it places you in your **home directory**. From there you
can navigate your filesystem to go to other directories _(more on that later)_.

But first, you might want to check **where** you currently are.
Use the `pwd` command:

```bash
$> pwd
/Users/Batman
```

{% note %}

`pwd` means "**p**rint **w**orking **d**irectory": it gives you the absolute
path to the directory you're currently in.

{% endnote %}

### The `ls` command

Now that you know where you are, you might want to know **what your current directory is containing**.

Use the `ls` command:

```bash
$> ls
(lots and lots of files)
```

{% note %}

`ls` means "**l**i**s**t": it lists the contents of a directory.

{% endnote %}

By default, `ls` doesn't list **hidden elements**.
By convention in Unix-like systems, files that start with `.` (a dot) are hidden.

If you want it to do that, you need to pass the `-a` (**a**ll) option:

```bash
$> ls -a
(lots and lots of files, including the hidden ones)
```

### The `cd` command

It's time to go out a little and move to another directory.

Suppose you have a `Documents` directory in your home directory, that contains
another directory `TopSecret` where you want to go. Use the `cd` (**c**hange
**d**irectory) command, passing it as argument **the path to the directory** you
want to go to:

```bash
$> pwd
/Users/Batman

$> cd Documents/TopSecret

$> pwd
/Users/Batman/Documents/TopSecret
```

This is a **relative path**: it is relative to the current working directory.

#### Absolute paths

You can also go to a specific directory anywhere on your filesystem like this:

```bash
$> cd /Users/Batman/Documents

$> pwd
/Users/Batman/Documents
```

This is an **absolute path** because it starts with a `/` character. It starts
at the root of your filesystem so it does not matter where you are now.

{% note type: tip %}

You also have **auto-completion** with the `cd` command. Hit the `Tab` key after
entering some letters.

{% endnote %}

#### The `.` path

The `.` path represents the current directory. The following commands are
strictly equivalent:

{% cols %}

```bash
$> cd Documents/TopSecret
```

<!-- col -->

```bash
$> cd ./Documents/TopSecret
```

{% endcols %}

You can also _not go anywhere_:

{% highlight bash mark_lines="4" %}
$> pwd
/Users/Batman

$> cd .

$> pwd
/Users/Batman
{% endhighlight %}

Or compress the current directory:

```bash
tar -c -v -f /somewhere/compressed.tar.gz .
```

This does not seem very useful now, but it will be in further tutorials.

#### The `..` path

To go up into the parent directory, use the `..` path (**don't forget the space between `cd` and `..`**):

{% highlight bash mark_lines="4" %}
$> pwd
/Users/Batman/Documents

$> cd ..

$> pwd
/Users/Batman
{% endhighlight %}

You can also drag and drop a directory from your Explorer or your Finder to the CLI to see its absolute path automaticaly written:

```bash
$> cd
(Drag and drop a directory from your Explorer/Finder, and...)
$> cd /Users/Batman/Pictures/
```

At any time and from anywhere, you can return to your **home directory** with
the `cd` command, without any argument or with a `~` (tilde):

{% cols %}

```bash
$> cd
$> pwd
/Users/Batman
```

<!-- col -->

```bash
$> cd ~
$> pwd
/Users/Batman
```

{% endcols %}

{% note type: tip %}

To type the `~` character, use this combination:

- `AltGr-^` on **Windows**
- `Alt-N` on **Mac**

{% endnote %}

#### Path reference

| Path        | Where                                                                                                             |
| :---------- | :---------------------------------------------------------------------------------------------------------------- |
| `.`         | The current directory.                                                                                            |
| `..`        | The parent directory.                                                                                             |
| `foo/bar`   | The file/directory `bar` inside the directory `foo` in the current directory. This is a **relative path**.        |
| `./foo/bar` | _Same as the above_                                                                                               |
| `/foo/bar`  | The file/directory `bar` inside the directory `foo` at the root of your filesystem. This is an **absolute path**. |
| `~`         | Your home directory. This is an **absolute path**.                                                                |
| `~/foo/bar` | The file/directory `bar` inside the directory `foo` in your home directory. This is an **absolute path**.         |

#### Your projects directory

Throughout this course, you will often see the following command (_or something resembling it_):

```bash
$> cd /path/to/projects
```

This means that you use **the path to the directory in which you store your projects**.
For example, on John Doe's macOS system, it could be `/Users/jdoe/Projects`.

{% note type: warning %}

Do not actually write `/path/to/projects`. It will obviously fail, unless you
happen to have a `path` directory that contains a `to` directory that contains a
`projects` directory...

{% endnote %}

{% callout %}

**Windows users:** if your username contains **spaces** or **accents**, you
should **NOT** store your projects under your home directory. You should find a
path elsewhere on your filesystem. This will save you **a lot of needless pain
and suffering**.

{% endcallout %}

### The `mkdir` command

You can create directories with the CLI.

Use the `mkdir` (**m**a**k**e **dir**ectory) command to create a new directory in the current directory:

```bash
$> mkdir BatmobileSchematics
$> ls
BatmobileSchematics
```

You can also create a directory elsewhere:

```bash
$> mkdir ~/Documents/TopSecret/BatmobileSchematics
```

This will only work if all directories down to `TopSecret` already exist. To
automatically create all intermediate directories, add the `-p` (**p**arents)
option:

```bash
$> mkdir -p ~/Documents/TopSecret/BatmobileSchematics
```

### The `touch` command

The `touch` command updates the last modification date of a file.
It also has the useful property of creating the file if it doesn't exist.

Hence, it's a **quick way to create an empty file** in the CLI:

```bash
$> touch foo.txt

$> ls
foo.txt
```

### The `echo` command

The `echo` command simply **echo**es its arguments back to you:

```bash
$> echo Hello World
Hello World
```

This seems useless, but can be quite powerful when combined with Unix features like [redirection][redirection].
For example, you can **redirect the output to a file**.

The `>` operator means _"**write** the output of the previous command into a file"_.
This allows you to quickly create a simple text file:

```bash
$> echo foo > bar.txt

$> ls
bar.txt
```

If the file already exists, it is overwritten.
You can also use the `>>` operator, which means _"**append** the output of the previous command to the end of a file"_:

```bash
$> echo bar >> bar.txt
```

### The `cat` command

The `cat` command can display one file or con**cat**enate multiple files in the CLI.
For example, this displays the contents of the previous example's file:

```bash
$> cat bar.txt
foo
bar
```

This creates a new `hello.txt` file and displays the result of concatenating the two files:

```bash
$> echo World > hello.txt

$> cat bar.txt hello.txt
foo
bar
World
```

### Stopping running commands

Sometimes a command will take too long to execute.

As an example, run this command which will wait one hour before exiting:

```bash
$> sleep 3600
```

As you can see, the command keeps executing and you **no longer have a prompt**.
Anything you type is ignored, as it is no longer interpreted by the shell,
but by the `sleep` command instead (which doesn't do anything with it).

By convention in Unix shells, you can always terminate a running command by
typing `Ctrl-C` (press the **C** key while holding the **C**on**tr**o**l** key).

{% note type: warning %}

Note that `Ctrl-C` **forces termination** of a running command. It might not
have finished what it was doing.

{% endnote %}

### Windows users

This is how you reference or use your **drives** (`C:`, `D:`, etc) in the
Windows Subsystem for Linux (WSL):

```bash
$> cd /mnt/c/foo/bar
$> cd /mnt/d/foo
```

{% note %}

If you are using Git Bash, it's `/c` instead of `/mnt/c`.

{% endnote %}

**Copy/Paste**

Since `Ctrl-C` is used to stop the current process, it **can't** be used as a
shortcut to copy things from the CLI. Instead, the **W**indows **S**ubsystem for
**L**inux (WSL) has two custom shortcuts:

- `Shift-Ctrl-C` to **copy** things from the CLI
- `Shift-Ctrl-P` to **paste** things to the CLI

## Vim

[**Vim**][vim] is an infamous CLI editor originally developed in 1976 (WHAT?!)
for the Unix operating system.

{% note %}

The name comes from "**vi** i**m**proved", because Vim is an improved clone of
an earlier editor: [vi][vi] (from **vi**sual).

{% endnote %}

### WHY?!

Why would you need to learn it?

Sometimes it's just the **only editor you have** (e.g. on a server).
Also **some developer tools might open Vim** for user input.

If this happens (_and it will_), there's **one** imperative rule to follow:

**DO NOT PANIC!**

Open a file by running the `vim` command with the path to the file you want to
create/edit:

```bash
vim test.txt
```

### How Vim works

Vim can be unsettling at first, until you know how it works.

**Let go of your fear. And your mouse**, it's mostly useless in Vim.
You control Vim by **typing**.

The first thing to understand whith Vim is that it has _3 modes_:

- **Normal** mode (the one you're in when Vim starts).
- **Command** mode (the one to use to save and/or quit).
- **Insert** mode (the one to use to insert text).

To go into each mode use this keys:

| From           | Type  | To go to |
| :------------- | :---- | :------- |
| Normal         | `:`   | Command  |
| Normal         | `i`   | Insert   |
| Command/Insert | `Esc` | Normal   |

### Normal mode

The **Normal** mode of Vim is the one you're in when it starts.
In this mode, you can move the cursor around with the arrow keys.

You can also use some commands to interact with the text:

| Command | Effect                                                          |
| :------ | :-------------------------------------------------------------- |
| `x`     | Delete the character under the cursor                           |
| `dw`    | Delete a word, with the cursor standing before the first letter |
| `dd`    | Delete the complete line the cursor is on                       |
| `u`     | Undo the last command                                           |
| `:`     | Enter **Command** mode (to save and/or quit)                    |
| `i`     | Enter **Insert** mode (to type text)                            |

{% note type: tip %}

At anytime, you can hit the `Esc` key to go back to the **Normal** mode.

{% endnote %}

### Command mode

The **Command** mode, which you can only access from the **Normal** mode,
is the one you'll mostly use to save and/or quit.

To enter the **Command** mode, hit the `:` key.
From there, you can use some commands:

| Command     | Effect                                                                |
| :---------- | :-------------------------------------------------------------------- |
| `q`         | **Q**uit Vim (will fail if you have unsaved modifications)            |
| `w`         | **W**rite (save) the file and all its modifications                   |
| `q!`        | Force (**!**) Vim to **q**uit (any unsaved modification will be lost) |
| `wq` or `x` | **W**rite and **q**uit, i.e. save the file then quit Vim.             |

<!-- TODO: add link http://www.openvim.com/ -->

## Nano

<div class="flex justify-center">
  <img src='images/nano.jpg' class="!m-0" />
</div>

> Nano: a simpler CLI editor to keep your sanity.

### An alternative to Vim

If Vim is a bit too much for you, [nano][nano] is another CLI editor that is
much simpler to use and is also usually installed on most Unix-like systems (and
in Git Bash).

You can open a file with nano in much the same way as Vim, using the `nano`
command instead:

```bash
$> nano test.txt
```

### Editing files with nano

Editing files is much more straightforward and intuitive with nano. Once the
file is open, you can simply type your text and move around with arrow keys:

![Nano](images/nano.png)

{% note type: tip %}

Nano also helpfully prints its main keyboard shortcuts at the bottom of the
window. The most important one is `^X` for Exit. In keyboard shortcut parlance,
the `^` symbol always represents the control key.

{% endnote %}

So, **to exit from nano, type `Ctrl-X`**.

#### Saving files

When you exit nano with `Ctrl-X`, it will ask you whether you want to save your
changes:

![Nano Save](images/nano-save.png)

Press the `y` key to save or the `n` key to discard your changes.

#### Confirming the filename

When saving changes, nano will always ask you to **confirm the filename** where
the changes should be saved:

![Nano Filename](images/nano-filename.png)

As you can see, it tells you the name of the file you opened. Now you can:

- Simply press `Enter` to save the file.
- Or, change the name to save your changes to another file (and keep the
  unmodified original).

### Setting nano as the default editor

Editing the shell configuration will depend on your shell: for Zsh (the default
terminal shell on macOS) or Bash shell (the default in Git Bash and most Linux
systems), you have to set the `$EDITOR` environment variable. You can do that by
adding the following line to your **`~/.zshrc` or `~/.bash_profile` file**
depending on which shell you are using:

```
export EDITOR=nano
```

Remember that you must **relaunch your terminal** for this change to take
effect.

If you are unsure of what shell you are using, type in the following
command. The output will display the name of your current shell.

```bash
$> echo $0
bash
```

{% note type: tip %}

Now that you know how to use nano, you can edit your Bash profile file with the
following command: `nano ~/.bash_profile`.

{% endnote %}

{% note %}

On Ubuntu, you can list available editors and choose the default one with the
following command:

```bash
$> sudo update-alternatives --config editor
```

{% endnote %}

## The `PATH` variable

When you type a command in the CLI, it will try to see **if it knows this
command** by looking in some directories to see if there is an **executable file
that matches the command name**.

```bash
$> rubbish
bash: rubbish: command not found
```

This means that the CLI failed to find the executable named `rubbish` in any of
the directories where it looked.

The list of the directories (and their paths) in which the CLI searches is
stored in the `PATH` environment variable, each of them being separated with a
`:`.

You can print the content of your `PATH` variable to see this list:

```bash
$> echo $PATH
/usr/local/bin:/bin:/usr/bin:/custom/dir
```

### Understanding the `PATH`

Assuming your `PATH` looks like this:

```bash
$> echo $PATH
/usr/local/bin:/bin:/usr/bin:/custom/dir
```

What happens when you run the following command?

```bash
$> ls -a -l
```

1. The shell will look in the `/usr/local/bin` directory. _There is no
   executable named `ls` there, moving on..._
2. The shell will look in the `/bin` directory. **There is an executable named
   `ls` there!** Execute it with arguments `-a` and `-l`.
3. We're done here. No need to look at the rest of the `PATH`. If there happens
   to be an `ls` executable in the `/custom/dir` directory, it will **not be
   used**.

### Finding commands

You can check where a command is with the `which` command:

```bash
$> which ls
/bin/ls
```

If there are multiple versions of a command in your `PATH`, you can add the `-a`
option to list them **a**ll:

```bash
$> which -a git
/opt/homebrew/bin/git
/usr/bin/git
```

{% note %}

Remember, the shell will use the first one it finds, so in this example it
would use `/opt/homebrew/bin/git` if you type `git`, completely ignoring
`/usr/bin/git`.

{% endnote %}

### Using non-system commands

Many development tools you install come with executables that you can run from the CLI (e.g. Git, Node.js, MongoDB).

Some of these tools will install their executable in a **standard directory** like `/usr/local/bin`, which is already in your `PATH`.
Once you've installed them, you can simply run their new commands.
Git and Node.js, for example, do this.

However, sometimes you're downloading only an executable and saving it in a directory somewhere that is **not in the `PATH`**.

#### Custom command example

Run the following commands to download a simple Hello World shell script and make it into an executable:

```bash
$> mkdir -p ~/hello-program/bin
$> curl -o ~/hello-program/bin/hello https://gist.githubusercontent.com/AlphaHydrae/8e09bf8790cbd6e3c7d9974988da3c28/raw/74372a1be35e973897c0a1fc946f3d18012a860c/hello.sh
$> chmod 755 ~/hello-program/bin/hello
```

{% note %}

The `curl` command is used to download the script file, and the `chmod` command
to make that file executable.

{% endnote %}

You should now be able to find it in the `~/hello-program/bin` directory:

```bash
$> ls ~/hello-program/bin
hello
```

It's now installed, we can find it using the CLI, but it still cannot be run. Why?

```bash
$> hello
command not found: hello
```

#### Executing a command in a directory that's not in the `PATH`

You can run a command from anywhere by writing **the absolute path to the executable**:

```bash
$> ~/hello-program/bin/hello
Hello World
```

You can also **manually go to the directory** containing the executable and **run the command there**:

```bash
$> cd ~/hello-program/bin
$> ./hello
Hello World
```

{% note type: tip %}

When the first word on the CLI starts with `/`, `~/`, `./` or `../`, the shell
interprets it as a file path. Instead of looking for a command in the `PATH`,
it simply executes that file.

{% endnote %}

But, ideally, you want to be able to **just type `hello`**, and have the script be executed.
For this, you need to **add the directory containing the executable** to your `PATH` variable.

### Updating the `PATH` variable

To add a new path in your `PATH` variable, you have to edit a special file, used
by your CLI interpreter (shell). This file depends upon the shell you are using:

| CLI                        | File to edit      |
| :------------------------- | :---------------- |
| Git Bash                   | `~/.bash_profile` |
| Terminal / [Zsh][zsh-site] | `~/.zshrc`        |

Open the adequate file (`.bash_profile` for this example) from the CLI with
`nano` or your favorite editor if it can display hidden files:

```bash
$> nano ~/.bash_profile
```

Add this line at the bottom of your file (use `i` to enter **insert** mode if
using Vim):

```vim
export PATH="$HOME/hello-program/bin:$PATH"
```

If you're in Vim, press `Esc` when you're done typing, then `:wq` and `Enter` to
save and quit. If you're in nano, press `Ctrl-X`, then answer `Yes` and confirm
the filename.

#### Does it work?

{% note type: warning %}

Remember to **close and re-open your CLI** to have the shell reload its
configuration file.

{% endnote %}

{% cols %}

<!-- col order-1 md:order-none flex items-end -->

You should now be able to run the Hello World shell script as a command simply
by typing `hello`:

<!-- col order-3 md:order-none flex items-end -->

You don't even have to be in the correct directory:

<!-- col order-2 md:order-none -->

```bash
$> hello
Hello World
```

<!-- col order-4 md:order-none -->

```bash
$> cd
$> pwd
/Users/jdoe
$> hello
Hello World
```

{% endcols %}

And your CLI knows where it is:

```bash
$> which hello
/Users/jdoe/hello-program/bin/hello
```

It knows this because the directory containing the script is now in your PATH:

```bash
$> echo $PATH
/Users/jdoe/hello-program/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin
```

#### What have I done?

You have **added a directory to the `PATH`**:

```vim
export PATH="~/hello-program/bin:$PATH"
```

This line says:

- Modify the `PATH` variable.
- In it, put the new directory `~/hello-program/bin` and the previous value of the `PATH`, separated by `:`.

The next time you run a command, your shell will **first look** in this directory for executables, then in the **rest of the `PATH`**.

**Common mistakes**

- What you must put in the `PATH` is **NOT** the path to the executable,
  but the path to the **directory containing the executable**.
- You must re-open your CLI for the change to take effect:
  the shell configuration file (e.g. `~/.bash_profile`) is only applied when the shell starts.

## Unleash your terminal

<img class='w100' src='images/unleash-your-terminal.png' />

### Oh My Zsh

Command-line shells have been worked on for a very long time. Modern shells
such as the [Z shell (Zsh)][zsh] have a whole community that created many
plugins to simplify your daily command-line work.

On macOS or Linux, you may want to install [Oh My Zsh][oh-my-zsh] to fully
unleash the power of your Terminal. It has [plugins][oh-my-zsh-plugins] to
integrate with Homebrew, Git, various programming languages like Ruby, PHP, Go,
and much more.

On Windows, you may want to [install the Windows Subsystem for Linux][wsl] so
you can install a Linux distribution like Ubuntu. You can then [install Zsh and
Oh My Zsh as well][oh-my-zsh-windows].

### Other tools for the command line lover

- [`bat`](https://github.com/sharkdp/bat): a `cat` clone with wings
- [`tldr`](https://github.com/tldr-pages/tldr): better `man` pages
- [`fzf`](https://junegunn.github.io/fzf/) to quickly find files
- [`ack`](https://beyondgrep.com) to search for text in files (`grep`
  alternative)
- [`rsync`](https://rsync.samba.org) for incremental file transfers (`cp` &
  `scp` alternative)

{% cols %}

A Terminal [multiplexer](https://en.wikipedia.org/wiki/Multiplexer) like:

- [tmux](https://github.com/tmux/tmux/wiki)
- [screen](https://www.gnu.org/software/screen/)
- [zellij](https://zellij.dev) 💙

<!-- col -->

![Terminal multiplexer](images/terminal-multiplexer.png)

{% endcols %}

[ace]: https://en.wikipedia.org/wiki/Automatic_Computing_Engine
[ada-lovelace]: https://en.wikipedia.org/wiki/Ada_Lovelace
[alan-turing]: https://en.wikipedia.org/wiki/Alan_Turing
[algorithm]: https://en.wikipedia.org/wiki/Algorithm
[analytical-engine]: https://en.wikipedia.org/wiki/Analytical_Engine
[artificial-intelligence]: https://en.wikipedia.org/wiki/Artificial_intelligence
[augmented-reality]: https://en.wikipedia.org/wiki/Augmented_reality
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[bernoulli-numbers]: https://en.wikipedia.org/wiki/Bernoulli_number
[brain-interface]: https://en.wikipedia.org/wiki/Brain–computer_interface
[bug]: https://en.wikipedia.org/wiki/Bug_(engineering)#History
[building-the-future-of-the-command-line]: https://github.com/readme/featured/future-of-the-command-line
[c]: https://en.wikipedia.org/wiki/C_(programming_language)
[cat]: https://en.wikipedia.org/wiki/Cat_(Unix)
[charles-babbage]: https://en.wikipedia.org/wiki/Charles_Babbage
[cli]: https://en.wikipedia.org/wiki/Command-line_interface
[computation]: https://en.wikipedia.org/wiki/Computation
[computer-science]: https://en.wikipedia.org/wiki/Computer_science
[delay-line-memory]: https://en.wikipedia.org/wiki/Delay-line_memory
[digital]: https://en.wikipedia.org/wiki/Digital_data
[electro-mechanical-computers]: https://en.wikipedia.org/wiki/Mechanical_computer#Electro-mechanical_computers
[eniac]: https://en.wikipedia.org/wiki/ENIAC
[freebsd]: https://en.wikipedia.org/wiki/FreeBSD
[general-purpose-computer]: https://en.wikipedia.org/wiki/Computer
[gitbash]: https://gitforwindows.org
[gui]: https://en.wikipedia.org/wiki/Graphical_user_interface
[keypunch]: https://en.wikipedia.org/wiki/Keypunch
[lfm]: https://en.wikipedia.org/wiki/Luigi_Federico_Menabrea
[linux]: https://en.wikipedia.org/wiki/Linux
[macos]: https://en.wikipedia.org/wiki/MacOS
[mainframe]: https://en.wikipedia.org/wiki/Mainframe_computer
[motion-sensing]: https://en.wikipedia.org/wiki/Motion_detection
[nano]: https://en.wikipedia.org/wiki/GNU_nano
[node]: https://nodejs.org
[note-g]: https://en.wikipedia.org/wiki/Note_G
[oh-my-zsh]: https://ohmyz.sh
[oh-my-zsh-plugins]: https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
[oh-my-zsh-windows]: http://kevinprogramming.com/using-zsh-in-windows-terminal/
[powershell]: https://en.wikipedia.org/wiki/PowerShell
[programmable]: https://en.wikipedia.org/wiki/Computer_program
[punched-card]: https://en.wikipedia.org/wiki/Punched_card
[redirection]: https://en.wikipedia.org/wiki/Redirection_(computing)
[slide-git]: ../git
[stored-program-computer]: https://en.wikipedia.org/wiki/Stored-program_computer
[tar]: https://en.wikipedia.org/wiki/Tar_(computing)
[the-imitation-game]: https://en.wikipedia.org/wiki/The_Imitation_Game
[tldr-pages]: https://tldr.sh
[transistor]: https://en.wikipedia.org/wiki/Transistor
[tty]: https://en.wikipedia.org/wiki/Teleprinter
[tui]: https://en.wikipedia.org/wiki/Touch_user_interface
[turing-machine]: https://en.wikipedia.org/wiki/Turing_machine
[unix]: https://en.wikipedia.org/wiki/Unix
[unix-shell]: https://en.wikipedia.org/wiki/Unix_shell
[vi]: https://en.wikipedia.org/wiki/Vi_(text_editor)
[vim]: https://en.wikipedia.org/wiki/Vim_(text_editor)
[virtual-reality]: https://en.wikipedia.org/wiki/Virtual_reality
[vt100]: https://en.wikipedia.org/wiki/VT100
[vui]: https://en.wikipedia.org/wiki/Voice_user_interface
[windows-subsystem-for-linux]: https://docs.microsoft.com/en-us/windows/wsl/about
[wsl]: https://learn.microsoft.com/en-us/windows/wsl/about
[wsl-install]: https://learn.microsoft.com/en-us/windows/wsl/install
[zsh]: https://en.wikipedia.org/wiki/Z_shell
[zsh-site]: http://zsh.sourceforge.net/
