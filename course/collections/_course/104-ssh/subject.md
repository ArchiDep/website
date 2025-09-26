---
title: Secure Shell (SSH)
---

Learn about the SSH cryptographic network protocol and how to use the SSH command line tool to connect to other computers.

<!-- slide-include ../../BANNER.md -->

**You will need**

- A Unix CLI

**Recommended reading**

- [Command Line Introduction](../cli/)

## The `ssh` command

The `ssh` command is available on most Unix-like systems (e.g. Linux & macOS)
and in Unix shells on Windows (e.g. Git Bash or WSL). Its basic syntax is:

```
ssh [user@]hostname [command]
```

Here's a few examples:

- `ssh example.com` - Connect to the SSH server at `example.com` and log in
  (with the same username as in your current shell).
- `ssh jde@example.com` - Connect to the SSH server at `example.com` and log in
  as user `jde`.
- `ssh jde@192.168.50.4 hostname` - Run the `hostname` command as user `jde`
  on the SSH server at `192.168.50.4`.

Run `man ssh` to see available options (or just `ssh` in Git Bash).

## SSH known hosts

When you connect to an SSH server for the first time, you will most likely get a
message similar to this:

```bash
$> ssh example.com
The authenticity of host 'example.com (192.168.50.4)' can't be established.
ECDSA key fingerprint is SHA256:colYVucS/YU0JSK7woiLAf5ChPgJYAR1BWJlET2EwDI=
Are you sure you want to continue connecting (yes/no)?
```

What does this mean? _I thought SSH was **secure**?_

### Are you really the SSH server I'm looking for?

As we've seen, when SSH establishes a secure channel, a Diffie-Hellman
asymmetric key exchange will occur to agree on a secret symmetric encryption
key. To secure this exchange, the server will perform an asymmetric digital
signature so that no attacker can impersonate the server.

To verify the signature, **your SSH client will ask the server for its public
key**. **This is where a man-in-the-middle attack is possible.** SSH warns you
that someone is sending you a public key, but it has no way of verifying whether
it's actually the server's public key, or whether it's the public key of an
attacker performing a man-in-the-middle attack.

Basically, **SSH makes the following guarantee**:

- Once you have established a secure channel to a given server, no third party
  can decrypt your communications. Forward secrecy is also guaranteed in the
  event your credentials are compromised in the future.

**SSH does not guarantee** that:

- You are connecting to the correct server. You may be connecting to an
  attacker's server.

#### How can I solve this problem?

If you are using SSH to transmit sensitive data, **you should check that the
server's public key is the correct one before connecting.**

One way to do this is to use the **key fingerprint** that is shown to you when
first connecting. The key fingerprint is a [cryptographic hash][hash] of the
public key:

```bash
ECDSA key fingerprint is SHA256:colYVucS/YU0JSK7woiLAf5ChPgJYAR1BWJlET2EwDI=
```

Some services that allow you to connect over SSH, like GitHub, [publish their
SSH key fingerprints on their website][github-fingerprints] so that users may
check them. In other cases, the key may be physically transmitted to you, or
dictated over the phone.

You should **check that both fingerprints match** before proceeding with the
connection. If it does not, either you typed the wrong server address, or an
attacker may be trying to hack your connection.

### Known hosts file

If you accept the connection, SSH will save the server's address and public key
in its **known hosts file**. You can see the contents of this file with the
following command:

```bash
$> cat ~/.ssh/known_hosts
example.com,192.168.50.4 ecdsa-sha2-nistp256 eTJtK2wrRzhW5RQzUHprbFJa...
```

The format of each line in this file is `[domain],[ipaddr] algorithm pubkey`.

The line above means that when SSH connects to `example.com` at IP address
`192.168.50.4`, it expects the server to send this specific public key
(`eTJtK2wrRzhW5RQzUHprbFJa...`) using the [ECDSA][ecdsa] algorithm.

{% note type: more %}

ECDSA is another asymmetric algorithm like RSA, although ECDSA is based on
[elliptic curve cryptography][elliptic-curve] while RSA is based on prime
numbers.

{% endnote %}

#### Adding public keys to the known hosts file

Another solution to SSH man-in-the-middle attacks when first connecting is to
put the server's public key in the known hosts file yourself.

If you have previously obtained the server's public key (the full key, not just
the fingerprint), you can **add it to the known hosts file** before attempting
to connect.

