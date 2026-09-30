# Tutor notes: 202 Hello Git

## Starting point

- 201 Version Control with Git: the exercise practises its subject page. When
  the student asks about Git itself, answer from 201's notes: they give the
  depth, the vocabulary and the misconceptions to check the student's
  explanations against.
- A Unix shell, as in 101: the Terminal on macOS, the WSL on Windows. On
  Windows, the repositories go in the WSL's own directories, not under `/mnt/c`.
- `EDITOR=nano`, from "Set your editor" in 102. A merge opens the editor, and a
  student who skipped 102 lands in Vim.
- Nothing on GitHub: the two clones are over HTTPS, so no account or SSH key is
  needed yet.
- Some students used Git in their first year and arrive with a configuration of
  their own. "Set up Git" checks it: an old identity, `master` as the default
  branch or another editor show up there.
- `/path/to/projects` is a placeholder: any directory of their own that is not
  inside a repository.

## Learning objectives

The model of 201, tried on the student's own repository: the three areas, seen
through a file that is both staged and modified; a commit as a snapshot that
never changes, named by its hash; `.gitignore`, and why it cannot protect a file
already committed; branches as pointers and `HEAD`; and how the shape of the
history decides between a fast-forward and a three-way merge. The page's "What
have I done?" states what the student should understand afterwards.

Each step asks for a prediction first. Every answer is on the page, in a "Check
your prediction" or "Answer" box that the student can open at any time. Ask for
the prediction and the reason behind it before they open the box, and send them
to it rather than answering. A wrong prediction is what the step is for.

Headings marked ❓ are optional, and so is "Merge in the reverse order" (👾). The
page says that "Going further" is not asked in the exam; it is the only place
the exercise practises 201's "Undoing things".

Seen but not explained here: `origin`, the `set up to track 'origin/fix-typo'`
message of `git switch`, and `git remote rm origin` ("Collaborating with Git");
`git filter-repo`, only in a "Tell me more" box. No merge in the exercise
conflicts: conflicts come with "Collaborating with Git". What 201's notes list
as not in the course stays out. In particular, do not fix a mistake with `git
reset`, `git stash` or a rebase: the course's own commands are `git restore`,
`git restore --staged` and `git commit --amend`.

## Where it leads

Everything the course does with Git builds on this exercise; 201's notes list
the later chapters. Those that lean on particular parts of the exercise:

- Hello GitHub: the identity set in "Who are you?" is the one GitHub shows on
  commits, which it never checks. A fetch leaves the shape of "Two merges", and
  a remote accepts a push only if it is a fast-forward. It links back to "I am
  stuck in Vim" for the merge of a pull.
- Guess It: the repository's `.gitignore` keeps `node_modules` out, and the page
  links back to "Ignore a secret".
- "Unix Environment Variables" and the deployments after it take secrets out of
  the code, which is why a committed one matters. "Deploy a PHP application with
  Docker Compose" ignores a `.env` file exactly as here.
- "Configure a PHP application through environment variables" throws away
  changes on the server with `git restore`, practised only in "Discard a
  change".

## Key steps

The diagrams are simgit animations the tutor cannot see. Except the first one in
"Two merges", which only shows the prepared graph, each opens on the state
before the step and waits for the student to play it. Ask the student to
describe the graph they predict, which pointers move and which new commits
appear, before they play it.

- **"Set up Git".** After: `git config user.name`, `git config user.email` and
  `git config init.defaultBranch` print the student's name, e-mail address and
  `main`, and `echo $EDITOR` prints `nano`. Ask: why set your identity before
  the first commit, rather than later?
- **"Create a repository".** Before: why check `git status` before `git init`?
  After: `On branch main` and `No commits yet`. Ask: where does Git keep the
  history? (`ls -a` shows `.git`.)
- **"Your first commit".** After: `git status` still lists `hi.txt` as
  untracked, and `git log` shows one commit with the student's own name. Ask:
  why is your hash not `a82bb9b`?
- **"Staged and modified"**, the step the exercise is built around. Four
  predictions in a row. Afterwards, ask the student to say which two areas `git
diff` compares, and which two `git diff --cached` compares, and where each of
  the two lines of `hello.txt` is. The commit's summary says `1 file changed, 1
