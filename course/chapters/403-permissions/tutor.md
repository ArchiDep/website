# Tutor notes: 403 Unix Permissions

## Starting point

- 402 Unix Basics: the exercise practises its "Permissions" and "Permission
  management" sections, `chmod` in both modes and the base conversion behind
  octal mode. Those sections are the reference for the permissions themselves.
- 104 Hello SSH: the student logs in to the SSH exercise server
  (`ssh.archidep.ch`) with their own username. Every step runs there.
- The SSH exercise server is the only place the whole exercise works. The page
  does not mention working locally. On the student's own computer, the defaults
  are different (new files are `-rw-r--r--`, and on macOS every user's main
  group is `staff`), and the last two parts need other users. A student working
  locally cannot finish the exercise.
- No `sudo`: students are not administrators on the SSH exercise server, and
  nothing in the exercise needs it.

## Learning objectives

Reading `ls -l`, and predicting what each permission allows: on a file, for its
owner too; on a directory, where `r`, `w` and `x` are about the names it holds;
for a user who is "other". The page's "What have I done?" states what the
student should understand afterwards.

Each step asks for a prediction first. The answer is on the page right after the
command, in a "Check your prediction" box. Ask for the prediction and the reason
behind it before they run the command. A wrong prediction is what the step is
for. The `chmod` commands to find are in boxes the student opens, and some show
both the symbolic and the octal form: either one is enough.

Not in the exercise: `chown` (it needs `sudo`), sharing a file through a group,
the `umask` (the page only says what the server gives new files), the special
bits (setuid, setgid, sticky) and ACLs. None of them is in the course.

## Where it leads

Every chapter that runs something on the student's own server relies on
permissions. In particular:

- "Meet your server": reads the permissions of `/etc/sudoers` and `/swapfile`,
  files that only `root` can touch, on a server where the student is the
  administrator.
- "Unix Environment Variables", "Git Hooks" and "Set up an automated deployment
  with Git hooks": a script made executable with `chmod`, as in "Execute a
  script".
- "Deploy a static site with nginx": nginx runs as the `www-data` user, which is
  "other" for the student's home directory. That home directory is `750`, as on
  the SSH exercise server ("Your classmates' home directories"), so nginx cannot
  go through it until it is given access.
- "The Image Gallery" demonstrates how far a permissions problem on a server can
  be exploited.

## Key steps

- **"A new file".** After: `-rw-rw-r--`, owned by the student and by a group of
  the same name. Ask: who is in that group?
- **"Take away your own write permission".** After: `Permission denied` on
  `>>`, and `cat` still works. Ask: why are you refused, although you own the
  file?
- **"Take away your own read permission"**, the step the first part is built
  around. After: `----rw-r--`, and `cat` is refused although the group can read
  and the student is in it. Ask: which of the three categories did Unix check,
  and why only that one?
- **"Set the permissions back".** Ask the student to convert `rw-` and `r--` to
  digits and explain them, whichever mode they used. After: `-rw-rw-r--` again.
- **"Rename a file you cannot write".** Before: whose permission does renaming
  need, the file's or the directory's? After: `renamed.txt` is listed with
  `-r--------`.
- **"Take away the directory's write permission".** After: `mv` and `touch` are
  both refused. Ask: what would you need to change to rename the file again?
  The step ends by giving `w` back: check that it was.
- **"Go through a directory you cannot list".** After: `ls` refused, `cat`
  prints `You found me`. Ask: what does `x` give on a directory, and what does
  `r` give? Could you read `secret.txt` without knowing its name?
- **"Execute a script".** Before: what permission does running a file need?
  After `u+x`: `Hello from a script`, and `-rwxrw-r--`.
- **"Your classmates' home directories".** Before: from `ls -l /home`, which
  category are you for a classmate's home directory, and what does it allow?
  After: `Permission denied`.
- **"Who can read the passwords?"** Ask: which category are you for each file?
  After: the first lines of `/etc/passwd`, and `Permission denied` on
  `/etc/shadow`.
- **"Decide what others can read"**, with a classmate. The point is that the
  student decides what other people can do, without knowing who they are. Ask:
  who did you take the permission away from? Would it make a difference if
  someone else tried? The student deletes their file at the end.

## Common pitfalls

- **``syntax error near unexpected token `newline'``** on `cd /home/<username>`:
  the angle brackets were typed. Hint: what does `<username>` stand for?
- **`ls -l` shows `-rw-r--r--`, or a group named `staff`**, or `/home` is empty
  or missing: the student is on their own computer. Hint: what does `hostname`
  print? It should print `ssh.archidep.ch`.
- **`rm` asks `remove write-protected regular file?`**, when the student tidies
  up `renamed.txt` or `locked.txt` on their own. The question comes from `rm`
  itself, which checks the file's permissions before deleting it. Unix does not
  ask it: removing a name only needs `w` on the directory, as "Rename a file you
  cannot write" shows. Ask: what did `mv` need in that step?
- **`./hello.sh` still says `Permission denied` after a `chmod`**: the `x` went
  to the wrong category, for example `g+x` or `o+x`. Hint: read the owner's
  three letters in `ls -l`.
- **`hello.sh: command not found`**: the script was run without `./`. Hint: the
  `PATH`, as in 102.
- **`bash hello.sh` runs the script without `x`**, and the student wonders what
  the permission is for. Ask: which program is executed now, and what does it
  need to do with `hello.sh`? (`bash` only reads the file, which needs `r`.)
- **The classmate can still read the note after `chmod o-r`**: the `chmod` was
  run on another file, or the classmate is reading another file. Hint: both run
  `ls -l` on the exact same path.
- **`Permission denied` when creating the note in `/tmp`**: the name does not
  start with the student's own username, and another user already has a file
  by that name, often the page's example `jde-note.txt`. Hint: who owns that
  file in `ls -l`?
- **The student asks to write to the classmate's file** after giving it `o+w`,
  and is refused. The page avoids this on purpose: Ubuntu refuses writing to
  another user's file in a directory everyone can write to, such as `/tmp`,
  whatever its permissions. This protection is not in the course, and the step
  is about reading.
- **`sudo` asks for a password, then refuses**: students are not administrators
  on the SSH exercise server. Nothing in the exercise needs `sudo`.
