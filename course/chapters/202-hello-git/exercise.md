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

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

The directory is not a repository, and neither is any of its parents:

```bash
$> git status
fatal: not a git repository (or any of the parent directories): .git
```

This is how you check that you are **not** already in a repository before
running `git init`. If `git status` had printed a status instead, you would have
been inside an existing repository, and `git init` would have created a second
one nested inside it.

{% endsolution %}

Now turn the directory into a repository:

```bash
$> git init
Initialized empty Git repository in /path/to/projects/hello-git/.git/
```

**Predict:** what will `git status` print now? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

The repository exists, but it has no commits yet:

```bash
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

**Predict:** how will `git status` describe these two files? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

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

{% endsolution %}

Now stage only one of them:

```bash
$> git add hello.txt
```

**Predict:** what will `git status` say now? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

Only `hello.txt` is staged, and `hi.txt` is still untracked:

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

{% endsolution %}

Look at what is staged with `git diff --cached`. It shows the one line of the
new file:

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

You are about to commit with `git commit -m "Add hello.txt"`.

**Predict:** which files will be in this commit?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

Only `hello.txt`. A commit contains **only what is staged**: `hi.txt` is not, so
it stays untracked, outside the commit.

{% endsolution %}

Commit:

```bash
$> git commit -m "Add hello.txt"
[main (root-commit) a82bb9b] Add hello.txt
 1 file changed, 1 insertion(+)
 create mode 100644 hello.txt
```

Your commit's hash will be different from `a82bb9b`: it is computed from the
commit's content, which includes your name and the date.

Check with `git status` that `hi.txt` is still untracked, and look at the
history with `git log`.

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

**Predict:** what will `git status` say about `hello.txt`? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

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

{% endsolution %}

**Predict:** which line will `git diff` show? Then check:

```bash
$> git diff
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

`git diff` compares the working directory with the staging area. It shows what
you have changed but not staged: the second line.

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
```

{% endsolution %}

**Predict:** which line will `git diff --cached` show? Then check:

```bash
$> git diff --cached
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

`git diff --cached` compares the staging area with the last commit. It shows
what you have staged: the first line.

```bash
$> git diff --cached
diff --git a/hello.txt b/hello.txt
index 557db03..2136a8e 100644
--- a/hello.txt
+++ b/hello.txt
@@ -1 +1,2 @@
 Hello World
+You are beautiful
```

{% endsolution %}

You are about to commit with `git commit -m "Tell the world it is beautiful"`.

**Predict:** which lines will this commit add?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

Only "You are beautiful". A commit saves the staging area, not the working
directory, so it saves the version of `hello.txt` that `git diff --cached`
showed you.

{% endsolution %}

Commit:

```bash
$> git commit -m "Tell the world it is beautiful"
```

**Predict:** what will `git status` say now? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

The second line is still there, modified but not staged:

```bash
$> git status
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   hello.txt

no changes added to commit (use "git add" and/or "git commit -a")
```

{% endsolution %}

Commit what is left:

```bash
$> git commit -am "Add trees of green"
```

The `-a` option stages every modified file that Git already tracks before
committing.

## :exclamation: Ignore a secret

Applications often read secrets, such as database passwords, from files that
must never be shared. Other types of files, such as logs, are also not meant to
be in the repository's permanent history. Create a secret file, and a log file
too:

```bash
$> echo "DB_PASSWORD=ch4ngeme" > .env
$> echo "Starting..." > debug.log
```

Check the status:

```bash
$> git status
On branch main
Untracked files:
  (use "git add <file>..." to include in what will be committed)
        .env
        debug.log

nothing added to commit but untracked files present (use "git add" to track)
```

Both files are untracked, so `git add .` would now put your password in the
history. Tell Git to ignore both files, by creating a `.gitignore` file that
lists them:

```bash
$> echo ".env" > .gitignore
$> echo "*.log" >> .gitignore
$> cat .gitignore  # check the contents
```

**Predict:** what will `git status` say now? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

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

{% endsolution %}

`git add .` is now safe: it stages the `.gitignore` file, and skips `.env` and
`debug.log`. Commit the ignore file:

```bash
$> git add .
$> git commit -m "Ignore secrets and logs"
```

