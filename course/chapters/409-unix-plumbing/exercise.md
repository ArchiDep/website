---
title: Unix plumbing
cloud_server: details
excerpt_separator: <!-- more -->
---

This exercise is about redirecting the standard streams of commands to files,
and connecting commands to each other with pipes, to analyze text on your cloud
server.

{% callout type: exercise %}

Do this exercise on your cloud server, through SSH: its first steps look at
files that only exist on a server.

{% endcallout %}

<!-- more -->

## :exclamation: Where does each line go?

Connect to your cloud server and go to your home directory, where the files of
this exercise will be created:

```bash
$> cd
```

Search the SSH configuration of your server for the word
`PasswordAuthentication`:

```bash
$> grep -r PasswordAuthentication /etc/ssh
```

Some of the lines it displays are output data, and some are error messages.
Which are which, and why are there errors?

{% solution %}

```bash
$> grep -r PasswordAuthentication /etc/ssh
grep: /etc/ssh/ssh_host_ecdsa_key: Permission denied
/etc/ssh/ssh_config:#   PasswordAuthentication yes
/etc/ssh/sshd_config:#PasswordAuthentication yes
/etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
/etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication
grep: /etc/ssh/ssh_host_rsa_key: Permission denied
grep: /etc/ssh/ssh_host_ed25519_key: Permission denied
```

The lines starting with `/etc/ssh/` are the lines `grep` found, its output data,
on its standard output stream. The lines starting with `grep:` are error
messages, on its standard error stream: the server's private SSH keys can only
be read by `root`, and you are running `grep` as yourself.

The lines on your server may differ slightly. What matters is which stream each
one is on.

{% endsolution %}

{% callout type: more, id: ssh-config-dir %}

The `/etc/ssh` directory holds the configuration of SSH on your server:

- `sshd_config` configures the SSH server, the program that accepts your
  connection when you run `ssh` from your computer.
- `ssh_config` configures the SSH client, used when you run `ssh` from this
  server to connect to another machine.
- The `ssh_host_..._key` files are the server's private keys, which prove its
  identity to the clients that connect to it: the fingerprint you checked the
  first time you connected identifies one of these keys. These files can only be
  read by `root`, and you are not `root` (unless you use `sudo`).

`PasswordAuthentication` is the setting that decides whether the SSH server
accepts passwords, or only keys like yours. A line starting with `#` is a
comment, which the server ignores: these lines document the setting and its
default value.

{% endcallout %}

Now run the same command three more times, redirecting:

- Its standard output stream to a file named `found.txt`.
- Its standard error stream to a file named `errors.txt`.
- Both output streams to a single file named `all.txt`.

Each time, what is still displayed in your terminal, and what ends up in the
file? Display the file with `cat` to see.

{% solution %}

```bash
$> grep -r PasswordAuthentication /etc/ssh > found.txt
grep: /etc/ssh/ssh_host_ecdsa_key: Permission denied
grep: /etc/ssh/ssh_host_rsa_key: Permission denied
grep: /etc/ssh/ssh_host_ed25519_key: Permission denied

$> cat found.txt
/etc/ssh/ssh_config:#   PasswordAuthentication yes
/etc/ssh/sshd_config:#PasswordAuthentication yes
/etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
/etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication
```

```bash
$> grep -r PasswordAuthentication /etc/ssh 2> errors.txt
/etc/ssh/ssh_config:#   PasswordAuthentication yes
/etc/ssh/sshd_config:#PasswordAuthentication yes
/etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
/etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication

$> cat errors.txt
grep: /etc/ssh/ssh_host_ecdsa_key: Permission denied
grep: /etc/ssh/ssh_host_rsa_key: Permission denied
grep: /etc/ssh/ssh_host_ed25519_key: Permission denied
```

```bash
$> grep -r PasswordAuthentication /etc/ssh &> all.txt

$> cat all.txt
grep: /etc/ssh/ssh_host_ecdsa_key: Permission denied
grep: /etc/ssh/ssh_host_rsa_key: Permission denied
grep: /etc/ssh/ssh_host_ed25519_key: Permission denied
/etc/ssh/ssh_config:#   PasswordAuthentication yes
/etc/ssh/sshd_config:#PasswordAuthentication yes
/etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
/etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication
```

With `&>`, nothing is displayed, and the lines are not in the same order as in
your terminal: when its standard output is a file, `grep` collects the lines it
finds and writes them in one go, while it writes each error as soon as it
happens.

{% endsolution %}

