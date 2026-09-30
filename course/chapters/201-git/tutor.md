# Tutor notes: 201 Version Control with Git

## Scope

The subject page is the reference for the commands. The slides show the model at
work, as a walkthrough on one repository, with animated commit graphs the tutor
cannot see.

Only the slides have:

- "What is Git?": what version control is for, and Git's origin and design goals
  (speaker notes).
- "What is branching?": why teams branch (work in isolation, take changes at
  their own pace, choose what to release), and links to branching workflows.
- The walkthrough, on `ArchiDep/git-calculator` (three commits on `main`), with
  `git remote rm origin` right after the clone, explained with remotes. Branch
  `sub`, commit the subtraction (`return a - b;`); switch back to `main` and see
  `subtraction.js` revert; branch `fix-add` from `main`, fix the addition (`a *
b` to `a + b`); switch between the two diverged branches; merge `fix-add` into
  `main` as a fast-forward; merge `sub` as a three-way merge, whose message
  opens the editor; delete both branches. The steps for a reader following alone
  are the 🛠️ lines of the speaker notes, and "Merge commit" shows the final
  `git graph`.
- Inside it, three slides on the three areas: "What's in a Git project?" (the
  `.git` directory, with `HEAD`, `config`, `hooks`, `index` and `objects`), "The
  basic Git workflow" and "Using the staging area" (a loading dock).

On the page:

- "Git and the command line": why the course uses the command line, not a GUI.
- "How Git stores your project": snapshots, blobs and trees, commits and their
  parents, hashes and their three consequences. The `git cat-file -p` callout is
  optional.
- "The basic Git commands": the vocabulary list, then `config`, `init` (never
  inside another repository or in the home directory), `clone`, `status`, `add`,
  `diff` and `--cached`, `commit` (`-m`, `-a`), `log` (display and search
  options, the `git graph` alias), `branch`, `switch` (`checkout` as its older
  name), `merge` (fast-forward, three-way, `-m`, `--abort`).
- "Undoing things": `restore --staged` (safe), `restore` (destructive), `commit
--amend` (rewrites history), `branch -D`, and `git reflog` in a tip. Hello Git
  practises these only in its optional "Going further", which it says the exam
  does not ask about.
- "Best practices": links on committing often and writing messages.

Optional: "Appendix: going further" (reading only) and "Appendix: a short
history of version control" (local, centralized and distributed systems; deltas
against snapshots).

## Left out

Taught later, so do not explain them here beyond what the page does:

- Remotes, `origin`, pushing, fetching, pulling, remote-tracking branches,
  GitHub, and resolving merge conflicts: "Collaborating with Git". This subject
  only says that a conflict exists and that `git merge --abort` cancels a merge.
- `.gitignore`, and untracking a committed file with `git rm --cached`: "Hello
  Git". A detached `HEAD` is only an optional step there.
- Keeping secrets out of the code: "Unix Environment Variables" and the
  deployment exercises that follow it.
- Hooks and bare repositories: "Git Hooks", "Set up an automated deployment with
  Git hooks".

Not in the course: rebase, interactive rebase, `reset`, `stash`, tags,
interactive staging, revision syntax such as `HEAD~2`, `blame`, `bisect` (the
appendix lists them as reading), merge strategies (the `'ort'` in the output
is not explained), pack files and delta compression, submodules, Git LFS,
signed commits, and Git GUIs.

## Key concepts and vocabulary

- **Snapshot**: a commit records the full content of every file, not the
  changes. A **blob** is one file's content, a **tree** one directory's listing;
  a commit points to the root tree.
- **Commit**: a snapshot, an author, a date, a message and its **parent** (two
  for a **merge commit**). The chain of parents is the **history**, drawn as the
  **commit graph**.
- **Hash**: a commit's name, computed with SHA-1 from its content. Shown
  shortened to 7 characters. Same content, same hash; change anything, another
  commit.
- **Repository**: the project with its whole history.
- **The three areas**, which the course also calls the three parts of a Git
  project: the **Git directory** (`.git`, where commits are stored), the
  **working directory** or working tree (one version, taken out to edit) and the
  **staging area** or **index** (what the next commit will save).
- **The basic workflow**: check out (switch to) a version, modify, stage (`git
add`), commit.
- **Tracked** and **untracked** files; changes **staged** and **not staged**.
- **Branch**: a movable **pointer to a commit**. **`HEAD`** says which branch
  you are on. Committing moves the current branch forward; switching moves
  `HEAD` and rewrites the working directory to that branch's snapshot.