If you do that, SSH will consider that the server is already a _known host_, and
will not prompt you to accept the public key.

#### Preventing future man-in-the-middle attacks

The known hosts file has another purpose. Once SSH knows to expect a specific
public key for a given domain or IP address, it will warn you if that public key
changes:

```
$> ssh 192.168.50.4
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ECDSA key sent by the remote host is
SHA256:FUwFoK/hcqRAvJgDFmljwOur8t/mhfbm4tfIxdaVTQ==.
Please contact your system administrator.
Add correct host key in /path/to/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /path/to/.ssh/known_hosts:33
ECDSA host key for 192.168.50.4 has changed and you have requested strict checking.
Host key verification failed.
```

As the message mentions, either the server changed its SSH key pair, or **an
attacker may be intercepting your communications**.

If you're sure it's not an attack, for example if you know the server actually
changed its key pair, you can eliminate this warning by putting the correct
public key in the known hosts file (or by removing the offending line).

## Password authentication

Establishing a secure channel is one thing, but that only ensures an attacker
cannot intercept communications. Once the channel is established, you must still
**authenticate**, i.e. **prove that you are in fact the user you are attempting
to log in as**.

How you authenticate depends on how the SSH server is configured. **Password
authentication** is one method. When enabled, the SSH server will prompt you for
the correct password; in this example, the password of the user named `jde` in
the server's user database:

```bash
$> ssh jde@192.168.50.4

The authenticity of host '192.168.50.4 (192.168.50.4)' can't be established.
ECDSA key fingerprint is SHA256:E4GYJCEoz+G5wv+EdkPyRLytgP7aTj9BS9lr1d38Xg==.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.50.4' (ECDSA) to the list of known hosts.

jde@192.168.50.4's password:
```

{% note type: tip %}

Most SSH clients will not display anything while you type your password. Simply
press `Enter` when you're done to submit it.

{% endnote %}

## Logging in with SSH

If you run the `ssh` command with no extra arguments and authenticate with your
password, **SSH will run the default [shell][shell]** configured for that user,
typically [Bash][bash] on Linux servers:

```bash
$> ssh jde@192.168.50.4
jde@192.168.50.4's password:
Welcome to Ubuntu 18.04.1 LTS (GNU/Linux 4.15.0-33-generic x86_64)

  System information as of Wed Oct 21 04:29:00 UTC 2015
  ...

$
```

{% note type: tip %}

Note that you may have a different command line prompt once you are connected,
in this example `$` instead of `$>`.

{% endnote %}

### Typing commands while connected through SSH

You are now **connected to a Bash shell running on the server**. Anything you
type is encrypted through SSH's secure channel and interpreted by that shell.
Any data that Bash outputs is also encrypted, sent back through the channel and
displayed in your terminal.

<p class='center'><img class='w90' src='images/ssh-channel-and-processes.jpg' /></p>

### Disconnecting

Disconnect with the command `exit` (or with `Ctrl-D` on Linux or macOS). You
should be back to the shell running on your local computer, with your usual
prompt:

```bash
$ exit
Connection to 192.168.50.4 closed.

$>
```

### Where am I?

Sometimes, you might forget what shell your terminal is connected to. Is it a
shell on your local machine or one running on the server?

If you're not sure, the `hostname` command may help you. It prints the network
name of the current machine:

```bash
$> hostname
MyComputer.local

$> ssh jde@192.168.50.4
jde@192.168.50.4's password:

$ hostname
example.com
```

In this example, the local computer is named `MyComputer.local`, while the
server is named `example.com`.

As you can see, the `hostname` command returns different results before and
after connecting to the server with SSH, because it's running on your local
machine the first time, but is running on the server the second time.

## Logging in or running a command

When you execute `ssh` with the `[command]` option, it will execute the command
and close the connection as soon as that command is done.

Run this from your local shell:

```bash
$> hostname
MyComputer.local

$> ssh jde@192.168.50.4 echo Hello World
Hello World

$> hostname
MyComputer.local
```

As you can see, you are still in your local shell.
The connection was closed as soon as the `echo` command completed.

## Public key authentication

Password authentication works, but it has some drawbacks:

- Attackers may try to [brute force][brute-force] your password.
- If an attacker succeeds in performing a man-in-the-middle attack (for example
  if you forget to check the public key the first time you connect), he may
  steal your password.
- If the server is compromised, an attacker may modify the SSH server to steal
  your password.

