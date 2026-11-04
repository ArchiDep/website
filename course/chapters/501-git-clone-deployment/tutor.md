# Tutor notes: 501 Deploy a web application with Git

## Starting point

- 410 Deploy a web application with SFTP, finished: Node.js and PostgreSQL
  installed on the server, the `guessit` database and database user created with
  `schema.sql`, and `~/guessit-ex` uploaded from the student's computer. The
  `DATABASE_URL` in `~/guessit-ex/server.js` holds the only copy on the server
  of the database password, which this exercise copies.
- 410's first step: a fork of Guess It under the student's own GitHub account,
  with the fixed queries. That fork is what is cloned here.
- "How to improve our basic deployment": the flaws of the SFTP deployment. This
  exercise fixes the first one, the manual upload.
- 502 The Twelve-Factor App: the page quotes its first factor, Codebase.
- 403 Permissions: reading `ls -ld`, and `chown`. 202 Hello Git and 204 Hello
  GitHub: `git clone`, `git status` and `git diff`.

## Learning objectives

What is deployed becomes a commit of the codebase instead of a copy of a
directory, the dependencies are installed on the server from `package-lock.json`
rather than uploaded, and the deployment lives in `/srv`, owned by the student,
rather than in their home directory. The page's "What have I done?" states what
the student should understand afterwards.

The deployment is still incomplete on purpose. The password is edited into
`server.js` on the server and left uncommitted, so Git sees it as a change to
the code, which gets in the way of a later `git pull`; the application still
runs in development mode, by hand, under the student's own account. The page
names the uncommitted change as a problem and stops there: the following
exercises fix each of these.

`Ctrl-C` appears in a tip, as a way to stop the command running in the terminal,
without explanation. What it does is explained in 505.

Not in the exercise: `git pull`, which comes in the next exercise; cloning over
SSH, which a "more" callout explains is not needed for a public repository; `npm
audit` and the vulnerabilities npm reports; the Filesystem Hierarchy Standard
beyond `/srv` being where a server keeps what it serves; and why the home
directory is closed to other users (`drwxr-x---`), which is Ubuntu's default.

The architecture diagram is 410's, unchanged: only the directory Guess It runs
from differs.

## Where it leads

Every later exercise on Guess It works on this clone in `/srv/guessit`:

- "Configure a web application through environment variables" discards the
  uncommitted change to `server.js` with `git restore`, then updates the clone
  with `git pull`, after a commit the student pushes from their computer. It
  reads the password from `~/guessit-ex/server.js` again.
- "Manage a web application with systemd as a Process Manager" gives
  `/srv/guessit` to the `guessit` group and closes it to other users, which is
  why it is in `/srv` and owned by the student, and runs the application from it
  with `WorkingDirectory`.
- "Set up an automated deployment with Git hooks" deploys with `git push` to a
  repository on the server instead of cloning and pulling by hand.

## Key steps

- **"Optional: find your way around your server again"**. Expected: the files of
  `~/guessit-ex`, `node_modules` included; `v26.x.y` from `node -v`; PostgreSQL
  on `127.0.0.1:5432` and nothing on port 3000; a count of games from `psql`,
  possibly `0`.
  Sample question: why is Guess It no longer running?
- **"Stop the SFTP deployment"**. Only needed if the optional step started it
  again.
- **"Create the deployment directory"**.
  Question before: "Why can't you run `mkdir /srv/guessit` without `sudo`?"
  Expected after: `ls -ld /srv/guessit` shows the student's username twice, as
  owner and group.
  Question after: "What would change if you cloned with `sudo`?" (The files
  would be `root`'s, and every update would need `sudo`.)
- **"Clone the repository"**. The URL is the student's fork, over HTTPS.
  Expected after: `ls -a` lists `.git` and `.gitignore` and no `node_modules`.
  Sample question: why is there no `node_modules`?
- **"Install the dependencies"**. `npm ci`, as the student, in `/srv/guessit`.
  Expected: `added 83 packages`, possibly followed by a vulnerability report
  that the page says to leave alone.
  Question after: "Your server downloaded the packages itself. How did it know
  which versions to install?"
- **"Optional: compare with the SFTP deployment"**. The same count in both
  `node_modules`.
- **"Update the configuration"**. The clone's `DATABASE_URL` has the fork's
  password, `change-me-now` unless the student committed another. Only a
  different password needs editing. Sample question: why must this change not
  be committed?
- **"Optional: see what Git sees"**. Only if `server.js` was edited:
  `git status` lists it as modified.
- **"Run the application"**. Expected: the home page at the server's IP address
  and port 3000, with the games won on the SFTP deployment on the leaderboard.
  Question after: "You replaced the application's files. Why are the old games
  still there?"

## Common pitfalls

- **`git clone` says `could not create work tree dir '/srv/guessit'`**: the
  directory was not created first, so Git tried to create it in `/srv`, where
  only `root` may write. Hint: what does `ls -ld /srv/guessit` show?
- **`git clone` asks for a username and password**: the URL is mistyped, or
  points to a repository that is private or does not exist, and GitHub asks for
  credentials rather than saying so. Hint: open the same URL, without `.git`, in
  a browser.
- **The clone is of `ArchiDep/guessit-ex`, or of a groupmate's fork**: the
  deployment works today, but the next exercise pulls a commit the student
  pushes to their own fork, which this clone does not track. Hint: what does
  `git remote -v` print in `/srv/guessit`?
- **The student runs `npm run dev` from their home directory, or from
  `~/guessit-ex`**: the SFTP deployment runs instead, with its own `server.js`.
  Hint: what does `pwd` print?
- **`npm ci` fails with `EACCES`, or `git status` says `dubious ownership`**: a
  command was run with `sudo`, and some of the files belong to `root`. Hint:
  who owns the files that `ls -la /srv/guessit` lists?
- **The student commits the password, or wants to**: the page warns against it.
  A commit already made can stay unpushed; once pushed, the password is in the
  public fork's history, and changing the password of the `guessit` database
  user is the real fix, which the course does not cover.
