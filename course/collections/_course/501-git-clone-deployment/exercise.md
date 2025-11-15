---
title: Deploy a PHP application with Git
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to deploy a PHP application much like the [previous
exercise]({% link _course/410-sftp-deployment/exercise.md %}), but using Git to
put the code on the server instead of SFTP.

{% callout type: exercise %}

Connect to your cloud server with SSH for this exercise.

{% endcallout %}

<!-- more -->

## :exclamation: Requirements

Make sure you have completed the [previous exercise]({% link
_course/410-sftp-deployment/exercise.md %}) first.

Stop your `php -S` command if it is still running.

{% note type: tip %}

You can use `Ctrl-C` to stop any command currently running in your terminal.

{% endnote %}

## :exclamation: Use your own repository

If you were not Bob (i.e. the person who owns the repository) during the
collaboration exercise, [create your own fork of the repository][github-fork] so
that you can modify it independently.

![GitHub Fork](images/fork.png)

## :exclamation: Clone the repository

Instead of manually uploading files through SFTP, you will connect to the server
through SSH and clone the repository from GitHub. Copy your repository's public
HTTPS URL:

![HTTP Clone URL](images/github-http-clone-url.png)

{% callout type: more, id: github-http %}

**Why the HTTP and not the SSH URL?** As long as your repository is public, it
is simpler to use the HTTP URL to clone it, since it requires no credentials.

To clone the repository with the SSH URL from your server, you would need to
have SSH public key authentication set up on your server the same way you did on
your local machine. You would need to generate an SSH key pair on the server,
and add its public key to your GitHub account (or to the repository's Deploy
Keys). Or you would need to put your own personal SSH key pair on the server,
which would make it vulnerable in the event the server is compromised.

{% endcallout %}

While connected to your server, you need to clone the repository somewhere. For
example, you could clone it to the `todolist-repo` directory in your home
directory.

{% note type: tip %}

The command to clone a Git repository is `git clone <url> [<directory-name>]`.
The directory name is optional, and defaults to the last component of the URL's
path without the ".git" extension. For example:

- `git clone https://github.com/bob/awesome-repo.git` will create a directory named "awesome-repo".
- `git clone https://github.com/bob/awesome-repo.git foo` will create a directory named "foo".

{% endnote %}

## :exclamation: Update the configuration

Since your configuration is still hardcoded, you need to update the first few
lines of `index.php` with the same configuration as for the previous exercise
(`BASE_URL`, `DB_USER`, `DB_PASS`, etc).

There are several ways you can do this:

- Clone the repository locally (if you haven't already), make the change on your
  local machine and commit and push it to GitHub. Then connect to your server
  move into the cloned repository and pull the latest changes from GitHub.
- Go into the cloned repository on the server and edit `index.php` with nano or
  Vim, or edit it on your machine and overwrite it with FileZilla, as you
  prefer.

In both cases, make sure the configuration fits your server's environment.

## :exclamation: Run the PHP development server

Run a PHP development server on port 3000 like you did during the previous
exercise, but do it in the cloned repository this time:

```bash
$> php -S 0.0.0.0:3000
```

You (and everybody else) should be able to access the application in a browser
at the correct IP address and port (e.g. `W.X.Y.Z:3000`).

## :checkered_flag: What have I done?

You are now transfering code to your deployment environment (your server) using
a version control tool (Git) instead of manually, as recommended in the
[Codebase section of The Twelve-Factory App](https://12factor.net/codebase).
Always deploying from the same codebase makes it less likely that you will make
a mistake like:

- Copying an outdated version of the codebase from the wrong directory.
- Forgetting to upload some of the modified files when you upload them by hand.

Using Git now also allows you to use Git commands like `git pull` to easily pull
the latest changes from the repository.

### :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise. Note that it has not changed
compared to [the previous exercise]({% link
_course/410-sftp-deployment/exercise.md %}#classical_building-architecture)
since we have neither created any new processes nor changed how they
communicate.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="Git Clone Deployment Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="Git Clone Deployment Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

[github-fork]: https://docs.github.com/en/get-started/quickstart/fork-a-repo
[php-todolist]: https://github.com/ArchiDep/php-todo-ex
