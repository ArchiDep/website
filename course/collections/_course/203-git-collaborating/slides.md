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

<p class='center'><img src='../images/centralized-workflow.png' width='60%' /></p>

**Notes:**

In this workflow:

- A **shared central repository** is hosted on GitHub.
- Each developer has a **repository on their local machine**.
  - Each developer will add the shared repository as a **remote**.

---

### GitHub

<img class="w-1/2" src="../images/github.png" alt="GitHub" />

[GitHub][github] is a web-based Git repository and Internet hosting service

**Notes:**

It offers all of the **distributed version control** and **source code
management (SCM)** functionality of **Git** as well as other features like
access control, bug tracking, feature requests, task management, and wikis for
every project.

[distributed-workflows]: https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows
[github]: https://github.com
