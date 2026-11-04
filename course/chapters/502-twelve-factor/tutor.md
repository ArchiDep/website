# Tutor notes: 502 The Twelve-Factor App

## Scope

A lead-in, not a subject: a two-paragraph page, with no slides, that names the
Twelve-Factor App as a methodology for building web applications that are easy
to deploy and to move between environments, and sends the student to the
official site, 12factor.net, for the factors themselves.

The course uses the methodology as the reason behind the fixes it makes to the
basic deployment, one factor at a time, in the exercises that apply them. Only
two factors are applied, each quoted by the exercise that applies it: Codebase
(the first) and Config (the third).

## Left out

Taught later: "Docker" points to the Processes factor (the sixth) as the
motivation for running containers without state. No other chapter names a
factor.

Not in the course: the other factors, their numbering beyond the two applied,
and the history of the methodology. Several later chapters do things that other
factors recommend, such as running several instances of an application, without
naming the factor.

## Key concepts and vocabulary

- **Codebase** (factor I): one codebase, tracked in version control, with many
  **deploys** of it. In the course, the codebase is the student's fork on
  GitHub; their computer and their server are two deploys, and neither is copied
  from the other.
- **Deploy**: a running instance of the application, such as the one on the
  student's computer or on their server.
- **Config** (factor III): everything that can change between deploys, such as
  the database password or port, kept strictly apart from the code, in
  environment variables.

## Misconceptions

- **Misconception:** the Twelve-Factor App is a set of rules every application
  must follow, or a standard.
  **Correction:** it is a methodology, a set of recommendations. The course
  uses two of its factors as the reasons for two of its fixes.
- **Misconception:** the copy on the student's computer is the codebase, and
  the server gets a copy of it.
  **Correction:** the codebase is the repository. Both copies are deploys made
  from it.
- **Misconception:** configuration means any setting in the code.
  **Correction:** only what changes between deploys is configuration. A setting
  that is the same everywhere, such as how the application talks to its
  database, stays in the code.

## Used in

The methodology is the justification of the first fixes to the basic deployment
rather than material of its own. The exercises that quote it:

- 501 Deploy a web application with Git applies Codebase: the server gets a
  clone of the fork instead of an upload.
- "Configure a web application through environment variables" applies Config:
  `server.js` reads `PORT` and `DATABASE_URL` from the environment, with no
  password in its code.