**Question:** why commit the `.gitignore` file, rather than keep it on your
machine?

{% solution title: "Check your answer", emoji: thinking, reveal: always %}

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

**Predict:** what will `git status` say about `api-key.txt`? Then check:

```bash
$> git status
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

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
been committed, ignoring it has no effect until you stop tracking it.

{% endsolution %}

To make Git stop tracking the file, while keeping it on your disk, remove it
from the staging area only, then commit that along with the ignore file:

```bash
$> git rm --cached api-key.txt
$> git add .gitignore
$> git commit -m "Stop tracking the API key"
```

Check that `api-key.txt` is still in your directory with `ls`, and that
`git status` no longer mentions it.

**Predict:** is the first key, `sk-9f8e7d6c5b4a`, gone from the repository? Then
check the history of the file:

```bash
$> git log -p -- api-key.txt
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

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

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

Creating a branch does not switch to it: the star is still on `main`.

```bash
$> git branch
  bye
* main
```

{% endsolution %}

Then switch to the new branch, and commit a new file on it:

```bash
$> git switch bye
$> echo "Goodbye World" > goodbye.txt
$> git add goodbye.txt
$> git commit -m "Say goodbye"
```

**Predict:** here are the last few commits of the graph, with the `main`, `bye`
and `HEAD` pointers, before you switched to `bye` and committed. Predict what
the graph looks like now, after the switch and the commit. Then play the diagram
to check your prediction:

<simgit-story name='helloGitBranch' start-chapter='branch' end-chapter='commit' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

`bye` has moved forward to the new commit, with `HEAD`, and `main` has stayed
where it was. Check yours with `git graph`, and/or with VSCode's Git Graph
extension:

```bash
$> git graph
* 4d2684e (HEAD -> bye) Say goodbye
* dc04e3e (main) Stop tracking the API key
* 6c3bb3c Configure the API
...
```

{% endsolution %}

Now switch back:

```bash
$> git switch main
```

**Predict:** predict what the switch changes in the graph. Then play the diagram
to check your prediction:

<simgit-story name='helloGitBranch' start-chapter='commit' end-chapter='back-to-main' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

**Predict:** does `goodbye.txt` still exist? Then check with `ls`.

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

No: switching rewrote the working directory to match the snapshot `main` points
to, which does not have the file.

`api-key.txt`, `debug.log` and `.env` are still there: they are ignored, so Git
does not touch them when you switch.

{% endsolution %}

**Predict:** will `git log --oneline` show the "Say goodbye" commit? Then check:

```bash
$> git log --oneline
```

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

No: `git log` only shows the history of the commit `HEAD` points to, and "Say
goodbye" is not in the history of `main`. `git graph` shows it because of its
`--all` option, which shows the history of every branch.

{% endsolution %}

Switch to `bye` again: `goodbye.txt` is there again, and "Say goodbye" is in the
history. The file was never lost, only stored in the commit. Then come back to
`main`.

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

You are on `main`. You want to bring both `fix-typo` and `contact-page` into it,
one after the other.

### :exclamation: Merge `fix-typo`

You are going to merge `fix-typo` into `main`, with `git merge fix-typo`.

**Predict:** will the merge be a fast-forward, or will Git create a merge
commit?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

A fast-forward. `fix-typo` is **directly ahead** of `main`: its commit comes
right after the one `main` points to. Git only has to move `main` forward, and
creates no commit.

{% endsolution %}

Merge:

```bash
$> git merge fix-typo
Updating b85d48f..27d2a53
Fast-forward
 about.html | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

**Predict:** predict what the merge changes in the graph. Then play the diagram
to check your prediction:

<simgit-story name='helloGitMerges' start-chapter='prepared' end-chapter='fast-forward' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

### :exclamation: Merge `contact-page`

You are now going to merge `contact-page` into `main`, with
`git merge contact-page`.

**Predict:** will the merge be a fast-forward, or will Git create a merge
commit?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

A merge commit. `contact-page` has **diverged** from `main`: it was created from
"Add an about page", and `main` has two more commits since. Git performs a
**three-way merge** from the common ancestor, `3947df4`, and creates a merge
commit with two parents.

{% endsolution %}

Merge. This time, Git opens your editor with a commit message that it has
written for you. Keep it as it is, and exit: in nano, press `Ctrl-X`. If you
find yourself in Vim instead, see [I am stuck in Vim](#i-am-stuck-in-vim).

```bash
$> git merge contact-page
Merge made by the 'ort' strategy.
 contact.html | 11 +++++++++++
 index.html   |  1 +
 2 files changed, 12 insertions(+)
 create mode 100644 contact.html
