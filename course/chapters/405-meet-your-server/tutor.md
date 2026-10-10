# Tutor notes: 405 Meet your server

## Starting point

- 404 Run your own virtual server on Microsoft Azure, finished: the server
  exists, has its swap file, and the student logs in to it with their key. A
  student without a server cannot do this exercise.
- 402 Unix Basics: users, `sudo` and permissions, which the page links to.
  Those sections are the reference for them.
- 403 Unix Permissions: reading `ls -l` as owner, group and other. `/etc/shadow`
  was looked at there, so it is not repeated here.

## Learning objectives

Seeing what being the administrator of a server means: membership of the `sudo`
group, `sudo` without a password, files that only `root` can touch, accounts
that are services rather than people, and an address that is not the one the
student connects to. The page's "What have I done?" states what the student
should understand afterwards.

The exercise is short and changes nothing on the server. Most steps end on a
question, with the answer in a "Check your answer" box. Ask for the answer and
the reason behind it before the student opens the box.

Not in the exercise: the syntax of the sudoers file and `visudo`, which the page
only names; the fields of `/etc/passwd`, in the appendix of 402; reading
`htop`, which has no question; and how the cloud provider routes the public
address to the private one ("Unix Networking"). Giving the account a password
or changing the `sudo` configuration, which the page mentions for real
production servers, is not in the course either. A mistake there can cost the
student `sudo` on a server with no other administrator.

## Where it leads

The student administers this server for the rest of the course. In particular:

- "Unix Networking" takes up the question of "Which address is yours?": `ip
address`, and private and public addresses.
- Passwordless `sudo` is why the student's private key, and any terminal left
  logged in, are worth protecting. "The Image Gallery" shows what an attacker
  can do once they are on a server.
- System users come back whenever a service runs as its own user: `www-data`
  for nginx in "Deploy a static site with nginx", and a dedicated user to run an
  application in "Manage a PHP application with systemd as a Process Manager".
- `htop` comes back in "Unix Processes", among the commands that
  show running processes.

## Key steps

- **"Who are you?"** After: `id` lists the `sudo` group among others. The other
  groups do not matter. Ask: what does being in that group allow?
- **"List the home directory of `root`".** Before: what will each command do?
  After: the first is refused, the second lists `/root` without asking for a
  password. Ask: why could `sudo` not ask for a password here?
- **"Ask `sudo` what you may do".** After: `(ALL : ALL) ALL` and
  `(ALL) NOPASSWD: ALL`, after a few lines of defaults the page leaves out. Ask:
  who can become `root` on your server, and what do they need?
- **"Files only `root` can touch".** Ask the student to read each permission
  string as owner, group and other. Then ask why the swap file must stay
  private.
- **"The accounts of the server".** Ask: how do you tell a person from a
  service on each line? Why give each service its own user?
- **"What is running?"** Nothing to check. Ask what the student recognises, if
  anything.
- **"Which address is yours?"** Before: will the server know the address you
  connect to? After: an `inet` address under `eth0` that is not the public one.
  How the public address reaches the server is not answered here: it is the
  question "Unix Networking" takes up.

## Common pitfalls

- **`ip: command not found`, many unknown groups in `id`, or `sudo` asks for
  the password of the student's computer**: the commands ran on the student's
  own computer. Hint: what does `hostname` print?
- **`ls: cannot access '/swapfile': No such file or directory`**: the swap step
  of 404 was skipped or undone. Hint: what does `free -h` say about swap? Then:
  "Add swap space to your virtual server" in 404.
- **`sudo -l` shows more than the page**, such as a `Matching Defaults entries`
  paragraph first: expected, the page only shows the lines that matter.
- **More than one address besides `lo`**, for example an `inet6` line: the page
  only asks about the `inet` lines. Ask which one is not `127.0.0.1`.
