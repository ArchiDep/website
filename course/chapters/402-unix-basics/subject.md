---
title: Unix Basics
---

Learn the basics of Unix and Unix-like operating systems like Linux, and how to
manage them from the command line.

{% note %}

In many respects, the basics of Unix are the same for the original Unix
operating system and Unix-like operating systems derived from Unix like Linux or
macOS. From here on, when we refer to "Unix", we will in fact be talking about
all Unix and Unix-like systems in general.

{% endnote %}

## File system

The **file system** controls how data is stored and retrieved. Without it,
information on a storage medium such as a hard drive would be one large body of
data, with no way to tell where one piece of information stops and the next
begins.

Various file systems exist:

| Operating system or device type | Common file systems |
| :------------------------------ | :------------------ |
| Linux                           | ext2, ext3, ext4    |
| macOS                           | HFS, APFS           |
| Windows                         | NTFS                |
| USB                             | FAT, exFAT          |

### Case-sensitivity

One of the differences between file systems is how they would treat these file
names:

- `a-file.txt`
- `A-file.txt`
- `A-fIlE.txt`
- `A-FILE.txt`

When you use macOS or Windows, your file system is probably [HFS][hfs],
[APFS][apfs] or [NTFS][ntfs]. These file systems are **case-insensitive**,
meaning that the four file names above represent the same file. You **cannot
create both `a-file.txt` and `A-FILE.txt` in the same directory**. As far as the
file system is concerned, that's the same file.

When you use Linux, your file system is probably in the [Extended File System
(ext)][ext] family. It is a **case-sensitive** file system. The four names above
represent **4 different files**.

It is important to know this difference when you are transferring files between
different file systems.

### File hierarchy

In Unix systems, the file system is said to be **rooted**, meaning that there is
**always one root**, denoted by the path `/`.

Separate volumes such as disk partitions, removable media and network shares
belong to the same file hierarchy (unlike Windows for example, where each drive
has a letter that is the root of its file system tree).

Such volumes can be **mounted** on a directory (typically under `/mnt`), causing
the volume's file system tree to appear as that directory in the larger tree.

#### Inspecting volumes

The `df` (**d**isk **f**ree) shows you all volumes and the available space on
each of them (the `-h` option displays size in a human-readable format instead
of the raw number of bytes):

```bash
$> df -h
Filesystem      Size  Used Avail Use% Mounted on
tmpfs            99M  608K   98M   1% /run
/dev/sda1       9.7G  1.4G  8.3G  15% /
tmpfs           493M     0  493M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           493M     0  493M   0% /sys/fs/cgroup
/dev/sdb1        50G   19G   28G  41% /mnt/network-drive
```

You can see that **there is only one root (`/`)**, and that all other volumes
are **mounted** somewhere in the file hierarchy.

For example, the last line represents a network drive mounted under the
`/mnt/network-drive` directory.

Mounted volumes are defined in the [`/etc/fstab` file (**f**ile **s**ystems
**tab**le)][fstab].

#### Common Unix directories

Many of these directories are common to all Unix systems.

| Directory | Description                                                |
| :-------- | :--------------------------------------------------------- |
| `/bin`    | Fundamental binaries like `ls` or `cp`                     |
| `/boot`   | Files required to successfully boot                        |
| `/dev`    | Devices, i.e. file representations of (pseudo-)peripherals |
| `/etc`    | System-wide configuration files                            |
| `/home`   | User home directories                                      |
| `/lib`    | Shared libraries needed by programs in `/bin`              |
| `/media`  | Default mount point for removable devices (USB, etc)       |
| `/opt`    | Locally installed software                                 |
| `/root`   | Home directory of the `root` superuser                     |
| `/sbin`   | System binaries (for system administration)                |
| `/tmp`    | Temporary files not expected to survive a reboot           |
| `/usr`    | Non-system-critical executables, libraries and resources   |
| `/var`    | Variable files (e.g. lock/log files, databases)            |

{% note %}

From [Unix Filesystem Conventional Directory Layout][unix-layout].

{% endnote %}

## Unix users

Like all modern operating systems, Unix operating systems like Linux are
**multi-user systems**, meaning that more than one user can have access to the
system at the same time.

