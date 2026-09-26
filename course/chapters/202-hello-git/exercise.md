---
title: Hello Git
excerpt_separator: <!-- more -->
---

Practise the basics of [Git][git] on the command line: create a repository,
stage and commit changes, keep secrets out of it, and work with branches and
merges.

<!-- more -->

**You will need**

- A Unix CLI
- [Visual Studio Code][vscode] (optional, for the Git Graph extension)

**Recommended reading**

- [Version Control with Git]({% link chapters/201-git/subject.md %})

Each exercise asks you to **predict** what Git will do before you check it.
Write your prediction down, then run the command and compare. A wrong prediction
is not a failure: it is exactly the misunderstanding the exercise is there to
reveal. Each exercise has a solution you can reveal to check your answers.

## :exclamation: Set up Git

Git may already be set up on your computer. Check each of these, and only change
what is missing.

### :exclamation: Is Git installed?

```bash
$> git --version
git version 2.55.0
```

Any recent version is fine. If the command is not found, install Git:

- On **macOS**, run `xcode-select --install`, which installs the command-line
  tools, Git included.
- On **Windows** in the WSL, or on **Linux**, install it with your package
  manager, for example `sudo apt install git`.

Otherwise, follow the [official installation instructions][install-git].

### :exclamation: Who are you?

Every commit records the name and e-mail address of its author, for good. Check
that Git knows yours:

```bash
$> git config user.name
John Doe
$> git config user.email
john.doe@example.com
```

