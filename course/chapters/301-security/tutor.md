# Tutor notes: 301 Security

## Scope

The subject page is short on purpose: the subject is taught in the room.

- Subject page: OWASP, and the OWASP Top 10, which it links to.
- In the room: an introduction to OWASP, then a security analysis of Guess It,
  done by the Guess It groups on their own copy of the application, then a
  demonstration of what they were meant to find, and how it is fixed.

The students' copy of Guess It is the one from 205, running on their own
computer. What the analysis is meant to find is not written here, so that these
notes give nothing away. "The security analysis" below has the hints.

## Left out

Taught later:

- How a permissions problem on a server can be exploited: "The Image Gallery".
- Encrypting the traffic between a browser and a server, and proving the
  server's identity: "TLS/SSL Certificates".

Not in the course: penetration testing tools and scanners, security audits,
authentication and session design, and the details of each Top 10 category
beyond what a student needs to recognise it.

## Key concepts and vocabulary

- **OWASP**, the Open Worldwide Application Security Project: a nonprofit
  foundation whose projects, tools and documents about application security are
  free and open to anyone.
- **The OWASP Top 10**: an awareness document for developers, a broad consensus
  about the most critical security risks to web applications. It is revised
  every few years: use the current edition on owasp.org, which the page links
  to, rather than a list from memory.
- **Vulnerability**: a weakness in an application that someone can use to make
  it do what its developers did not intend. **Exploiting** it is doing so.
- **The attacker's view**: an application receives whatever is sent to it, not
  only what its own pages would send. Anything that comes from a visitor is
  under the visitor's control.

## Misconceptions

- **Misconception:** a small application, or a student project, is not worth
  attacking.
  **Correction:** much of the attacking on the Internet is automated, and scans
  every address it can reach. An application on a public server is found
  without anyone looking for it.
- **Misconception:** HTTPS makes an application secure.
  **Correction:** it protects the traffic on its way. A flaw in the
  application itself is just as exploitable over HTTPS.
- **Misconception:** the OWASP Top 10 is a complete checklist, or a standard to
  comply with.
  **Correction:** it is an awareness document about the most critical risks.
  An application can avoid all ten and still be vulnerable.
- **Misconception:** finding a vulnerability takes special tools or expert
  skills.
  **Correction:** many are found by reading the code with the attacker's view in
  mind, and by trying what a careful developer did not expect.

## The security analysis

In the room, the groups search their own Guess It for vulnerabilities, before
the teacher demonstrates them. Which vulnerabilities it has, and where, is the
answer to the analysis. These notes do not hold it, and neither does any page
of the course before the demonstration.

Hints for the search, from the most general:

- Which categories of the OWASP Top 10 could apply to an application like this
  one? Each category's description says what to look for.
- What can a visitor send to the application? Every way in: each form, each
  field, each part of a URL.
- Where does each of them go in `server.js`? What does the application do with
  it, and where does it end up?
- Could what a visitor sends change what the application does, rather than only
  being a value it stores or compares?
- What happens with input the developer did not expect: empty, very long, or
  full of special characters?

A student who thinks they have found one can test it with three questions: what
exactly would an attacker send, what would the application do with it, and who
would be harmed?

The analysis is done on the student's own copy, on their own computer.
Attacking a classmate's application, a deployed one, or any system the student
does not own is outside the exercise. A test that damages data loses only the
student's own games.

## Used in

Security comes back throughout the course, wherever a server is exposed to the
Internet. In particular:

- "Meet your server" shows that whoever can log in as the student can become
  `root` on their server, without a password.
- "The Image Gallery" demonstrates how far a permissions problem on a server
  can be exploited.
- "TLS/SSL Certificates" and "Provision an SSL certificate using Certbot by
  Let's Encrypt" protect the traffic between browsers and the student's server.
