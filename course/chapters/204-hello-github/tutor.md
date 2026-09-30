# Tutor notes: 204 Hello GitHub

## Starting point

- 203 Collaborating with Git: the exercise practises its subject in a group.
  When the student asks about remotes, pushing, fetching or conflicts, answer
  from 203's notes: they give the depth, the vocabulary and the misconceptions
  to check the student's explanations against.
- 202 Hello Git: the identity set in "Who are you?", `EDITOR=nano` (Chuck's pull
  opens the editor), the `git graph` alias, and the fast-forward and three-way
  merges of "Two merges", which this exercise sees from the remote's side.
- 104 Hello SSH: the key pair, in `~/.ssh` on the student's own computer (in the
  WSL on Windows). GitHub gets the public key.
- A GitHub account each, and a group of two or three. Each step is for the
  member its heading names, and some only work once another member has finished
  theirs. Ask first which role the student plays (Alice, Bob or Chuck) and how
  big the group is: the student only sees their own repository.
- `alice` in `git@github.com:alice/guessit-ex.git` is Alice's GitHub username.
  `/path/to/projects` stands for the directory where the student keeps their
  projects, the same as in 202.
- Node.js is not needed. In the optional "Everyone: run the application", the
  home page says that the leaderboard could not be loaded: that is expected, and
  not something to fix here. Guess It installs the database.

## Learning objectives

The model of 203, played by a group on a fork: a fork and a clone as copies of
one history, with the same hashes; `origin/main` as a record that moves only
when Git talks to GitHub; fetch, merge and pull; a remote that only accepts a
fast-forward, hence the two rejections and merging before pushing; conflicts as
a matter of lines, not files; and who pushes (the SSH key and the collaborators)
against who wrote a commit (the configured name, which GitHub does not check).
The page's "What have I done?" states what the student should understand
afterwards.

Every step asks for a prediction. The answers are on the page, in "Check your
prediction" boxes that the student can open at any time. Ask for the prediction
and the reason behind it before they open the box, and send them to it rather
than answering. The diagrams are simgit animations the tutor cannot see. Each
opens on the state before the step and waits for the student to play it: ask the
student to describe the graph they predict (which pointers move, in which
repositories, which new commits appear) before they play it.

Optional: "Create an SSH key" and "Add your key to GitHub", only for a student
whose check fails, and "Everyone: run the application". The steps for Chuck are
only for groups of three.

Seen but not explained: `origin/HEAD` (the page says to ignore it), what
`pull.rebase` set to `true` would do, `--global` (in a note), the `'ort'`
strategy, and the full hash after `>>>>>>>`. What 203's notes list as not in the
course stays out. In particular, do not answer a rejected push with `--force`, a
rebase or `git pull --rebase`, and do not undo a mistake with `git reset` or
`git stash`. Pull requests are not in the course either: the fork is the group's
repository, not a contribution to `ArchiDep/guessit-ex`, and GitHub's "Sync
fork" button is not used.

## Where it leads

Everything the course does with remotes builds on this exercise; 203's notes
list the later chapters. Those that lean on particular parts of it:

- Guess It: the same group, fork and clones. Its setup steps are this exercise's
  up to "Everyone: clone the fork", and the rest is the same collaboration
  without a script: whenever a push is refused, pull first. Each commit there
  must carry its author's own name. Later, each student makes a fork of their
  own from the group's fork, to deploy the application.
- The deployment exercises clone and pull on the student's server, a third copy
  that moves only when they pull, like Bob's before his fetch.

## Key steps

- **"Everyone: check your SSH key on GitHub".** After: a key listed on GitHub
  has the fingerprint `ssh-keygen -lf` prints. Ask: which of the two key files
  does GitHub have, and why never the other?
- **"Everyone: configure `git pull`".** After: `git config pull.rebase` prints
  `false`.
- **"Everyone: clone the fork".** Before: whose repository, and which kind of
  URL? On a first connection to GitHub, the SSH client asks whether to trust it.
  That decision is the student's, as in 104: ask where the fingerprints they can
  trust are published, and do not answer `yes` for them. After: `git graph`
  shows `02b3426` and `2262855`, the same hashes for everyone, with `(HEAD ->
main, origin/main, origin/HEAD)` on the first. Ask: what is `origin/main`, and
  when does it move?