As explained earlier, SSH uses asymmetric cryptography (among other techniques)
to establish its secure channel. It's **also possible to use asymmetric
cryptography to authenticate**.

### How does it work?

If you have a **private-public key pair**, you can **give your public key to the
server**. Using **your private key**, your SSH client **can prove to the SSH
server that you are the owner of that public key**.

This has advantages over password authentication:

- It's virtually impossible to [brute-force][brute-force] (it is larger and
  probably has much more [entropy][entropy] than your password).
- Your private key will not be compromised by a man-in-the-middle attack or if
  the server is compromised, as it is never transmitted to the server, only used
  to solve mathematical problems based on the public key.

{% note type: warning %}

Note that **public key authentication is only as secure as the file containing
your private key**. If you publish that file anywhere or allow your local
machine to be compromised, the attacker will be able to impersonate you on any
server or service where you put your public key.

{% endnote %}

### How does public key authentication work?

To authenticate you, the server will need your **public key**. That way, you
will be able to prove, using your **private key**, that you are the owner of
that public key.

{% callout type: warning %}

Remember, **your private key MUST remain private** (i.e. the `id_ed25519` file).
You should **never** give it to any person, server or web service. Only give
your public key (i.e. the `id_ed25519.pub` file).

{% endcallout %}

### Using multiple keys

You may have multiple key pairs.

Some key pairs may have been generated by other programs or web services. For
example, some Git user interfaces generate a key pair to access GitHub, or
Amazon Web Services's Elastic Compute Cloud (EC2) generates key pairs to give
you access to their virtual machines.

Having multiple key pairs may be part of a security strategy to limit the access
an attacker might gain if one of them is compromised.

To generate a key with a custom name, use the `-f` (**f**ile) option when
generating the key with the `ssh-keygen` command. To use a specific key pair,
use the `ssh` command's `-i` (**i**dentity) option, which allows you to choose
the private key file you want to use:

```bash
$> ssh-keygen -f custom_key
$> ssh -i ~/.ssh/custom_key jde@192.168.50.4
```

{% note %}

It is the private key file you want to use with the `-i` option, not the public
key, as the private key is the one your SSH client will use to prove that it
owns the public key.

{% endnote %}

### Key management

A few tips on managing your key pairs:

- You may disseminate your **public key** freely to authenticate to other
  computers or services.
- **NEVER give your private key to anyone**.
- Conversely, you may copy your private key to another computer of yours if you
  want it to have the same access to other computers or services.
- **Back up your private and public key files** (`id_rsa` and `id_rsa.pub`) to
  avoid having to regenerate a pair if you lose your computer or switch to
  another computer. (If you create a new key pair, you will have to replace the
  old public key with the new one everywhere you used it.)
- Use [the `ssh-copy-id` command][ssh-copy-id] to copy your public key to other
  computers to use public key authentication instead of password authentication.

  _You will see how to do that in the SSH exercises._

- For web services using public key authentication (e.g. GitHub), you usually
  have to manually copy the public key file's contents (`id_rsa.pub`) and
  provide it to them in your account's settings.

### Key protection

It's good practice to [protect your private key with a
**passphrase**][ssh-passphrase]. You can enter a passphrase when generating
your key pair with the `ssh-keygen` command. You can also [add a passphrase to
an existing key][ssh-passphrase-add] later.

- **Without a passphrase, anyone who gains access to your computer has the
  potential to copy your private key.** For example, family members,
  coworkers, system administrators and hostile actors could gain access.
- The **downside** to using a passphrase is that **you need to enter it every
  time you use SSH**. You can temporarily cache your passphrase using
  [ssh-agent][ssh-agent] so you don't have to enter it every time you connect.

  <p class='center'><img class='w70' src='images/ssh-agent.png' /></p>

- **If a private key is compromised** (e.g. your computer is hacked or stolen),
  you should **remove the corresponding public key** from computers and web
  services you have copied it to.

## SSH for other network services

As mentioned initially, SSH is a network protocol. It can be used not only for
command line login, but to secure other network services.

A few examples are:

- [**S**ecure **C**o**p**y (`scp`)][scp] - A means of securely transferring
  computer files between a local and remote host.
- [rsync][rsync] - Utility for efficiently transferring and synchronizing files
  across computer systems.
- [SSH File Transfer Protocol (SFTP)][sftp] - Network protocol that provides
  file access, file transfer and file management.
- [Git][git] - Version control system that can use SSH (among other protocols)
  to transfer versioned data.