A **user** is **any entity that uses the system**. This may be:

- A **person**, like Alice or Bob
- A **system service**, like a MySQL database or an SSH server

A Unix system maintains a list of user accounts representing these people and
system services, each with a different **name** such as `alice`, `bob` or
`sshd`. Each of these user accounts is also identified by a **numerical user ID
(or UID)**.

### User access

Managing users is done for the purpose of security by limiting access in certain
ways, such as file permissions.

The **superuser**, named `root`, has complete access to the system and its
configuration. It is intended for administrative use only.

Unix also has the notion of **groups**. Much like a user account, a group is
identified by a **name** and by a **numerical group ID (or GID)**. Each user
belongs to a **main group**, and can also be **added to other groups**, which
grants that user all privileges assigned to each group.

{% cols %}

A Unix system usually creates a main group for each user, with the same name as
the user. For example, user `alice` has the `alice` group as its main group.

This provides a quick way of giving `bob` access to `alice`'s files by adding
him to the `alice` group, if necessary.

<!-- col -->

<div class="w-full p-4 dark:bg-radial dark:from-gray-300 dark:from-40% dark:to-zinc-300/50">
  <img src='images/users-groups.png' />
</div>

{% endcols %}

### Types of users

As we said at the beginning of this section, a user can be a **login user**
representing a person or a **system user** generally representing a service.

You may wonder why we even need system users? In Unix systems, users are the
fundamental access control mechanism, so we need system users to limit the
permissions of people using the system, but also of services running on that
system. For example:

- Alice should not be able to access Bob's files without his permission, and
  vice-versa.
- A database server like MySQL needs to access some files for storage, but it
  doesn't need to access Alice's or Bob's files. It also doesn't need to be able
  to log in since it's a service and not a person.

### Difference between login and system users

There is **no fundamental difference between a login and a system user**. It's
simply an organizational distinction to make life easier for system
administrators.

