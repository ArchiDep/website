---
title: Version Control with Git
---

Learn the basics of [Git][git], one of the most popular distributed version
control systems. This is a condensed version of the first chapters of the [Git
Book](https://git-scm.com/book/en/v2), which you should read if you want more
detailed information on the subject.

**You will need**

- A Unix CLI

**Recommended reading**

- [Command line]({% link chapters/101-command-line/subject.md %})

## Git and the command line

There are a lot of different ways to use Git: the original **command line
tools** and various **GUIs** of varying capabilities. But the command line is
the only place you can run **all** Git commands with all their options.

If you know how to run the command line version, you can easily figure out how
to use the GUI version, while the opposite is not necessarily true. So the
**command line** is what we will use.

## Best practices

- [**Commit early and often, perfect later** (Seth
  Robertson)](https://sethrobertson.github.io/GitBestPractices/)

  Git only takes full responsibility for your data when you commit. If you fail
  to commit and then do something poorly thought out, you can run into trouble.
  Additionally, having periodic checkpoints means that you can understand how
  you broke something.

- [**Writing a good commit message**
  (GitKraken)](https://www.gitkraken.com/learn/git/best-practices/git-commit-message)

  If by taking a quick look at previous commit messages, you can discern what
  each commit does and why the change was made, you’re on the right track. But
  if your commit messages are confusing or disorganized, then you can help your
  future self and your team by improving your commit message practices with help
  from this article.

- [**Conventional Commits**](https://www.conventionalcommits.org)

  If you want to go further, look at _Conventional Commits_, a specification for
  adding human and machine readable meaning to commit messages.

## Appendix: a short history of version control

Git was not the first version control system. It belongs to the third of three
generations, each of which answered the limits of the one before.

### Local version control systems (1980s)

The simplest way to keep old versions of your files is to **copy them manually**
into other directories. The [**R**evision **C**ontrol **S**ystem (RCS)][rcs],
first released in 1982, automated this process on your own machine.

![Local version control](images/local-vcs.png)

It is still easy to **accidentally edit the wrong files**, and **hard to
collaborate** on different versions with other people.

### Centralized version control systems (1990s)

Centralized version control systems are based on a **single central server**
that keeps all the versioned files. [**C**oncurrent **V**ersion **S**ystems
(CVS)][cvs] and [**S**ub**v**ersio**n** (SVN)][svn] are such systems, first
released in 1990 and 2000 respectively.

![Centralized version control](images/centralized-vcs.png)

Administrators have **fine-grained control** over who can do what. But many
operations need the network, which makes them **slow**; the server is a
**single point of failure**; and the history **can be lost** if it has no
backups.

You could also consider storing your files in a shared Dropbox, Google Drive,
etc. to be a kind of centralized version control system. However, it doesn't
have as many tools for **consulting and manipulating the history** of your
project, or to **collaborate on source code**.

### Distributed version control systems (2000+)

Systems such as [Git][git] and [Mercurial][mercurial], both first released in
2005, are **distributed**. Each client **fully mirrors** the repository: the
whole history, not just the latest snapshot.

![Distributed version control](images/distributed-vcs.png)

Because Git stores all versions of all files **locally**, most operations are
almost instantaneous and do not need a connection to a server:

- Browsing the history
- Checking a file's changes from a month ago
- Committing

Basically any collaborative workflow is possible, since the team can organize
itself however it wants (see [distributed workflows][distributed-workflows]).
Administrators still control their servers, but not their collaborators'
machines.

### Snapshots, not differences

Most earlier systems, such as Subversion, store each file as its first version
followed by the list of **changes** (or deltas) made to it over time.

![Subversion stores changes as deltas](images/deltas.png)

Git stores its data as **snapshots** instead. Every time you commit, it takes a
picture of what all your files look like at that moment and stores a reference
to that snapshot. To be efficient, **if a file has not changed, Git does not
store it again**, just a link to the identical file it has already stored.

![Git stores changes as snapshots](images/snapshots.png)

[cvs]: https://en.wikipedia.org/wiki/Concurrent_Versions_System
[distributed-workflows]: https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows
[git]: https://git-scm.com/
[mercurial]: https://www.mercurial-scm.org/
[rcs]: https://en.wikipedia.org/wiki/Revision_Control_System
[svn]: https://subversion.apache.org/