## :exclamation: Did it work?

Every command ends with an exit status, which the shell keeps in the special
variable `$?`. Display it with `echo $?` right after each of these commands:

```bash
$> grep PasswordAuthentication /etc/ssh/sshd_config
$> echo $?

$> grep unicorn /etc/ssh/sshd_config
$> echo $?

$> grep -r PasswordAuthentication /etc/ssh
$> echo $?
```

What does each exit status mean? The last command found lines: why is its exit
status not `0`?

{% solution %}

```bash
$> grep PasswordAuthentication /etc/ssh/sshd_config
...
$> echo $?
0

$> grep unicorn /etc/ssh/sshd_config
$> echo $?
1

$> grep -r PasswordAuthentication /etc/ssh
...
$> echo $?
2
```

`grep` exits with `0` when it found lines, with `1` when it found none, and with
`2` when something went wrong. The last command found lines, but it could not
read some files: the errors decide its exit status, whatever it found.

The exit status is a separate answer from the output. A command can print a lot
and still fail, or print nothing and succeed.

{% endsolution %}

## :exclamation: Download the song

In your home directory, download the song that the next pipelines work on:

```bash
$> curl -L https://tinyurl.com/archidep-otr > rainbow.txt
```

{% note type: tip %}

This command is already a redirection: `curl` prints what it downloads to its
standard output stream, and `>` sends it into the `rainbow.txt` file instead of
your terminal.

{% endnote %}

Display the file:

```bash
$> cat rainbow.txt
Somewhere over the rainbow
...
```

## :exclamation: Pipe the song

Use command pipelines to answer questions about the song. For example, how many
lines are there in the text?

```bash
$> cat rainbow.txt | wc -l
51
```

Now it's your turn:

- Count the number of words in the text

{% solution %}

```bash
$> cat rainbow.txt | wc -w
255
```

{% endsolution %}

- Print the lines of the text containing the word `rainbow`

{% solution %}

```bash
$> cat rainbow.txt | grep rainbow
Somewhere over the rainbow
Somewhere over the rainbow
Somewhere over the rainbow
The colors of the rainbow so pretty in the sky
Oh, somewhere over the rainbow
```

Note that this looks for occurrences of the word "rainbow" exactly like this, in
lowercase. If you wanted to make a case-insensitive search, you would use the
`grep` command's `-i` or `--ignore-case` option.

{% endsolution %}

- Do the same but without any duplicates

{% solution %}

```bash
$> cat rainbow.txt | grep rainbow | sort | uniq
Oh, somewhere over the rainbow
Somewhere over the rainbow
The colors of the rainbow so pretty in the sky
```

`uniq` only filters out repeated lines that are next to each other, which is why
the lines are sorted first.

{% endsolution %}

- Print the second word of each line in the text

{% solution %}

```bash
$> cat rainbow.txt | cut -d ' ' -f 2
over
up
the
in

over
fly
...
```

{% endsolution %}

- Count the number of times the letter `e` is used (case-insensitive)

{% solution %}

```bash
$> cat rainbow.txt | fold -w 1 | grep -i e | wc -l
131
```

{% endsolution %}

Here are a few commands you might find useful for these pipelines. They all read
the data from their standard input stream (or from a file you name), and print
the result on their standard output stream, so they can be piped into each
other:

| Command                             | Description                                                                                  |
| :---------------------------------- | :------------------------------------------------------------------------------------------- |
| `cut -d ' ' -f <n>`                 | Select word in column `<n>` of each line (using one space as the delimiter)                  |
| `fold -w 1`                         | Print one character by line                                                                  |
| `grep [-i] <letterOrWord>`          | Select only lines that contain a given letter or word, e.g. `grep foo` (`-i` to ignore case) |
| `head -n <n>`                       | Keep only the first `<n>` lines                                                              |
| `sort [-nr]`                        | Sort lines alphabetically (`-n` to sort numerically, `-r` to reverse the order)              |
| `tr '[:upper:]' '[:lower:]'`        | Convert all uppercase characters to lowercase                                                |
| `tr -s '[[:punct:][:space:]]' '\n'` | Split by word                                                                                |
| `uniq [-c]`                         | Filter out repeated lines (`-c` also counts them)                                            |
| `wc [-l] [-w]`                      | Count lines or words                                                                         |

{% note type: tip %}

If you want to know more about any of these commands or their options, type
`man <command>`, e.g. `man cut`.

{% endnote %}

### :space_invader: Challenge

