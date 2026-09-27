---
title: Guess It
excerpt_separator: <!-- more -->
---

Collaborate on [GitHub][github] as a team of two or three: fork an incomplete
application, push and pull each other's changes, resolve a conflict, then finish
the application together.

<!-- more -->

**You will need**

- [Git][git]
- A free [GitHub][github] account each, with your SSH key
- A Unix CLI
- [Node.js][node] 26 and a [PostgreSQL][postgres] server, version 14 or newer,
  for the second part

**Recommended reading**

- [Version Control with Git]({% link chapters/201-git/subject.md %})
- [Collaborating with Git]({% link chapters/203-git-collaborating/subject.md %})

**Going further**

- [Git Branching - Remote Branches](https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches)
- [Distributed Git](https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows)

The application is [Guess It][ex-repo], a guess-the-number game with a
leaderboard. It is written in JavaScript for [Node.js][node] and stores its
games in a [PostgreSQL][postgres] database. All its code is in one file,
`server.js`, and three of its database queries are missing.

The exercise has two parts:

1. **Together, step by step**: you fork the application, clone it, and share
   changes through GitHub. Your pushes will be refused, and you will resolve a
   conflict. Nothing in this part needs the application to run.
2. **Then on your own**: you install what the application needs, run it, and
   each implement one of the missing queries.

Your group's fork is the application you will deploy in every deployment
exercise for the rest of the course. Keep it, and keep your group.

## :exclamation: Form your group

Form a group of two or three. Throughout this exercise, the members of the group
are referred to as **Alice**, **Bob** and, in a group of three, **Chuck**.
Decide who is who.

Each step is for the member named in its title. A step for **Chuck** is only
for groups of three: a group of two skips it.

The first part is a script. **Do the steps in order, and wait for each other**:
some steps only work once another member has finished the one before. If your
group gets lost, delete the clones and the fork, and start this part over.

Along the way, you are asked to **predict** what Git will do, one question at a
time. Write your prediction down before you check it:

- Some questions have an answer you can reveal right below them. Reveal it
  before you run the command the question is about.
- Others ask you to predict what a command changes in the repositories. They
  come with a diagram that does not play by itself: it shows the repositories
  before the command. Make your prediction (in your mind or on paper), then play
  the diagram with its controls to check it.

Each diagram shows GitHub and one or two members of the group, whoever the step
is about.

## :exclamation: Everyone: check your SSH key on GitHub

Everyone does this step. You will talk to GitHub over SSH, with a key pair of
your own. You may or may not have already added your public key to GitHub
already. Let's check.

Display the fingerprint of your public key:

```bash
$> ssh-keygen -lf ~/.ssh/id_ed25519.pub
256 SHA256:+9n19lW3aaw4kfotwaDm7Gt3FO1x1EAwJi8CcUyY6oE name@host (ED25519)
```

Then, on GitHub, open the **SSH and GPG keys** section of your account settings:

{% cols %}

![GitHub settings](images/github-settings.png)

<!-- col -->

![GitHub SSH settings](images/github-settings-ssh.png)

{% endcols %}

Each key listed there is shown with its fingerprint.

{% callout type: exercise %}

