---
title: Unix Permissions
excerpt_separator: <!-- more -->
---

This exercise shows how Unix permissions control who can read, write and
execute files. You will do it on the SSH exercise server, where the other users
are real people: your classmates.

You will change permissions with the `chmod` command, either in its symbolic
mode (e.g. `u+w`) or in its octal mode (e.g. `664`). See [the `chmod`
command][unix-basics-chmod] in Unix Basics for how both modes work.

<!-- more -->

## :exclamation: Setup

{% callout type: exercise %}

Connect to the SSH exercise server with your username, as you did in [Hello
SSH][hello-ssh].

{% endcallout %}

Create a directory for this exercise in your home directory, and go into it:

```bash
$> mkdir ~/permissions
$> cd ~/permissions
```

{% note type: warning %}

Do everything in this directory, and never change the permissions of your home
directory itself: you could lock yourself out of it.

{% endnote %}

Most steps ask you to **predict** what will happen before you run a command.
Make your prediction, run the command, then check it. A wrong prediction is the
most useful outcome: it shows you exactly what you had not understood yet.

## :exclamation: Read and write your own file

Start with the most basic permissions, reading and writing, on a file of your
own.

### :exclamation: A new file

Create a file and look at its permissions:

```bash
$> echo "Hello" > notes.txt
$> ls -l notes.txt
```

Look at the resulting line. What do the permissions mean? Who owns the file, and
what can the owner, the group and others do with it?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```bash
$> ls -l notes.txt
-rw-rw-r-- 1 jde jde 6 Oct  8 14:02 notes.txt
```

You own the file (`jde`), and so does your group, also named `jde`, which only
you belong to. The owner and the group can read and write (`rw-`), and others
can only read (`r--`).

{% endsolution %}

### :exclamation: Take away your own write permission

Find and execute the appropriate `chmod` command to remove the write permission
of the owner (you) from `notes.txt`.

{% solution %}

```bash
$> chmod u-w notes.txt
```

{% endsolution %}

Then try to add a line to the file:

```bash
$> echo "World" >> notes.txt
```

Will it work? You are still the owner of the file, after all.

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
-bash: notes.txt: Permission denied
```

The permissions of a file apply to its owner too. You can still read it, since
you only removed the write permission:

```bash
$> cat notes.txt
Hello
```

{% endsolution %}

### :exclamation: Take away your own read permission

Find and execute the appropriate `chmod` command to remove the read permission
of the owner from `notes.txt` as well.

{% solution %}

```bash
$> chmod u-r notes.txt
```

{% endsolution %}

Look at the permissions, then try to read the file:

```bash
$> ls -l notes.txt
$> cat notes.txt
```

The group `jde` can still read and write the file, and you are in that group.
Can you read it?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
----rw-r-- 1 jde jde 6 Oct  8 14:02 notes.txt
cat: notes.txt: Permission denied
```

Unix checks **only one category** of users: the first one that applies to you.
You are the owner, so only the owner's permissions (`---`) count, and the
group's permissions are never looked at, even though you are in the group.

{% endsolution %}

### :exclamation: Set the permissions back

Give `notes.txt` its original permissions back, `rw-rw-r--`, using the `chmod`
command either in symbolic or in octal mode.

{% solution %}

```bash
$> chmod 664 notes.txt
$> chmod u=rw,g=rw,o=r notes.txt
```

`rw-` is `110` in binary, which is 6, and `r--` is `100`, which is 4.

{% endsolution %}

## :exclamation: Directories

Directories have the same three permissions as files, but they do not mean
quite the same thing. See what each of them allows on a directory.

### :exclamation: Rename a file you cannot write

Create a file that only its owner can read, and nobody can write:

```bash
$> echo "Do not touch" > locked.txt
$> chmod 400 locked.txt
$> ls -l locked.txt
-r-------- 1 jde jde 13 Oct  8 14:05 locked.txt
```

Now try to rename it:

```bash
$> mv locked.txt renamed.txt
```

Will it work?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

It works:

```bash
$> ls -l
-rw-rw-r-- 1 jde jde  6 Oct  8 14:02 notes.txt
-r-------- 1 jde jde 13 Oct  8 14:05 renamed.txt
```

Renaming a file does not change the file itself: it changes the **directory**
that lists its name. What counts is the `w` permission on the directory, and
`~/permissions` is your directory, which you can write to. Deleting a file works
the same way.

{% endsolution %}

### :exclamation: Take away the directory's write permission

Find and execute the appropriate `chmod` command to remove the write permission
of the owner from the `~/permissions` directory itself.

{% solution %}

```bash
$> chmod u-w ~/permissions
```

{% endsolution %}

Try to rename the file back, then to create a new file:

```bash
$> mv renamed.txt locked.txt
$> touch new.txt
```

Will either command work? You own both the directory and the file.

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
mv: cannot move 'renamed.txt' to 'locked.txt': Permission denied
touch: cannot touch 'new.txt': Permission denied
```

Without `w` on the directory, you can no longer add, rename or remove anything
in it, even files that you own and could write to.

{% endsolution %}

Give the directory its write permission back.

{% solution %}

```bash
$> chmod u+w ~/permissions
```

{% endsolution %}

### :exclamation: Go through a directory you cannot list

Create a directory with a file in it, then leave the directory only the `x`
permission, for its owner only:

```bash
$> mkdir closed
$> echo "You found me" > closed/secret.txt
$> chmod 100 closed
```

Try to list the directory, then to read the file inside it:

```bash
$> ls closed
$> cat closed/secret.txt
```

Which of the two commands will work?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
ls: cannot open directory 'closed': Permission denied
You found me
```