What are the five most used words in the song (case-insensitive), and how many
times is each one used?

{% solution %}

```bash
$> cat rainbow.txt | \
     tr '[:upper:]' '[:lower:]' | \
     tr -s '[[:punct:][:space:]]' '\n' | \
     sort | \
     uniq -c | \
     sort -nr | \
     head -n 5
     18 the
     17 i
     13 and
      9 you
      8 of
```

The second `sort` uses the `-n` option to sort the counts as numbers rather than
as text, and `-r` to put the largest first.

{% endsolution %}

## :exclamation: Pipe your server's users

The file `/etc/passwd` lists the users of your server, one per line, with fields
separated by colons (`:`). The seventh and last field of each line is the user's
login shell, the program started when that user logs in.

Use a pipeline to count how many users have each login shell.

{% note type: tip %}

Remember the `cut` command you used to print the second word of each line of the
song: its `-d` option gives the character that separates the fields (the
**d**elimiter), and its `-f` option the number of the **f**ield to keep.

{% endnote %}

{% solution %}

```bash
$> cat /etc/passwd | cut -d : -f 7 | sort | uniq -c
      3 /bin/bash
      1 /bin/sync
     21 /usr/sbin/nologin
```

The numbers on your server will differ.

{% endsolution %}

Most users have `/usr/sbin/nologin` as their login shell. Why?

{% solution %}

They are the system users you met in [Meet your server]({% link
chapters/405-meet-your-server/exercise.md %}): users that run services rather
than people. `nologin` refuses to log them in, so nobody can open a shell as one
of them.

{% endsolution %}

## :question: Discard the errors

In the first step, you ran this command, which displays both the lines it finds
and error messages:

```bash
$> grep -r PasswordAuthentication /etc/ssh
```

Find out how to run it so that it displays only the lines it found, without
creating any file. The optional section of the subject on how to [discard an
output stream]({% link chapters/408-unix-processes/subject.md
%}#appendix-discard-an-output-stream) explains how.

{% solution %}

Redirect its standard error stream to the null device, `/dev/null`, which
discards everything written to it:

```bash
$> grep -r PasswordAuthentication /etc/ssh 2> /dev/null
/etc/ssh/ssh_config:#   PasswordAuthentication yes
/etc/ssh/sshd_config:#PasswordAuthentication yes
/etc/ssh/sshd_config:# PasswordAuthentication.  Depending on your PAM configuration,
/etc/ssh/sshd_config:# PAM authentication, then enable this but set PasswordAuthentication
```

{% endsolution %}

## :checkered_flag: What have I done?

You took commands that each do one small job, and decided where their input
comes from and where their output goes: into a file, or straight into another
command. None of these commands was written to work with files or
with each other: the shell connected them.

Every process has three standard streams: one input and two outputs. A program
writes its data to the standard output stream and its errors to the standard
error stream. In your terminal, both end up on the same screen, which is why
they look alike. They only show that they are separate once you send one of
them somewhere else: the data went into `found.txt`, and the errors kept
reaching you.

Redirection is done by the shell, not by the program. The shell connects the
streams before the program starts, and the program does not know: `grep` wrote
to its standard output as usual, and it ended up in a file.

The exit status is a third answer, separate from both outputs. `grep` found
lines and still reported a failure, because it also met errors. Scripts and
tools that run commands for you rely on the exit status, not on what is
printed, to decide whether a command worked.

A pipe connects the standard output stream of one process to the standard
input stream of the next. Each command in a pipeline only knows how to do one
job, and the pipeline does what none of them can do alone: count the uses of a
word, or the users of each shell. The error messages are not part of the
pipeline: they still go to your terminal, so that you see them.

This is the Unix philosophy: small programs that do one thing well, work
together, and handle text streams. It works because every program speaks the
same language, a stream of text in and a stream of text out.

Later in the course, the applications you deploy will also write to their
standard streams, and that is where you will look for their logs.

## :boom: Troubleshooting

### :boom: `Permission denied` when redirecting to a file

You are in a directory where you are not allowed to create files, such as `/etc`.
Go back to your home directory with `cd` or `cd ~` and run the command again.

### :boom: `rainbow.txt: No such file or directory`

You are not in the directory where you downloaded the file. Go back to your home
directory with `cd` or `cd ~`, or download it again as in [Download the song](#download-the-song).

### :boom: The `grep` lines on my server are not the same as the solution's

The SSH configuration of your server may differ slightly from the one used to
write the solution. What matters is which lines are output data and which are
error messages, not their exact text.
