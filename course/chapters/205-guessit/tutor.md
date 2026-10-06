# Tutor notes: 205 Guess It

## Starting point

- 204 Hello GitHub, or at least its steps from "Form your group" to "Everyone:
  clone the fork", which the page lists. The student needs a clone of the
  group's fork that they can push from. 203's notes are the reference for
  pushing and pulling.
- 202 Hello Git: the identity set in "Who are you?" is the name each member's
  commit must carry. The repository's `.gitignore` keeps `node_modules` out, as
  in 202.
- A Unix shell, as in 101. On Windows, everything runs in the WSL: Node.js,
  PostgreSQL, the clone and `npm`. Only the browser is on the Windows side.
- A PostgreSQL server may already be installed on the student's computer, from
  an earlier database course. "Check what you already have" decides what to do
  with it: ask for its outputs before anything is installed.
- Placeholders: `jde` in error messages is the student's own username, and
  `postgresql@17` stands for the version `brew list` printed.

## Learning objectives

An application needs more than its code: a runtime (Node.js); dependencies
installed from the repository's list into a directory Git ignores (`npm ci`);
and a database server, a program of its own, which the application reaches as a
client, through a port, with a connection URL, as a user that owns its database
and nothing else. Then the group shares its work through its fork, with no
script. The page's "What have I done?" states what the student should understand
afterwards. Its "Architecture" diagram is an image the tutor cannot see. It
draws the browser, the application on port 3000 and PostgreSQL on port 5432, all
on the student's computer.

The exercise is not about SQL, or about the code of `server.js`. The three
queries are on the page, in boxes the student can open at any time. Writing one
first is practice the student may choose, and the page's query is the check:
help them compare the two rather than propose another way of writing it. Leave
the rest of `server.js` as it is, and do not review it or suggest changes to it:
later chapters work from this code as the page gives it.

