---
title: Unix Permissions
cloud_server: details
excerpt_separator: <!-- more -->
---

This exercise illustrates how you can restrict access to files and directories
using Unix permissions.

{% callout type: exercise %}

Connect to your cloud server with SSH for this exercise.

{% endcallout %}

<!-- more -->

## :exclamation: Setup

Create a new `alice` user:

```bash
$> sudo useradd --create-home --shell /bin/bash alice
```

{% note type: tip %}
You can also use the equivalent short versions of these options:

```bash
$> sudo useradd -m -s /bin/bash alice
```

{% endnote %}

Make sure other users can access and list the contents of `alice`'s home
directory:

```bash
$> sudo chmod o+rx /home/alice
```

## :exclamation: The exercise

- Create a file named `file.txt` in `alice`'s home directory that is readable by `alice` but not by you.

{% solution %}

```bash
# Switch to alice.
$> sudo su - alice
# Create the file (it will belong to alice and the alice group).
$> touch file.txt
# Switch back to your user.
$> exit
# Remove read permissions for other users (including yours).
$> sudo chmod o-r /home/alice/file.txt
```

**Another solution**

```bash
# Create the file as root (it will belong to root and the root group).
$> sudo touch /home/alice/file.txt
# Give the file to alice.
$> sudo chown alice /home/alice/file.txt
# Remove read permissions for other users (including yours).
$> sudo chmod o-r /home/alice/file.txt
```

**Setting the permissions in octal mode**

```bash
$> sudo chmod 640 /home/alice/file.txt
```

{% endsolution %}

- Create a directory named `for_alice` in the system's temporary directory
  (`/tmp`). The `alice` user must be able to traverse this directory, but not list its contents or create new files in it.

{% solution %}

```bash
# Create the directory.
$> sudo mkdir /tmp/for_alice
# Give the directory to your user and alice's group.
$> sudo chown jde:alice /tmp/for_alice
# Specify that the group can only traverse the directory
# and (optionally) that other users have no permissions.
$> sudo chmod g=x,o-rwx /tmp/for_alice
```

**Setting the permissions in octal mode**

```bash
$> sudo chmod 710 /tmp/for_alice
```

{% endsolution %}

- The directory must contain a `readable.txt` file that `alice` can read from, but not write to.

{% solution %}

**Solution with access by other users**

```bash
# Move into the directory.
$> cd /tmp/for_alice
# Simply create the file. It will be readable by everyone by default.
$> echo "Hello, I'm readable" > readable.txt
```

**Without access by other users**

```bash
# Give the file to alice's group (which should have read access by default).
$> sudo chown jde:alice readable.txt
# Remove all permissions for other users.
$> sudo chmod o-rwx readable.txt
```

**Setting the permissions in octal mode**

```bash
$> sudo chmod 640 readable.txt
```

{% endsolution %}

- The directory must contain a `writable.txt` file that `alice` can read from and write to.

{% solution %}

**Solution with access by other users**

```bash
$> cd /tmp/for_alice
# Create the file.
$> echo "Hello, I'm writable" > writable.txt
# Add the write permission to other users.
$> sudo chmod o+w writable.txt
```

**Without access by other users**

```bash
# Give the file to alice's group.
$> sudo chown jde:alice writable.txt
# Add the write permission to the group and (optionally)
# remove all permissions for other users.
$> sudo chmod g+w,o-rwx writable.txt
```

**Setting the permissions in octal mode**

```bash
$> sudo chmod 660 writable.txt
```

{% endsolution %}

## :question: Optional: check if it works

You should not be able to read the file in `alice`'s home directory:

```bash
$> cat /home/alice/file.txt
cat: /home/alice/file.txt: Permission denied
```

Temporarily log in as `alice` (using your administrative privileges and the `su` command, as in **s**witch **u**ser):

```bash
$> sudo su --login alice
```

{% note type: tip %}
When you are done, you can go back to being you with the `exit` command. Your command line prompt should remind you who you are. When in doubt, use the `whoami` command.
{% endnote %}

{% note type: more %}

The `--login` option can also be abbreviated to `-l` or even simply `-` (yes,
the people who designed Unix were lazy enough that they did not even want to
type one more letter).

{% endnote %}

You should be able to read the file in the home directory:

```bash
$> cat /home/alice/file.txt
```

You should not be able to list the `for_alice` directory:

```bash
$> ls /tmp/for_alice
ls: cannot open directory '/tmp/for_alice/': Permission denied
```

You should not be able to create a file in the `for_alice` directory:

```bash
$> echo Hello > /tmp/for_alice/file.txt
-bash: /tmp/for_alice/file.txt: Permission denied
```

You should be able to read the `readable.txt` file in the `for_alice` directory:

```bash
$> cat /tmp/for_alice/readable.txt
```

You should not be able to modify the `readable.txt` file in the `for_alice` directory:

```bash
$> echo "Hello, I'm Alice" >> /tmp/for_alice/readable.txt
-bash: /tmp/for_alice/readable.txt: Permission denied
```

You should be able to write to and read from the `writable.txt` file in the `for_alice` directory:

```bash
$> echo "Hello, I'm Alice" >> /tmp/for_alice/writable.txt

$> cat /tmp/for_alice/writable.txt
Hello, I'm Alice
```

{% note type: more %}

As a reminder, in Bash, `>>` means to redirect the standard output of a command
into a file and to append to the end of that file. If you wanted to overwrite
the whole contents of the file, you could use `>` instead.

{% endnote %}

## :checkered_flag: What have I done?

You have learned to open or restrict access to files in a Unix system by judicious use of the `chown` and `chmod` commands to change ownership and/or permissions.

You have also practiced using some of the other Unix file-related commands you have learned about so far.
