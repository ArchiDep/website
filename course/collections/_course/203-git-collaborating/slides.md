---
title: Collaborating with Git
---

# {{ page.title }}

Architecture & Deployment <!-- .element: class="subtitle" -->

**Notes:**

Learn how to collaborate on [GitHub][github] with [Git][git].

**You will need**

- [Git][git]
- A free [GitHub][github] account
- A Unix CLI

**Recommended reading**

- [Version control with Git]({% link _course/201-git/subject.md %})
- [Git branching]({% link _course/202-git-branching/slides.md %})

---

## Distributed version control system

Working with remote repositories

---

### What is a remote?

<img class="w-3/4" src='../images/remotes.png' />

**Notes:**

A **remote repository** is a version of your project that is hosted on the
Internet or network somewhere. You can have **several of them**.

Collaborating with others involves **pushing** and **pulling** data to and from
these remote repositories when you need to share work.

---

### Centralized workflow

There are [many ways][distributed-workflows] to work with Git as a team. Many
teams will simply use a simple **centralized workflow**:

<img src='../images/centralized-workflow.png' width='60%' />

**Notes:**

In this workflow:

- A **shared central repository** is hosted on GitHub.
- Each developer has a **repository on their local machine**.
  - Each developer will add the shared repository as a **remote**.

---

### Integration manager workflow

The classic workflow for many open source projects:

<img src='../images/integration-manager-workflow.png' width='80%' />

**Notes:**

- The **project maintainer pushes to their public repository**.
- **Contributors clone that repository**, make changes, **push to their own
  public copy** and make a **merge request** on GitHub (or via email).
- The **maintainer merges changes** on GitHub (or locally and then pushes them
  to the main repository).

One of the main advantages of this approach is that you can continue to work,
and **the maintainer of the main repository can pull in your changes at any
time**. Contributors don't have to wait for the project to incorporate their
changes — each party can work at their own pace.

---

### Benevolent dictator workflow

A workflow for very large projects:

<img src='../images/benevolent-dictator-workflow.png' width='80%' />

**Notes:**

- Regular **developers work on their topic branch** and rebase their work on top
  of `main` in the reference repository.
- **Lieutenants merge the developers' topic branches** into their `main` branch.
- The **dictator merges the lieutenants' `main` branches** into the dictator’s
  `main` branch.
- Finally, the **dictator pushes that `main` branch to the reference
  repository** so the other developers can rebase on it.

This kind of workflow isn’t common, but can be useful in **very big projects**,
or in highly hierarchical environments. It allows the project leader (the
dictator) to delegate much of the work and collect large subsets of code at
multiple points before integrating them.

---

### GitHub

<!-- .element: class="hidden" -->

<img class="w-1/2" src="../images/github.png" alt="GitHub" />

[GitHub][github] is a web-based Git repository hosting service.

**Notes:**

It offers all of the **distributed version control** and **source code
management (SCM)** functionality of **Git** as well as other features like
access control, bug tracking, feature requests, task management, and wikis for
every project.

[distributed-workflows]: https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows
[github]: https://github.com
