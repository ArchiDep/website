# Tutor notes: 103 Secure Shell (SSH)

## Scope

The slides explain how SSH works; the subject page is about using it.

- Slides: SSH as a client-server protocol, "Same terminal, remote shell", the
  two steps ("How is it secure?"), then the cryptography behind them. Hello SSH
  relies on "Man-in-the-Middle attack on SSH", "One mechanism, both directions"
  and "Threats countered". The rest (symmetric and asymmetric encryption,
  Diffie-Hellman, forward secrecy, hashes and MACs) is background.
- Subject page: `ssh [user@]hostname [command]`; "SSH known hosts" (checking
  the fingerprint, pasting it at the prompt, `~/.ssh/known_hosts`, the "REMOTE
  HOST IDENTIFICATION HAS CHANGED" warning and `ssh-keygen -R`); password
  authentication; logging in, `exit`, `hostname`, running a single command;
  "Public key authentication" (the signature, `authorized_keys`, `-i` and `-f`,
  key management, passphrase, `ssh-agent`); SSH for `scp`, rsync, SFTP and Git.

Optional: the appendix "Cryptography with OpenSSL".

## Left out

Taught later:

- `~/.ssh/config`: "Run your own virtual server on Microsoft Azure".
- Git over SSH and GitHub's fingerprints: "Hello GitHub".
- How HTTPS proves a server's identity with certificates instead:
  "TLS/SSL Certificates".

Not in the course: configuring the SSH server, port forwarding, agent
forwarding, jump hosts, SSH certificates, and the mathematics beyond the colour
analogy and `(g^a)^b = (g^b)^a`.

## Key concepts and vocabulary

- **SSH client and server**: `ssh` is a local program. The server starts a
  shell for the user; commands typed then run on the server and their output
  comes back. `hostname` and `whoami` tell which machine a shell is on. Each
  machine has its own files, home directory and `PATH`.
- **Two separate steps**: the **secure channel**, then **authentication**
  (password or key).
- **Host key**: the server's key pair, in `/etc/ssh/ssh_host_*_key`. Its
  **key fingerprint** is a hash of the public key (`SHA256:...`).
- **Known hosts** (`~/.ssh/known_hosts`, on the client): the address and public
  key of each server accepted. The user decides once, on the first connection,
  by checking the fingerprint against a trusted source.
- **Man-in-the-middle attack**: what an unchecked fingerprint allows.
- **Key pair**: the private key `~/.ssh/id_ed25519` and the public key
  `~/.ssh/id_ed25519.pub`. **Authorized keys** (`~/.ssh/authorized_keys`, on the
  server): the public keys allowed to log in as that user.
- **Digital signature**, in both directions: the server signs the key exchange
  with its host key, the client signs data unique to the connection with the
  user's private key. Private keys never leave their machine; each signature is
  valid for one connection only.
- **Passphrase** protects the private key file; **`ssh-agent`** keeps it
  unlocked for a session.

## Misconceptions

- **Misconception:** key login works by the server encrypting a challenge with
  the public key.
  **Correction:** the course teaches it as a **signature**: the private key
  signs, the public key checks. Explain it that way, even though many
  explanations elsewhere do not.
- **Misconception:** the channel is encrypted, so this is the right server.
  **Correction:** encryption does not prove identity; only a checked
  fingerprint does.
- **Misconception:** the first-connection question and "REMOTE HOST
  IDENTIFICATION HAS CHANGED" are obstacles to get past.
  **Correction:** they are the one check SSH cannot do alone. `ssh-keygen -R`
  is for a key known to have changed legitimately, such as a server recreated
  at the same address.
- **Misconception:** "Host key verification failed" after answering `no` is an
  error.
  **Correction:** refusing an unknown key is the right outcome.
- **Misconception:** the private key is sent to the server, or the public key
  must be kept secret.
  **Correction:** it is the other way around.
- **Misconception:** only people with access to the computer can take an
  unprotected private key.
  **Correction:** any program running as the student can read it, AI agents
  included. A passphrase stops it being read; while `ssh-agent` holds it
  unlocked, such a program can still use it, but not copy it.
- **Misconception:** `ssh-copy-id` disables the password.
  **Correction:** it adds a way to log in; only the server's configuration can
  refuse passwords.
- **Misconception:** `-i`, or an SFTP application's key file, takes the `.pub`
  file.
  **Correction:** it takes the private key.

## Used in

Most of the course, from Hello SSH on: every exercise on a server is reached
with `ssh` and the key pair made there, and Git talks to GitHub over SSH. Parts
that exercises lean on in particular:

- Hello SSH plays all of the subject page, on the SSH exercise server.
- Hello GitHub checks a fingerprint against the ones GitHub publishes.
- "Run your own virtual server on Microsoft Azure" gives the public key to a
  server at its creation, which then accepts no password.
- "Deploy a PHP application with SFTP" uses an SFTP application with the
  private key.