If one of your keys on GitHub has the same fingerprint as your local public key,
your key is already there: [skip to the next step](#alice-fork-the-repository).

{% endcallout %}

If the list is empty, or no fingerprint matches, perform the next two optional
steps.

{% note %}

If `ssh-keygen` fails with _"No such file or directory"_, you may have an older
key: try `ssh-keygen -lf ~/.ssh/id_rsa.pub`. If that fails too, you have no key
yet.

{% endnote %}

### :question: Create an SSH key

If you do not already have a key, create one with `ssh-keygen`, and press Enter
at every prompt to keep the defaults:

```bash
$> ssh-keygen
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/jdoe/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/jdoe/.ssh/id_ed25519
Your public key has been saved in /home/jdoe/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:+9n19lW3aaw4kfotwaDm7Gt3FO1x1EAwJi8CcUyY6oE name@host
```

{% note type: tip %}

Read [SSH Key Protection]({% link chapters/103-ssh/subject.md %}#key-protection)
again as a reminder on whether or not to set a passphrase.

{% endnote %}

### :question: Add your key to GitHub

If your **public key** is not already on GitHub, display and copy it:

```bash
$> cat ~/.ssh/id_ed25519.pub
ssh-ed25519 AAAAC3NzaC1... jde@example
```

{% callout type: warning %}

**Never** copy or share your private key, the `~/.ssh/id_ed25519` file without
`.pub`.

{% endcallout %}

In the **SSH and GPG keys** section of your GitHub settings, add a new SSH key,
and paste your public key there:

![GitHub SSH key creation](images/github-settings-ssh-key.png)

The title of the key is up to you. It is useful when you have several keys, to
remember which is which.

Check the fingerprints again: the key GitHub now lists must have the fingerprint
`ssh-keygen -lf` prints.

## :exclamation: Alice: fork the repository

**Alice** opens the [`ArchiDep/guessit-ex` repository][ex-repo] in her browser,
and clicks the **Fork** button in the top-right corner of the page:

![Fork](images/fork.png)

This creates a copy of the repository on GitHub that belongs to Alice, under her
GitHub username instead of `ArchiDep`. It is the group's repository from now on.

## :exclamation: Alice: invite Bob (and Chuck)

Only the owner of a repository can push to it. For the others to push, the owner
must add them as **collaborators**.

**Alice** opens the settings of her fork, and adds the GitHub usernames of
**Bob** (and **Chuck** for groups of three) as collaborators:

![GitHub collaborators](images/github-collaborators.png)

## :exclamation: Bob (and Chuck): accept the invitation

**Bob** and **Chuck** must then **accept the invitation**, sent to them by
email, before they can push.

## :exclamation: Everyone: configure `git pull`

Everyone does this step. Later on, `git pull` has to combine your work with
someone else's. Git refuses to do it until you have told it how, so check what
yours is set to:

```bash
$> git config pull.rebase
false
```

If it prints nothing, set it:

```bash
$> git config --global pull.rebase false
```

With this setting, `git pull` combines diverging work with a merge commit, as
`git merge` does.

## :exclamation: Everyone: clone the fork

Everyone, Alice included, clones **Alice's fork**. On its page on GitHub, copy
its **SSH** URL, not the HTTPS one:

![GitHub clone with SSH URL](images/github-clone.png)

{% callout type: warning %}

Make sure to clone Alice's fork, under her username, and **not** the repository
from the `ArchiDep` organization, or you will not be able to push your commits
later.

{% endcallout %}

Clone it into your projects directory:

```bash
$> cd /path/to/projects
$> git clone git@github.com:alice/guessit-ex.git
Cloning into 'guessit-ex'...
...
$> cd guessit-ex
```

{% note type: tip %}

If this is your first connection to GitHub over SSH, your SSH client warns you
that it does not know this server, and shows you the fingerprint of its key
before anything is transferred:

```
The authenticity of host 'github.com (W.X.Y.Z)' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

GitHub is one of the services that [publish their SSH key
fingerprints][github-fingerprints], so you have a trusted source to check
against. Compare the fingerprint in the warning with the published one for the
same algorithm by eye, or, instead of answering `yes`, paste that published
fingerprint (the full `SHA256:...` value) at the prompt, which has your SSH
client make the comparison and refuse to connect if they differ.

{% endnote %}

**Predict:** predict what your repository contains after the clone: its commits,
and the pointers on them. Then play the diagram to check your prediction. It
shows Alice's clone, and everyone's is the same:

<simgit-story name='guessit' start-chapter='exercise' end-chapter='clone' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

A clone copies the **whole history** of the repository, and checks out its
`main` branch. Check yours with `git graph`:

```bash
$> git graph
* 954181f (HEAD -> main, origin/main, origin/HEAD) Show total games played in leaderboard
* d6881a1 Initial commit
```

These are the commits of the `ArchiDep` repository, which the fork copied, so
their hashes are the same for everyone.

`origin` is the name Git gave the repository you cloned from, Alice's fork on
GitHub. `origin/main` is a **remote-tracking branch**: your record of where
`main` points to on `origin`. It moves only when Git talks to GitHub. The
diagram does not show `origin/HEAD`, which records the default branch of the
repository on GitHub; you can ignore it.

## :question: Everyone: run the application

This step is optional. The Git part of this exercise does not need the
application to run, but if Node.js is already installed on your computer, you
can see your changes in your browser as you go.

Check your version of Node.js:

```bash
$> node --version
v26.x.y
```

If the command is not found, or prints a version older than 22, skip this step:
you will install Node.js in [the second part](#install-nodejs) of this exercise.

Otherwise, open a new terminal, install the application's dependencies in your
clone, and start it:

```bash
$> cd /path/to/projects/guessit-ex
$> npm ci
$> npm run dev
Guess It is listening on http://localhost:3000
```

Open [http://localhost:3000](http://localhost:3000) in your browser. There is no
database yet, so the home page says that the leaderboard could not be loaded:
that is ok and expected. You will install or configure PostgreSQL later, in the
second part of this exercise.

![Guess It home page](images/guessit-no-db.png)

Keep the application running in a terminal of its own, and use the other one for
Git.

{% note type: tip %}

`npm run dev` restarts the application automatically whenever `server.js`
changes, including when a pull changes it: reload the page to see the change.
Stop it with `Ctrl-C`.

{% endnote %}

## :exclamation: Share a change

In this section, Alice makes a first change and pushes it to GitHub. Bob, and
possibly Chuck, then bring it into their own repositories. Nobody else changes
anything in the meantime, so nothing gets in the way.

### :exclamation: Alice: add the team to the README

**Alice** adds a "Team" section to `README.md`, after its first paragraph, with
the names of the members of the group:

```markdown
## Team

- Alice
- Bob
- Chuck
```

She commits the change:

```bash
$> git add README.md
$> git commit -m "Add the team to the README"
[main 6f658d5] Add the team to the README
 1 file changed, 6 insertions(+)
```

Your commits will have hashes other than the ones quoted in this exercise, since
they have your name and date in them.

**Predict:** predict how the commit changes Alice's repository. Then play the
diagram to check your prediction:

<simgit-story name='guessit' start-chapter='alice-ready' end-chapter='alice-readme' through-chapter='alice-push' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

### :exclamation: Alice: push the change

**Predict:** will GitHub accept Alice's push?

{% solution title: "Check your prediction", reveal: always %}

Yes. On GitHub, `main` points to the commit Alice's commit was made on top of.
Alice's commit is directly ahead of it, so GitHub only has to move its `main`
forward: a **fast-forward**.

{% endsolution %}

**Alice** pushes:

```bash
$> git push origin main
...
To github.com:alice/guessit-ex.git
   954181f..6f658d5  main -> main
```

`git push origin main` sends the commit your `main` points to, with the history
behind it that the remote does not have yet, to the remote named `origin`, and
asks it to move its own `main` there.

**Predict:** predict what the push changes, on GitHub and in Alice's repository.
Then play the diagram to check your prediction:

<simgit-story name='guessit' start-chapter='alice-readme' end-chapter='alice-push' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", reveal: always %}

The push also moved `origin/main` in Alice's repository: her Git has just seen
where `main` is on GitHub.

{% endsolution %}

### :exclamation: Bob: look before you fetch

Wait until Alice has pushed. Alice's commit is on GitHub now.

**Predict:** what will `git status` say in **Bob**'s repository? Then run it:

```bash
$> git status
```

{% solution title: "Check your prediction", reveal: always %}

Bob's repository has not changed:

```bash
$> git status
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

"Up to date" is only true as far as Bob knows. `origin/main` is his record of
where `main` was on GitHub the last time his Git talked to it, when he cloned.
**Git does not synchronise anything by itself**: nothing tells Bob's repository
that Alice has pushed.

{% endsolution %}

### :exclamation: Bob: fetch

**Bob** is going to ask GitHub what is new, with `git fetch`.

**Predict:** after the fetch, will Bob's `README.md` have Alice's "Team"
section?

{% solution title: "Check your prediction", reveal: always %}

No. A fetch downloads the commits Bob does not have, and updates his record of
where `main` is on GitHub, `origin/main`. It changes neither his `main` nor the
files in his working directory.

{% endsolution %}

**Bob** fetches:

```bash
$> git fetch origin
From github.com:alice/guessit-ex
   954181f..6f658d5  main       -> origin/main
```

Check `README.md`: it has no "Team" section yet.

**Predict:** predict what the fetch changes in Bob's repository. Then play the
diagram to check your prediction:

<simgit-story name='guessit' start-chapter='bob-look' end-chapter='bob-fetch' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

**Predict:** what will `git status` say now? Then run it:

```bash
$> git status
```

{% solution title: "Check your prediction", reveal: always %}

Now that Bob's Git knows about Alice's commit, it says that Bob's branch is
behind:

```bash
$> git status
On branch main
Your branch is behind 'origin/main' by 1 commit, and can be fast-forwarded.
  (use "git pull" to update your local branch)

nothing to commit, working tree clean
```

{% endsolution %}

### :exclamation: Bob: merge

**Bob** is going to merge what he fetched into his `main`, with
`git merge origin/main`.

**Predict:** will the merge be a fast-forward, or will Git create a merge
commit?

{% solution title: "Check your prediction", reveal: always %}

A fast-forward. `main` has not moved since Bob cloned, so Alice's commit is
directly ahead of it: Git only has to move `main` forward.

{% endsolution %}

**Bob** merges:

```bash
$> git merge origin/main
Updating 954181f..6f658d5
Fast-forward
 README.md | 6 ++++++
 1 file changed, 6 insertions(+)
```

`README.md` now has the "Team" section.

**Predict:** predict what the merge changes in Bob's repository. Then play the
diagram to check your prediction:

<simgit-story name='guessit' start-chapter='bob-fetch' end-chapter='bob-merge' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

### :exclamation: Chuck: pull

If **Chuck** is present in the group, he does the same as Bob in one command:
`git pull` is a `git fetch` followed by a `git merge`.

**Predict:** will Chuck's pull end with a fast-forward, or with a merge commit?

{% solution title: "Check your prediction", reveal: always %}

A fast-forward, for the same reason as Bob's merge: Chuck's `main` has not moved
since he cloned.

{% endsolution %}

**Chuck** pulls:

```bash
$> git pull
From github.com:alice/guessit-ex
   954181f..6f658d5  main       -> origin/main
Updating 954181f..6f658d5
Fast-forward
 README.md | 6 ++++++
 1 file changed, 6 insertions(+)
```

**Predict:** predict what the pull changes in Chuck's repository. Then play the
diagram to check your prediction:

<simgit-story name='guessitChuck' start-chapter='chuck-look' end-chapter='chuck-pull' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

## :exclamation: Conflicting changes

Everyone now has the same history. In this section, you all change the
application at the same time, without pulling each other's work. Alice and Bob
change the same line, and Chuck (if present) another line of the same file. You
will then push in order, see what happens, and resolve any conflicts. At the
end, everyone will pull, and you will all have the same history again.

### :exclamation: Everyone: change something

The accent colour of the page is set at the top of `server.js`:

```js
const ACCENT_COLOR = '#6c3ce9';
```

**Alice** and **Bob** each set it to a different colour, and commit, without
pushing.

For example, **Alice**:

```bash
# (Edit server.js and set ACCENT_COLOR to '#e63946'...)
$> git add server.js
$> git commit -m "Make the accent red"
```

And **Bob**:

```bash
# (Edit server.js and set ACCENT_COLOR to '#2a9d8f'...)
$> git add server.js
$> git commit -m "Make the accent green"
```

If **Chuck** is present in the group, he changes another line of the same file:
the title in the navigation bar, near the end of `server.js`. He signs it with
the names of the group, and commits, without pushing:

```js
<a class="navbar-brand" href="/">
  🎯 Guess It, by Alice, Bob &amp; Chuck
</a>
```

```bash
$> git add server.js
$> git commit -m "Sign the navbar"
```

If you started the application in [the optional
step](#everyone-run-the-application), reload the page to see your change.

**Predict:** predict what Alice's repository, GitHub's and Bob's look like after
Alice's and Bob's commits. Then play the diagram to check your prediction:

<simgit-story name='guessit' start-chapter='pair-look' end-chapter='pair-commits' through-chapter='alice-push-red' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

Chuck's commit appears later, in the diagrams of the steps that are his.

### :exclamation: Alice: push first

**Predict:** will GitHub accept Alice's push?

{% solution title: "Check your prediction", reveal: always %}

Yes, for the same reason as before. On GitHub, `main` still points to the parent
commit of Alice's latest commit, so moving `main` to Alice's commit is a
fast-forward.

{% endsolution %}

**Alice** pushes:

```bash
$> git push origin main
...
To github.com:alice/guessit-ex.git
   6f658d5..f739362  main -> main
```

**Predict:** predict what the push changes, in Alice's repository, on GitHub and
in Bob's repository. Then play the diagram to check your prediction:

<simgit-story name='guessit' start-chapter='pair-commits' end-chapter='alice-push-red' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", reveal: always %}

Nothing changes in Bob's repository: his Git has not talked to GitHub.

{% endsolution %}

### :exclamation: Bob: push

Wait until Alice has pushed.

**Predict:** will GitHub accept Bob's push? Look at the last diagram.

{% solution title: "Check your prediction", reveal: always %}

No. GitHub's `main` points to Alice's newest commit, which Bob does not have.
Moving it to Bob's commit would throw Alice's work away, so GitHub refuses.

{% endsolution %}

**Bob** pushes, and reads the rejection:

```bash
$> git push origin main
To github.com:alice/guessit-ex.git
 ! [rejected]        main -> main (fetch first)
error: failed to push some refs to 'github.com:alice/guessit-ex.git'
hint: Updates were rejected because the remote contains work that you do not
hint: have locally. This is usually caused by another repository pushing to
hint: the same ref. If you want to integrate the remote changes, use
hint: 'git pull' before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
```

The reason Git gives, `(fetch first)`, says that GitHub has work Bob does not
even know about yet. The hint suggests `git pull`, which fetches and then
merges. Bob will do these one at a time, to see what each changes.

### :exclamation: Bob: fetch, and push again

**Bob** fetches:

```bash
$> git fetch origin
From github.com:alice/guessit-ex
   6f658d5..f739362  main       -> origin/main
```

**Predict:** predict what the fetch changes in Bob's repository. Then play the
diagram to check your prediction:

<simgit-story name='guessitBobFetch' start-chapter='bob-rejected' end-chapter='bob-fetch-red' through-chapter='github-layout' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", reveal: always %}

Bob's history has **diverged** from GitHub's: his `main` and his `origin/main`
each have a commit the other does not have, on top of the same commit. This is
the shape of two branches that need a three-way merge, as in [Hello Git]({% link
chapters/202-hello-git/exercise.md %}#two-merges).

{% endsolution %}

`git status` should confirm your prediction:

```bash
$> git status
On branch main
Your branch and 'origin/main' have diverged,
and have 1 and 1 different commits each, respectively.
  (use "git pull" if you want to integrate the remote branch with yours)

nothing to commit, working tree clean
```

**Predict:** now that Bob has Alice's commit, will GitHub accept his push? Why?

{% solution title: "Check your prediction", reveal: always %}

No. Fetching did not change Bob's `main`: it still does not contain Alice's
commit, so moving GitHub's `main` to it would still throw Alice's work away. **A
remote only accepts a push that fast-forwards its branch.** Bob has to merge
Alice's work into his first.

{% endsolution %}

**Bob** pushes again, and reads the rejection:

```bash
$> git push origin main
To github.com:alice/guessit-ex.git
 ! [rejected]        main -> main (non-fast-forward)
error: failed to push some refs to 'github.com:alice/guessit-ex.git'
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart. If you want to integrate the remote changes,
hint: use 'git pull' before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
```

The reason is another one this time, `(non-fast-forward)`: Bob's Git knows
about Alice's commit now, and the push would not move GitHub's `main` forward.

### :exclamation: Bob: pull, and resolve the conflict

**Bob** is going to pull, to merge Alice's commit into his `main`.

**Predict:** will Git manage to merge on its own?

{% solution title: "Check your prediction", reveal: always %}

No. Alice and Bob both changed the same line of `server.js`, differently. Git
cannot know which change to keep, so it stops in the middle of the merge, and
asks Bob to choose.

{% endsolution %}

**Bob** pulls:

```bash
$> git pull
Auto-merging server.js
CONFLICT (content): Merge conflict in server.js
Automatic merge failed; fix conflicts and then commit the result.
```

`git status` tells you where you are:

```bash
$> git status
On branch main
Your branch and 'origin/main' have diverged,
and have 1 and 1 different commits each, respectively.
  (use "git pull" if you want to integrate the remote branch with yours)

You have unmerged paths.
  (fix conflicts and run "git commit")
  (use "git merge --abort" to abort the merge)

Unmerged paths:
  (use "git add <file>..." to mark resolution)
	both modified:   server.js

no changes added to commit (use "git add" and/or "git commit -a")
```

Open `server.js`. Git has written both versions of the line into the file,
between **conflict markers**:

```
<<<<<<< HEAD
const ACCENT_COLOR = '#2a9d8f';
=======
const ACCENT_COLOR = '#e63946';
>>>>>>> f739362c10033226a41a2fec7eb54ed0860fab48
```

Between `<<<<<<< HEAD` and `=======` is Bob's version, the commit he is on.
Between `=======` and `>>>>>>>` is the version he is merging, Alice's commit.
Only the line both of them changed is in conflict: the rest of the file was
merged.

Choosing is Bob's job. He keeps one of the two colours, or writes a third, and
**removes the three marker lines**:

```js
const ACCENT_COLOR = '#2a9d8f';
```

Then he marks the conflict as resolved by staging the file, and finishes the
merge:

```bash
$> git add server.js
$> git status
On branch main
Your branch and 'origin/main' have diverged,
and have 1 and 1 different commits each, respectively.
  (use "git pull" if you want to integrate the remote branch with yours)

All conflicts fixed but you are still merging.
  (use "git commit" to conclude merge)

$> git commit -m "Choose the right accent color"
[main 028ac6a] Merge branch 'main' of github.com:alice/guessit-ex
```

{% note type: tip %}

`-m` gives the commit message on the command line. If you do not give it, Git
opens your editor to write the message.

{% endnote %}

**Predict:** predict what Bob's repository looks like after the merge commit.
Then play the diagram to check your prediction:

<simgit-story name='guessit' start-chapter='bob-fetch-red' end-chapter='bob-pull' through-chapter='bob-push-merge' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

### :exclamation: Bob: push the merge

**Predict:** will GitHub accept Bob's push now?

{% solution title: "Check your prediction", reveal: always %}

Yes. Bob's merge commit has Alice's commit as one of its parents. From GitHub's
point of view, moving `main` from Alice's commit to Bob's merge commit is moving
it forward: a fast-forward.

{% endsolution %}

**Bob** pushes:

```bash
$> git push origin main
...
To github.com:alice/guessit-ex.git
   f739362..028ac6a  main -> main
```

**Predict:** predict what the push changes, on GitHub and in Alice's repository.
Then play the diagram to check your prediction:

<simgit-story name='guessitBobPushMerge' start-chapter='pair-merged' end-chapter='bob-push-merge' through-chapter='alice-layout' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

{% solution title: "Check your prediction", reveal: always %}

Alice's `origin/main` has not moved: her Git has not talked to GitHub since her
own push.

{% endsolution %}

### :exclamation: Chuck: push

If **Chuck** is present in the group, he waits until Bob has pushed his merge.

**Predict:** will GitHub accept Chuck's push?

{% solution title: "Check your prediction", reveal: always %}

No, for the same reason as Bob's first push: GitHub has commits that Chuck does
not have.

{% endsolution %}

**Chuck** pushes, and reads the rejection:

```bash
$> git push origin main
To github.com:alice/guessit-ex.git
 ! [rejected]        main -> main (fetch first)
...
```

### :exclamation: Chuck: pull

If **Chuck** is present in the group, it's his turn to pull. Otherwise skip this
step.

**Predict:** will Chuck's pull end with a conflict?

{% solution title: "Check your prediction", reveal: always %}

No. Chuck changed the same file as Alice and Bob, but not the same line. A
conflict is about lines, not files: Git merges changes to different lines of a
file by itself.

The histories have diverged, though, so the merge still needs a merge commit,
and Git asks for its message.

{% endsolution %}

**Chuck** pulls. The pull opens your editor, with a commit message that Git has
written for you. Keep it as it is, and exit: in nano, press `Ctrl-X`. If you
find yourself in Vim instead, see [I am stuck in Vim]({% link
chapters/202-hello-git/exercise.md %}#i-am-stuck-in-vim).

```bash
$> git pull
From github.com:alice/guessit-ex
   6f658d5..028ac6a  main       -> origin/main
Auto-merging server.js
Merge made by the 'ort' strategy.
 server.js | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

**Predict:** predict what Chuck's repository looks like after the pull. Then
play the diagram to check your prediction:

<simgit-story name='guessitChuck' start-chapter='chuck-title' end-chapter='chuck-pull-merge' through-chapter='chuck-push-merge' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

### :exclamation: Chuck: push the merge

If **Chuck** is present in the group, he can now push his merge commit.
Otherwise skip this step.

**Predict:** will GitHub accept Chuck's push now?

{% solution title: "Check your prediction", reveal: always %}

Yes: Chuck's merge commit has GitHub's `main` in its history, so moving `main`
to it is a fast-forward.

{% endsolution %}

**Chuck** pushes:

```bash
$> git push origin main
...
To github.com:alice/guessit-ex.git
   028ac6a..04e6514  main -> main
```

**Predict:** predict what the push changes on GitHub. Then play the diagram to
check your prediction:

<simgit-story name='guessitChuck' start-chapter='chuck-pull-merge' end-chapter='chuck-push-merge' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

### :exclamation: Everyone: pull

Wait until Chuck has pushed, or Bob in a group of two. Then **Alice**, **Bob**
and **Chuck** are each going to pull.

**Predict:** will these pulls be fast-forwards, or will they create merge
commits?

{% solution title: "Check your prediction", reveal: always %}

Fast-forwards. Nobody has committed since their last pull or push, so what is on
GitHub is directly ahead of everyone's `main`, or is `main` itself for whoever
pushed last.

{% endsolution %}

Everyone pulls. What happens depends on the size of your group.

#### :exclamation: In a group of two

Bob pushed last, so only Alice has anything to pull:

```bash
$> git pull
From github.com:alice/guessit-ex
   f739362..028ac6a  main       -> origin/main
Updating f739362..028ac6a
Fast-forward
 server.js | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

Bob's repository is already up to date:

```bash
$> git pull
Already up to date.
```

**Predict:** predict what Alice's and Bob's repositories look like after their
pulls. Then play the diagram to check your prediction:

<simgit-story name='guessitPair' start-chapter='pair-behind' end-chapter='final-pulls' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

#### :exclamation: In a group of three

Chuck pushed last, so Alice and Bob both pull his merge.

**Alice**'s pull brings Bob's merge too:

```bash
$> git pull
From github.com:alice/guessit-ex
   f739362..04e6514  main       -> origin/main
Updating f739362..04e6514
Fast-forward
 server.js | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

**Bob**'s brings Chuck's:

```bash
$> git pull
From github.com:alice/guessit-ex
   028ac6a..04e6514  main       -> origin/main
Updating 028ac6a..04e6514
Fast-forward
 server.js | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

Chuck's repository is already up to date.

**Predict:** predict what Alice's and Bob's repositories look like after their
pulls. Then play the diagram to check your prediction:

<simgit-story name='guessit' start-chapter='pair-behind' end-chapter='bob-final-pull' sizing='auto-height' commit-representation='below' duration='1200' mode='manual' defer-until-visible='true'></simgit-story>

#### :exclamation: Everyone: check your status

Everyone now has the same history, and `git status` says so:

```bash
$> git status
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

## :exclamation: Run the application

From here on, each member of the group works on their own computer, at their own
pace. You will still share your work through GitHub: whenever a push is refused,
pull first, as you did above.

### :exclamation: Install Node.js

Check whether you have Node.js 26:

```bash
$> node --version
v26.x.y
```

If the command is not found, or prints version older than 22, install Node.js 26
by following the instructions of its [download page][node-download] for your
system. On Windows, install it **in the WSL**, with the Linux instructions.

### :exclamation: Install PostgreSQL

The application needs a PostgreSQL server, version 14 or newer. It connects to
it at `localhost`, on port 5432: that is the address in its connection URL. On
Windows, the application runs in the WSL, so the server must answer in the WSL.

You may already have a PostgreSQL server, installed for another course. Check
before you install anything: two PostgreSQL servers on the same computer both
want port 5432, and only one of them can have it.

#### :exclamation: Check what you already have

First, check whether a server already answers on port 5432. Run this in your
terminal on macOS, or in the WSL on Windows:

```bash
$> nc -zv localhost 5432
Connection to localhost (127.0.0.1) 5432 port [tcp/postgresql] succeeded!
```

The message ends with `succeeded!` if a server answers, and with
`Connection refused` if none does. It is slightly different on macOS, but it
ends the same way.

Then check which PostgreSQL servers are installed, and follow the table for your
system.

**In the WSL, or on Linux:**

```bash
$> pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
16  main    5432 online postgres /var/lib/postgresql/16/main /var/log/postgresql/postgresql-16-main.log
```

This lists the servers installed with `apt`, Ubuntu's package manager. If the
command is not found, there is none.

| `nc`         | `pg_lsclusters`                  | Next step                               |
| :----------- | :------------------------------- | :-------------------------------------- |
| `succeeded!` | a server on port 5432, `online`  | [Connect as a superuser][pg-connect]    |
| `succeeded!` | not found, or no server `online` | [Connect as a superuser][pg-connect]    |
| `refused`    | a server on port 5432, `down`    | [Start your server][pg-start]           |
| `refused`    | not found                        | [Install PostgreSQL in the WSL][pg-wsl] |

In the second row, the server that answers was not installed with `apt`: it is
another server, for example one installed on Windows, which some WSL network
settings make visible in the WSL.

{% note type: tip %}

A PostgreSQL server installed on Windows itself usually does **not** answer in
the WSL: you are in the last row. This is expected. The WSL has its own
`localhost`, separate from Windows'. You can install another server in the WSL:
the two do not interfere with each other.

{% endnote %}

**On macOS:**

```bash
$> ls -d /Applications/Postgres.app   # Postgres.app
$> brew list | grep postgresql        # PostgreSQL installed with Homebrew
$> ls /Library/PostgreSQL             # the installer of postgresql.org
```

`No such file or directory`, or no output, means that it is not installed.
`brew: command not found` means that you do not have Homebrew.

| `nc`         | Installed                                        | Next step                               |
| :----------- | :----------------------------------------------- | :-------------------------------------- |
| `succeeded!` | anything                                         | [Connect as a superuser][pg-connect]    |
| `refused`    | Postgres.app, or PostgreSQL in Homebrew          | [Start your server][pg-start]           |
| `refused`    | nothing, or only the installer of postgresql.org | [Install PostgreSQL on macOS][pg-macos] |

#### :question: Start your server

Start the server you already have:

- **Installed with `apt`, in the WSL or on Linux:**

  ```bash
  $> sudo service postgresql start
  ```

  Some WSL installations do not start services by themselves. If the server is
  stopped again after you restart your computer, start it again the same way.

- **Postgres.app:** open it, and click `Start`.
- **Homebrew:** start the version that `brew list` printed, for example
  `postgresql@17`:

  ```bash
  $> brew services start postgresql@17
  ```

Run `nc -zv localhost 5432` again: it must now succeed. Then [connect as a
superuser][pg-connect].

#### :question: Install PostgreSQL in the WSL

Follow the [Install PostgreSQL][wsl-postgres] section of Microsoft's guide to
databases in the WSL, up to and including `sudo service postgresql start`. You
do not need to give the `postgres` user a password, as the guide then suggests.

On Linux without the WSL, follow [PostgreSQL's instructions for
Ubuntu][postgres-ubuntu]: `apt install postgresql` is enough.

Run `nc -zv localhost 5432` again: it must now succeed. Then [connect as a
superuser][pg-connect].

#### :question: Install PostgreSQL on macOS

Check whether you have [Homebrew][homebrew]:

```bash
$> brew --version
Homebrew 5.0.0
```

- **If you have Homebrew**, install [PostgreSQL 18][brew-postgres] with it, and
  start it:

  ```bash
  $> brew install postgresql@18
  $> brew services start postgresql@18
  ```

  At the end of its output, `brew install` says that `postgresql@18 is
keg-only`, and gives an `echo 'export PATH=...' >> ~/.zshrc` command below.
  Run that command, then open a new terminal: it makes the `psql` command
  available.

- **Otherwise**, install [Postgres.app][postgres-app] by following the steps on
  its home page. Do the step that configures your `$PATH`, even though the page
  says that it is optional: you will need the `psql` command. Then open a new
  terminal.

Run `nc -zv localhost 5432` again: it must now succeed. Then [connect as a
superuser][pg-connect].

#### :exclamation: Connect as a superuser

To create the application's database in the next step, you will connect to your
server as a PostgreSQL superuser. The command depends on where your server
comes from:

| Your server                               | Superuser command                        |
| :---------------------------------------- | :--------------------------------------- |
| Installed with `apt`, in the WSL or Linux | `sudo -u postgres psql`                  |
| Postgres.app, or Homebrew                 | `psql postgres`                          |
| Any other server                          | `psql -h localhost -U postgres postgres` |

With any other server, `psql` asks for the password of the `postgres` user,
which was chosen when that server was installed. If `psql` is not found in the
WSL, install it with `sudo apt install postgresql-client`.

Use your command to check the version of your server:

```bash
$> sudo -u postgres psql -c 'SHOW server_version;'
            server_version
---------------------------------------
 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
(1 row)
```

It must be 14 or newer. With `apt`, you get the version of your Ubuntu: 14 on
Ubuntu 22.04, 16 on 24.04, 18 on 26.04. If yours is older, use the [PostgreSQL
Apt Repository][postgres-ubuntu] to install a newer one.

{% note type: tip %}

`sudo -u postgres psql` may also print
`could not change directory to "/home/jde/guessit-ex": Permission denied`. It
runs `psql` as the `postgres` user of your system, which is not allowed in your
directory. You can ignore this warning.

Postgres.app may ask whether your terminal is allowed to connect to it the
first time. Allow it.

{% endnote %}

### :exclamation: Create the database

The repository has a `schema.sql` file, which creates the database user, the
database and its table. Open it, and **change the password** it gives the user,
`change-me-now`. Choose a password made only of letters, digits and dashes: it
goes into a URL in the next step, where other characters would have to be
encoded. It is simpler if everyone in the group uses the same one.

Then run it with your [superuser command][pg-connect], giving it the file with
`<`. For example:

```bash
$> sudo -u postgres psql < schema.sql   # installed with apt
$> psql postgres < schema.sql           # Postgres.app, or Homebrew
```

{% note type: more %}

With `<`, your shell reads the file and passes its content to `psql`. With
`sudo -u postgres`, `psql` runs as another user, which is not allowed to read
your files, so it could not open the file itself.

{% endnote %}

### :exclamation: Configure and start the application

Open your `guessit-ex` directory in your editor. At the top of `server.js`, put
the password you chose into `DATABASE_URL`, in place of `change-me-now`:

```js
const DATABASE_URL =
  'postgresql://guessit:change-me-now@localhost:5432/guessit';
```

If the application is still running from [the optional
step](#everyone-run-the-application), it has restarted by itself when you saved
`server.js`. Otherwise, install its dependencies, and start it:

```bash
$> npm ci
$> npm run dev
Guess It is listening on http://localhost:3000
```

Open [http://localhost:3000](http://localhost:3000) in your browser. `npm run
dev` restarts the application automatically whenever you save `server.js`. Stop
it with `Ctrl-C`.

The game starts, but it does not work yet: the leaderboard stays empty, guesses
are not counted, and giving up does not delete the game. The queries that do
these are missing.

{% note type: more %}

`npm ci` downloads the dependencies listed in `package-lock.json` into a
`node_modules` directory. The repository's `.gitignore` ignores that directory,
so that you do not commit it, as you learned in [Hello Git]({% link
chapters/202-hello-git/exercise.md %}#ignore-a-secret).

{% endnote %}

## :exclamation: Implement the missing queries

Three queries in `server.js` are missing. Each is marked with an
`// IMPLEMENT ME` comment, with a description of what it must do above it:

- The **leaderboard**, on the home page: the games that have been won, fewest
  attempts first, and among equals the one found first. Only the top ten.
- **Recording a guess**: add one to the game's attempts, and record when the
  number was found if the guess is right.
- **Giving up**: delete the game.

Each member of the group implements at least one of them. In a group of two, one
member implements two.

The queries are given below. Try to write yours first if you want to practice
your SQL, and use the solution to check it. Or take it as it is, if you prefer:
this exercise is about working together with Git, not about SQL. Either way, the
commit is yours.

{% solution title: "The leaderboard query", reveal: always %}

```js
const leaderboardQuery =
  'SELECT name, attempts, found_at FROM game WHERE found_at IS NOT NULL ORDER BY attempts ASC, found_at ASC LIMIT 10';
```

{% endsolution %}

{% solution title: "The guess query", reveal: always %}

```js
const updateQuery = `UPDATE game SET attempts = attempts + 1, found_at = CASE WHEN secret = ${guess} THEN NOW() ELSE found_at END WHERE id = '${game.id}'`;
```

{% endsolution %}

{% solution title: "The give-up query", reveal: always %}

```js
const deleteQuery = `DELETE FROM game WHERE id = '${game.id}'`;
```

{% endsolution %}

Check that your query works in your browser, then commit it and push it to the
group's repository. Pull the others' work as they push theirs.

{% callout type: exercise %}

By the next session, your group's repository on GitHub must hold a working
application:

- A game can be played until the number is found, or given up.
- The leaderboard lists the games that have been won, fewest attempts first.
- Each member of the group has made at least one of these commits, on their own
  computer, with their own name and email address.

{% endcallout %}

## :checkered_flag: What have I done?

You have worked as a team on one repository on GitHub, each from your own clone
of it.

You have seen that Git never synchronises anything by itself. A remote-tracking
branch such as `origin/main` is your record of where a branch was on the remote
the last time your Git talked to it. `git fetch` updates that record and
downloads the commits, without changing your branches or your files. `git merge`
then brings them into your branch, and `git pull` does both.

You have had pushes refused, for two reasons: the remote had commits you did not
have yet (`fetch first`), and then your history had diverged from the remote's
(`non-fast-forward`). A remote only accepts a push that moves its branch
forward. To push, you merged the remote's work into yours first.

You have resolved a conflict, where two people changed the same line, and seen
that changes to different lines of the same file merge on their own.

Finally, you have made the application work, each with commits of your own.

## :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="Guess It Local Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="Guess It Local Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

## :boom: Troubleshooting

Here are a few tips about problems you may encounter during this exercise.

### :boom: `Permission denied (publickey)`

GitHub does not know your SSH key. [Check your SSH key on
GitHub](#check-your-ssh-key-on-github) again: the fingerprint of the key GitHub
lists must be the one `ssh-keygen -lf` prints for your public key:

```bash
$> ssh-keygen -lf ~/.ssh/id_ed25519.pub
256 SHA256:... jde@example (ED25519)
```

### :boom: `ERROR: Permission to alice/guessit-ex.git denied to bob`

You are not a collaborator of the repository yet. Check that Alice has invited
you, and that you have accepted the invitation, which GitHub sent you by email.

### :boom: `ERROR: Permission to ArchiDep/guessit-ex.git denied`

You cloned the `ArchiDep` repository instead of Alice's fork. Check where your
`origin` points to:

```bash
$> git remote -v
origin  git@github.com:ArchiDep/guessit-ex.git (fetch)
origin  git@github.com:ArchiDep/guessit-ex.git (push)
```

Delete your clone, and [clone Alice's fork](#everyone-clone-the-fork) instead.

### :boom: `fatal: Need to specify how to reconcile divergent branches.`

If `git pull` fails with this message:

```bash
$> git pull
hint: You have divergent branches and need to specify how to reconcile them.
hint: You can do so by running one of the following commands sometime before
hint: your next pull:
hint:
hint:   git config pull.rebase false  # merge
hint:   git config pull.rebase true   # rebase
hint:   git config pull.ff only       # fast-forward only
hint:
hint: You can replace "git config" with "git config --global" to set a default
hint: preference for all repositories. You can also pass --rebase, --no-rebase,
hint: or --ff-only on the command line to override the configured default per
hint: invocation.
fatal: Need to specify how to reconcile divergent branches.
```

You have skipped [configuring `git pull`](#everyone-configure-git-pull). Run
this command once:

```bash
$> git config --global pull.rebase false
```

Then run `git pull` again.

{% note type: more %}

With the `--global` option, this setting is saved in your global `~/.gitconfig`
file, and applies to every repository on your computer.

{% endnote %}

### :boom: `password authentication failed for user "guessit"`

The password in the `DATABASE_URL` at the top of `server.js` is not the one you
set in `schema.sql` when you created the database. Put the same password in
both.

### :boom: `connect ECONNREFUSED`

The home page says that the leaderboard could not be loaded, and the terminal
where the application runs shows `ECONNREFUSED` in the error below
`Could not load the leaderboard`. The application cannot reach PostgreSQL on
port 5432: your PostgreSQL server is either not running or is not reachable on
that port. [Check what you have][pg-check] again, and start your server if it is
stopped.

### :boom: `psql: command not found`

On macOS, the `psql` command of Postgres.app and of Homebrew's PostgreSQL is not
available until you configure your `$PATH`, as described in [Install PostgreSQL
on macOS][pg-macos]. Open a new terminal after doing it.

### :boom: `Peer authentication failed for user "postgres"`

Your server was installed with `apt`. Its `postgres` user can only connect from
the `postgres` user of your system: use `sudo -u postgres psql`, not
`psql -U postgres`.

### :boom: `role "jde" does not exist`

Your server was installed with `apt`, and you ran `psql` as yourself. Use
`sudo -u postgres psql`, as in [Connect as a superuser][pg-connect].

### :boom: Your server no longer starts after you restart your Mac

After you restart your Mac, Postgres.app says that port 5432 is already in use,
or `brew services list` shows an `error` for your PostgreSQL. Or `nc` succeeds,
but you can no longer connect as a superuser.

You have an older PostgreSQL server, from the installer of postgresql.org, which
started first and took port 5432. Uninstall it with the uninstaller in its
`/Library/PostgreSQL/<version>/` directory, then [start your server][pg-start]
again.

[ex-repo]: https://github.com/ArchiDep/guessit-ex
[brew-postgres]: https://formulae.brew.sh/formula/postgresql@18
[git]: https://git-scm.com
[github]: https://github.com
[github-fingerprints]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
[homebrew]: https://brew.sh
[node]: https://nodejs.org
[node-download]: https://nodejs.org/en/download
[pg-check]: #check-what-you-already-have
[pg-connect]: #connect-as-a-superuser
[pg-macos]: #install-postgresql-on-macos
[pg-start]: #start-your-server
[pg-wsl]: #install-postgresql-in-the-wsl
[postgres]: https://www.postgresql.org
[postgres-app]: https://postgresapp.com
[postgres-ubuntu]: https://www.postgresql.org/download/linux/ubuntu/
[wsl-postgres]: https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-database#install-postgresql