## The birth (or death) of an SSH connection

![The birth (or death) of an SSH connection](images/ssh-connection.png)

- [PDF version](./images/ssh-connection.pdf)
- [PNG version](./images/ssh-connection.png)

## References

- [How does SSH Work](https://www.hostinger.com/tutorials/ssh-tutorial-how-does-ssh-work)
- [Demystifying Symmetric and Asymmetric Methods of Encryption](https://www.cheapsslshop.com/blog/demystifying-symmetric-and-asymmetric-methods-of-encryption)
- [Understanding the SSH Encryption and Connection Process](https://www.digitalocean.com/community/tutorials/understanding-the-ssh-encryption-and-connection-process)
- [Diffie-Hellman Key Exchange][dh]
- [Simplest Explanation of the Math Behind Public Key Cryptography][pubkey-math]
- [SSH, The Secure Shell: The Definitive Guide](https://books.google.ch/books/about/SSH_The_Secure_Shell_The_Definitive_Guid.html?id=9FSaScltd-kC&redir_esc=y)
- [SSH Authentication Sequence and Key Files](https://serverfault.com/a/935667)

[aes]: https://en.wikipedia.org/wiki/Advanced_Encryption_Standard
[authorized_keys]: https://www.ssh.com/ssh/authorized_keys/openssh
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[brute-force]: https://en.wikipedia.org/wiki/Brute-force_attack
[ciphertext]: https://en.wikipedia.org/wiki/Ciphertext
[dh]: https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange
[discrete-logarithm]: https://en.wikipedia.org/wiki/Discrete_logarithm
[ecdsa]: https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm
[elliptic-curve]: https://en.wikipedia.org/wiki/Elliptic-curve_cryptography
[enigma]: https://en.wikipedia.org/wiki/Enigma_machine#Operation
[enigma-operating-shortcomings]: https://en.wikipedia.org/wiki/Cryptanalysis_of_the_Enigma#Operating_shortcomings
[entropy]: https://en.wikipedia.org/wiki/Password_strength#Entropy_as_a_measure_of_password_strength
[forward-secrecy]: https://en.wikipedia.org/wiki/Forward_secrecy
[github-fingerprints]: https://docs.github.com/en/github/authenticating-to-github/githubs-ssh-key-fingerprints
[git]: https://git-scm.com
[hash]: https://en.wikipedia.org/wiki/Cryptographic_hash_function
[hash-non-crypto]: https://en.wikipedia.org/wiki/Hash_function
[hmac]: https://en.wikipedia.org/wiki/HMAC
[hsm]: https://en.wikipedia.org/wiki/Hardware_security_module
[integer-factorization]: https://en.wikipedia.org/wiki/Integer_factorization
[key-exchange]: https://en.wikipedia.org/wiki/Key_exchange
[mac]: https://en.wikipedia.org/wiki/Message_authentication_code
[mitm]: https://en.wikipedia.org/wiki/Man-in-the-middle_attack
[openssl]: https://www.openssl.org
[pem]: https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail
[plaintext]: https://en.wikipedia.org/wiki/Plaintext
[pubkey]: https://en.wikipedia.org/wiki/Public-key_cryptography
[pubkey-math]: https://www.onebigfluke.com/2013/11/public-key-crypto-math-explained.html
[rsa]: https://en.wikipedia.org/wiki/RSA_(cryptosystem)
[rsync]: https://en.wikipedia.org/wiki/Rsync
[scp]: https://en.wikipedia.org/wiki/Secure_copy
[sftp]: https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol
[shell]: https://en.wikipedia.org/wiki/Shell_(computing)
[side-channel]: https://en.wikipedia.org/wiki/Cryptanalysis#Side-channel_attacks
[sneakers]: https://en.wikipedia.org/wiki/Sneakers_(1992_film)
[ssh-agent]: https://www.cyberciti.biz/faq/how-to-use-ssh-agent-for-authentication-on-linux-unix/
[ssh-copy-id]: https://www.ssh.com/academy/ssh/copy-id
[ssh-passphrase]: https://learn.microsoft.com/en-us/azure/devops/repos/git/gcm-ssh-passphrase?view=azure-devops
[ssh-passphrase-add]: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases
[symmetric-encryption]: https://en.wikipedia.org/wiki/Symmetric-key_algorithm
[syn-flood]: https://en.wikipedia.org/wiki/SYN_flood
