# Tutor notes: 513 TLS/SSL Certificates

## Scope

The subject page and the slides cover the same ground, mostly in the same
words. Each also holds something the other does not.

Both hold what a certificate is: a document binding one or more domain names,
possibly a wildcard, to a public key, signed by its issuer. A certificate is
public, and the private key that goes with it never leaves the server: the
server signs with it as with an SSH host key, but a certificate authority
vouches for the public key where SSH had the user check a fingerprint. Both give
a simplified HTTPS connection: agreeing on a cipher suite, a Diffie-Hellman key
exchange as in SSH, the server sending its certificate and signing the handshake
with its private key, the browser checking the certificate (name, dates, issuer)
and the signature, then symmetric encryption of the traffic.

Both then hold the chain of trust: an end-entity certificate signed by an
intermediate certificate authority, signed in turn by a self-signed root; the
server sending its certificate and the intermediates; root certificates being
trusted only because they are in the lists installed with browsers and operating
systems, under root programs and the rules of the CA/Browser Forum. Then
obtaining a certificate: domain validation by HTTP, DNS or email, paid
certificates (compatibility, warranty, Extended Validation, whose "green bar"
browsers dropped in 2019), the shrinking maximum lifetimes down to 47 days in
2029, Let's Encrypt and ACME, Certbot and its renewal timer, and TLS termination
at nginx.

Only the subject page holds the problem TLS solves (reading, modifying,
impersonating, with a man-in-the-middle diagram), the digital signature
diagram, Let's Encrypt's move from 90 to 45 days, and Certificate
Transparency logs, including that a name is public as soon as it gets a
certificate.

Only the slides hold the browser screenshots (a certificate, its chain, the
`NET::ERR_CERT_AUTHORITY_INVALID` error and its details), Let's Encrypt's six
principles, and one demonstration: generating a self-signed certificate with
`openssl req` into `/etc/ssl`, and the three nginx lines that serve a site with
it (`listen 443 ssl`, `ssl_certificate`, `ssl_certificate_key`), each option
explained in the notes. No exercise has students generate a self-signed
certificate.

## Left out

Taught later:

- Obtaining a certificate with Certbot, the nginx configuration it writes, the
  redirection from HTTP to HTTPS, and the renewal timer, hands-on: "Provision a
  TLS certificate with Certbot and Let's Encrypt".
- A platform obtaining and renewing certificates for the student: "Deploy static
  sites to Netlify" and "Deploy web applications with a database to Render".

Not in the course: the mathematics of RSA, Diffie-Hellman or any other
algorithm, beyond naming them; how a cipher suite is chosen; differences between
TLS versions; certificate signing requests; how revocation works; how ACME works
beyond its role; how Certificate Transparency logs work beyond their purpose;
TLS options in nginx beyond the three lines of the demo; SNI, HSTS, client
certificates and mutual TLS; and obtaining a wildcard certificate, which only
DNS validation allows.

## Key concepts and vocabulary

- **TLS** (Transport Layer Security): the protocol that encrypts the traffic and
  authenticates the server. **SSL**: its deprecated predecessor, whose name is
  still used for certificates.
- **HTTPS**: HTTP through a TLS connection, by default on port 443.
- **Man-in-the-middle attack**: someone between client and server reads,
  changes or answers in place of the server.
- **Public key certificate**: binds a name to a public key, signed by its
  **issuer**. A **TLS certificate** is one valid for domain names.
- **Wildcard certificate**: valid for every subdomain, such as `*.example.com`.
- **Private key**: the secret the server signs with; the certificate itself is
  public.
- **Digital signature**: made with a private key, checked with the matching
  public key.
- **Certificate authority (CA)**: an organization that issues certificates by
  signing them.
- **Chain of trust**: **end-entity certificate**, **intermediate
  certificate(s)**, **root certificate**.
- **Self-signed certificate**: signed with its own private key. Every root is
  one; so is one made with `openssl`.