```

**Predict:** predict what the merge changes in the graph. Then play the diagram
to check your prediction:

<simgit-story name='helloGitMerges' start-chapter='fast-forward' end-chapter='three-way' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

Check yours with `git graph`:

```bash
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
`fix-typo` still be merged as a fast-forward?

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

No: this time, `fix-typo` needs a merge commit too.

Merging `contact-page` first is a three-way merge, as before, and creates a merge
commit on `main`. But `fix-typo` does not have that merge commit in its history:
`main` has moved on since `fix-typo` was created, so the two have diverged, and
merging `fix-typo` is a second three-way merge, with a second merge commit.

Whether a merge can be a fast-forward does not depend on the branch you merge:
it depends on the shape of the history **at the moment you merge it**.

{% endsolution %}

Check it, in a second copy of the repository, cloned into another directory:

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

**Predict:** predict the graph you end up with. Then play the diagram to check
your prediction:

<simgit-story name='helloGitMergesReversed' start-chapter='prepared' end-chapter='fix-typo-second' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

Check yours with `git graph`:

```bash
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
the files you end up with. But the history is different: two merge commits
instead of one.

{% endsolution %}

## :question: History hunt

This exercise is **optional**. Every project on GitHub comes with its whole
history, and you can search it without leaving your terminal. Clone the
repository of [2048][2048], the puzzle game that went viral in 2014, next to
your `hello-git` directory (not inside it):

```bash
$> cd /path/to/projects
$> git clone https://github.com/gabrielecirulli/2048.git
$> cd 2048
```

Then answer the questions below. Each one names the command that finds the
answer. Remember that you leave `git log` by pressing `q`.

**The first commit**

When was the first commit of the game made, and by whom? What was its message?

`git log` shows the most recent commits first. `git log --reverse` shows the
oldest first.

{% solution title: "Answer", reveal: always %}

```bash
$> git log --reverse
commit f4d95b6...
Author: Gabriele Cirulli <...>
Date:   Wed Mar 5 15:20:56 2014 +0100

    initial commit
```

Gabriele Cirulli made it on 5 March 2014. The rest of that day's commits style
the page and write the README: the code that moves the tiles only arrives three
days later.

{% endsolution %}

**Ads for a day**

In 2018, the author added ads to the game. How long did they stay?

`git log --grep <text>` only shows the commits whose message contains the text,
and `-i` makes the search ignore uppercase and lowercase.

{% solution title: "Answer", reveal: always %}

```bash
$> git log -i --grep ads
commit fc1ef4f...
Author: Gabriele Cirulli <...>
Date:   Sat Oct 27 18:25:12 2018 +0200

    Remove Adsense code

commit ffa8559...
Author: Gabriele Cirulli <...>
Date:   Sat Oct 27 13:21:45 2018 +0200

    Add AdSense code
```

About five hours, on 27 October 2018. The messages say "AdSense" and "Adsense",
Google's advertising service, which both contain "Ads" with a capital A: without
`-i`, `git log --grep ads` finds nothing.

{% endsolution %}

**How do you win?**

Find the commit that added the win condition, and look at the code it added.
What exactly makes you win?

Search the messages with `--grep`, then show the commit with
`git show <hash>`, which prints its message and its changes.

{% solution title: "Answer", reveal: always %}

```bash
$> git log --oneline --grep win
...
e65111f add win condition
$> git show e65111f
...
+          // The mighty 2048 tile
+          if (merged.value === 2048) self.won = true;
```

You win as soon as two tiles merge into a 2048 tile.

{% endsolution %}

**The best score**

The game remembers your best score in the browser's storage, `localStorage`.
Who wrote the commit that first used it?

A commit message does not always name what the code does. `git log -S <text>`
searches the changes instead: it shows the commits that added or removed the
text.

{% solution title: "Answer", reveal: always %}

```bash
$> git log --oneline --reverse -S localStorage
664546e Store best score in localStorage
...
$> git show 664546e
commit 664546e...
Author: Tim Petricola <...>
```

Tim Petricola, on 10 March 2014, five days after the first commit. This one
could also be found with `--grep "best score"`, but `-S` finds code whatever the
message says.

{% endsolution %}

**Who helped?**

How many people have made commits in this project, and who made the most after
its author?

`git shortlog -sn` counts the commits of each author.

{% solution title: "Answer", reveal: always %}

```bash
$> git shortlog -sn
   131  Gabriele Cirulli
     6  Laurent Margirier
     6  sigod
     5  Tim Petricola
