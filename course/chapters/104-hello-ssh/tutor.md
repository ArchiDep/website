# Tutor notes: 104 Hello SSH

## Starting point

- 103 Secure Shell (SSH): the exercise puts its subject page into practice.
  When the student asks about SSH, answer from 103's notes: they give the depth,
  the vocabulary and the misconceptions to check the student's explanations
  against.
- A Unix shell, as in 101: the Terminal on macOS, the WSL on Windows. The key
  pair is made and kept there, never in PowerShell.
- The student's username and password for the SSH exercise server, and the
  fingerprints of its host keys, which are on the dashboard. Only the logged-in
  student can see them.
- 102 Hello Shell is optional here. A student who kept its treasure brings it to
  Avalon; one who did not brings the output of `uname -a` instead. Both ways
  are equal.
- Some students already have a key pair, from GitHub or elsewhere: "Do I
  already have a key pair?" says when it can be reused.

## Learning objectives

Working on two machines from one terminal: logging in after checking the
fingerprint, giving the server a public key with `ssh-copy-id`, copying files
in both directions with `scp` and with an SFTP application, and running one
command on the server without logging in. The page's "What have I done?" states
what the student should understand afterwards.

Most of the exercise is a tutorial on the page. Only its last part, Avalon, is
played through programs on the server (below). Headings marked ❓ are optional,
but Avalon's hints send students back to the tip at the end of "Spot the
difference", on running a single command.

