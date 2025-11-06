---
title: Configure a PHP application through environment variables
cloud_server: details
excerpt_separator: <!-- more -->
---

The goal of this exercise is to improve the configuration step of the [previous
exercise]({% link _course/501-git-clone-deployment/exercise.md %}) by using
environment variables instead of hardcoded configuration values.

<!-- more -->

## :exclamation: Setup

Make sure you have completed the [previous exercise]({% link
_course/501-git-clone-deployment/exercise.md %}) first.

Stop your `php -S` command if it is still running.

{% note type: tip %}

You can use `Ctrl-C` to stop any command currently running in your terminal.

{% endnote %}

## :exclamation: Update the configuration

{% callout type: exercise %}

Do this part of the exercise on your local machine, not on the server.

{% endcallout %}

Clone the repository if you do not have it already:

```bash
$> cd /path/to/projects
$> git clone git@github.com:MyUser/php-todo-ex.git
```

{% note type: tip %}

Make sure to use your own [fork](https://guides.github.com/activities/forking/)
of the repository, the same as in the [previous exercise]({% link
_course/501-git-clone-deployment/exercise.md %}).

{% endnote %}

Modify the first few lines of `index.php` to take configuration values from the
environment if available.

For example, instead of:

```php
define('BASE_URL', '/');
```

Use this:

```php
define('BASE_URL', getenv('TODOLIST_BASE_URL') ?: '/');
```

With this code, the `BASE_URL` variable will be equal to the value of the
`TODOLIST_BASE_URL` environment variable if it has been set, or it will default
to `/` if the environment variable is not available.

{% note type: more %}

This is accomplished using the [PHP shorthand ternary operator
`?:`][php-shorthand-comparisons].

{% endnote %}

**DO NOT** set a default value for the password, as it is a bad practice to
hardcode sensitive values (as mentioned in the [Config section of The
Twelve-Factor App](https://12factor.net/config)). The definition of the
`DB_PASS` variable should have no default and look like this:

```php
define('DB_PASS', getenv('TODOLIST_DB_PASS'));
```

Make sure to update the definitions of all other variables (`DB_USER`,
`DB_NAME`, `DB_HOST` and `DB_PORT`) to take their value from the environment,
with an appropriate default value.

{% note type: tip %}

Regarding the default values, you may assume that for a typical deployment, a
MySQL database server is available on the host machine itself (`127.0.0.1`) and
exposed on the default MySQL port (`3306`).

{% endnote %}

**Commit and push your changes** to the remote repository on GitHub.

{% solution %}

The configuration at the top of your index.php file in your PHP todolist
repository should look like this:

```php
define('BASE_URL', getenv('TODOLIST_BASE_URL') ?: '/');

// Database connection parameters.
define('DB_USER', getenv('TODOLIST_DB_USER') ?: 'todolist');
define('DB_PASS', getenv('TODOLIST_DB_PASS'));
define('DB_NAME', getenv('TODOLIST_DB_NAME') ?: 'todolist');
define('DB_HOST', getenv('TODOLIST_DB_HOST') ?: '127.0.0.1');
define('DB_PORT', getenv('TODOLIST_DB_PORT') ?: '3306');
```

You should have at least three copies of the PHP todolist repository with this
version of the code:

- Your fork of the PHP todolist repository on GitHub (e.g.
  https://github.com/JohnDoe/php-todo-ex, assuming `JohnDoe` is your GitHub
  username).
- Your local clone of that repository on your machine, which you used to make
  the changes asked in the exercise.
- Your clone of that repository on your cloud server.

{% endsolution %}

## :exclamation: Pull the latest version from the server

{% callout type: exercise %}

You may now connect to your server to perform the rest of the exercise.

{% endcallout %}

Go into the cloned repository from the previous exercise (`~/todolist-repo` if
you followed the instructions to the letter).

You may have made manual configuration changes during the previous exercise. You
must discard them with the `git restore <file>` command. This will remove any
uncommitted changes and restore the latest version of the file that was
committed in the repository:

```bash
$> git restore index.php
```

You can now pull the latest version of the code from GitHub.

{% note type: tip %}

The command to pull the latest changes is `git pull <remote> <branch>`. If you
do not remember the name(s) of your remote(s), you can list them with the `git
remote` command (or with `git remote -v` to also see their URLs).

{% endnote %}

{% solution %}

At the end of the exercise, the repository on your Azure server should have no
uncommitted changes, i.e. the `git status` command should print "nothing to
commit, working tree clean" when executed in the `~/todolist-repo` directory on
your server.

{% endsolution %}

## :exclamation: Run the PHP development server

Still in the cloned repository, run a PHP development server on port 3000 like
in the previous exercise. Note that this time you must provide the appropriate
configuration through environment variables:

- You must provide the `TODOLIST_DB_PASS` environment variable which has no
  default value.
- If the default values you have hardcoded for other variables are not suitable
  for your server's environment, you must also provide the corresponding
  environment variables with suitable values.

{% note type: tip %}

You can execute a command with additional environment variables using the
following syntax: `EXAMPLE='value' ANOTHER='one' command arg1 arg2`.

The single quotes around the variables' values are optional if the value
contains no spaces or special characters.

{% endnote %}

You (and everybody else) should be able to access the application in a browser
at the correct IP address and port (e.g. `W.X.Y.Z:3000`) and it should work.

## :checkered_flag: What have I done?

You have made your application configurable through the environment, as
recommended in the [Config section of The Twelve-Factor
App](https://12factor.net/config).

This means that you no longer need to make any changes to the code before
deploying your application to any new environment. It can now be deployed
_anywhere_, on any server or on any developer's local machine, without changing
a single line of code.

You simply need to set the appropriate environment variables when running it,
and the application will use that configuration instead of the hardcoded
defaults. For example, if you are deploying the application on a server where
the MySQL database server is exposed on a non-standard port like `5000`, simply
set the `TODOLIST_DB_PORT` variable, and the application will happily connect to
it.

### :classical_building: Architecture

This is a simplified architecture of the main running processes and
communication flow at the end of this exercise. Note that it has not changed
compared to [the previous exercises]({% link
_course/501-git-clone-deployment/exercise.md %}#classical_building-architecture)
since we have neither created any new processes nor changed how they
communicate.

![Diagram](./images/architecture.png)

<div class="flex items-center gap-2">
  <a href="./images/architecture.pdf" download="PHP Todolist Architecture" class="tooltip" data-tip="Download PDF">
    {%- include icons/document-arrow-down.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
  <a href="./images/architecture.png" download="PHP Todolist Architecture" class="tooltip" data-tip="Download PNG">
    {%- include icons/photo.html class="size-12 opacity-50 hover:opacity-100" -%}
  </a>
</div>

[php-shorthand-comparisons]: https://stitcher.io/blog/shorthand-comparisons-in-php
