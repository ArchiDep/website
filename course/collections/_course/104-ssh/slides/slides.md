---
title: Secure Shell (SSH)
---

# Secure Shell (SSH)

Architecture & Deployment <!-- .element: class="subtitle" -->

---

## What is SSH?

SSH is a **cryptographic network protocol** for operating network services
**securely over an unsecured network**.

---

### What is it used for?

<div class="flex flex-col gap-4">
  <div class="flex justify-center items-center gap-2">
    <iconify-icon icon="fluent:window-text-24-regular" noobserver></iconify-icon> Command line login
  </div>
  <div class="flex justify-center items-center gap-2">
    <iconify-icon icon="cib:git" noobserver></iconify-icon> Git
  </div>
  <div class="flex justify-center items-center gap-2">
    <iconify-icon icon="fluent:folder-arrow-up-24-regular" noobserver></iconify-icon> FTP
  </div>
</div>

---

### How does it work?

SSH is a **client-server** protocol.

<pre class="mermaid">
architecture-beta
    service sshcl1(fluent:window-text-24-regular)[SSH Client]
    service sshcl2(fluent:window-text-24-regular)[SSH Client]
    service sshcl3(fluent:window-text-24-regular)[SSH Client]
    service sshsrv(fluent:server-24-regular)[SSH Server]

    sshcl1:R --> L:sshsrv
    sshcl2:L --> R:sshsrv
    sshcl3:R --> T:sshsrv

</pre>

**Notes:**

Using an SSH client, a user (or application) on machine A can connect to an SSH
server running on machine B, either to log in (with a command line shell) or to
execute programs.

---

### How is it secure?

1. SSH establishes a **secure channel**.
2. It then requires **authentication**.

**Notes:**

Note that steps 1 and 2 are **separate and unrelated processes**.

---

### Step 1: the secure channel

<div class="grid grid-cols-12">
  <div class="col-span-4 flex flex-col justify-center items-end">
    <div class="flex flex-col items-center">
      <iconify-icon icon="fluent:laptop-24-regular" noobserver width="160" height="160"></iconify-icon>
      <span class="text-3xl">SSH Client</span>
    </div>
  </div>
  <div class="col-span-4 flex flex-col justify-center items-center">
    <img src='images/ssh-secure-channel-establishment.png' width="250" />
  </div>
  <div class="col-span-4 flex flex-col justify-center items-start">
    <div class="flex flex-col items-center">
      <iconify-icon icon="fluent:server-24-regular" noobserver width="160" height="160"></iconify-icon>
      <span class="text-3xl">SSH Server</span>
    </div>
  </div>
</div>

_This is done for you and (mostly) automatic._

**Notes:**

SSH establishes a **secure channel** between client and server using various
**cryptographic techniques**. This is handled automatically by the SSH client
and server.

---

### Step 2: authentication

<div class="grid grid-cols-12">
  <div class="col-span-5">
    <div class="size-full flex flex-col justify-center items-end">
      <div class="chat chat-start">
        <div class="chat-header">1. SSH Client</div>
        <div class="chat-bubble chat-bubble-primary min-h-0 text-[1rem]">Hi, I'd like to log in as user "bob".</div>
      </div>
      <iconify-icon icon="fluent:laptop-24-regular" noobserver width="160" height="160"></iconify-icon>
      <div class="chat chat-start">
        <div class="chat-header">3. SSH Client</div>
        <div class="chat-bubble chat-bubble-info min-h-0 text-[1rem]">Here's bob's password.</div>
      </div>
    </div>
  </div>
  <div class="col-span-2">
    <div class="size-full flex justify-center items-center">
      <img src='images/ssh-secure-channel-establishment.png' width="250" class='opacity-65' />
    </div>
  </div>
  <div class="col-span-5">
    <div class="size-full flex flex-col justify-center items-start">
      <div class="chat chat-end">
        <div class="chat-header">2. SSH Server</div>
        <div class="chat-bubble chat-bubble-error min-h-0 text-[1rem]">Oh yeah? How do I know you're bob?</div>
      </div>
      <iconify-icon icon="fluent:server-24-regular" noobserver width="160" height="160"></iconify-icon>
      <div class="chat chat-end">
        <div class="chat-header">4. SSH Server</div>
        <div class="chat-bubble chat-bubble-success min-h-0 text-[1rem]">Go right ahead.</div>
      </div>
    </div>
  </div>