...
```

28 names, and Laurent Margirier and sigod tie after the author. But a name is
only what each author configured with `git config user.name`: the README says
that Anna Harren's GitHub account is `iirelu`, and both names are in the list.

{% endsolution %}

**Three commits with the same message**

The user `rayhaanj` made three commits with the same message. Find them with
`git log --author`, and look at each one with `git show`. What are they, and why
are there three?

{% solution title: "Answer", reveal: always %}

```bash
$> git log --oneline --author rayhaanj
96e9290 Added vim keybindings
fb8eabe Added vim keybindings
29c4bea Added vim keybindings
```

`29c4bea` and `fb8eabe` add the same keyboard shortcuts, H, J, K and L, which
move around in Vim. Both start from the same parent, and they only differ by a
space. `96e9290` is a merge commit: `git show` prints a `Merge:` line with its
two parents, the two other commits. Their author made the change twice on
diverging histories, and merged them. You can see it by drawing the graph from
the merge commit rather than from the latest one: `git graph -4 96e9290` (or
`git log --graph --oneline -4 96e9290` if you did not create the alias).

The shortcuts are still in the game today: try them. And the message, three
times the same, cannot tell the three commits apart.

{% endsolution %}

**A renamed file**

The game's stylesheet is `style/main.scss`. Has it always had that name?

`git log -- <file>` shows only the commits that changed a file, and `--follow`
keeps following it when it was renamed. Compare the two, and add
`--name-status` to see what each commit did to the file.

{% solution title: "Answer", reveal: always %}

```bash
$> git log --oneline --follow --name-status -- style/main.scss
...
a26e1c6 rename style.scss to main.scss
R100    style/style.scss        style/main.scss
22ef3be move css to style dir
R100    style.scss      style/style.scss
b0bf6c5 basic tile styling
M       style.scss
3403e78 basic styling
A       style.scss
```

It was created as `style.scss` at the root of the project in the second commit,
then moved into `style`, then renamed to `main.scss`. Without `--follow`, the
history stops at the last rename. `A`, `M` and `R` mean added, modified and
renamed.

{% endsolution %}

## :checkered_flag: What have I done?

You kept the history of a project: every version you committed is still there,
to go back to, compare, or build on in parallel. All of it lives in the hidden
`.git` directory at the root of your project, the **Git directory**. Without it,
your files stay but their history is gone. Copied elsewhere, it carries the
whole history with it, which is what `git clone` does.

Along the way, you:

- Created a repository and made commits.
- Committed a file that was both staged and modified.
- Ignored files, and stopped tracking one that was committed too late.
- Created branches, switched between them, and merged them.
- (Optionally) searched the history of a real project.

A commit saves the **staging area**, not your files. Git keeps your project in
three places: the working directory, where you edit; the staging area, where you
prepare the next commit; and the Git directory, where commits are stored. `git
add` copies a file from the first to the second as it is at that moment, which
is how `hello.txt` could be both staged and modified. `git status` tells you
where each change is.

A commit is a snapshot of the whole project, named by the **hash** of its
content. Change anything in it, even its author or its date, and it becomes a
different commit, which is why the commits you made do not have the hashes shown
on this page. A commit, once made, never changes.

That is why your first API key is still in the history, even after you stopped
tracking it, and anyone with a copy has it. The only real fix for a committed
secret is to change it. `.gitignore` only protects files Git does not track yet,
so it has to come **before** the secret, and it is committed so that everyone on
the project shares it. Keeping secrets out of the code comes back later in the
course.

A **branch** is only a pointer to a commit, and `HEAD` says which one you are
on. Committing moves the current branch forward. Switching moves `HEAD` and
rewrites your working directory to match another snapshot. Nothing is lost when
you switch: `goodbye.txt` disappeared from `main`, but it was still in the
commit of `bye`.

How Git **merges** depends only on the shape of the history. When the other
branch is directly ahead, as `fix-typo` was, Git just moves the pointer forward:
a fast-forward. When the two have diverged, as `contact-page` had, Git combines
what each side changed since their common ancestor into a merge commit, which
has two parents. Merged in another order, the same branches give the same files
but a different history.

If you went on the history hunt, you also saw that a history is something you
can search, and that an author's name is only what they configured.

So far, your history has lived in a single copy, on your computer. In
[Collaborating with Git][collaborating], you share it with others through a
remote, where diverged histories come back as refused pushes and conflicts.
Later in the course, a repository is also how you put your application on your
server.

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

**Predict:** will the commit still have the same hash? Why? Then check with
`git log --oneline`.

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

No. Amending does not modify the commit, it **replaces** it with a new one. A
commit is named by the hash of its content, and its message is part of that
content, so a new message makes a different commit. The old commit is no longer
on any branch.

{% endsolution %}

This is why you should not amend a commit you have already shared: the others
still have the old commit, and their history no longer matches yours.

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

{% solution title: "Check your prediction", emoji: thinking, reveal: always %}

No. The files a commit contains are part of its content too, and they now
include `b.txt`: amending replaced the commit with a new one, as it did for the
message.

{% endsolution %}

### :question: The limits of `commit -a`

Modify `hi.txt` and create a new file, `new.txt`, then commit with `-a` only:

```bash
$> echo "Hi Alice" >> hi.txt
$> echo "new" > new.txt
$> git commit -am "Greet Alice"
```

Which of the two changes did the commit include? Why?

{% solution title: "Check your answer", reveal: always %}

Only the change to `hi.txt`. The `-a` option stages the modified files that Git
**already tracks**. `new.txt` is untracked, so it is not in the commit, and
`git status` still lists it as untracked. A new file always needs a `git add`.

{% endsolution %}

### :question: Rename a file

Rename a file with the `mv` command (or in your editor), and look at `git
status`. Then stage everything with `git add .`, and look again. What changed in
how Git describes it?

{% solution title: "Check your answer", reveal: always %}

Before `git add`, Git sees two separate changes: a tracked file that has been
deleted, and a new file that is untracked. For example, after
`mv hello.txt hola.txt`:

```bash
$> git status
...
        deleted:    hello.txt