- **Trusted root certificates**: the lists installed with browsers and operating
  systems; **root programs** decide what goes in them.
- **Domain validation**: proving control of a domain, by **HTTP validation** (a
  token at `/.well-known/acme-challenge/` on port 80), **DNS validation** (a
  `TXT` record) or **email validation**.
- **Extended Validation (EV)**: a certificate for which the CA also checked the
  legal identity of the organization.
- **Let's Encrypt**: a free, automatic CA. **ACME**: the open protocol a program
  uses to obtain and renew certificates from it. **Certbot**: one such program.
- **Certificate Transparency**: public logs of every certificate issued.
- **TLS termination**: the reverse proxy is the end of the TLS connection, and
  forwards plain HTTP to the application.

## Misconceptions

- **Misconception:** the certificate must be kept secret, and whoever copies it
  can impersonate the site.
  **Correction:** the certificate is public; the server sends it to every
  client. The private key is the secret. A copied certificate is useless without
  it, since the attacker cannot sign the handshake.
  Question that reveals it: "Your browser downloaded `example.com`'s certificate
  a minute ago. Why can't you use it to pretend to be `example.com`?"
- **Misconception:** the traffic is encrypted with the public key in the
  certificate.
  **Correction:** in the course's model, the traffic is encrypted with a shared
  key agreed by a Diffie-Hellman exchange, which never travels. The certificate's
  key pair is used to sign the handshake and check that signature.
- **Misconception:** a self-signed certificate does not encrypt, or encrypts
  less well.
  **Correction:** it encrypts like any other. It is refused only because nobody
  trusted vouches for it, so the browser cannot tell it from an attacker's.
- **Misconception:** a root certificate is technically special.
  **Correction:** it is self-signed, like one made with `openssl`. It is trusted
  only because it is in the list installed with the browser or operating system.
- **Misconception:** the certificate authority checks who you are.
  **Correction:** domain validation proves only control of the domain, which is
  all a browser needs. Only Extended Validation checks a legal identity, and
  browsers no longer show it.
- **Misconception:** a paid or EV certificate is more secure than one from Let's
  Encrypt.
  **Correction:** all encrypt the same way. Paying buys compatibility with older
  clients, a warranty, or an identity check.
- **Misconception:** the certificate authority creates the private key and sends
  it with the certificate.
  **Correction:** the key pair is generated on the server, and the private key
  never leaves it. The CA only signs a certificate for the public key.
- **Misconception:** the browser asks the certificate authority about each
  certificate, every time it connects.
  **Correction:** in the course's model, the server sends its certificate and
  the intermediates, and the browser checks the chain up to a root it already
  has.
- **Misconception:** TLS and SSH secure a connection in different ways.
  **Correction:** both have the server sign with its private key and the client
  check with the public key. They differ in how the client knows the public key
  is the right one: in SSH, the user checks a fingerprint; in TLS, a CA vouches
  for it.
  Question that reveals it: "When you first connected to your server with SSH,
  what did you do that your browser cannot do for every site?"
- **Misconception:** with HTTPS, the traffic is encrypted all the way to the
  application.
  **Correction:** behind a reverse proxy, TLS ends at nginx, which forwards plain
  HTTP over the loopback address. The application does not change.
- **Misconception:** a wildcard certificate can be obtained by HTTP validation,
  like any other.
  **Correction:** only DNS validation proves control of every name under a
  domain.

## Used in

Every site of the student's server served over HTTPS from here on relies on this
subject, and on nginx terminating TLS. In particular:

- "Provision a TLS certificate with Certbot and Let's Encrypt" obtains a
  certificate by HTTP validation, has nginx use it, and looks at the private
  key's permissions and the renewal timer.
- "Deploy static sites to Netlify" and "Deploy web applications with a database
  to Render" have the platform obtain Let's Encrypt certificates for the
  student.
