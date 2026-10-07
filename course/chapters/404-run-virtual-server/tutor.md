# Tutor notes: 404 Run your own virtual server on Microsoft Azure

## Starting point

- 401 Cloud Computing: the server is an IaaS virtual machine, rented with free
  student credits. When the student asks what they are renting, answer from
  401's notes.
- 104 Hello SSH: the student's key pair, `~/.ssh/id_ed25519` and its `.pub`, on
  their own computer. On Windows, it is in the WSL, and every command of the
  exercise is typed there, never in PowerShell.
- 103 Secure Shell (SSH): the fingerprint check on the first connection, which
  the optional "(Optionally) get your machine's public SSH key" applies to the
  new server.
- 402 Unix Basics: `sudo`, used here for the first time on a server where the
  student is an administrator, and "Inspecting volumes", behind the swap step.
- An `@hes-so.ch` e-mail address for Azure for Students.
- A domain assigned by the teacher, and a username the student confirms on the
  dashboard, before the exercise or in its second step. Once it is confirmed, a
  box on the page shows both, with the hostname made from them; after
  registration, it also shows the server's IP address and the `ssh` command. The
  tutor cannot see this box: ask the student what it says.

## Learning objectives

Renting a virtual machine from an IaaS provider and preparing it for the course:
choosing a size and a region within the credits, opening ports in the
provider's firewall, giving the server a public key instead of a password, then
working on it with `sudo`. The page's "What have I done?" is short: the steps
themselves are what the rest of the course needs.

Most of the page is a recipe. What is worth understanding is the reason behind
each step, and the "Tell me more" boxes give it: the firewall, the hostname, the
swap space and the host keys. Ask for those reasons rather than letting the
student copy commands.

Headings marked ❓ are optional. Skipping the fingerprint check teaches students
to answer `yes` without checking, which 103 warns against: encourage it, but do
not block the student on it.

Seen here, explained later: public and private IP addresses ("Unix
Networking"), ports ("Make TCP connections"), DNS and the assigned domain
("Domain Name System (DNS)"). Not in the course: the Azure portal beyond these
steps, the Azure CLI beyond the one command of the troubleshooting section,
configuring the SSH server, and memory management beyond what the swap box
says.

## Where it leads

Everything from "Unix Networking" onwards runs on this server: a student without
one cannot do any exercise after it. In particular:

- "Meet your server" comes right after, on the same server.
- Ports 3000 and 3001 are used by "Make TCP connections" and by the
  deployments that run an application on a port before it sits behind a
  reverse proxy. Ports 80 and 443 are used once nginx serves the sites.
- "Domain Name System (DNS)" and "Domain name configuration" point the assigned
  domain at the server's public IP address, the hostname chosen here.
- The swap space keeps the server from running out of memory when it compiles
  or runs several applications at once.
- The teacher's key lets the teacher log in to help, and the host keys given to
  the dashboard let it check that it connects to the student's real server.
- `~/.ssh/config`, if set up, works with every `ssh`, `scp` and Git command of
  the course.

## Key steps

- **"Apply to Azure for Students".** This is where students most often get
  stuck, and the tutor cannot see the portal. Ask the student to copy the exact
  message. A problem with the account itself is for the teacher.
- **"Choose or confirm your username for the course".** Only if the student has
  not confirmed one yet: the dashboard suggests a name to accept or change.
  After: the page's box shows the username, the domain and the hostname. Ask:
  where will you use this username? A change made after the server exists does
  not reach the server.
- **"Get your public SSH key".** Before: which of the two files does Azure
  need, and why is it safe to paste it into a website?
- **"Configure basic settings"**, with "I can't select the right size or
  region". Check the image (`Ubuntu 26.04`, x64) and the size (`B1s` or
  `B2ats_v2`) before going on. The regions allowed differ from one student to
  another.
- **"Configure your administrator account".** Ask: which username, and where
  does it come from? It must be the one the page's box shows, and Azure refuses
  some common names such as `admin` or `root`.
