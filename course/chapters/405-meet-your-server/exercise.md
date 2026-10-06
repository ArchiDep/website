---
title: Meet your server
cloud_server: details
excerpt_separator: <!-- more -->
---

A short exploration of the cloud server you have just set up: who you are on
it, what you are allowed to do, and what else is running there. Nothing in this
exercise changes your server.

{% callout type: exercise %}

Connect to **your new cloud server** with SSH for this exercise.

{% endcallout %}

<!-- more -->

This exercise uses what you learned about [users][unix-basics-users],
[`sudo`][unix-basics-sudo] and [permissions][unix-basics-permissions] in Unix
Basics, on a server where you are the administrator.

Most steps ask you a question before or after you run a command. Answer it,
then check your answer.

## :exclamation: Who are you?

Your server has only one user that represents a person: you. Start by asking
the server what it knows about you.

```bash
$> id
uid=1000(jde) gid=1000(jde) groups=1000(jde),4(adm),24(cdrom),27(sudo),30(dip),105(lxd)
```

Which of the groups listed is the one that makes you an administrator?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

The `sudo` group. Its members are trusted to use the `sudo` command, as defined
in the `/etc/sudoers` file. Azure added you to it, and to a few other groups,
when it created the server.

{% endsolution %}

## :exclamation: What are you allowed to do?

Being in the `sudo` group means you can run commands as `root`. See what that
looks like on your server.

### :exclamation: List the home directory of `root`

Try to list the home directory of the `root` user, first as yourself, then with
`sudo`:

```bash
$> ls -a /root
$> sudo ls -a /root
```

The first command runs as you, and is refused. The second runs as `root`, and
works, **without asking for a password**. Did you notice that you never chose a
password for your account? You only gave Azure your public SSH key.

Azure configured your server so that you can use `sudo` without a password for
convenience. If you ever administer a real production server, it is more secure
to harden this configuration by giving every account a password, and requiring
it for `sudo`.

### :exclamation: Ask `sudo` what you may do

The `-l` option asks `sudo` to **l**ist what you are allowed to do:

```bash
$> sudo -l
User jde may run the following commands on jde:
    (ALL : ALL) ALL
    (ALL) NOPASSWD: ALL
```

You may run **any command** (`ALL`), **as any user** (`(ALL)`), and the second
line adds that you can do it **without a password** (`NOPASSWD`).

Since your account has no password, `sudo` could not ask for one. In practice,
this means that **anyone who can log in as you can also become `root`**, with
nothing else to type: whoever has your private key, or a terminal you left
connected.

## :exclamation: Files only `root` can touch

Some files on your server are protected even from the users who can read most
others. Look at the permissions of two of them:

```bash
$> ls -l /etc/sudoers /swapfile
-r--r----- 1 root root        1800 Apr  8 10:00 /etc/sudoers
-rw------- 1 root root  2147483648 Oct  9 14:30 /swapfile
```

Who can read each file, and who can write to it?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

`/etc/sudoers`: `root` and the `root` group can read it, and **nobody** can
write to it, not even its owner. That is a reminder never to edit it directly:
`root` can override it, but the `visudo` command is the safe way.

`/swapfile`: only `root` can read and write it. It is the swap space you created
when you set up your server, with `chmod 600`. When memory runs out, the server
moves parts of the memory of running programs into it, which may contain
anything those programs hold, passwords included. No other user should be able
to read it.

{% endsolution %}

## :exclamation: Who else lives here?

You are the only person with an account on your server, but you are not its only
user.

### :exclamation: The accounts of the server

Display the list of the server's user accounts:

```bash
$> cat /etc/passwd
```

Each line is an account, and the last field of each line is the program it
starts when someone logs in as that user. Which accounts are people, and which
are services?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
...
syslog:x:102:102::/nonexistent:/usr/sbin/nologin
...
jde:x:1000:1000:Ubuntu:/home/jde:/bin/bash
```

Only `root` and your own account start a shell (`/bin/bash`). Most other
accounts start `/usr/sbin/nologin` or `/bin/false`, which refuse the login: they
are **system users**, used by services, so that each service can only access its
own files. The [appendix of Unix Basics][unix-basics-passwd] describes every
field of these lines.

{% endsolution %}

### :exclamation: What is running?

The `htop` command shows what is running on your server, and how much of its
processor and memory is used:

```bash
$> htop
```

Quit `htop` with `q`.

## :exclamation: Which address is yours?

You connect to your server with its IP address. Ask the server what its own
address is:

```bash
$> ip address
```

Find the lines starting with `inet`. The one under the `lo` (loopback) interface
is the local address. You should see at least one other IP address under a different
interface. Is it the address you use to connect to your server with SSH?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    inet 10.0.0.4/24 metric 100 brd 10.0.0.255 scope global eth0
```

It is not. Your server does not know the address you use to reach it, because
that address is managed by the cloud provider (Azure in this case). The address
you see is a private address, which the cloud provider uses to route your
connection to your server in their infrastructure.

{% endsolution %}

## :checkered_flag: What have I done?

You looked around the server you set up, without changing anything, and
discovered a few things about it.

You are an administrator because you are a member of the `sudo` group, which
`/etc/sudoers` trusts. On your server, that trust needs no password at all: you
never chose one. Whoever can log in as you can become `root`, and `root` can do
anything on the server. That makes your account, and your private key, worth
protecting.

Most of the accounts of a server are not people. Services run as system users
that cannot log in, each with access to its own files only. Permissions are how
the server keeps its secrets, such as its swap space or its list of
administrators, away from everyone but `root`.

Later in this course, you will run applications on this server, and you will
have to decide which user each of them runs as.

## :boom: Troubleshooting

Here's a few tips about some problems you may encounter during this exercise.

### :boom: `sudo` asks me for a password

You are probably not on your cloud server. Check where you are:

```bash
$> hostname
```

If it is `ssh.archidep.ch`, you are on the SSH exercise server, where you are
not an administrator. Disconnect with `exit`, and connect to your own server.

### :boom: `htop: command not found`

Install it with APT:

```bash
$> sudo apt update
$> sudo apt install htop
```

[unix-basics-passwd]: {% link chapters/402-unix-basics/subject.md %}#appendix-user-database-files
[unix-basics-permissions]: {% link chapters/402-unix-basics/subject.md %}#permissions
[unix-basics-sudo]: {% link chapters/402-unix-basics/subject.md %}#the-sudo-command
[unix-basics-users]: {% link chapters/402-unix-basics/subject.md %}#unix-users