</div>

**Notes:**

The user or service that wants to connect to the SSH server must
**authenticate** to gain access, for example with a password.

---

### Security through cryptography

- [Symmetric encryption][symmetric-encryption]
- [Asymmetric cryptography][pubkey]
  - Key exchange
  - Digital signatures
- [Hash-based Message Authentication Codes (HMAC)][hmac]

**Notes:**

SSH establishes a **secure channel** between two computers **over an insecure
network** (e.g. a local network or the Internet). Establishing and using this
secure channel requires a combination of various cryptographic techniques.

---

### Symmetric encryption

![Symmetric Encryption](images/symmetric-encryption.png)

**Notes:**

[Symmetric-key algorithms][symmetric-encryption] can be used to encrypt
communications between two or more parties using a **shared secret**. [AES][aes]
is one such algorithm.

**Assuming all parties possess the secret key**, they can encrypt data, send it
over an insecure network, and decrypt it on the other side. An attacker who
intercepts the data **cannot decrypt it without the key** (unless a weakness is
found in the algorithm or [its implementation][enigma-operating-shortcomings]).

--v

#### Example: symmetric encryption with AES

```bash
# Create a "plaintext" file
$> cd /path/to/projects
$> mkdir aes-example
$> cd aes-example
$> echo 'too many secrets' > plaintext.txt
```

```bash
# Encrypt the plaintext
$> cat plaintext.txt | openssl aes-256-cbc > ciphertext.aes
enter aes-256-cbc encryption password:
Verifying - enter aes-256-cbc encryption password:
```

**Notes:**

Create a [**plaintext**][plaintext] file containing the words "too many
secrets".

You may encrypt that file with the [OpenSSL library][openssl] (installed on most
computers). Executing the example command pipeline will prompt you for an
encryption key.

--v

#### Example: symmetric decryption with AES

```bash
# Decrypt the ciphertext
$> cat ciphertext.aes | openssl aes-256-cbc -d
enter aes-256-cbc decryption password:
too many secrets
```

**Notes:**

The resulting [**ciphertext**][ciphertext] stored in the `ciphertext.aes` file
cannot be decrypted without the key. Executing the example command pipeline
and entering the same key as before when prompted will decrypt it.

The `-d` option makes the command **d**ecrypt the provided contents instead of
encrypting it.

---

### Symmetric encryption over an insecure network

- **Both parties must have the key**
- It used to be **physically transferred**

**Notes:**

For example in the form of the codebooks used to operate the German [Enigma
machine][enigma] during World War II. But that is **impractical for modern
computer networks**.

---

### Man-in-the-middle attack (MitM)

![Man-in-the-middle attack (MitM)](images/symmetric-encryption-insecure-network.png)

**Notes:**

**Sending the key over the insecure network risks it being
compromised** by a [Man-in-the-Middle attack][mitm].

---

### Asymmetric cryptography

<div class="grid grid-cols-3 gap-4">
  <div>
    <strong class="text-2xl">Encryption</strong>
    <img src='images/asymmetric-cryptography-encryption.png' />
  </div>
  <div>
    <strong class="text-2xl">Key exchange</strong>
    <img src='images/asymmetric-cryptography-key-exchange.png' />
  </div>
  <div>
    <strong class="text-2xl">Digital Signatures</strong>
    <img src='images/asymmetric-cryptography-signature.png' />
  </div>
</div>

**Notes:**

[Public-key or asymmetric cryptography][pubkey] is any cryptographic system that
uses pairs of keys: **public keys** which may be disseminated widely, while
**private keys** which are known only to the owner. It has several use cases:

- Encrypting and decrypting data.
- Securely exchanging shared secret keys.
- Verifying identity and protecting against tampering.

---

### The properties of an asymmetric key pair

- **Quick & easy to generate a key pair**
- **Too slow & hard to find the private key from the public key**
- The private key can solve mathematicalsproblems based on the public key,
  **proving ownership of that key** _(but not the other way around)_

**Notes:**

