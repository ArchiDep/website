# Tutor notes: 203 Collaborating with Git

## Scope

The subject page is the reference for the commands. The slides are a demo on one
repository pushed to two remotes, with animated commit graphs the tutor cannot
see; each draws the student's computer and one repository on GitHub.

Only the slides have:

- The walkthrough, which goes on from 201's deck: the calculator repository, on
  `main` with the merge commit of `sub` (`e0711c3`), and no remote, since 201's
  deck removed `origin`. In order: "Add a remote" (`origin`, an empty repository
  on GitHub); "Push" (`git push -u origin main`, `[new branch]`);
  "Remote-tracking branches"; "Your team's repository" (a second remote, `team`,
  where a colleague pushed `9dcba66` "Finish the calculator" on top of
  `907e519`); "Push to the team", rejected with `(fetch first)`; "Nothing
  moved"; "Fetch"; "The divergent history"; "Push after fetching", rejected with
  `(non-fast-forward)`; "Merge", which conflicts in `subtraction.js` (`return a
  - b;`against`return -b + a;`) while the colleague's new title in
`index.html`merges on its own; "A merge in progress"; "Conflict markers";
"Resolve the conflict" (keeps`return a - b;`); "Finish the merge" (`a92ed4f`,
parents `e0711c3`and`9dcba66`); "Push the merge", accepted
(`9dcba66..a92ed4f`); "Remotes do not sync" (`ahead of 'origin/main' by 2
    commits`); and "`git pull`".
- Questions put before the answer: "will it work?" before each push, "can this
  one fast-forward?" before the merge. Ask the student for their answer and
  reason before they move to the next slide.
- The team repository belongs to the course: students cannot push to it and are
  not meant to replay the demo. "Hello GitHub" is where they do it themselves.

Only the subject has:

- "Remotes": access control, issues and pull requests as what GitHub adds.
- "`git remote`: name your remotes": `rename` and `rm`, and `origin` as the name
  `git clone` gives.
- "A rejected push": the two reasons Git gives, side by side.
- In "Resolving a conflict", `git commit --no-edit`, and the advice to pull
  often and commit small changes.

Both have the tip to create a GitHub repository without a README, a licence or a
`.gitignore` before pushing an existing project to it (in the slides, in the
speaker notes of "GitHub").

Optional: "Appendix: going further" (reading only).

## Left out

Taught later, so do not explain them here beyond what the page does:

- Forks, collaborators, `pull.rebase`, GitHub's host key on the first SSH
  connection, and who pushes against who wrote a commit: "Hello GitHub". The
  subject names forks only in its appendix.
- Cloning on a server over HTTPS, and pulling there: "Deploy a PHP application
  with Git".
- Bare repositories, and pushing to a remote on the student's own server: "Git
  Hooks" and "Set up an automated deployment with Git hooks".
- A remote named `upstream` for the original repository of a fork, and a remote
  branch other than `main`: "Deploy web applications with a database to Render".

Not in the course: rebasing and `git pull --rebase` (the appendix lists them as
reading), force pushing, pull requests and code review, refspecs, deleting a
branch on a remote, tags, `git mergetool`, rerere, the common ancestor's version
in a conflict (`diff3`), `--ours` and `--theirs`, undoing a merge once
committed, and HTTPS authentication to GitHub with tokens. Only conflicts on
lines both sides changed are covered: modify/delete and add/add conflicts are
practised nowhere. Do not answer a rejected push with `--force` or a rebase: the
course's answer is always to fetch, merge, then push.

Merging unrelated histories is not covered either: the tip in "`git remote`:
name your remotes" names the error, and its way out is a new, empty repository
on GitHub rather than `--allow-unrelated-histories`.

## Key concepts and vocabulary

- **Remote**: another copy of the repository, usually on a server, holding the
  whole commit graph. Known to a repository by a **name** and a **URL**.
  `origin` is only the conventional name `git clone` gives.
- **Distributed**: every copy holds everything, and no copy is more important
  than another, except by agreement. GitHub hosts one more copy.
- **Push**: sends the commit a branch points to, with the commits behind it the
  remote does not have, and asks the remote to move its branch there.
- **Upstream**: the remote-tracking branch a local branch is compared to by `git
status`, and used by `git push` and `git pull` without arguments. Set by `-u`
  on the first push of a branch. Render later names a _remote_ `upstream`, which
  is another thing.
- **Remote-tracking branch** (`origin/main`, `team/main`): the record of where
  the remote's branch was the last time Git talked to it. Not a live view; it
  moves on push, fetch and pull, and is never committed on. In recent Git, the
  first fetch from a remote added with `git remote add` also creates
  `origin/HEAD` (or `team/HEAD`). The slides do not show it, and "Hello GitHub"
  says to ignore it.
- **A remote only accepts a fast-forward** of its branch: the fast-forward of
  201, seen from the remote's side. Anything else would throw away commits
  someone else pushed.
- **Rejected push**: `(fetch first)` when the remote's branch points to a commit
  the student's repository does not know; `(non-fast-forward)` when it knows
  that commit but the branch does not include it. A rejected push changes
  nothing, on either side.
- **Fetch**: downloads the commits the student does not have and moves the
  remote-tracking branches. Changes neither their branches nor their files.
