---
title: Git Cheatsheet
sidebar_title: Git
---

If you want to learn more about Git, read the [Pro Git
book](https://git-scm.com/book/en/v2) (online & free).

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

- Choose a **branching workflow**:
  - [A successful branching model](http://nvie.com/posts/a-successful-git-branching-model/) (for large teams)
  - [A successful branching model considered harmful](https://barro.github.io/2016/02/a-succesful-git-branching-model-considered-harmful/)
  - [Branch-per-feature](http://dymitruk.com/blog/2012/02/05/branch-per-feature/)
  - [Trunk-based development](https://trunkbaseddevelopment.com)
- Enable [Git Rerere](https://git-scm.com/book/en/v2/Git-Tools-Rerere)

## One-time configuration

### Configure your identity

You must configure identity using your user name and e-mail address. This is
important because every Git commit uses this information, and it's immutably
baked into every commit you make. **You should obviously replace your `"John
Doe"` and `john.doe@example.com` with your own information.**

```bash
$> git config --global user.name "John Doe"
$> git config --global user.email john.doe@example.com
```

### Automagically exclude annoying `.DS_Store` files from your commits (macOS only)

You can create a global ignore file in your home directory to ignore them:

```bash
$> echo ".DS_Store" >> ~/.gitignore
```

Run the following command to configure Git to use this file. You only have to do it once on each machine:

```bash
$> git config --global core.excludesfile ~/.gitignore
```

## Frequent operations

### Create a new empty repository

```bash
$> cd /path/to/projects
$> mkdir my-new-project
$> cd my-new-project
$> git init
```

### Put an existing project on GitHub

```bash
$> cd /path/to/projects/my-project
$> git init
```

If you **don't want to commit some files**, create a `.gitignore` file listing them each on one line, e.g.

```txt
*.log
node_modules
```

Commit the project's files:

```bash
$> git add --all
$> git commit -m "Initial commit"
```

Create your new repository [on GitHub](http://github.com), copy the SSH clone
URL (e.g. `git@github.com:MyUser/my-project.git`), and add it as a remote:

```bash
$> git remote add origin git@github.com:MyUser/my-project.git
```

Push your `main` branch and track it (with the `-u` option):

```bash
$> git push -u origin main
```

### Push my latest changes to the GitHub repository

Commit and push your changes:

```bash
$> git add --all
$> git commit -m "My changes"
$> git push origin main
```

**If GitHub rejects your push**, you should **pull the latest changes** first.

### Pull the latest changes from the GitHub repository

**If you have uncommitted change** (check with `git status`), stage and commit them:

```bash
$> git add --all
$> git commit -m "My changes"
```

Pull the changes:

```bash
$> git pull
```

If you've worked on the same files, there might be a **merge**. **If there is a
merge conflict**, [resolve it]({% link
_course/202-git-branching/slides.md %}#/37) and complete the merge with `git
commit`.

### Add an SSH key to my GitHub account

See [Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).