There is a mathematical relationship between a public and private key, based on
problems that currently admit no efficient solution such as [integer
factorization][integer-factorization], [discrete logarithm][discrete-logarithm]
and [elliptic curve][elliptic-curve] relationships.

Here's a [mathematical example][pubkey-math] based on integer factorization,
a problem that is computationally economical in one direction (multiplication)
but very computationally expensive in the other (factorization).

Effective security only requires keeping the private key private; **the public
key can be openly distributed without compromising security**.

---

### Asymmetric encryption

![Asymmetric encryption](images/asymmetric-encryption.png)

**Notes:**

One use case of asymmetric cryptography is **asymmetric encryption**, where the
**sender encrypts a message with the recipient's public key**. The message can
only be **decrypted by the recipient using the matching private key**.

--v

#### Example: generate an asymmetric RSA key pair

```bash
$> cd /path/to/projects
$> mkdir rsa-example
$> cd rsa-example

# Generate a private key
$> openssl genrsa -out private.pem 2048
Generating RSA private key, 2048 bit long modulus
.............++++++
.................................++++++
e is 65537 (0x10001)

# Generate public key from the private key (quick & easy)
$> openssl rsa -in private.pem \
   -out public.pem -outform PEM -pubout
writing RSA key
```

**Notes:**

Let's try encryption with [RSA][rsa] this time, an asymmetric algorithm. To do
that, we need to generate a **key pair, i.e. a private and public key**. The
example commands will generate first a private key in a file named
`private.pem`, then a corresponding public key in a file named `public.pem`.

By convention, we use the `.pem` extension after the [Privacy-Enhanced Mail
(PEM) format][pem], a de facto standard format to store cryptographic data.

--v

#### Example: asymmetric encryption with RSA

```bash
# Create a plaintext
$> echo 'too many secrets' > plaintext.txt

# Encrypt the plaintext with the public key
$> openssl pkeyutl -encrypt -in plaintext.txt \
   -inkey public.pem -pubin -out ciphertext.rsa

# See what's there
$> ls
ciphertext.rsa plaintext.txt private.pem public.pem
```

**Notes:**

You can create a plain text and **encrypt it with the public key** using the
OpenSSL library.

The example command will read the plaintext file `plaintext.txt` specified with
the `-in` (**in**put) option. It will also read the public key in the
`public.pem` file with the `-inkey` (**in**put **key**) and `-pubin` (**pub**lic
**in**) options.

It will then write the encrypted ciphertext to the `ciphertext.rsa` file with
the `-out` (**out**put) option.

In addition to your key pair, you should have two additional files containing
the plaintext and ciphertext:

--v

#### Example: asymmetric decryption with RSA

```bash
# Decrypt the ciphertext with the private key
$> openssl pkeyutl -decrypt \
   -inkey private.pem -in ciphertext.rsa
too many secrets

# It does not work with the public key
$> openssl pkeyutl -decrypt \
  -inkey public.pem -in ciphertext.rsa
unable to load Private Key [...]

# It does not work either with another private key
$> openssl genrsa -out hacker-private.pem 1024
$> openssl pkeyutl -decrypt \
   -inkey hacker-private.pem -in ciphertext.rsa
RSA operation error [...]
```

**Notes:**

The ciphertext can be **decrypted with the corresponding private key**. Note
that you **cannot decrypt the ciphertext using the public key**. Of course, a
hacker using **another private key cannot decrypt it either**.

Hence, you can encrypt data and send it to another party provided that you have
their public key. **No single shared key needs to be exchanged** (the private
key remains a secret known only to the recipient).

---

### Asymmetric encryption and forward secrecy

![Forward Secrecy](images/asymmetric-encryption-forward-secrecy.png)

**Notes:**

Asymmetric encryption protects data sent over an insecure network from
attackers, but **only as long as the private keys remain private**. It does not
provide **forward secrecy**, meaning that if the private keys are compromised in
the future, all data encrypted in the past is also compromised.

---

### Symmetric vs. asymmetric encryption

<table class="text-4xl">
  <thead>
    <tr>
      <th></th>
      <th>Pros</th>
      <th>Cons</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>Symmetric encryption</th>
      <td><strong class="text-success">Fast</strong>, can be implemented in <strong class="text-success">hardware</strong></td>
      <td><span class="text-error">Must send key, no forward secrecy</span></td>
    </tr>
    <tr>
      <th>Asymmetric encryption</th>
      <td><strong class="text-success">No shared key</strong></td>
      <td><span class="text-error">Slow, no forward secrecy</strong></td>
    </tr>
  </tbody>
