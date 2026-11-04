# Tutor notes: 504 Configure a web application through environment variables

## Starting point

- 501 Deploy a web application with Git: the clone of the student's fork in
  `/srv/guessit`, with its dependencies installed, and possibly an uncommitted
  change to the password in `server.js`.
- 410 Deploy a web application with SFTP: `~/guessit-ex` on the server, whose
  `server.js` holds the database password; and the clone on the student's
  computer, where they may have left the password uncommitted in `schema.sql`.
- 503 Unix Environment Variables: setting a variable for one command, shell
  variables against environment variables, inheritance, and `process.env` in
  Node.js. 502 The Twelve-Factor App: the page quotes its third factor, Config.
- 202 Hello Git and 204 Hello GitHub: committing only some files, and pushing.

Part of the exercise is done on the student's computer, the rest on the server.

## Learning objectives

Separating configuration from code: `server.js` reads `PORT` and `DATABASE_URL`
from the environment, with defaults that hold no secret, so that the same commit
runs on every deploy and the server's clone has no local change. The page's
"What have I done?" states what the student should understand afterwards.

The student writes the code change themselves, from the example given for
`PORT`. The page withholds the solution until the class has covered the
exercise, so a student working on it does not have it. The `||` operator is
explained in a "more" note; how `node-postgres` parses the URL is not in the
exercise.

The deployment is still incomplete on purpose. The configuration is now typed in
front of `npm run dev` every time, and the shell keeps it in its history,
password included; the page names this problem and stops there. The application
still runs in development mode, by hand, under the student's account, and stops
when they log out.

Not in the exercise: `export` and `.bashrc` for the application's configuration,
`.env` files and the libraries that read them, validating the configuration at
startup, `git stash`, and a password with special characters in a URL.

The architecture diagram is 410's, unchanged: only where Guess It gets its
configuration from differs.

## Where it leads

Every later deployment of an application configures it through the environment.
In particular:

- "Manage a web application with systemd as a Process Manager" moves
  `DATABASE_URL` from the command line into `/etc/guessit/guessit.env`, a file
  only `root` can read, which systemd reads with `EnvironmentFile`. It fixes the
  password left in the shell's history.
- "Platform-as-a-Service (PaaS)" and the deployments to hosting platforms set
  the variables in a web interface instead of on a server.

## Key steps

- **"Stop the Git deployment"**. Only needed if Guess It still runs.
- **"Update the configuration"**, on the student's computer.
  Expected after: both constants read `process.env`, the default
  `DATABASE_URL` has no password, and the comments no longer say to change the
  password in the file.
  Question after: "Why may `PORT` have a default, but not the password?"
- **"Update the README"**. Setup step 2 replaced with the text the page gives.
- **"Commit and push your changes"**.
  Expected: `git diff` shows only `server.js` and `README.md` changed by this
  exercise, with no password in either; a commit pushed to the student's fork.
  Sample question: which files did you leave out of the commit, and why?
- **"Pull the latest version on the server"**.
  Expected after: `git pull origin main` prints `Fast-forward` with
  `README.md` and `server.js`, and `git status` says
  `nothing to commit, working tree clean`.
  Question after: "Why did the change to `server.js` have to go before the
  pull?" (The new commit changes `server.js` too, and Git does not throw away
  a change that is not committed.)
- **"Optional: run the application without its configuration"**. The page asks
  why the application could not connect, answered in a solution box shown from
  the start. Expected: Guess It starts and listens, and the home page says the
  leaderboard could not be loaded, with `client password must be a string` in
  the terminal.
- **"Run the application"**.
  Expected: the leaderboard of the earlier deployments, and no error in the
  terminal.
  Question after: "You gave the variable to `npm`. How did `server.js` get
  it?" (Each process gets a copy of its parent's environment.)
  Question after: "Where is the password now, on your server?" (In
  `~/guessit-ex/server.js`, and in the shell's history.)

## Common pitfalls

- **`git push` from the computer is rejected, or the pull on the server brings
  nothing**: the clone on the computer, or the one on the server, is not of the
  student's own fork. Hint: compare what `git remote -v` prints on the computer
  and on the server.
- **The student commits `schema.sql`, or `git add .`, with a password in it**:
  the page says to commit only the two files. Unpushed, the commit can still be
  undone; once pushed, the password is in the public fork's history. Hint: what
  does `git show --stat` list?
- **The default `DATABASE_URL` still has the password, or `change-me-now`**:
  the password was left in the code when the line was rewritten. Hint: what
  would someone reading your fork on GitHub learn from that line?
- **`git pull` says `Your local changes to the following files would be
overwritten by merge: server.js`**: `git restore server.js` was skipped. The
  "more" note under "Pull the latest version on the server" says why Git
  refuses.
- **The optional step's error does not appear, and Guess It works without any
  variable**: the application runs from `~/guessit-ex`, whose `server.js` still
  has the password, instead of `/srv/guessit`. Hint: what does `pwd` print?
- **Guess It works without any variable, from `/srv/guessit`**: the pull did
  not bring the new `server.js`, or `git restore` was skipped and the old
  password is still in it. Hint: what does `git log -1` print, and `git
status`?