- Both login and system users are stored in the same [user database
  files](#appendix-user-database-files) with the same format.
- A login user can log in because it has a password and a login shell.
- A system user has no password and no login shell and therefore cannot log in.
- A system user has a UID in a different range by default, typically under 1000.
  (This difference can be utilized by the GUI, for example to omit system users
  when populating a username dropdown list at login.)

{% note type: tip %}

You can even transform a login user into a system user and vice-versa through
judicious use of the `usermod` command.

{% endnote %}

### Managing users

Creating, modifying and deleting users and groups is done with commands such as
`useradd`, `usermod`, `passwd`, `userdel` and `groupadd`. The [System
Administration Cheatsheet][sysadmin-cheatsheet-users] shows how to use them,
including how to create a login user and a system user.

## Administrative access

Many administrative tasks such as installing packages, managing users or
changing file permissions can only be performed by the `root` user.

If you have the `root` user's password (or an authorized public key), you can
**log in as root** directly. But **you should avoid it** as often as possible.

It is **dangereous to log in as `root`**. One wrong move and you could
irreversibly damage the system. For example:

- Delete a system-critical file or files
- Change permissions on system-critical executables
- Lock yourself out of the system (e.g. by disabling SSH on a server)

### The `sudo` command

The `sudo` command (which means "**s**uper**u**ser **do**") offers another
approach to give users administrative access.

When **trusted users** precede an administrative command with `sudo`, they are
generally prompted for **their own password**. Once authenticated, the
administrative command is **executed as if by the `root` user**.

```bash
$> ls -la /root
ls: cannot open directory '/root': Permission denied

$> sudo ls -la /root
[sudo] password for jde:
drwx------  4 root root 4096 Sep 12 14:53 .
drwxr-xr-x 24 root root 4096 Sep 12 14:44 ..
-rw-------  1 root root  137 Sep 11 09:51 .bash_history
-rw-r--r--  1 root root 3106 Apr  9 11:10 .bashrc
...
```

{% note type: more %}

Only trusted users can use `sudo`. Unauthorized usage will be
[reported][xkcd-incident]. The relevant logs can be checked with `sudo
journalctl $(which sudo)` (if you are a trusted user).

{% endnote %}

#### The sudoers file

The `/etc/sudoers` file defines which users are trusted to use `sudo`. This is a
classic example (the basic syntax is [described here][sudoers]):

```
Defaults        env_reset
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:..."

root    ALL=(ALL:ALL) ALL
%admin  ALL=(ALL) ALL
%sudo   ALL=(ALL:ALL) ALL
```

This configuration allows members of the `sudo` group to execute any command
(i.e. they are trusted users).

It's also possible to allow a user or group to execute `sudo` without a password
prompt, which is typically how many cloud providers configure their virtual
servers. This is convenient, but it is less secure than requiring a password,
and it is not recommended for production servers.

{% callout %}

**NEVER EVER edit the `/etc/sudoers` file by hand**, as you will break the
`sudo` command if you introduce syntax errors into the file. Use the `visudo`
command which will not let you save unless the file is valid.

With these defaults settings common to most Unix systems, you can simply add a
user to the `sudo` group to make them trusted `sudo` users.

{% endcallout %}

### The `su` command

The `su` command (which means "**s**witch **u**ser") is also a common
administrative tool. As its name indicates, it can be used to log in as another
user. If you are a trusted sudoer, you can use it to become another user:

```bash
$> whoami
bob

$> ls -la /home/alice
ls: cannot open directory '/home/alice': Permission denied

$> sudo su -l alice
[sudo] password for bob:

$> whoami
alice

# When you're done, exit the shell to return to your previous user:
$> exit

$> whoami
bob
```

{% note type: more %}

The `-l` option of the `su` command makes sure you get a **login shell**, i.e.
an environment similar to what you get when actually logging in. If you don't
use it, you will have a minimal shell environment that might be missing some
things.

{% endnote %}

#### Performing administrative tasks as root

You can also use the `su` command to log in as `root`.
You can perform any necessary administrative tasks without `sudo` (since you are `root`),
then again go back to your previous shell with `exit`:

```bash
$> sudo su -l root

$> whoami
root

$> journalctl $(which sudo)
...

$> exit

$> whoami
bob
```

{% callout %}

As mentioned before, be extra careful not to break the system when you are
`root`.

{% endcallout %}

## Permissions

Someone who logs in on a Unix system can use any file their user account is
permitted to access. The system determines whether or not a user or group can
access a file based on the permissions assigned to it.

There are **three different permissions** for files and directories. They are
represented by one character:

| Permission | For files                                           | For directories                                       |
| :--------- | :-------------------------------------------------- | :---------------------------------------------------- |
| `r`        | **Read** the contents of the file                   | **List** the directory                                |
| `w`        | **Write** to the file (modify it)                   | **Create** or **delete** files in the directory       |
| `x`        | **Execute** the file (if it's a binary or a script) | **Traverse** the directory (to access a subdirectory) |

The symbol `-` (a hyphen) represents no permission, indicating that the
corresponding access is not granted.

### User categories

Each of the three permissions are assigned to three different categories of
users:

| Category | Description                                               |
| :------- | :-------------------------------------------------------- |
| `owner`  | The **user** who owns the file                            |
| `group`  | The **group** that owns the file (any user in that group) |
| `other`  | Any other user with access to the system                  |

### Checking file permissions

When you run the `ls` command with the `-l` option (**l**ong format), you can
see more information about files, including their **type and permissions**:

```bash
$> ls -l
drwxr-xr-x 2 root root 4096 Sep  7 12:16 some-directory
-rwxr-x--- 1 root vip   755 Jan 18  2018 some-executable
-rw-r----- 1 bob  bob   321 Jan 18  2018 some-file
lrwxrwxrwx 1 bob  bob   39  Jan 18  2018 some-link -> some-file
```

Column 1 represents the permissions assigned to the file, while columns 3 and 4
represent their ownership (owner and group). The first 10-letter column can be
separated into one letter for the type of file, and three 3-letter groups for
owner, group and other permissions respectively:

```
TYPE  OWNER PERM  GROUP PERM  OTHER PERM  OWNER  GROUP
d     rwx         r-x         r-x         root   root  ... some-directory
-     rwx         r-x         ---         root   vip   ... some-executable
-     rw-         r--         ---         bob    bob   ... some-file
l     rwx         rwx         rwx         bob    bob   ... some-link -> some-file
```

{% note type: tip %}

The [file types][unix-file-types] you will most often handle are `-` for files,
`d` for **d**irectories and `l` for **l**inks. There are others like `p` for
[named **p**ipes][unix-named-pipe], `s` for [**s**ockets][unix-socket] and `b`
or `c` for **b**lock or **c**haracter [device files][unix-device-file], but they
are outside the scope of this course.

{% endnote %}

## Permission management

The following commands can be used to change the permissions or ownership of
files:

| Command | Purpose                                                                        |
| :------ | :----------------------------------------------------------------------------- |
| `chmod` | **Ch**ange the **mod**e (another name for file permissions) of a file or files |
| `chown` | **Ch**ange the **own**er (and optionally the group) of a file or files         |

Use `man <command>` to read their manual, e.g. `man chmod`.

### The `chown` command

The [`chown` command][chown] is quite simple to use. The following command
changes the owner of `file.txt` to `alice`:

```bash
$> sudo chown alice file.txt
```

The following command changes the owner of `file.txt` to `bob` and its group to
`vip`:

```bash
$> sudo chown bob:vip file.txt
```

You can also recursively (with the `-R` option) change the owner and group of a
directory and all its files:

```bash
$> sudo chown -R bob:bob /home/bob
```

{% callout %}

Be **EXTREMELY CAREFUL when changing ownership recursively**. Changing the
ownership of system-critical files may break your system. **Make sure you typed
the correct path.**

{% endcallout %}

### The `chmod` command

The [`chmod` command][chmod] is used to change file permissions and is a little
more complicated. It has two syntaxes to specify which permissions you want:
**symbolic mode** and **octal mode**.

With **symbolic mode**, you specify which permissions you want with letters
similar to those shown by `ls -l`, and you have more control over which specific
permissions you want to add or remove:

```bash
$> sudo chmod ug+x script.sh
$> sudo chmod a-w readonly.txt
$> sudo chmod o-rwx secret.txt
```

With **octal mode**, you specify all of a file's permissions at once.
You cannot add or remove a specific permission without also setting the others:

```bash
$> sudo chmod 755 executable.sh
$> sudo chmod 640 secret.txt
```

#### Symbolic mode

The symbolic syntax of the `chmod` command is:

```
chmod [reference...][operator][permission...] file
```

Specify one or more references (`[reference...]`) to select user categories:

| Reference | Category | Description                              |
| :-------- | :------- | :--------------------------------------- |
| `u`       | User     | The user who owns the file (the owner)   |
| `g`       | Group    | The group that owns the file             |
| `o`       | Others   | Any other user with access to the system |
| `a`       | All      | All three of the above, same as `ugo`    |

Use one of the available operators (`[operator]`):

| Operator | Description                                                   |
| :------- | :------------------------------------------------------------ |
| `+`      | Add permissions to the specified category of users            |
| `-`      | Remove permissions from the specified category of users       |
| `=`      | Set the exact permissions for the specified category of users |

#### Using symbolic mode

The symbolic syntax basically allows you to specify:

- What category or categories of users you want to change permissions for (`u`,
  `g`, `o` or `a`)
- What kind of change you want to do (`+`, `-` or `=`)
- What permission(s) you want to change (`r` for read, `w` for write or `x` for
  execution/traversal)

For example, the following command adds read and write permissions to `u` (the
owner of the file):

```bash
$> sudo chmod u+rw file.txt
```

The following command sets the permissions for `g` (the group of the file) to
read and execute:

```bash
$> sudo chmod g=rx file.txt
```

#### Bases: one number, several ways to write it

**Octal mode** writes permissions as numbers in base 8 (octal). The following
`chmod` commands are equivalent:

```bash
$> sudo chmod 755 executable.sh
$> sudo chmod u=rwx,g=rx,o=rx executable.sh
```

To see why, remember that a base is only a way of writing a number.

In base 10, which we use every day, there are ten digits (0 to 9), and each
position is worth ten times the position to its right:

| Digits of `755` (in base 10 or decimal) |              7 |              5 |              5 |
| :-------------------------------------- | -------------: | -------------: | -------------: |
| Position value                          | 10<sup>2</sup> | 10<sup>1</sup> | 10<sup>0</sup> |
|                                         |            100 |             10 |              1 |

So `755` means 7 × 100 + 5 × 10 + 5 × 1.

In base 2 (binary), there are only two digits, 0 and 1, and each position is
worth twice the position to its right:

| Digits of `101` (in base 2 or binary) |             1 |             0 |             1 |
| :------------------------------------ | ------------: | ------------: | ------------: |
| Position value                        | 2<sup>2</sup> | 2<sup>1</sup> | 2<sup>0</sup> |
|                                       |             4 |             2 |             1 |

So binary `101` means 1 × 4 + 0 × 2 + 1 × 1, which is 5 in decimal.

In base 8 (octal), there are eight digits, 0 to 7, and each position is worth
eight times the position to its right:

| Digits of `755` (in base 8 or octal) |             7 |             5 |             5 |
| :----------------------------------- | ------------: | ------------: | ------------: |
| Position value                       | 8<sup>2</sup> | 8<sup>1</sup> | 8<sup>0</sup> |
|                                      |            64 |             8 |             1 |

So in octal, `755` means 7 × 64 + 5 × 8 + 5 × 1, which is 493 in decimal.

The important thing to remember is that **the representation of a number is not
the same as the number itself**. These are all **the same number**, just written
in different representations:

- 493<sub>10</sub> (base 10, decimal notation)
- 755<sub>8</sub> (base 8, octal notation)
- 111101101<sub>2</sub> (base 2, binary notation)
- CDXCIII (Roman numerals)

Decimal notation is not "more correct" than octal or binary notation. It's the
one we learn and use every day because it's intuitive to us humans with our 10
fingers. Computers don't care, and for reasons that will become clear later,
binary is a much better fit for computers than decimal.

#### Octal mode

So why does Unix use octal notation for file permissions?

Remember that we have 9 permissions: 3 (`r`, `w`, `x`) for each of the 3
categories of users (owner, group, others). Each permission is either on or off,
which is a binary choice and can be represented as a bit (1 for on, 0 for off).

This means that for each category of users, there are 8 possible combinations of
permissions (3 bits with 2 possibilities each = 2<sup>3</sup> possibilities =
8):

| Permissions          | Text  | In binary each bit on (1) or off (0) | In octal (same number) |
| :------------------- | :---- | :----------------------------------: | :--------------------: |
| read, write, execute | `rwx` |                 111                  |           7            |
| read, write          | `rw-` |                 110                  |           6            |
| read, execute        | `r-x` |                 101                  |           5            |
| read only            | `r--` |                 100                  |           4            |
| write, execute       | `-wx` |                 011                  |           3            |
| write only           | `-w-` |                 010                  |           2            |
| execute only         | `--x` |                 001                  |           1            |
| no permissions       | `---` |                 000                  |           0            |

So we could choose to represent the set of permissions for a file or a directory
as 9 binary digits, or **bits**. For example, `rwx r-x ---` can be represented
as `111 101 000` (in binary, with spaces added for clarity).

But `111101000` is a long string of digits, and it is not very easy to read or
remember. It is much more convenient to represent the same permissions as 3
octal digits, `750`, which is equivalent, since each octal digit is equivalent
to 3 binary digits (1 octal digit also represents 8 possible values).

Using the table above, you can quickly translate `750` back into permission
flags:

- `7` means `rwx` for the owner, i.e. the owner can read, write and
  execute/traverse;
- `5` means `r-x` for the group, i.e. the group can read and execute/traverse,
  but not write;
- `0` means `---` for others, i.e. others have no access at all.

You can represent any other set of 9 permissions with 3 octal digits:

- `755` is equivalent to `rwxr-xr-x`.
- `751` is equivalent to `rwxr-x--x`.
- `640` is equivalent to `rw-r-----`.

That is why octal suits Unix permissions. It is simply a compact way of
representing the 9 permission bits. If you ever use `chmod` regularly, you will
get used to it and will be able to quickly translate between octal and symbolic
modes.

#### Using octal mode

The octal syntax does not allow you to make a granular change to a specific
permission (e.g. `u+x`). However, it does allow you to easily change an entire
file's permissions in one command.

For example, the following command sets permissions `rwxr-xr-x` to `script.sh`:

```bash
$> sudo chmod 755 script.sh
```

The following command sets permissions `rw-r-----` to `secret.txt`:

```bash
$> sudo chmod 640 secret.txt
```

## References

- [Red Hat Enterprise Linux - Introduction to System Administration](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Introduction_To_System_Administration/)
- [Red Hat Enterprise Linux - Security Guide](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Security_Guide/)

## Appendix: Unix file types

> ["Everything is a file."][unix-everything-is-a-file]

Unix systems have regular files and directories like most other systems. But in
addition to these, it represents various other things as files:

| Type                          | Description                                                          |
| :---------------------------- | :------------------------------------------------------------------- |
| File                          | A regular file                                                       |
| Directory                     | A directory containing any number of files                           |
| [Symbolic link][unix-symlink] | A reference to another file                                          |
| [Named pipe][unix-named-pipe] | A connector from the output of one process to the input of another   |
| [Socket][unix-socket]         | A bidirectional endpoint for inter-process communication             |
| [Device][unix-device-file]    | Representations of physical or logical peripherals (e.g. hard drive) |

## Appendix: user database files

These files define what user accounts and groups are available on a Unix system:

| File           | Contents                                                                                                                                              |
| :------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/etc/passwd`  | List of user accounts, as well as their primary group, home directory and default shell (it originally also contained user passwords, hence the name) |
| `/etc/shadow`  | Hashes of user passwords (more secure than storing them in word-readable `/etc/passwd`)                                                               |
| `/etc/group`   | List of groups and their members                                                                                                                      |
| `/etc/gshadow` | Hashes of group passwords (optional), group administrators                                                                                            |

You should **never edit these files by hand**.

Unix systems provide various **system administration commands** for this
purpose, such as `useradd`, `passwd` and `groupadd` for Linux.

### The `/etc/passwd` file

Each line in [`/etc/passwd`][etc-passwd] defines a user account, with data
separated by semicolons:

```
jde:x:500:500:jde:/home/jde:/bin/bash
```

- **Username** (`jde`) - The name of the user account (used to log in)
- **Password** (`x`) - User password (or `x` if it is stored in `/etc/shadow`)
- **User ID (UID)** (`500`) - The numerical equivalent of the username
- **Group ID (GID)** (`500`) - The numerical equivalent of the user's primary
  group name (often the same as the UID for most users, on a Unix system with
  default settings)
- **GECOS** (`jde`) - Historical field used to store extra information (usually
  the user's full name)
- **Home directory** (`/home/jde`) - Absolute path to the user's home directory
- **Shell** (`/bin/bash`) - The program automatically launched whenever the user
  logs in (e.g. on a terminal or through SSH)

{% note type: tip %}

Changing the shell can be used to prevent some users, like system users, from
logging in (e.g. by using `/bin/false` or `/usr/sbin/nologin`).

{% endnote %}

### The `/etc/group` file

Each line in [`/etc/group`][etc-group] defines a group, also semicolon-separated:

```
vip:x:512:bob,eve
```

- **Group name** (`vip`) - The name of the group
- **Group password** (`x`) - Optional group password (or `x` if the password is
  stored in `/etc/gshadow`); if specified, allows users not part of the group to
  join it with the correct password
- **Group ID (GID)** (`512`) - The numerical equivalent of the group name
- **Member list** (`bob,eve`) - A comma-separated list of the users belonging to the group

### The shadow files

Both `/etc/passwd` and `/etc/group` must be **readable by anyone** on a Unix
system, because they are used by many programs to perform the translation from
username to UID and from group name to GID.

It is therefore bad practice to store passwords in these files, even encrypted
or hashed. Any user might copy them and attempt a brute-force attack (which
could be done on a separate, dedicated infrastructure).

Therefore, the corresponding shadow files exist:

- [`/etc/shadow`][etc-shadow] stores password hashes for user accounts, and
  other security-related data such as password expiration dates.
- [`/etc/gshadow`][etc-gshadow] stores password hashes for groups, and other
  security-related data such as who is the group administrator.

These files are only readable by the `root` user (or any user that belongs to
the `root` or `shadow` groups).

## Appendix: welcome to the future

Some of the commands mentioned in this course are older than you, although they
are regularly updated. But new command line tools are also being developed
today:

- The [`duf` command][duf] is a modern alternative to `df` to list free disk
  space, written in [Rust][rust], a modern systems programming language.

## Appendix: of dolphins and humans

Still don't believe that binary is "as correct" as decimal?

Read the following excerpts from a base conversion textbook by humans, and the
same textbook written by English-speaking dolphins:

{% cols %}

**Human textbook**

Both humans and dolphins use a positional number system to represent numbers.
The base of the system is determined by the number of digits available to
represent numbers.

Dolphins have 2 flippers, so they use base 2 (binary) to count. We humans have 10
fingers, so we use base 10 (decimal) to count.

Here's how to convert a dolphin's binary number to a human's decimal number:

`1101` means 1 × 2<sup>3</sup> + 1 × 2<sup>2</sup> + 0 × 2<sup>1</sup> + 1 ×
2<sup>0</sup> = 13 in decimal.

(Dolphins use the same first two digits we humans use, "0" and "1", but they
don't have any more since they only have two flippers.)

<!-- col -->

**Dolphin textbook**

Both dolphins and humans use a positional number system to represent numbers.
The base of the system is determined by the number of digits available to
represent numbers.

Humans have 1010 fingers, so they use base 1010 (decimal) to count. We dolphins
have 10 flippers, so we use base 10 (binary) to count.

Here's how to convert a human's decimal number to a dolphin's binary number:

`13` means 1 × 1010<sup>1</sup> + 11 × 1010<sup>0</sup> = 1101 in binary.

(Humans use digits we don't have, like "2" to represent the number `10`, and "3"
to represent the number `11`.)

{% endcols %}

Both versions are just as valid from each perspective. Our hypothetical
English-speaking dolphins just have a different representation of numbers than
humans, and vice versa. A dolphin would undoubtedly understand the second
textbook better than the first, and find it strange that humans have digits
other than `0` and `1`.

[apfs]: https://en.wikipedia.org/wiki/Apple_File_System
[chmod]: https://linux.die.net/man/1/chmod
[chown]: https://linux.die.net/man/1/chown
[duf]: https://github.com/muesli/duf
[etc-group]: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Introduction_To_System_Administration/s3-acctspgrps-group.html
[etc-gshadow]: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Introduction_To_System_Administration/s3-acctsgrps-gshadow.html
[etc-passwd]: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Introduction_To_System_Administration/s2-acctsgrps-files.html
[etc-shadow]: https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/4/html/Introduction_To_System_Administration/s3-acctsgrps-shadow.html
[ext]: https://en.wikipedia.org/wiki/Extended_file_system
[fstab]: https://en.wikipedia.org/wiki/Fstab
[hfs]: https://en.wikipedia.org/wiki/Hierarchical_File_System_(Apple)
[ntfs]: https://en.wikipedia.org/wiki/NTFS
[octal-mode]: https://en.wikipedia.org/wiki/File_system_permissions#Numeric_notation
[rust]: https://www.rust-lang.org
[sudoers]: https://www.sudo.ws/docs/man/1.8.13/sudoers.man/#SUDOERS_FILE_FORMAT

[sysadmin-cheatsheet-users]: {% link cheatsheets/sysadmin/cheatsheet.md %}#how-do-i-create-another-user-useradd
[unix-device-file]: https://en.wikipedia.org/wiki/Device_file
[unix-everything-is-a-file]: https://en.wikipedia.org/wiki/Everything_is_a_file
[unix-file-types]: https://en.wikipedia.org/wiki/Unix_file_types
[unix-layout]: https://en.wikipedia.org/wiki/Unix_filesystem#Conventional_directory_layout
[unix-named-pipe]: https://en.wikipedia.org/wiki/Named_pipe
[unix-socket]: https://en.wikipedia.org/wiki/Unix_domain_socket
[unix-symlink]: https://en.wikipedia.org/wiki/Symbolic_link
[xkcd-incident]: https://xkcd.com/838/
