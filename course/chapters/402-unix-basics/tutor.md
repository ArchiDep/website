# Tutor notes: 402 Unix Basics

## Scope

The slides are what is taught; the subject page goes further and is the
reference for `chmod`.

- Slides: "One tree" (one root, mounted volumes, `/etc/fstab`); "Case matters";
  "Users and groups"; "Root and `sudo`" and "Who can list `/root`?";
  "Permissions" and "Reading `ls -l`"; `chown`; `chmod` in symbolic mode; "Are
  you allowed?", on a file and a directory of the student's own; then a
  reminder of bases (10, 2 and 8, and the same number written in each) before
  `chmod` in octal mode.
- Subject page: the same, with more detail: "File system", "Unix users" (types
  of users, login and system users), "Administrative access" (`sudo`, "The
  sudoers file"), "Permissions", and "Permission management", where "Bases: one
  number, several ways to write it" and "Octal mode" explain octal mode in
  full.

Kept as reading or reference, not taught: the table of file systems, "Common
Unix directories", "Managing users" (and the System Administration Cheatsheet
it links to), "The `su` command", the syntax of the sudoers file, and the
appendices: file types, the user database files (the fields of `/etc/passwd`
and `/etc/group`, the shadow files), "Welcome to the future", and "Of dolphins
and humans".

## Left out

Taught later:

- Services that run as their own user: `www-data` for nginx in "Deploy a static
  site with nginx", and the suggestion of a dedicated system user in "Manage a
  PHP application with systemd as a Process Manager".

Not in the course: the special permission bits (setuid, setgid, sticky), the
`umask`, access control lists, how file systems store files (inodes), PAM, and
security modules such as AppArmor. File types other than files, directories and
links are named but outside the course, as the page says.

## Key concepts and vocabulary

- **One tree**: a single root, `/`. Other volumes are **mounted** on a directory
  of the tree, not given a drive letter. `/etc/fstab` lists the volumes mounted
  at boot.
- **Case-sensitive** file names on Linux; usually case-insensitive on macOS and
  Windows.
- **User**: anything that uses the system, a person or a service, with a name
  and a **UID**. **Login users** and **system users** differ only by convention:
  a system user has no password and no login shell.
- **Group**: a name and a **GID**. Each user has a **main group**, usually of
  the same name, and may be in other groups.
- **`root`**, the **superuser**: can do anything. Not to log in as.
- **`sudo`**: runs **one command** as `root`, for a **trusted user**, after
  asking for **the user's own password** (or none, on servers configured so).
  `/etc/sudoers` says who is trusted, usually the `sudo` group. Edited only with
  `visudo`.
- **Permissions**: `r`, `w` and `x`, for each of three **categories**: the
  **owner**, the **group**, and **others**. On a directory: `r` lists, `w`
  creates and deletes (and renames) the names in it, `x` **traverses** it.
- **`ls -l`**: the type, the nine permissions, the owner and the group.
- **`chown`** changes the owner and group; **`chmod`** changes the permissions,
  in **symbolic mode** (`u`, `g`, `o`, `a`; `+`, `-`, `=`; `r`, `w`, `x`) or in
  **octal mode** (three digits, one per category).
- **Bases**: a base is a way of writing a number. One octal digit stands for
  three bits; `r`, `w` and `x` are worth 4, 2 and 1, so `rwxr-x---` is `750`.

## Misconceptions

- **Misconception:** the owner of a file can always read and write it.
  **Correction:** the owner is checked against the owner's permissions like
  anyone else. Owning a file only means being allowed to change them.
- **Misconception:** a user in the file's group gets the group's permissions on
  top of the owner's.
  **Correction:** only one category applies, the first that matches: owner,
  then group, then others. An owner with `---` is refused, whatever the group
  may do.
- **Misconception:** `chmod` always needs `sudo`, since the subject page's
  examples all use it.
  **Correction:** the owner of a file can change its permissions without
  `sudo`. `sudo` is needed for files the student does not own, and to change an
  owner with `chown`.
- **Misconception:** deleting or renaming a file needs `w` on the file.
  **Correction:** it needs `w` on the directory that holds its name.
- **Misconception:** `x` on a directory means running it, and `r` lets you read
  the files inside.
  **Correction:** `x` lets you go through the directory to a name you know; `r`
  only lists the names. Reading a file inside depends on the file's own `r`.
- **Misconception:** `755` is seven hundred and fifty-five, or octal is a less
  "real" notation than decimal.
  **Correction:** it is one number, 493 in decimal, written in base 8, and each
  digit stands for one category. `chmod` never needs it converted to decimal.
- **Misconception:** `sudo` asks for the password of `root`, or makes the
  student `root` until they log out.
  **Correction:** it asks for the student's own password, and runs a single
  command as `root`.
- **Misconception:** system users are a different kind of account.
  **Correction:** they are stored the same way; the distinction is a
  convention, kept so that services cannot log in and only reach their own
  files.

## Used in

Most of the course from here on: every deployment runs commands with `sudo`,
installs files somewhere in the tree, and has to get permissions right on the
student's server. Parts that exercises lean on in particular:

- "Unix Permissions" practises the permissions of files and directories,
  `chmod` in both modes, and being "other", on the SSH exercise server.
- "Run your own virtual server on Microsoft Azure" uses `sudo` for the first
  time on the student's own server, and mounts a swap file through
  `/etc/fstab`.
- "Meet your server" reads the student's groups, `sudo` without a password,
  root-only files and the server's system users.
- "Unix Environment Variables", "Git Hooks" and "Set up an automated deployment
  with Git hooks" make a script executable with `chmod`.
- "Deploy a static site with nginx" has to let the `www-data` user through the
  student's home directory.
- "Containerize a web application using Docker" changes ownership with `chown`.