If both commands print your name and e-mail address, you can [skip to the next
step](#the-default-branch).

If either command prints nothing, or you get a default identity (macOS typically
makes up an identity from your computer's user name and host name, such as
`jdoe@MacBook-Pro.local`), then you should configure your own name and e-mail
address:

```bash
$> git config --global user.name "John Doe"
$> git config --global user.email john.doe@example.com
```

Without this configuration, Git either refuses to commit, or records your
default identity in your commits.

### :exclamation: The default branch

Check that new repositories start with a branch called `main`:

```bash
$> git config init.defaultBranch
main
```

If it prints nothing, set it:

```bash
$> git config --global init.defaultBranch main
```

Otherwise, `git init` calls the first branch `master`, and prints a long
warning about it every time.

### :exclamation: Your editor

Some Git commands open an editor, for example to write a merge commit message.
Check that yours is nano, which you set up in [Hello Shell]({% link
chapters/102-hello-shell/exercise.md %}#set-your-editor):

```bash
$> echo $EDITOR
nano
```

If it prints nothing, see [setting nano as the default editor]({% link
chapters/101-command-line/subject.md %}#setting-nano-as-the-default-editor).

### :exclamation: The `git graph` alias

Create the alias used throughout the slides, which draws the commit graph of a
repository:

```bash
$> git config --global alias.graph "log --oneline --decorate --graph --all"
```

### :question: Git Graph for Visual Studio Code

`git graph` draws the graph in your terminal. For a more readable picture,
install the [Git Graph][git-graph] extension in Visual Studio Code. Open a
repository's directory in Visual Studio Code, then click **Git Graph** in the
status bar at the bottom of the window.

{% note type: warning %}

**On Windows**, your repositories are in the WSL, and Git Graph only sees them
if Visual Studio Code is opened in the WSL too. Open it from your WSL terminal,
in the repository's directory:

```bash
$> code .
```

The first time, this installs what Visual Studio Code needs to work in the WSL.
Then install the Git Graph extension again **in the WSL**, where Visual Studio
Code offers to.

{% endnote %}

## :exclamation: Create a repository

Create a directory for a new project, and move into it:

```bash
$> cd /path/to/projects
$> mkdir hello-git
$> cd hello-git
```

**Predict:** what will `git status` print here? Then check:

```bash
$> git status
```

Now turn the directory into a repository, and check the status again:

```bash
$> git init
$> git status
```

{% solution %}

Before `git init`, the directory is not a repository, and neither is any of its
parents:

```bash
$> git status
fatal: not a git repository (or any of the parent directories): .git
```

This is how you check that you are **not** already in a repository before
running `git init`. If `git status` had printed a status instead, you would have
been inside an existing repository, and `git init` would have created a second
one nested inside it.

After `git init`, the repository exists, but it has no commits yet:

```bash
$> git init
Initialized empty Git repository in /path/to/projects/hello-git/.git/
$> git status
On branch main

No commits yet

nothing to commit (create/copy files and use "git add" to track)
```

If `git init` printed a long `hint:` about `master` instead, and `git status`
says `On branch master`, see [the troubleshooting
entry](#hint-using-master-as-the-name-for-the-initial-branch).

{% endsolution %}

## :exclamation: Your first commit

Create two files:

```bash
$> echo "Hello World" > hello.txt  # or use your favorite
                                   # editor to create the file
$> echo "Hi Bob" > hi.txt
```

**Predict:** how will `git status` describe these two files? Check.

Now stage only one of them:

```bash
$> git add hello.txt
```

**Predict:** what will `git status` say now? Check, then look at what is staged:

```bash
$> git diff --cached
```

Commit:

```bash
$> git commit -m "Add hello.txt"
```

**Predict:** which files are in this commit? What will `git status` say after
it? Check, and look at the history with `git log`.

{% note type: tip %}

When the output of `git log` or `git diff` is longer than your terminal, Git
shows it one screen at a time, and does not give you your prompt back. Scroll
with the arrow keys, and press `q` to quit.

{% endnote %}

Finally, commit the other file too:

```bash
$> git add hi.txt
$> git commit -m "Add hi.txt"
```

{% solution %}

New files are **untracked**: Git sees them, but will not include them in a
commit unless you tell it to:

```bash
$> git status
On branch main

No commits yet

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        hello.txt
        hi.txt

nothing added to commit but untracked files present (use "git add" to track)
```

After `git add hello.txt`, only that file is staged, and `hi.txt` is still
untracked:

```bash
$> git status
On branch main

No commits yet

Changes to be committed:
  (use "git rm --cached <file>..." to unstage)
        new file:   hello.txt

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        hi.txt
```

`git diff --cached` shows the one line of the new file, staged:

```bash
$> git diff --cached
diff --git a/hello.txt b/hello.txt
new file mode 100644
index 0000000..557db03
--- /dev/null
+++ b/hello.txt
@@ -0,0 +1 @@
+Hello World
```

The commit contains **only what was staged**: `hello.txt`. `hi.txt` is still
untracked afterwards:

```bash
$> git commit -m "Add hello.txt"
[main (root-commit) a82bb9b] Add hello.txt
 1 file changed, 1 insertion(+)
 create mode 100644 hello.txt
$> git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
        hi.txt

nothing added to commit but untracked files present (use "git add" to track)
```

Your commit's hash will be different from `a82bb9b`: it is computed from the
commit's content, which includes your name and the date.

{% endsolution %}

## :exclamation: Staged and modified

Add a line to `hello.txt`, and stage it:

```bash
$> echo "You are beautiful" >> hello.txt
$> git add hello.txt
```

Before committing, add another line to the same file:

```bash
$> echo "I see trees of green" >> hello.txt
```

**Predict:**

- What will `git status` say about `hello.txt`?
- What will `git diff` show? And `git diff --cached`?
- If you commit now, which lines will the commit add?

Check with `git status`, `git diff` and `git diff --cached`, then commit:

```bash
$> git commit -m "Tell the world it is beautiful"
```

**Predict:** what will `git status` say now? Check, then commit what is left:

```bash
$> git commit -am "Add trees of green"
```

{% solution %}

`hello.txt` appears **twice** in the status: once as staged, and once as
modified but not staged.

```bash
$> git status
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   hello.txt

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   hello.txt
```

`git add` put a snapshot of the file **as it was when you ran it** into the
staging area: with "You are beautiful", but without "I see trees of green",
which you wrote afterwards. The working directory and the staging area now hold
two different versions of the same file.

`git diff` shows what is in the working directory but not staged: the second
line. `git diff --cached` shows what is staged: the first line.

```bash
$> git diff
diff --git a/hello.txt b/hello.txt
index 2136a8e..730ea5a 100644
--- a/hello.txt
+++ b/hello.txt
@@ -1,2 +1,3 @@
 Hello World
 You are beautiful
+I see trees of green
$> git diff --cached
diff --git a/hello.txt b/hello.txt
index 557db03..2136a8e 100644
--- a/hello.txt
+++ b/hello.txt
@@ -1 +1,2 @@
 Hello World
+You are beautiful
```

The commit saves the staging area, so it only adds "You are beautiful". After
it, the second line is still there, modified but not staged:

```bash
$> git status
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   hello.txt

no changes added to commit (use "git add" and/or "git commit -a")
```

The last command commits it: the `-a` option stages every modified file that
Git already tracks before committing.

{% endsolution %}

## :exclamation: Ignore a secret

Applications often read secrets, such as database passwords, from files that
must never be shared. Other types of files, such as logs, are also not meant to
be in the repository's permanent history. Create a secret file, and a log file
too:

```bash
$> echo "DB_PASSWORD=ch4ngeme" > .env
$> echo "Starting..." > debug.log
```

Check `git status`: `git add .` would now put your password in the history.
Tell Git to ignore both files, by creating a `.gitignore` file that lists them:

```bash
$> echo ".env" > .gitignore
$> echo "*.log" >> .gitignore
$> cat .gitignore  # check the contents
```

**Predict:** what will `git status` say now? Check, then commit the ignore file:

```bash
$> git add .
$> git commit -m "Ignore secrets and logs"
```

**Question:** why commit the `.gitignore` file, rather than keep it on your
machine?

{% solution %}

The ignored files disappear from the status. Only the new `.gitignore` file is
left, untracked:

```bash
$> git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
        .gitignore

nothing added to commit but untracked files present (use "git add" to track)
```

`git add .` is now safe: it stages the `.gitignore` file, and skips `.env` and
`debug.log`.

The `.gitignore` file is committed so that it is **part of the project**:
everyone who works on it gets the same list, and nobody commits `.env` by
mistake on their own machine.

{% endsolution %}

## :exclamation: A secret committed too late

Your application now needs an API key. Create a file for it, and commit your
work as you usually do:

```bash
$> echo "API_KEY=sk-9f8e7d6c5b4a" > api-key.txt
$> git add .
$> git commit -m "Configure the API"
```

Oops: `api-key.txt` was not in your `.gitignore`, so `git add .` staged it, and
it is now in a commit. Add it to the ignore file, and replace the key with a new
one:

```bash
$> echo "api-key.txt" >> .gitignore
$> echo "API_KEY=sk-0a1b2c3d4e5f" > api-key.txt
```

**Predict:** what will `git status` say about `api-key.txt`? Check.

To make Git stop tracking the file, while keeping it on your disk, remove it
from the staging area only, then commit that along with the ignore file:

```bash
$> git rm --cached api-key.txt
$> git add .gitignore
$> git commit -m "Stop tracking the API key"
```

Check that `api-key.txt` is still in your directory with `ls`, and that
`git status` no longer mentions it.

**Predict:** is the first key, `sk-9f8e7d6c5b4a`, gone from the repository?
Check the history of the file:

```bash
$> git log -p -- api-key.txt
```

{% solution %}

Adding the file to `.gitignore` changes nothing: Git still tracks it, and sees
the new key as a modification:

```bash
$> git status
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   .gitignore
        modified:   api-key.txt
```

**`.gitignore` only applies to files Git does not track yet.** Once a file has
been committed, ignoring it has no effect until you stop tracking it with
`git rm --cached`, which removes it from the staging area without touching your
copy.

The first key is **not gone**. The commit "Configure the API" still contains it,
and always will: every commit is a permanent snapshot.

```bash
$> git log -p -- api-key.txt
...
    Configure the API

diff --git a/api-key.txt b/api-key.txt
new file mode 100644
index 0000000..a4578ba
--- /dev/null
+++ b/api-key.txt
@@ -0,0 +1 @@
+API_KEY=sk-9f8e7d6c5b4a
```

Anyone who gets a copy of this repository gets that key too. Once a secret has
been committed, and especially once the repository has been shared, consider it
**leaked**: the only real fix is to change the secret itself, here by revoking
the key and getting a new one. This is why the `.gitignore` file comes **first**,
before the secret.

{% endsolution %}

{% callout type: more, id: remove-secret-from-history %}

It is possible to remove a file from the **entire history** of a repository,
with dedicated tools such as [`git filter-repo`][git-filter-repo]. But since a
commit is named by the hash of its content, and every commit points to its
parent, this changes the commit that added the file, and **every commit after
it**: they all get new hashes. The result is a different history.

That **comes at a cost**. Everyone else who works on the repository has to throw
away their copy of the old history and start again from the new one, or their
next merge brings the old commits, and the secret, right back. Any work they
based on the old commits has to be moved onto the new ones. It's a perfectly
good way to make your colleagues angry.

And it **does not help with the leak** itself: anyone who copied the repository
before the rewrite still has the secret. So even after rewriting the history,
the secret must be changed. [GitHub's guide to removing sensitive
data][github-sensitive-data] describes the whole procedure.

{% endcallout %}

## :exclamation: Branch and switch

Still in `hello-git`, create a branch:

```bash
$> git branch bye
```

**Predict:** which branch are you on now? Check with `git branch`, which lists
the branches, with a star next to the current one:

```bash
$> git branch
```

Then switch to the new branch, and commit a new file on it:

```bash
$> git switch bye
$> echo "Goodbye World" > goodbye.txt
$> git add goodbye.txt
$> git commit -m "Say goodbye"
```

**Predict:** draw the last few commits of the graph, with the `main`, `bye` and
`HEAD` pointers. Check with `git graph`, and/or with VSCode's Git Graph
extension.

Now switch back:

```bash
$> git switch main
```

**Predict:** does `goodbye.txt` still exist? Will `git log --oneline` show the
"Say goodbye" commit? Check with `ls` and `git log --oneline`. Then switch to
`bye` again, check again, and come back to `main`.

This is what happened in your repository:

<simgit-story name='helloGitBranch' start-chapter='history' end-chapter='back-to-main' sizing='auto-height' commit-representation='below' duration='1200' defer-until-visible='true' replay-on-revisit='true'></simgit-story>

{% solution %}

Creating a branch does not switch to it: the star is still on `main`.

```bash
$> git branch
  bye
* main
```

After the commit, `bye` has moved forward to the new commit, with `HEAD`,
and `main` has stayed where it was:

```bash
$> git graph
* 4d2684e (HEAD -> bye) Say goodbye
* dc04e3e (main) Stop tracking the API key
* 6c3bb3c Configure the API
...
```

On `main`, `goodbye.txt` is gone: switching rewrote the working directory to
match the snapshot `main` points to, which does not have the file. `git log`
only shows the history of the current branch, so "Say goodbye" is not in it.
Switch back to `bye`, and the file is there again: it was never lost, only
stored in the commit.

`api-key.txt`, `debug.log` and `.env` are on both branches: they are ignored, so
Git does not touch them when you switch.

{% endsolution %}

## :exclamation: Two merges

This exercise uses a prepared repository, with a history already made for you.
Get it, and move into it:

```bash
$> cd /path/to/projects
$> git clone https://github.com/ArchiDep/hello-git-merges.git
$> cd hello-git-merges
```

The repository has three branches on GitHub, but cloning only creates `main` on
your machine. Switch to each of the other two once, which creates them, then go
back to `main` and remove the link to GitHub, which you will learn about with
remotes:

```bash
$> git switch fix-typo
$> git switch contact-page
$> git switch main
$> git remote rm origin
```

Look at the graph, with `git graph` and/or with VSCode's Git Graph extension:

<simgit-story name='helloGitMerges' start-chapter='prepared' end-chapter='prepared' sizing='auto-height' commit-representation='below' duration='1200' defer-until-visible='true' replay-on-revisit='true' controls='false'></simgit-story>

You are on `main`. You want to bring both `fix-typo` and `contact-page` into it.

**Predict**, for each branch, before merging it:

- Will the merge be a fast-forward, or will Git create a merge commit?
- What will the graph look like afterwards? Draw it.

Then merge them, one after the other, and check each prediction with
`git graph`:

```bash
$> git merge fix-typo
$> git merge contact-page
```

The second merge opens your editor with a commit message that Git has written
for you. Keep it as it is, and exit: in nano, press `Ctrl-X`. If you find
yourself in Vim instead, see [I am stuck in Vim](#i-am-stuck-in-vim).

This is what happened:

<simgit-story name='helloGitMerges' start-chapter='prepared' end-chapter='three-way' sizing='auto-height' commit-representation='below' duration='1200' defer-until-visible='true' replay-on-revisit='true'></simgit-story>

{% solution %}

`fix-typo` is **directly ahead** of `main`: its commit comes right after the one
`main` points to. Git only has to move `main` forward, a **fast-forward**, and
creates no commit:

```bash
$> git merge fix-typo
Updating b85d48f..27d2a53
Fast-forward
 about.html | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

`contact-page` has **diverged** from `main`: it was created from "Add an about
page", and `main` has two more commits since. Git performs a **three-way merge**
from the common ancestor, `3947df4`, and creates a merge commit with two
parents:

```bash
$> git merge contact-page
Merge made by the 'ort' strategy.
 contact.html | 11 +++++++++++
 index.html   |  1 +
 2 files changed, 12 insertions(+)
 create mode 100644 contact.html
$> git graph
*   b91b87f (HEAD -> main) Merge branch 'contact-page'
|\
| * 54bd3ee (contact-page) Link to the contact page
| * 591343f Add a contact page
* | 27d2a53 (fix-typo) Fix a typo on the about page
* | b85d48f Improve the style
|/
* 3947df4 Add an about page
* 72208e4 Create the home page
```

Your merge commit's hash will be different from `b91b87f`, but the other hashes
will be the same as these, since you cloned these commits.

{% endsolution %}

### :space_invader: Merge in the reverse order

This question is harder, and optional.

**Predict:** what if you had merged `contact-page` first, then `fix-typo`? Would
`fix-typo` still be merged as a fast-forward? Draw the graph you would end up
with.

Then check, in a second copy of the repository, cloned into another directory:

```bash
$> cd /path/to/projects
$> git clone https://github.com/ArchiDep/hello-git-merges.git hello-git-reversed
$> cd hello-git-reversed
$> git switch fix-typo
$> git switch contact-page
$> git switch main
$> git remote rm origin
$> git merge contact-page
$> git merge fix-typo
```

Both merges open your editor: keep each message as it is, and exit.

This is what happens:

<simgit-story name='helloGitMergesReversed' start-chapter='prepared' end-chapter='fix-typo-second' sizing='auto-height' commit-representation='below' duration='1200' defer-until-visible='true' replay-on-revisit='true'></simgit-story>

{% solution %}

No: this time, `fix-typo` needs a merge commit too.

Merging `contact-page` first is a three-way merge, as before, and creates a merge
commit on `main`. But `fix-typo` does not have that merge commit in its history:
`main` has moved on since `fix-typo` was created, so the two have diverged, and
merging `fix-typo` is a second three-way merge, with a second merge commit:

```bash
$> git merge fix-typo
Merge made by the 'ort' strategy.
 about.html | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
$> git graph
*   a2e7d63 (HEAD -> main) Merge branch 'fix-typo'
|\
| * 27d2a53 (fix-typo) Fix a typo on the about page
* |   b175f11 Merge branch 'contact-page'
|\ \
| |/
|/|
| * 54bd3ee (contact-page) Link to the contact page
| * 591343f Add a contact page
* | b85d48f Improve the style
|/
* 3947df4 Add an about page
* 72208e4 Create the home page
```

The two branches, and the changes they bring, are the same as before, and so are
the files you end up with. But the history is different. Whether a merge can be
a fast-forward does not depend on the branch you merge: it depends on the shape
of the history **at the moment you merge it**.

{% endsolution %}

## :checkered_flag: What have I done?

You created a repository and made commits, and each prediction checked one piece
of how Git works:

- A new file is **untracked** until you add it, and a commit contains **only
  what is staged**.
- The working directory, the staging area and the repository are **three
  separate places**. `git add` puts a snapshot of a file in the staging area as
  it is at that moment, which is why a file can be both staged and modified.
  `git diff` and `git diff --cached` show you the difference between them.
- `.gitignore` keeps files out of the repository, but only files Git does not
  track yet. A secret that has been committed stays in the history: the only
  real fix is to change the secret.
- A branch is a pointer to a commit. Switching moves `HEAD` and rewrites the
  files of your working directory to match another snapshot.
- Whether a merge is a fast-forward or creates a merge commit depends on the
  shape of the history when you merge.

## :question: Going further

The exercises below are **optional**. They practise other Git commands that are
useful in everyday work, but that you will not be asked about in the exam. Do
them in your `hello-git` repository, on `main`, and use `git status` after each
step to see what happened.

### :question: Unstage a file

Modify a file and stage it:

```bash
$> echo "Hi Jane" >> hi.txt
$> git add hi.txt
```

Check with `git status` that the change is staged. Then take it back out of the
staging area:

```bash
$> git restore --staged hi.txt
```

Check again with `git status` and `cat hi.txt`: the change is no longer staged,
but it is still in the file.

### :question: Discard a change

Throw the change away:

```bash
$> git restore hi.txt
```

Check with `git status` and `cat hi.txt`. The change is gone for good: it was
never committed, so Git has no copy of it.

### :question: Fix the last commit's message

Make a commit with a typo in its message:

```bash
$> echo "Hi Steve" >> hi.txt
$> git commit -am "Greet Stve"  # add and commit in one step
                                # with -am (same as -a and -m)
```

Look at it with `git log --oneline`, and note its hash. Then fix the message:

```bash
$> git commit --amend -m "Greet Steve"
```

**Predict:** will the commit still have the same hash? Check with
`git log --oneline`. Why?

### :question: Add a forgotten file to the last commit

Create two files, but only stage one of them before committing:

```bash
$> echo "a" > a.txt
$> echo "b" > b.txt
$> git add a.txt
$> git commit -m "Add a and b"
```

Check with `git log --stat -1`, which shows the files changed by the last
commit: `b.txt` is not in it. Note the commit's hash, then add the file to the
same commit:

```bash
$> git add b.txt
$> git commit --amend
```

Your editor opens with the commit's message. Keep it as it is, and exit: in
nano, press `Ctrl-X`. Check again with `git log --stat -1` that the commit now
contains both files.

**Predict:** is it still the same commit? Compare its hash with the one you
noted. Why has it changed, although the message is the same?

{% solution %}

The hash has changed: amending does not modify the commit, it **replaces** it
with a new one. A commit is named by the hash of its content, and its content
now includes `b.txt`, so it is a different commit. The same happens when you
only fix the message, since the message is part of the content too. The old
commit is no longer on any branch.

This is why you should not amend a commit you have already shared: the others
still have the old commit, and their history no longer matches yours.

{% endsolution %}

### :question: The limits of `commit -a`

Modify `hi.txt` and create a new file, `new.txt`, then commit with `-a` only:

```bash
$> echo "Hi Alice" >> hi.txt
$> echo "new" > new.txt
$> git commit -am "Greet Alice"
```

Which of the two changes did the commit include? Why?

### :question: Rename a file

Rename a file with the `mv` command, and look at `git status`. Then stage
everything with `git add .`, and look again. What changed in how Git describes
it?

### :question: The global ignore file

Some files are created by your operating system or your editor in every
directory, such as `.DS_Store` on macOS. Rather than ignoring them in every
project, ignore them once for your whole computer:

```bash
$> echo ".DS_Store" >> ~/.gitignore  # the .gitignore file in your home
$> git config --global core.excludesFile ~/.gitignore
```

### :question: Travel back in time

Switch to an old commit, using a hash from `git log --oneline`:

```bash
$> git switch --detach a82bb9b
```

Look at your files, and at `git status`, which says `HEAD detached`: `HEAD`
points directly to a commit instead of a branch. Come back with
`git switch main`.

### :question: Delete an unmerged branch

Your `bye` branch was never merged. Try to delete it with `-d`, then with `-D`.
Where did the "Say goodbye" commit go?

Look for it with `git reflog`, which lists every commit `HEAD` has pointed to
recently, and create a branch pointing to it again with `git branch welcome-back
<hash>`.

## :boom: Troubleshooting

Here are a few problems you may run into during these exercises.

### :boom: `fatal: not a git repository`

You are not in a repository. Check where you are with `pwd`, and move into your
repository's directory with `cd`. This is expected in [create a
repository](#create-a-repository), before `git init`.

### :boom: `Author identity unknown`

Git does not know your name and e-mail address, so it cannot record the author
of your commit, and refuses to make it:

```bash
$> git commit -m "Add hello.txt"
Author identity unknown

*** Please tell me who you are.
...
fatal: unable to auto-detect email address (got 'jdoe@DESKTOP-ABC123.(none)')
```

Set them as described in [who are you?](#who-are-you), then run your commit
again.

### :boom: `Your name and email address were configured automatically`

Git did not know your name and e-mail address, so it made them up from your
computer's user name and name, and **made the commit** with them:

```bash
$> git commit -m "Add hello.txt"
[main (root-commit) a82bb9b] Add hello.txt
 Committer: jdoe <jdoe@MacBook-Pro.local>
Your name and email address were configured automatically based
on your username and hostname. Please check that they are accurate.
...
```

Set them as described in [who are you?](#who-are-you). Then fix the commit you
just made, which replaces its author with your new identity:

```bash
$> git commit --amend --reset-author
```

Your editor opens with the commit's message. Keep it as it is, and exit: in
nano, press `Ctrl-X`.

### :boom: `hint: Using 'master' as the name for the initial branch`

Git does not know which name to give the first branch of a new repository, so
`git init` used `master`, and printed a long hint:

```bash
$> git init
hint: Using 'master' as the name for the initial branch. This default branch name
hint: will change to "main" in Git 3.0. To configure the initial branch name
...
```

Set the default as described in [the default branch](#the-default-branch), for
your next repositories. Then rename the branch of the repository you just
created:

```bash
$> git branch -m main
```

### :boom: I am stuck in Vim

Git opened Vim to let you write or confirm a message. Press `Esc`, then type
`:q!` and press `Enter`. For a merge, Git then uses its own message; for a
commit, the message is empty and Git cancels the commit. To have Git open nano
instead, see [your editor](#your-editor).

### :boom: `git log` or `git diff` does not give my prompt back

The output was longer than your terminal, so Git shows it one screen at a time.
Scroll with the arrow keys, and press `q` to quit.

### :boom: `merge: fix-typo - not something we can merge`

The branch does not exist on your machine: you removed the link to GitHub before
switching to it. Delete the `hello-git-merges` directory, clone it again, and
follow the steps in [two merges](#two-merges) in order.

[git]: https://git-scm.com/
[git-filter-repo]: https://github.com/newren/git-filter-repo
[git-graph]: https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph
[github-sensitive-data]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
[install-git]: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
[vscode]: https://code.visualstudio.com