- **"Configure open ports".** Ask: what would happen to a web request on port
  80 without the rule? The answer is in the "Tell me more" box.
- **"Review your monthly cost".** Under $20 a month or $0.025 an hour. Above
  that, the size or the region is wrong: the student would run out of credits
  before the end of the course.
- **"Connect to your new virtual machine over SSH".** Before: why will `ssh` not
  ask for a password? After: the prompt shows the student's username on the new
  machine.
- **"Give the teacher access to your virtual machine".** Before: what does
  `--append` change? After: `cat ~/.ssh/authorized_keys` shows two lines, the
  student's key and the teacher's.
- **"Change the hostname of your virtual machine".** It is the hostname from the
  page's box. After the reboot, `hostname` prints it.
- **"Add swap space to your virtual server".** Before the `tee -a`: why is it
  `sudo tee` and not `sudo echo … >>`? (The shell opens the file, as the
  student, before `sudo` runs.) Before rebooting: `findmnt --verify` reports
  `0 parse errors, 0 errors`. After: `free -h` shows a `Swap` line of `2.0Gi`.
- **"Register your Azure VM with us".** Run on the server: three lines, each
  starting with a key type. Ask: why give the dashboard the public host keys,
  and never the private ones?
- **"Save typing with an SSH configuration file"** (optional). Ask: on which
  machine does this file go? After: `ssh archidep` logs in.

## Common pitfalls

- **Azure says the SSH public key is invalid**: the private key was pasted, or
  only part of the public one. Hint: which file ends in `.pub`? The key is one
  line, starting with `ssh-ed25519`.
- **`cat ~/.ssh/id_ed25519.pub` finds no file**: on Windows, the command ran in
  PowerShell instead of the WSL. Otherwise, the student has no key pair yet.
  Hint: where did you make your key pair in Hello SSH?
- **`Permission denied (publickey)` on the first connection**: the username
  differs from the one given to Azure, or the key given to Azure is not the one
  the student's SSH client offers (another computer, or PowerShell instead of
  the WSL). Hints: which username did you type in Azure? Then: which public key
  did you paste, and from which terminal?
- **The connection times out**: the IP address is wrong, port 22 was not
  allowed, or the virtual machine is stopped. Hint: compare the address with the
  one in the virtual machine's overview, and check that its status is running.
- **The student's own key no longer works after "Give the teacher access to your
  virtual machine"**: `--append` was left out, and `tee` replaced the student's
  key with the teacher's. If the student is still logged in, they can add their
  own key back to the file. If not, send them to the teacher, who can log in.
  Tell the student not to close the connection before checking.
- **`sudo` prints `unable to resolve host`** after the hostname changed: a
  warning that the server cannot find its new name. It does not stop the
  command.
- **`Permission denied` on `/etc/fstab`** with `sudo echo … >> /etc/fstab`: the
  redirection is done by the student's shell, which cannot write the file.
  Hint: compare with the page's command. Ask: which program writes to the file
  in each version?
- **`/etc/fstab` lost its other lines**: `-a` was left out of `tee`. **The
  student must not reboot**: the server may no longer start. Send them to the
  teacher.
- **`findmnt --verify` reports errors**, beyond the two warnings the page
  expects: do not reboot. Hint: compare the last line of `/etc/fstab` with the
  page's, character by character.
- **The server does not answer after `sudo reboot`**: it takes a couple of
  minutes. `Connection refused` or a timeout during that time is expected.
- **`ssh archidep` says `Could not resolve hostname archidep`**: the
  configuration file was written on the server instead of the student's
  computer, or has a typo in `Host`. Hint: what does `hostname` print in the
  terminal where you edited it?
- **The fingerprint does not match** any of the serial console's: the student
  may be comparing it with another key type's. Hint: which type does the
  warning name? If the ED25519 fingerprints really differ, the student should
  not connect: send them to the teacher.
