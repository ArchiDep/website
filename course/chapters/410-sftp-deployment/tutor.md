# Tutor notes: 410 Deploy a web application with SFTP

## Starting point

- 205 Guess It: the group's fork on GitHub, owned by one member, and a clone on
  each member's computer where the application ran with Node.js and PostgreSQL.
- 301 Security: the vulnerabilities of Guess It. The original repository now
  has their fixes, and the three queries. The first step gets each student a
  fork of their own with both: the owner of the group's fork merges the original
  repository into it, the other members fork, and anyone may fork again from a
  clean state.
- 404 Run your own virtual server on Microsoft Azure: the server exists, the
  student logs in to it with their key, and port 3000 is open in Azure.
- 104 Hello SSH: an SFTP application set up with the private key. On Windows,
  WinSCP with the converted `.ppk` key.
- 406 Unix Networking: ports, the loopback address, and an address that means
  all addresses. 408 Unix Processes: the `<` redirection, and a program in the
  foreground holding the terminal.

## Learning objectives

The first deployment of the course: running an application on a server instead
of on the student's computer, by the same steps. The files are the program, the
application and the database are two server processes on one machine, and which
addresses each listens on decides who can reach it. The page's "What have I
done?" states what the student should understand afterwards.

The deployment is naive on purpose. The application runs in development mode,
in the student's terminal, under their own account, and stops when they log
out. Keeping it running after logout, production mode and running it under
another user are the subject of the chapters that follow, not of this one.

The page does not mention two of the deployment's flaws, on purpose: committing
the password put in `schema.sql` and `server.js`, and how the application stops.
Whether students commit the password, and whether they find out how to stop the
application, is used later in the course.

Three architecture diagrams follow the exercise's parts, each stepped through
with captions: "What's running so far?" after the installation, "How did the
files get there?" after the upload, and "Architecture" at the end. The only
processes students are expected to be able to draw are three from the last one:
the browser, Guess It and PostgreSQL. Nothing SSH-related is expected: the SSH
processes are folded into two stacks, since 103 explained them.

Not in the exercise: how NodeSource's script configures APT, PostgreSQL's
authentication configuration, and percent-encoding passwords in a URL, which
the random hexadecimal password avoids. Unix sockets appear only in a "more"
callout and while stepping through the diagrams, which leave PostgreSQL's out
when fully drawn: students are not expected to draw or explain them.

## Where it leads

Every later deployment chapter starts from this deployment and fixes one of its
flaws:

- "How a computer works" ends on this deployment's processes: students draw
  them, then its architecture diagram is stepped through to say which program
  runs where, and in which memory.
- "How to improve our basic deployment" lists the flaws of this deployment,
  development mode and the upload of `node_modules` among them.
- "Deploy a PHP application with Git" replaces the SFTP upload, and installs the
  dependencies on the server.
- "Configure a PHP application through environment variables" moves the
  password out of `server.js`.
- "Manage a PHP application with systemd as a Process Manager" keeps the
  application running after the student logs out.

## Key steps

- **"Make sure you have your own up-to-date Guess It fork".** Which path applies depends on
  whose GitHub account owns the fork the student has. Afterwards: a fork under
  the student's own account, with the fixed queries, cloned on their computer.
  The fixed version is deployed because the application will be reachable from
  the Internet. Sample question: why deploy the fixed version rather than your
  own?
- **"Install the dependencies".** `npm ci` has to run again after the update:
  the fix of the cross-site scripting added the `mustache` dependency. Sample
  question: why install the dependencies again?
- **"Install Node.js".** Afterwards: `node -v` prints `v26.x.y`. An older
  version is Ubuntu's own `nodejs` package, installed when a NodeSource command
  was skipped or failed.
- **"What's running so far?"**. Installing PostgreSQL started it; installing
  Node.js only put files on the disk, and `node -v` ran and exited. What
  started PostgreSQL is left open on purpose, for "Manage a PHP application
  with systemd as a Process Manager": do not explain it.
- **"Update the configuration".** Done in the copy on the student's computer,
  before the upload, so that the files are deployed as they are. Afterwards: the
  password in `DATABASE_URL` is the one in `schema.sql`, and the port is 5432.
  Editing `server.js` on the server is only for fixing a mistake afterwards.
- **"Upload the application".** Afterwards: `ls ~/guessit-ex` on the server shows
  `server.js`, `schema.sql` and `node_modules`. Node.js needs the JavaScript
  files and `node_modules`; nothing is built. Sample question: which files does
  Node.js need to run the application?
- **"Optional: check that the files have arrived".** Checks the upload from the
  terminal: the directory's contents, the `DATABASE_URL` in `server.js`, and the
  number of packages in `node_modules`, the same on the server as on the
  computer. A smaller number on the server means the upload was interrupted.
- **"How did the files get there?"**. The SFTP application opens a second SSH
  connection to port 22, handed to a session of its own that starts an SFTP
  server rather than a shell, while the terminal's connection stays open.
  Sample question: how many SSH connections to your server were open during
  the upload?
- **"Initialize the database".** The shell reads `schema.sql`, and `psql` runs
  as the `postgres` user. The output is `CREATE ROLE`, `CREATE DATABASE`, a
  `You are now connected` line, `CREATE TABLE` and `ALTER TABLE`. Sample
  question: who runs `psql`, and who reads `schema.sql`?
- **"Run the application".** Afterwards: the home page loads at the server's
  public IP address, port 3000, with an empty leaderboard and no warning that
  it could not be loaded.
- **"Optional: see who listens where".** `ss -tln` shows PostgreSQL on
  `127.0.0.1:5432` and `[::1]:5432`, and Guess It on `*:3000`. That is one
  reason a browser reaches Guess It but not PostgreSQL. The other is the Azure
  firewall: the student opened port 3000 in 404, not 5432. Either alone would
  block PostgreSQL from the Internet. Sample question: why can your browser
  reach Guess It but not PostgreSQL?

## Common pitfalls

- **The merge in "Make sure your fork is up to date" reports conflicts in
  `server.js`**: expected. Both sides implemented the same queries, and the
  original repository's side has the fixed ones.
- **`error: remote upstream already exists`**: the commands of "Make sure your
  fork is up to date" were run a second time. The remote is already there, and
  `git fetch upstream` works.
- **A student who is not the owner of the group's fork updates it**: they can
  push to it as a collaborator, but it is not under their account. The page's
  paths depend on whose account the fork is under.
- **The browser cannot connect to port 3000 while the application runs**: port
  3000 is not open in Azure. 404's troubleshooting covers it, under "I forgot to
  open some (or all) of the ports in the firewall".
- **The browser cannot connect to port 3000, and the student's terminal is back
  at a prompt**: the application has stopped, for example because the SSH
  connection in which it was started closed.
- **`Guess It is listening` is printed, but nothing answers, or a second
  `npm run dev` prints it and exits**: another instance of the application
  already holds port 3000. Guess It prints its message even when it fails to
  listen, and exits with status 0.