- **"Alice: add the team to the README" and "Alice: push the change".** After
  the push: `02b3426..` followed by Alice's own hash, then `main -> main`. The
  commits the group makes have other hashes than the page's. Ask: what moved in
  Alice's repository?
- **"Bob: look before you fetch", "Bob: fetch", "Bob: merge" and "Chuck:
  pull".** After the fetch, `README.md` has no "Team" section yet, and `git
status` says `Your branch is behind 'origin/main' by 1 commit`. Ask: what did
  the fetch change, and what did it leave alone?
- **"Everyone: change something".** Everyone commits without pushing. Ask: which
  line did you change, and whose change will it conflict with?
- **"Bob: push" and "Bob: fetch, and push again".** Two rejections, `(fetch
first)` then `(non-fast-forward)`. Ask the student to say what each reason
  means, and why the fetch was not enough.
- **"Bob: pull, and resolve the conflict"**, the step the exercise is built
  around. Ask: which side of the markers is yours, and which is Alice's? After
  `git add`: `All conflicts fixed but you are still merging`. Before the commit,
  ask them to check the file for a marker line left behind.
- **"Bob: push the merge".** Ask: why is it accepted now, when the fetch alone
  was not enough?
- **"Chuck: pull".** No conflict, and the editor opens for the merge message.
  Ask: Chuck changed the same file, so why no conflict?
- **"Everyone: check your status".** Every member's `git graph` is the same: the
  same commits, with the same hashes.

## Common pitfalls

- **The group pushed out of order**: Bob before Alice, or Chuck before Bob's
  merge was on GitHub. Nothing is broken: whoever pushed first was accepted, and
  the others are refused. Only the names in the predictions and diagrams no
  longer match. Hint: who pushed first? Then: whoever is refused plays Bob's
  part from the rejection on. The page's other way out is to start over.
- **Alice and Bob chose the same colour**: Bob's pull merges without a conflict
  and opens the editor for the merge message, because both sides made the same
  change. Hint: compare the two lines. To see a conflict anyway, once everyone
  has pulled, Alice and Bob each commit a different colour and go through
  "Conflicting changes" again from "Alice: push first".
- **`error: Your local changes to the following files would be overwritten by
merge`** on a pull, or `Everything up-to-date` on a push: the change was made
  but not committed. Hint: what does `git status` say? Then: commit it, as the
  step says, and pull or push again. Do not suggest `git stash`.
- **`git config pull.rebase` prints `true`, or a pull fails with `fatal: Not
possible to fast-forward, aborting.`** (`pull.ff` set to `only`): a
  configuration from earlier Git use. The page only says what to do when nothing
  is set. Hint: what did the command print? Then: set `pull.rebase` to `false`
  as the page does, and remove the other with `git config --global --unset
  pull.ff`. If a pull has already rebased and stopped on the conflict (`git
  status` says a rebase is in progress), `git rebase --abort` goes back to
  before the pull. Rebasing is not in the course, so do not explain it further.
- **In "Bob: look before you fetch", `git status` already says Bob is behind**:
  his editor fetched for him. VS Code offers to run `git fetch` periodically,
  and a student who accepted gets it. Ask: did anything run a fetch? The point
  stands: a program asked GitHub, and nothing arrived by itself.
- **A push asks for `Username for 'https://github.com':` and fails**: the clone
  was made with the HTTPS URL. The clone worked because the fork is public, but
  GitHub refuses passwords for a push. Hint: `git remote -v`: does the URL start
  with `git@`? Then: `git remote set-url origin` followed by the SSH URL, as a
  recipe; or clone again with the SSH URL if nothing was committed there yet.
- **The diff shows far more changed lines than the one edited**, or a conflict
  spans much more than `ACCENT_COLOR`: the editor reformatted `server.js` on
  save. Hint: before committing, how many lines does `git diff` show? Then: turn
  format-on-save off, `git restore server.js`, and make the change again. A
  conflict already there is resolved the same way, block by block.
- **VS Code offers "Accept Current Change" and "Accept Incoming Change"** on the
  conflict: current is `HEAD`, the student's own version, and incoming is what
  is being merged. The buttons are fine to use. Ask which one they chose, and
  why.
- **The conflict markers were committed and pushed**, which the page warns Git
  does not prevent. If the application is running, it stops with a
  `SyntaxError`. Hint: search `server.js` for `<<<<<<<`, `=======` and
  `>>>>>>>`. Then: fix the file and commit again. The others get the fix with
  their next pull, and nothing has to be undone.