The `r` permission of a directory lets you see the names of the files in it. The
`x` permission lets you go through it to reach a file whose name you already
know. `secret.txt` is readable by you, so `cat` works.

{% endsolution %}

## :exclamation: Execute a script

Create a small shell script and run it:

```bash
$> echo 'echo "Hello from a script"' > hello.sh
$> ./hello.sh
```

Will it run?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
-bash: ./hello.sh: Permission denied
```

New files are not executable: the server gave `hello.sh` the permissions
`rw-rw-r--`, like `notes.txt`.

{% endsolution %}

Find and execute the appropriate `chmod` command to make the script executable
by its owner only, until you can run it successfully.

{% solution %}

```bash
$> chmod u+x hello.sh
$> ./hello.sh
Hello from a script
$> ls -l hello.sh
-rwxrw-r-- 1 jde jde 27 Oct  8 14:10 hello.sh
```

`rwxrw-r--` is `764`.

{% endsolution %}

## :exclamation: Where you are "other"

So far, you have only worked with your own files. Most files on this server
belong to other users, and for them, you are "other".

### :exclamation: Your classmates' home directories

Look at the permissions of the home directories on the server, your own among
them:

```bash
$> ls -l /home
```

Pick a classmate's username in the list, and try to go into their home
directory:

```bash
$> cd /home/<username>
```

Will it work?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
-bash: cd: /home/bob: Permission denied
```

Every home directory is `drwxr-x---` (`750`), owned by its user and by that
user's own group. You are neither that user nor in their group, so you are
"other", and others have no permissions at all.

{% endsolution %}

### :exclamation: Who can read the passwords?

Look at the permissions of the two files that hold the accounts of the server:

```bash
$> ls -l /etc/passwd /etc/shadow
-rw-r--r-- 1 root root   3466 Sep 23 17:15 /etc/passwd
-rw-r----- 1 root shadow 7610 Sep 23 17:15 /etc/shadow
```

Which of them can you read? Try to display the first lines of each:

```bash
$> head -n 3 /etc/passwd
$> head -n 3 /etc/shadow
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```bash
$> head -n 3 /etc/passwd
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin

$> head -n 3 /etc/shadow
head: cannot open '/etc/shadow' for reading: Permission denied
```

Everyone can read `/etc/passwd` (`644`), which many programs need to translate
user names into UIDs and vice versa. The password hashes are in `/etc/shadow`
instead, which only `root` can write and only the `shadow` group can read
(`640`).

{% endsolution %}

## :exclamation: Decide what others can read

{% callout type: exercise %}

Find a classmate for this part. You will each create a file, and check whether
the other can read it.

{% endcallout %}

Create a file in `/tmp`, the server's directory for temporary files, which
everyone can write to. Start its name with **your username**, since everyone
can see the names of the files in `/tmp`:

```bash
$> echo "Hi from jde" > /tmp/jde-note.txt
$> ls -l /tmp/jde-note.txt
-rw-rw-r-- 1 jde jde 12 Oct  8 14:20 /tmp/jde-note.txt
```

Ask your classmate to read your file:

```bash
$> cat /tmp/jde-note.txt
```

Will it work?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

It works: your classmate is "other" for your file, and others can read it
(`r--`).

{% endsolution %}

Find and execute the appropriate `chmod` command to remove the read permission
of others from your file.

{% solution %}

```bash
$> chmod o-r /tmp/jde-note.txt
```

{% endsolution %}

Ask your classmate to read your file again. Will it work this time?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

```
cat: /tmp/jde-note.txt: Permission denied
```

Your classmate is still "other", and others no longer have any permission on
your file (`---`).

{% endsolution %}

When you are done, delete your file:

```bash
$> rm /tmp/jde-note.txt
```

## :checkered_flag: What have I done?

You controlled who can do what with your files on a server shared by the whole
class. Your classmates were not hypothetical "other users": they were logged in
next to you, and some of your commands decided what they could see.

Along the way, you:

- Removed your own permissions on a file, and set them back.
- Renamed a file you could not write, and then could not, once its directory
  was protected.
- Read a file in a directory you could not list.
- Made a script executable.
- Found that you could not enter your classmates' home directories, or read
  the password hashes of the server.
- Shared a file with a classmate, then took it back.

Every file has an owner and a group, and three permissions, read, write and
execute, for each of three categories of users: the owner, the group and
others. Unix checks only one category, the first that applies to you. That is
why removing your own read permission locked you out of your own file, even
though your group could still read it.

Owning a file does not exempt you from its permissions, but it lets you change
them. Only the owner of a file, or `root`, can change its permissions with
`chmod`.

The permissions of a directory are about the names it holds, not about the
files themselves. `r` lets you list the names, `w` lets you add, rename and
remove them, and `x` lets you go through the directory to a file whose name you
know. That is why renaming `locked.txt` only depended on your directory, and why
a directory with `x` alone still let you read `secret.txt`.

Being "other" is the ordinary situation on a shared machine. The other users'
home directories are closed to you. When you removed the read permission of
others from your note, your classmate lost access to it without you having to
know who they were.

Later in this course, you will run applications on your own server. Deciding
which user an application runs as, and what that user may read and write, is
how you limit the damage when something goes wrong.

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: `Permission denied` when I go back into a directory

You probably removed the `x` permission of a directory you own. Give it back,
for example from your home directory:

```bash
$> cd ~
$> chmod u+x ~/permissions/closed
```

### :boom: I cannot create or rename anything in `~/permissions`

You probably removed the `w` permission of the directory and did not give it
back:

```bash
$> chmod u+w ~/permissions
```

[hello-ssh]: {% link chapters/104-hello-ssh/exercise.md %}
[unix-basics-chmod]: {% link chapters/402-unix-basics/subject.md %}#the-chmod-command