Used once, as recipes: `-o PubkeyAuthentication=no`, `ssh -p`, `chmod` ("Unix
Permissions"), and the `<` of the signature check ("Unix Pipeline"). Taught
later: `~/.ssh/config` ("Run your own virtual server on Microsoft Azure"). Not
in the course: configuring the SSH server (such as refusing passwords), `scp`
options beyond the page's examples, and rsync.

## Where it leads

The key pair made here is the student's for the whole course, and every
exercise on a server is reached with `ssh`. Knowing which machine a command runs
on is what students trip over in all of them. In particular:

- Hello GitHub: the public key is given to GitHub, and github.com's fingerprint
  is checked on the first connection.
- "Run your own virtual server on Microsoft Azure": the public key is given to
  the server when it is created, and the server accepts no password, which
  answers "Is your password gone?". Its fingerprints are checked another way.
- "Deploy a PHP application with SFTP": the SFTP application and the private
  key again, on the student's own server.

## Key steps

- **"Connect to the exercise server".** Before: where will you find the
  fingerprint to compare, and what would a mismatch mean? After: `hostname`
  prints `ssh.archidep.ch`.
- **"Spot the difference".** Before: what will `hostname` and `whoami` print in
  each terminal?
- **"Generate a private-public key pair".** Before: which machine must this run
  on? After: `ls ~/.ssh` on their own computer lists `id_ed25519` and
  `id_ed25519.pub`.
- **"Use `ssh-copy-id` to copy your public key to the server".** Before: which
  file is copied, from where to where? After: `ssh` logs in without
  `jde@ssh.archidep.ch's password:`. A key with a passphrase asks
  `Enter passphrase for key '…/id_ed25519':` instead: key authentication works,
  and that is not the server's password.
- **"Is your password gone?"** Ask for a prediction before the command.
- **"Which key is where?"** Ask for the reasoning behind each answer, not only
  the table. On the server, `cat /etc/ssh/ssh_host_ed25519_key` gives
  `Permission denied`, which answers "Secret?" for that one.
- **"Copy a file with the `scp` command".** Nothing to run until Avalon. Ask:
  which side is written first? Where is `jde@ssh.archidep.ch:hello.txt`?
- **"Sign a message with your key"** (optional). Before changing the message:
  what will the check say now? After the first check: is its fingerprint the
  one of `~/.ssh/authorized_keys`?

## Avalon

"The remote land of Avalon" and "A message on the shore" are played through
programs on the SSH exercise server, which tell the student what to do. The page
says how to start and what kinds of things Avalon makes them do.

How Avalon works:

- `dock` is a command on the server. It only opens in a session logged in with
  the key, since the server tells it how the session was authenticated. It
  builds `~/avalon` in the student's home directory on the server.
- The characters are programs in `~/avalon`, run with `./name`. Their texts are
  encoded: reading one with `cat` shows code, ending with a "HALT, TRAVELLER!"
  banner that says how to run it, and from which machine.
- **A hidden `.hint` in `~/avalon` gives the exact commands for the current
  step.** It is the solution, one step at a time. It is replaced as the student
  moves on, so it is worth reading again. A `.hint` in the home directory on the
  server points to `~/avalon`. One step is done on the student's computer,
  where no hint can follow, so the hint on the server covers it together with
  the next one.
- Each program says what is wrong when it refuses: the wrong machine, the wrong
  gift, a missing word. Read its message with the student before hinting.
- A word is drawn at random for each student. Its case does not matter.
- Starting over: `dock --restart` on the server, logged in with the key. It
  asks before it deletes Avalon, and draws a new word. Without `--restart`,
  `dock` only says where Avalon is.
- A message saying that Avalon is broken and that it is not the student's
  fault means the server is misconfigured: send the student to the teacher.
- The student plays. Do not read the programs of Avalon, and do not fetch
  `dock`, which is published next to the exercise: it holds the whole of
  Avalon, solution included. Do not tell the story ahead of the student. Ask
  what the program said, and what `hostname` prints in the terminal the command
  was typed in.

What each stage practises, and the question worth asking at it:

1. **The dock**: logging in with the key rather than the password. Ask: what
   did `ssh` ask you for this time?
2. **The gift**: a file made on the student's own computer and copied up with
   `scp` into `~/avalon`. Ask: on which machine is the file? Which side of the
   command is written first? Where does the path after the colon start? With
   the treasure, it also runs on the server as `./treasure` but not as
   `treasure`. Ask why (the `PATH`, see 102).
3. **The prophecy**: a file copied down with `scp` and run on the student's own
   computer. Ask: which side comes first now? What does the `.` at the end
   stand for?
4. **The Lady of the Lake**: a command run on the server from the student's
   computer, without logging in. Ask: where does the command run, where does its
   output appear, and in which directory does it start?
5. **The shore**: a first connection to a server the SSH client does not know
   yet, and deciding whether to trust it. That decision is the step: do not
   make it for the student, or tell them what the server is. Ask: where are the
   fingerprints you trust written down? Why does your client ask again, for an
   address it already knows? After an answer they regret: how does the client
   forget it?

## Common pitfalls

- **Still asked for a password after `ssh-copy-id`**, or `ssh-copy-id` says `No
identities found`. Hint: does the prompt name a key file?
- **The dock says the student came with a password, though their key works**:
  the session was opened with `-o PubkeyAuthentication=no` in "Is your password
  gone?" and kept open. Hint: log out, and log in with plain `ssh`. If that asks
  for a password, see the previous pitfall.
- **`REMOTE HOST IDENTIFICATION HAS CHANGED` for `ssh.archidep.ch`.** Hint:
  what could have changed, and how would you know it is not an attack?
- **`scp` asks whether to trust `ssh.archidep.ch`, asks for a password, or says
  the file to copy does not exist**: it was run on the server. Hints:
  `hostname`; the page says on which machine `scp` runs.
- **`scp` ends without an error but nothing arrives on the server.** Hint: what
  does the colon mean in the page's examples?
- **Merlin still asks for a gift after the copy**: the file is not in
  `~/avalon` under the name he asked for. It went to the home directory
  (nothing or something else after the colon), was renamed, or came inside a
  copied directory. An error about `avalon/` means `dock` has not built it yet.
  Hints: `ls ~/avalon` on the server; compare with the name Merlin gave.
- **`./prophecy` says `Permission denied` on the student's computer**: the hint
  covers it, with the chest of 102.
- **The command sent to the Lady of the Lake fails before she speaks**:
  - `No such file or directory` with a path of the student's own computer
    (`/Users/…`): their shell turned `~` into their own home directory before
    `ssh` sent the command. Hint: which machine expanded `~`? The hint writes
    the path relative to the home directory on the server.
  - `command not found`: she is not in the server's `PATH`, like the treasure.
  - `ssh … cd avalon && ./lady …`: the part after `&&` runs on the student's
    computer. Hint: how many commands did `ssh` receive?
- **She says it is not the word**: `THE-WORD` was typed as written, or the
  prophecy was brought home before a `dock --restart`. Hint: read the prophecy
  again, after bringing it home again if Avalon was restarted.
- **The shore: no question is asked, and a message appears at once**: the
  student answered `yes` earlier, perhaps before a restart, and their client
  trusts that server on that port. The hint in `~/avalon` covers it.
- **`ssh-keygen -Y sign` cannot load the key**: it was run on the server, where
  there is no private key. Hint: which machine holds `id_ed25519`?