- **Diverged** history, **common ancestor**, **fast-forward** (the pointer
  moves, no commit), **three-way merge** (a new merge commit), **fully merged**,
  **unreachable** commits.
- **Rewrites history**: `--amend` replaces a commit with a new one.
  **Destructive**: `git restore` loses changes that were never committed.
- The course's choices: `git switch` and `git restore` rather than `git
checkout`; `main`; the `git graph` alias (`log --oneline --decorate --graph
--all`); nano as the editor, and `Esc`, `:q!`, `Enter` to leave Vim.

## Misconceptions

- **Misconception:** a commit stores the changes made since the last one.
  **Correction:** it stores a snapshot of the whole project. A diff, in `git
diff` or `git log -p`, is computed by comparing two snapshots, which is also
  how Git detects a rename.
- **Misconception:** full snapshots waste space.
  **Correction:** an unchanged file has the same hash, so the new tree points to
  the blob already stored. Compression beyond that is not in the course.
- **Misconception:** a commit saves the files as they are in the folder.
  **Correction:** it saves the staging area. `git add` copies a file as it is
  at that moment, so a file can be both staged and modified, and every change
  has to be staged, not only new files (`-a` does it for tracked files only).
- **Misconception:** the hash is an identifier Git assigns, and theirs should
  match the page's.
  **Correction:** it is computed from the content, author and date included.
  Commits a student makes have other hashes than the slides; cloned commits have
  the same ones.
- **Misconception:** `--amend` edits the last commit.
  **Correction:** it replaces it with a new commit, with a new hash. No commit
  ever changes.
- **Misconception:** a branch is a copy of the project, or owns its commits.
  **Correction:** it is a pointer to one commit; its history is the chain of
  parents from there. Creating one copies nothing and does not switch to it.
- **Misconception:** switching branches loses the files that disappear.
  **Correction:** they are stored in the other branch's commits and come back
  when switching back. Git refuses to switch if uncommitted changes would be
  overwritten; otherwise those changes follow to the other branch.
- **Misconception:** deleting a branch deletes its commits.
  **Correction:** it deletes the pointer. `-d` refuses when commits would
  become unreachable; after `-D` they are lost for practical purposes.
- **Misconception:** `git merge x` sends the current branch into `x`, or moves
  both branches.
  **Correction:** it brings `x` into the current branch, and only the current
  branch moves.
- **Misconception:** a fast-forward is a kind of merge commit, and whether a
  merge fast-forwards depends on the branch.
  **Correction:** a fast-forward creates no commit, and it depends only on the
  shape of the history at the moment of the merge.
- **Misconception:** `HEAD` is the latest commit.
  **Correction:** it points to the current branch, which points to a commit.
- **Misconception:** `git log` shows every commit.
  **Correction:** it shows the history of the current commit; `--all` shows
  every branch.
- **Misconception:** Git and GitHub are the same thing.
  **Correction:** Git is a program, and the whole history is in the `.git`
  directory on the student's machine. GitHub hosts copies of repositories, which
  "Collaborating with Git" covers.
- **Misconception:** the "working directory" is where the shell is.
  **Correction:** in Git, it is the project's files as taken out of the
  repository. The shell's working directory (101) is a different thing with the
  same name.

## Used in

Most of the course: from "Deploy a PHP application with Git" on, deployments get
their code with Git, and "Collaborating with Git" is this subject applied
between copies of a repository. Parts that later chapters lean on in particular:

- "Hello Git" practises the whole subject except "Undoing things", which is
  optional there.
- "Collaborating with Git" reuses fast-forward and three-way merges: a remote
  only accepts a push that fast-forwards its branch, `git pull` is a fetch and a
  merge, and a conflict is a three-way merge on lines both sides changed. "Hello
  GitHub" and "Guess It" practise it on a group's repository, which later
  deployments start from.
- "Deploy a PHP application with Git" clones and pulls on the server.
- "Git Hooks" puts scripts in the Git directory (`.git/hooks`), which is why
  hooks are not versioned.
- "Set up an automated deployment with Git hooks" uses a bare repository, a Git
  directory with no working directory, and checks the pushed snapshot out into
  another directory, the way switching rewrites the working directory.
- "Deploy web applications with a database to Render" creates and switches to a
  branch.
- The Docker chapters compare `.dockerignore` to `.gitignore`.