</table>

**Notes:**

So far we learned that:

- Symmetric encryption works but provides no solution to the problem of securely
  transmitting the shared secret key.
- Asymmetric encryption works even better as it does not require a shared secret
  key, but it does not provide forward secrecy.

Additionally, it's important to note that **symmetric encryption is much faster
than asymmetric encryption**.

--v

### Symmetric encryption in hardware

![Hardware Security Module](images/hsm.jpg)

**Notes:**

Symmetric encryption is also less complex and can easily be implemented as
hardware (most modern processors support hardware-accelerated AES encryption).

This is a [hardware security module][hsm], a physical computing device that
safeguards and manages secrets, performs encryption and decryption functions for
digital signatures, strong authentication and other cryptographic functions

---

### What can we do?

It would be nice if we could share a **fast symmetric encryption key**...
without actually sharing it.

<img class='w100' src='images/asymmetric-cryptography-key-exchange.png' />

**Notes:**

<!-- slide-column -->

Ideally, we would want to be able to share a fast symmetric encryption key
without transmitting it physically or over the network. This is where asymmetric
cryptography comes to the rescue again. Encryption is not all it can do; it can
also do **key exchange**.

The [Diffie-Hellman Key Exchange][dh], invented in 1976 by Whitfield Diffie and
Martin Hellman, was one of the first public key exchange protocols allowing
users to **securely exchange secret keys** even if an attacker is monitoring the
communication channel.

---

#### Diffie-Hellman key exchange

<img src="images/dh.png" alt="Diffie-Hellman Key Exchange" class="w-1/3" />

**Notes:**

This conceptual diagram illustrates the general idea behind the protocol:

- Alice and Bob choose a **random, public starting color** (yellow) together.
- Then they each separately choose a **secret color known only to themselves**
  (orange and blue-green).
- Then they **mix their own secret color with the mutually shared color**
  (resulting in orange-tan and light-blue) and **publicly exchange** the two
  mixed colors.
- Finally, Alice and Bob **mix the color he or she received** from each other
  **with his or her own private color** (yellow-brown).

The result is a final color mixture that is **identical to the partner's final
color mixture**, and which was never shared publicly. When using large numbers
rather than colors, it would be computationally difficult for a third party to
determine the secret numbers.

---

### Man-in-the-Middle attack on Diffie-Hellman

![Man-in-the-Middle Attack on Diffie-Hellman](images/diffie-hellman-mitm.png)

**Notes:**

The Diffie-Hellman key exchange solves the problem of transmitting the shared
secret key over the network by computing it using asymmetric cryptography. It is
therefore never transmitted.

However, **a Man-in-the-Middle attack is still possible** if the attacker can
position himself between the two parties to **intercept and relay all
communications**.

---

### Asymmetric digital signature

![Digital Signatures with Asymmetric Cryptography](images/asymmetric-cryptography-signature.png)

**Notes:**

One of the other main uses of asymmetric cryptography is performing **digital
signatures**. A signature proves that the message came from a particular sender.

- Assuming **Alice wants to send a message to Bob**, she can **use her private
  key to create a digital signature based on the message**, and send both the
  message and the signature to Bob.
- Anyone with **Alice's public key can prove that Alice sent that message**
  (only the corresponding private key could have generated a valid signature for
  that message).
- **The message cannot be tampered with without detection**, as the digital
  signature will no longer be valid (since it based on both the private key and
  the message).

Note that a digital signature **does not provide confidentiality**. Although the
message is protected from tampering, it is **not encrypted**.

--v

#### Example: digital signature with RSA

```bash
# Create a message file
$> echo "Hello Bob, I like you" > message.txt

# Create a digital signature for
# that message with the private key
$> openssl dgst -sha256 -sign private.pem \
   -out signature.rsa message.txt

# See the signature (base64-encoded)
$> openssl base64 -in signature.rsa
```

**Notes:**

In the same directory as the previous example (asymmetric encryption with RSA),
create a `message.txt` file with the message that we want to digitally sign.