insertion(+)`, and `git status` still lists `hello.txt` as modified.
- **"Ignore a secret".** Before `.gitignore`: what would `git add .` have
  committed? After: `git status` lists only `.gitignore`. The page asks why
  `.gitignore` is committed.
- **"A secret committed too late".** After `git rm --cached` and the commit:
  `ls` still shows `api-key.txt`, and `git status` says nothing about it. For
  the last prediction, also ask what they would do in a real project, once a
  real key was pushed. The answer is on the page, and it is the point of the
  step.
- **"Branch and switch".** After the commit on `bye`: `git graph` shows
  `(HEAD -> bye)` on "Say goodbye" and `(main)` on the commit below it. After
  switching back to `main`: `ls` no longer shows `goodbye.txt`, but shows the
  three ignored files. Ask: where is `goodbye.txt` now?
- **"Two merges".** After the setup: `git graph` shows `main`, `fix-typo` and
  `contact-page`, and `HEAD -> main`. The commits cloned from GitHub have the
  same hashes as the page; only the merge commits differ.
  - "Merge `fix-typo`": `Updating b85d48f..27d2a53` and `Fast-forward`. Ask:
    which pointer moved, and was any commit created?
  - "Merge `contact-page`": `Merge made by the 'ort' strategy.` Ask: why could
    `main` not simply move to `contact-page`, and what would it have lost? What
    are the two parents of the merge commit?
  - "Merge in the reverse order" (optional): ask for the reasoning before the
    second clone, which is only there to check it.
- **"History hunt"** (optional). Each question names the command that answers
  it. It practises searching a real history: `git log`'s options, `git show` and
  `git shortlog`. "Who helped?" shows that an author's name is only what they
  configured.
- **"Going further"** (optional). The page asks for `git status` after each
  step; ask what it says before and after.

## Common pitfalls

- **The first `git status` prints a status instead of `fatal: not a git
repository`**: the directory is already inside a repository. Often it is their
  home directory, from an earlier attempt, or a projects directory that is
  itself a repository. Hints: which directories above this one could hold a
  `.git`? Check with `ls -a` in each. Then: create `hello-git` somewhere outside
  it. Removing a stray `.git` deletes the history it holds: check with the
  student that nothing in it matters to them, and never offer it as the first
  fix.
- **The prompt changes to `>` or `dquote>` after `git commit -m`**: a quote was
  left open, and the shell is waiting for the rest of the command. Hints: count
  the quotes; `Ctrl-C` gives the prompt back, then type the command again.
- **A diff shows `-Hello World`, or `debug.log` is still untracked after
  creating `.gitignore`**: a `>` was typed where the page has `>>`, and the file
  was overwritten. Hint: compare the two operators in "The `echo` command" of
  101, then `cat` the file.
- **In "Staged and modified", `git status` lists `hello.txt` only once**: both
  lines were written before `git add`, or the file was added again after the
  second line. Hint: which version of the file did your `git add` copy? Then
  write a third line and look again.
- **`git status` shows `deleted: api-key.txt` under "Changes to be committed"**
  after `git rm --cached`, and the student thinks the file is gone. It is
  expected: the next snapshot no longer holds the file, and the disk still does.
  Ask: deleted from where? What does `ls` say?
- **`ls` no longer shows `api-key.txt`** after "Stop tracking the API key": `git
rm` was run without `--cached`, which also deletes the file from the disk.
  Hint: what does `--cached` limit the command to? The key is made up: create
  the file again with the page's command, and nothing later depends on it.
- **`git log -p -- api-key.txt` shows the first key twice, and never the second
  one.** Expected: the "Stop tracking the API key" commit removed the file from
  the snapshot, so the key appears again as a line that starts with `-`. Ask:
  which commit adds the line, and which one removes it? Why is the second key
  nowhere in the history?
- **"Say goodbye" was committed on `main`**: the `git switch bye` failed or was
  skipped, and `git graph` shows `(HEAD -> main)` on it, with `bye` one commit
  behind. Ask: which branch moved, and why that one? Moving a commit to another
  branch is not in the course. Nothing later depends on `bye`, so the student
  can go on, but the next predictions will not match the page. Work through them
  with the graph they have.
- **`git status` in one repository lists another as an untracked directory**
  (`hello-git-merges/`, `hello-git-reversed/`, `2048/`): it was cloned inside a
  repository instead of next to it. Hint: `pwd` before `git clone`; the page
  says to `cd /path/to/projects` first.
- **Nano asks `Save modified buffer?`** when leaving a merge message: the
  message was edited. `Y`, then `Enter`, keeps the edited message and finishes
  the merge.
- **"Travel back in time" refuses to switch** with `Your local changes to the
following files would be overwritten by checkout`: a change is not committed,
  usually the rename, when the commit at the end of "Rename a file" was skipped.
  Hint: what does `git status` say? Commit it, then switch. The hash to use is
  one of the student's own, not `a82bb9b`.
- **In "Travel back in time", `.env`, `api-key.txt` and `debug.log` appear as
  untracked.** Expected, and worth a question: why are they no longer ignored?
  (`.gitignore` is a file of the snapshot, and the first commit does not have
  one.)
- **`git: 'switch' is not a git command`**: Git is older than 2.23. Hint: `git
--version`, then install a recent Git as "Is Git installed?" describes.