Used as recipes, taught later: `sudo` ("Unix Basics"), ports and `nc` ("Unix
Networking", "Make TCP connections"), and a program that holds the terminal
until `Ctrl-C` ("Unix Streams and Pipelines"). Not in the course: PostgreSQL
administration beyond the page (its authentication settings, other roles),
pgAdmin and other graphical clients, Express, and npm beyond `npm ci` and `npm
run dev`.

## Where it leads

The application and the group's fork stay with the student: later, each member
makes a fork of their own from the group's and deploys it. A group whose
application does not work by then is given a working version, as the page says.
In particular:

- Every deployment builds on a server the chain this exercise builds on the
  student's computer: the runtime, the dependencies installed there, a database
  server, a user of the application's own and the connection URL. Knowing which
  program is the client of which is what the deployments rely on.
- The architecture diagram is the first of those the deployment exercises draw,
  with more processes each time.

## Key steps

- **"Get your group's repository".** After: `git remote -v` shows the group's
  fork, under its owner's username, with a `git@github.com:` URL.
- **"Install Node.js".** After: `node --version` prints `v22` or newer, in the
  terminal where the application will run. Ask, on Windows: which terminal is
  that?
- **"Check what you already have".** A diagnosis: ask for the outputs, and for
  the row of the table they lead to, before any install. Ask: what does
  `succeeded!` tell you, and what does it not tell you? (Something listens on
  5432, but not which server.)
- **"Connect as a superuser".** After: `server_version` is 14 or newer.
- **"Create the database".** Before: has the password in `schema.sql` been
  changed? The file only works once. After: `CREATE ROLE`, `CREATE DATABASE`,
  `You are now connected to database "guessit" as user "postgres".` (another
  user than `postgres` with Postgres.app or Homebrew), `CREATE TABLE`, `ALTER
TABLE`. Ask: why does the application get a user of its own, rather than
  connecting as the superuser?
- **"Configure and start the application".** After: `Guess It is listening on
http://localhost:3000`, and the home page says `No games won yet. Be the first!`
  and `0 games played in total`. With the notice instead, the error below `Could
  not load the leaderboard` in the terminal says why. Ask: which program is a
  server, and which is its client? What does each part of `DATABASE_URL` say?
- **"Implement the missing queries".** A missing query fails silently, not with
  an error. Before any is implemented, the game starts and answers "Higher!" or
  "Lower!", which the server works out without the database; `You've made 0
guesses` never changes; the right number shows no message at all; and giving up
  goes back to the home page without deleting the game. Once each query works:
  - The guess: the count goes up, and the right number shows `you found it in N
tries!`.
  - The leaderboard: the won games, with their tries. It can only be checked
    once a game has been won, which needs the guess query in the student's own
    copy.
  - Giving up: `games played in total` on the home page goes down by one.

  Before the commit, ask whose name it will carry. After pushing, and once the
  others have pulled, `git log` in every member's clone shows each member's
  commit under their own name.

## Common pitfalls

- **The leaderboard notice comes back after writing the leaderboard query**: the
  notice is shown for any error, and this one is in the query, not the
  connection. The terminal shows a PostgreSQL error below `Could not load the
leaderboard`, such as `column "attemps" does not exist`. Hint: is the error
  about reaching the database, or about the query? Then compare it with the
  page's query.
- **A guess or giving up shows a page with only an `error: …` line**: the
  PostgreSQL error of the query just written, also in the terminal. The rest of
  the application still works. Same hints.
- **`column "…" does not exist`, naming a long random string**: the game's ID
  was put in the query without the quotes around it, so PostgreSQL reads it as a
  column name. Hint: compare with the page's query.
- **Nothing changes, and there is no error**, after writing the guess or give-up
  query: the query is written between `'` or `"` rather than backticks, so
  PostgreSQL receives `${game.id}` as it is, which matches no game. Hint:
  compare the quotes around your query with the page's.
- **The leaderboard stays empty although its query is right**: no game has been
  won in the student's own database. Winning needs the guess query, and each
  member has a database of their own: the code is shared through GitHub, the
  games are not. Hint: which query records a win, and is it in your copy yet?
- **`sudo` asks for a password the student does not know** (the WSL): it is the
  password of their Linux user, chosen when the WSL was installed, and nothing
  appears as they type it. A forgotten one is reset from PowerShell with `wsl -u
root passwd <username>`.
- **`node --version` prints a version older than 22, or `npm` is not found**:
  Node.js was installed with `sudo apt install nodejs`, which gives Ubuntu's
  older version, without `npm`. Hint: which instructions did you follow? Then:
  the download page's. After an install with nvm, open a new terminal.
- **Windows: `which node` prints a path under `/mnt/c`**: the WSL is finding the
  Node.js installed on Windows. Then: install Node.js in the WSL, as the page
  says.
- **`Error: listen EADDRINUSE: address already in use :::3000`**: the
  application is already running in another terminal, perhaps since the optional
  step of 204, or another project uses port 3000. Ask: what else could be
  listening on port 3000? Only one program can listen on a port, as with
  PostgreSQL's 5432.
- **`npm ci` fails with `npm error code EUSAGE`, or `npm run dev` with `npm
error code ENOENT`** about `package.json`: the command was run outside the
  clone. Hint: `pwd`.
- **`git status` lists `package-lock.json` as modified**: `npm install` was run
  instead of `npm ci`, and it rewrote the file. Hint: which command did you run?
  Then: `git restore package-lock.json` (202's "Discard a change"). It is not
  part of the commit.
- **A server nobody knows the `postgres` password of** ("Any other server"): the
  page has no way around it, and resetting it is not in the course. Send the
  student to the teacher. On macOS, the `psql` of the installer of
  postgresql.org is in `/Library/PostgreSQL/<version>/bin/`, not on the `PATH`.
- **A pull conflicts on a query**: two members implemented the same one,
  differently. Hint: which one works? Then resolve it as in 204. The same query
  taken from the page by both merges without a conflict.
- **GitHub shows a commit without linking it to the student's account**: the
  e-mail address in their Git configuration is not one of their GitHub
  account's. GitHub shows the name the commit carries, as in 204, and that name
  is what the page asks for. For later commits, set `user.email` to an address
  of the account; pushed commits stay as they are.