- **Pull**: a fetch, then a merge of what was fetched into the current branch.
- **Divergent history**: the shape of `sub` and `fix-add` in 201, now between a
  branch and its remote-tracking branch. It needs a three-way merge.
- **Merge conflict**: both sides changed the same lines since their common
  ancestor, differently, and Git stops in the middle of the merge. The files in
  conflict are **unmerged** ("both modified"); what Git merged on its own is
  already staged.
- **Conflict markers**: between `<<<<<<< HEAD` and `=======` is **yours**, the
  branch you are on; between `=======` and `>>>>>>>` is **theirs**, what is
  being merged. After `>>>>>>>` comes the name of what was merged: `team/main`
  after `git merge team/main`, a commit hash after a `git pull`, as in "Hello
  GitHub".
- **Resolving**: edit the file and remove the markers, `git add` to mark it
  **resolved**, then `git commit` to conclude the merge with a merge commit of
  two parents. `git merge --abort` gives up at any point before that commit.
- The course's choices: SSH URLs to GitHub (`git@github.com:<owner>/<repo>`),
  authenticated with the key pair from 103; merging, never rebasing; `main`; the
  `git graph` alias from 201.

## Misconceptions

- **Misconception:** GitHub is where the repository really is, and the one on
  the student's computer is a copy of it.
  **Correction:** every copy holds the whole history, including the one in the
  student's own `.git`. GitHub is one more copy, which a team agrees to treat as
  the shared one.
- **Misconception:** `origin` is a required name, or means GitHub.
  **Correction:** it is the conventional name `git clone` gives. The slides
  remove it and give it again, and `team` is a remote just as well.
- **Misconception:** a push uploads the student's files, or their changes.
  **Correction:** it sends commits. Changes that are not committed stay behind.
- **Misconception:** "Your branch is up to date with 'origin/main'" means that
  nothing new is on GitHub.
  **Correction:** it compares the branch to the record of the last time Git
  talked to `origin`. Only a fetch, a pull or a push updates that record.
- **Misconception:** a fetch updates the files, or a fetch and a pull are the
  same thing.
  **Correction:** a fetch changes neither the branches nor the files; a pull
  also merges.
- **Misconception:** remotes keep each other in sync, or GitHub passes commits
  on.
  **Correction:** Git never synchronises anything by itself. After the push to
  `team`, `origin` is still where the first push left it ("Remotes do not
  sync").
- **Misconception:** a rejected push means something is broken, or has to be
  forced through.
  **Correction:** it is the remote protecting commits someone else pushed, and
  it changes nothing. Forcing would throw the colleague's commit away, which is
  exactly what the rejection prevents.
- **Misconception:** once the colleague's commit is fetched, the push will be
  accepted.
  **Correction:** knowing the commit is not enough; the branch has to include
  it. That is the second rejection, `(non-fast-forward)`, and what the merge is
  for.
- **Misconception:** the remote merges the student's commits with the others'
  when they push.
  **Correction:** a remote never merges. The merge happens in the student's
  repository, and the merge commit has the colleague's commit as a parent, so
  pushing it is a fast-forward from the remote's side.
- **Misconception:** a conflict is about a whole file, or any file both sides
  changed conflicts.
  **Correction:** it is about lines. The colleague's title in `index.html` was
  merged on its own, and in "Hello GitHub" a change to another line of the same
  file merges without a conflict.
- **Misconception:** `HEAD` in the markers is the remote's version, or the
  latest one.
  **Correction:** it is the branch the student is on: their own version.
- **Misconception:** resolving a conflict means choosing one of the two sides.
  **Correction:** it can also be a third version combining them. In the demo,
  both lines compute the same thing, so keeping one is enough.
- **Misconception:** `git add` after a conflict adds a new file, or Git checks
  that the resolution is right.
  **Correction:** it marks the conflict as resolved. Git checks nothing: markers
  left in a file are committed like any other text, so test before committing.
- **Misconception:** `git pull` always merges.
  **Correction:** on a divergent history, recent Git refuses to pull until it
  is told how to reconcile the branches. "Hello GitHub" sets
  `pull.rebase false`, which makes it merge; the subject does not mention it.

## Used in

Most of the course: from "Hello GitHub" on, exercises push to and pull from
remotes, and the deployment exercises assume this subject without explaining it
again. Parts that later chapters lean on in particular:

- "Hello GitHub" replays the demo in a group, on a fork: the same two
  rejections, a conflict on one line of `server.js`, and a pull that merges
  without a conflict because it changes another line.
- "Guess It": the group shares its work through its fork, and pulls whenever a
  push is refused.
- "Deploy a PHP application with Git" clones on the server and pulls there;
  "Configure a PHP application through environment variables" counts the copies
  (GitHub, the student's computer, the server) and pulls with `git pull <remote>
<branch>`.
- "Set up an automated deployment with Git hooks" adds a second remote on the
  student's own server (`user@host:path`) and pushes to it; the copy on GitHub
  falls behind, as in "Remotes do not sync".
- "Deploy static sites to GitHub Pages" and "Deploy static sites to Netlify"
  deploy on a push to GitHub.
- "Deploy web applications with a database to Render" adds an `upstream` remote,
  fetches from it, and makes a branch from a remote-tracking branch.
- "Containerize a web application using Docker" and "Deploy a PHP application
  with Docker Compose" push from the student's computer and pull on the server.
