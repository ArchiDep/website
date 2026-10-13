# Tutor notes: 409 Unix plumbing

## Starting point

- 404 Run your own virtual server on Microsoft Azure, finished: the student
  logs in to their server over SSH. Every step runs there, in the home
  directory; the page shows the student's own server details.
- 408 Unix Processes: exit statuses, the standard streams, redirection and
  pipes. Its notes hold the vocabulary and the misconceptions this exercise
  practises against.
- 405 Meet your server: the server's system users, whose `nologin` login shell
  the last required step comes back to.
- 101 Command Line Introduction: `>` and `>>` with `echo`, `cat`, and `man`.

No `sudo`: every step runs as the student, and the errors of the first step
exist because the student is not `root`.

## Learning objectives

That a program writes data and errors to two separate streams, which only look
like one in the terminal; that the shell, not the program, connects them to
files or to other programs; that the exit status is a third answer, separate
from both outputs; and that a pipeline of small programs does what none of them
does alone. The page's "What have I done?" states what the student should
understand afterwards.

The commands of the pipeline steps (`cut`, `fold`, `sort`, `uniq`, `tr`, `head`,
`wc`) are given in a table with their options, below the questions. The step
practises choosing and ordering them; their other options are not in the
course.

Every step except "Download the song" ends in a question, with its answer in a
solution box. Not in the exercise: `2>&1`, here documents, `tee`, regular
expressions, and the SSH server configuration that the first step searches (its
callout only says what the files are).

## Where it leads

The exercise is short and nothing later depends on what it leaves on the
server. What it practises is used throughout the deployments:

- "Deploy a web application with SFTP" runs the application in the student's
  terminal, where its output and errors appear, sends `schema.sql` to `psql`
  with `<`, and counts packages with `ls | wc -l`.
- "Process Management on Linux" and "Manage a PHP application with systemd as
  a Process Manager" read what a service writes to its standard output and
  error with `journalctl`: the page's last paragraph points there.
- Later exercises filter long outputs with `| grep`, such as `dpkg --list |
grep php-fpm`.

## Key steps

- **"Where does each line go?"**, the first `grep -r`.
  Question before: "You are searching files you did not write. What could go
  wrong?"
  Expected after: lines starting with `/etc/ssh/`, mixed with lines starting
  with `grep:` and ending in `Permission denied`.
  Question after: "Which lines would you want in a file of results, and which
  should reach you?"
- **"Where does each line go?"**, the three redirections.
  Question before each: "What will still be printed in your terminal?"
  Expected after: with `>`, only the errors are printed; with `2>`, only the
  found lines; with `&>`, nothing, and `all.txt` has both, in another order.
  Question after: "Did `grep` know its output was going into a file?" (No: the
  shell connected it before `grep` started.)
- **"Did it work?"**
  Question before the third command: "It finds lines and meets errors. Which
  exit status do you expect?"
  Expected after: `0`, `1`, `2`.
  Question after: "A script runs this command and checks whether it worked. What
  does it look at, the output or the exit status?"
- **"Download the song"**.
  Question before: "Where does the `>` in this command send what `curl`
  downloads?"
  Expected after: `cat` prints the lyrics, starting with `Somewhere over the
rainbow`.
- **"Pipe the song"**.
  Question before: "Which command keeps only some lines, and which one counts?"
  Expected after: the counts and lines in the solutions (255 words, five lines
  containing `rainbow`, three without duplicates, 131 `e`). Empty lines in the
  output of `cut` are the song's blank lines.
  Question after: "Which command of your pipeline reads the file, and where do
  the others get their input?"
- **"Challenge"** (optional).
  Question before: "Which order of commands turns a text into one word per line,
  then counts each word?"
- **"Pipe your server's users"**.
  Question before: "What separates the fields of `/etc/passwd`, and which field
  is the login shell?"
  Expected after: a few lines like `28 /usr/sbin/nologin`; the numbers differ
  from server to server. The one `/bin/false` is `dhcpcd`, the DHCP client
  daemon, a system user like the `nologin` ones.
  Question after: "Why do most users have `nologin`?" (System users run
  services; nobody should log in as one.)
- **"Discard the errors"** (optional). The page sends the student to the
  subject's appendix on `/dev/null` first.
  Expected after: only the found lines, and no new file in the home directory.

## Common pitfalls

- **No `Permission denied` lines in the first step, and `echo $?` prints `0`
  after `grep -r`**: the command was run with `sudo`, and `root` may read the
  private keys. Question that leads to it: "Who is allowed to read the server's
  private keys, and who ran `grep`?"
- **Different lines, no `/etc/ssh` at all, or `/etc/passwd` with comment lines
  and few users**: the commands ran on the student's own computer. Hint: what
  does `hostname` print?
- **`grep: 2: No such file or directory`, and the found lines end up in
  `errors.txt`**: a space was typed between `2` and `>`. The shell then gives
  `2` to `grep` as one more file to search, and `>` redirects the standard
  output. Question that leads to it: "Which characters make up the operator?"
- **`echo $?` prints `0` where `1` or `2` was expected**: another command ran in
  between, often a first `echo $?`. Question that leads to it: "Of which command
  is `$?` the exit status?"
- **The student expects `&>`'s file to keep the terminal's order**, and thinks
  the redirection lost or mixed lines. The solution explains the order: the
  lines are all there.
- **`rainbow.txt` holds a short HTML page or nothing**: `curl` ran without `-L`,
  and saved the redirection of the short link instead of the song. Hint:
  compare the command with the page's.
- **`grep e` without `-i` gives 131 too**, and the student wonders what `-i` is
  for. The song has no capital `E`; `-i` is what makes the answer right for any
  text.
- **`uniq` without `sort` gives the right three lines**: in this song, the
  duplicate lines happen to be next to each other. Question that leads to it:
  "Would it still work if the same line came at the start and at the end?"
- **The challenge sorted with `sort -r` instead of `sort -nr` gives the right
  top five**: `uniq -c` pads its counts with spaces, so sorting them as text
  works here by luck. Question that leads to it: "How would text sorting order
  `9` and `18` without the padding?"
- **`cut -d : -f 7 /etc/passwd` without `cat`** is as correct as the solution's
  `cat /etc/passwd | cut …`. Every pipeline in the solutions starts with `cat`;
  either form is right.