The example OpenSSL command will use the private key file `private.pem` (from
the previous example) and generate a digital signature based on the message file
`message.txt`. The signature will be stored in the file `signature.rsa`.

If you open the file, you can see that it's simply binary data. You can see it
base64-encoded with the second example command.

--v

#### Example: verifying a digital signature with RSA

```bash
$> openssl dgst -sha256 -verify public.pem \
   -signature signature.rsa message.txt
Verified OK

# Modify the message...

$> openssl dgst -sha256 -verify public.pem \
   -signature signature.rsa message.txt
Verification Failure
```

**Notes:**

The example command uses the public key to check that the signature is valid for
the message. If you modify the message file and run the command again, it will
detect that the digital signature no longer matches the message:

---

### Cryptographic hash functions & MACs

<img src="images/hash.png" alt="Cryptographic Hash Functions" class="w-1/2" />

**Notes:**

A [cryptographic hash function][hash] is a [hash function][hash-non-crypto] that
has the following properties:

- The same message always results in the same hash (deterministic).
- Computing the hash value of any message is quick.
- It is infeasible to generate a message from its hash value except by trying
  all possible messages (one-way).

- A small change to a message should change the hash value so extensively that
  the new hash value appears uncorrelated with the old hash value.
- It is infeasible to find two different messages with the same hash value
  (collisions).

SSH uses [Message Authentication Codes (MAC)][mac], which are based on
cryptographic hash functions, to protect both the data integrity and
authenticity of all messages sent through the secure channel.

---

### Combining it all together in SSH

![SSH Cryptography](images/ssh-crypto.png)

**Notes:**

SSH uses most of the previous cryptographic techniques we've seen together to
achieve as secure a channel as possible.

---

#### Man-in-the-Middle attack on SSH

![Man-in-the-Middle Attack on SSH](images/ssh-mitm.png)

---

#### Threats countered

- Eavesdropping
- Connection hijacking
- DNS an IP spoofing
- Man-in-the-Middle attack

<div class="mt-4 text-warning italic">
  As long as you <strong class="text-error screen:animate-pulse">check the public key</strong>!
</div>

**Notes:**

SSH counters the following threats:

- **Eavesdropping:** an attacker can intercept but not decrypt communications
  going through SSH's secure channel.
- **Connection hijacking:** an active attacker can hijack TCP connections due to
  a weakness in TCP. SSH's integrity checking detects this and shuts down the
  connection without using the corrupted data.
- **DNS and IP spoofing:** an attacker may hack your naming service to direct
  you to the wrong machine.
- **Man-in-the-Middle attack:** an attacker may intercept all traffic between
  you and the real target machine.

The last two are countered by the asymmetric digital signature performed by the
server on the DH key exchange, **as long as the client actually checks the
server-supplied public key**. Otherwise, there is no guarantee that the server
is genuine.

---

#### Threats not countered

- Password cracking <span class="text-xl italic">([common passwords](https://en.wikipedia.org/wiki/List_of_the_most_common_passwords): 123456, password, qwerty1)</span>
- IP/TCP denial of service
- Traffic analysis
- Carelessness and coffee spills <div class="inline-block ml-2 emoji-container size-10">:coffee:</div>
- Genius mathematicians <span class="text-xl italic">(did you see [Sneakers][sneakers]?)</span>

![Flawless Security](images/xkcd-security.png)

**Notes:**

SSH does not counter the following threats:

- **Password cracking:** if password authentication is enabled, a weak password
  might be easily brute-forced or obtained through [side-channel
  attacks][side-channel]. Consider using public key authentication instead to
  mitigate some of these risks.

- **IP/TCP denial of service:** since SSH operates on top of TCP, it is
  vulnerable to attacks against weaknesses in TCP and IP, such as [SYN
  flood][syn-flood].
- **Traffic analysis:** although the encrypted traffic cannot be read, an
  attacker can still glean a great deal of information by simply analyzing the
  amount of data, the source and target addresses, and the timing.
- **Carelessness and coffee spills:** SSH doesn't protect you if you write your
  password on a post-it note and paste it on your computer screen.
- **Genius mathematicians:** did you see [Sneakers][sneakers]?

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
