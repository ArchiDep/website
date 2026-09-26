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

[git]: https://git-scm.com/
