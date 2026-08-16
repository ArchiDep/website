---
title: Deploy static sites to GitHub Pages
excerpt_separator: <!-- more -->
---

The goal of this exercise is to deploy a **static website** (only HTML,
JavaScript and CSS) on [GitHub Pages][github-pages], a static site hosting
service, instead of your own server in the Infrastructure-as-a-Service (IaaS)
Microsoft Azure Web Services cloud.

<!-- more -->

## :exclamation: Fork the clock project

Fork the [static clock website repository][static-clock-repo]:

![Fork the static clock repository](./images/github-pages-fork.png)

![Fork the static clock repository](./images/github-pages-fork-2.png)

Once that is done, you should have your own copy of the clock repository under
your GitHub username:

![Your fork of the static clock repository](./images/github-pages-forked.png)

## :exclamation: Configure GitHub Pages

Go to the **Pages Settings** and configure GitHub Pages to deploy the **root of
the `main` branch**:

![Configure GitHub Pages](./images/github-pages-configure.png)

Save the changes.

### :exclamation: What else?

You're done! It's as simple as that.

You should be able to access your deployed static website at
https://JohnDoe.github.io/static-clock-website (replacing `JohnDoe` with your
GitHub username).

{% note type: tip %}

It may take a couple of minutes for the site to become available.

{% endnote %}

## :exclamation: Make a change to test the automated deployment

If you push a new commit to your repository (or make one on GitHub), you
can see that the new version will be automatically deployed!

{% note type: tip %}

It can take a couple of minutes for new commits to be deployed by GitHub Pages.

{% endnote %}

## :checkered_flag: What have I done?

In this exercise, you have deployed a static website to GitHub Pages, a static
site hosting service and a type of PaaS platform, using nothing but the web
interface provided by GitHub. You did not have to do any of the following:

- Hosting
- Reverse proxying
- TLS encryption
- Automated deployments
- Domain name

GitHub Pages is **free** for public repositories. Read [their
documentation][github-pages-docs] for more information.

[github-pages]: https://pages.github.com
[github-pages-docs]: https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages
[static-clock-repo]: https://github.com/ArchiDep/static-clock-website