...
Untracked files:
        hola.txt
```

Once both are staged, Git notices that the new file has the same content as the
deleted one, and describes them as one rename:

```bash
$> git add .
$> git status
...
        renamed:    hello.txt -> hola.txt
```

Git does not record renames: a commit is a snapshot, which only says which files
exist and what they contain. Git works the rename out when it compares two
snapshots, from the content of the files.

{% endsolution %}

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

{% solution title: "Check your answer", reveal: always %}

`-d` refuses, because "Say goodbye" is not in the history of any other branch:
deleting `bye` would leave no branch leading to it. `-D` deletes it anyway:

```bash
$> git branch -d bye
error: the branch 'bye' is not fully merged
...
$> git branch -D bye
Deleted branch bye (was 4d2684e).
```

The commit is still in the repository. Only the pointer is gone: a branch is a
pointer to a commit, and deleting it does not delete the commit. But no branch
leads to it any more, so `git log` and `git graph` no longer show it, and Git
will eventually clean it up.

{% endsolution %}

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

[2048]: https://gabrielecirulli.github.io/2048/

[collaborating]: {% link chapters/203-git-collaborating/subject.md %}
[git]: https://git-scm.com/
[git-filter-repo]: https://github.com/newren/git-filter-repo
[git-graph]: https://marketplace.visualstudio.com/items?itemName=mhutchie.git-graph
[github-sensitive-data]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
[install-git]: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
[vscode]: https://code.visualstudio.com
