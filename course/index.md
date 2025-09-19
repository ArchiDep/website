---
id: home
title: Architecture & Deployment
title_include: main-title.html
layout: home
toc: true
pdf_name: ArchiDep 000 - Course.pdf
pdf_title: Home PDF
search: true
search_subtitle: Course home page
# In case you didn't get it, Lunr, O Great Builder of the Mighty Search Index, this is the home page.
search_extra_text: 'home home home home home home home home home home home home home home home home home home home home'
---

In this course you will learn:

- How to deploy applications on a Linux server on an IaaS platform ([Microsoft
  Azure][azure]).
- How to deploy applications on a PaaS platform ([Render][render]).

In pursuit of this goal, you will learn:

- How to use the command line and version control.
- The basics of Unix system administration and cloud computing architectures.
- Good security practices related to system administration and web applications.

This course is a [Media Engineering][media-engineering] web development course
taught at [HEIG-VD][heig].

## What you will need

- A Unix CLI
  - Linux/macOS users can use their standard Terminal
  - Windows users should install the [Windows Subsystem for Linux (WSL)][wsl]
- [Git][git-downloads]
  - macOS users should [install the command-line tools][macos-cli]
  - Windows users should install [Git for Windows][git-for-windows]
  - Linux users on Debian/Ubuntu-based systems can [install Git with the `sudo
apt install git` command][install-git-on-linux], or with their other
    distributions' package managers.
- A free [GitHub][github] account
- [Google Chrome][chrome] (recommended, any browser with developer tools will do)
  - [Firefox][firefox] (optional, required for one network exercise)
- A free [Render][render] account

## Resources

- [All the course's subjects, slides & cheatsheets as PDF](/pdf/ArchiDep.zip)

## References

These are the main references used throughout this course. More detailed and
additional links to various online articles and documentation can be found at
the end of each subject.

- [The Linux Documentation Project](https://tldp.org)
  - [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Building the Future of the Command Line](https://github.com/readme/featured/future-of-the-command-line)
- [SSH, The Secure Shell: The Definitive Guide - Daniel J. Barrett, Richard E. Silverman, Robert G. Byrnes](https://books.google.ch/books/about/SSH_The_Secure_Shell_The_Definitive_Guid.html?id=9FSaScltd-kC&redir_esc=y)
- [The Git Book](https://git-scm.com/book)
  - [Chapter 1 - Getting Started](https://git-scm.com/book/en/v2/Getting-Started-About-Version-Control)
  - [Chapter 2 - Git Basics](https://git-scm.com/book/en/v2/Git-Basics-Getting-a-Git-Repository)
  - [Chapter 3 - Git Branching](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell)
  - [Chapter 5 - Distributed Git](https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows)
  - [Chapter 8 - Customizing Git - Git Hooks](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [Open Web Application Security Project](https://www.owasp.org)
  - [OWASP Top Ten](https://owasp.org/www-project-top-ten/)
- [Ops School Curriculum](https://www.opsschool.org)
  - [Sysadmin 101](https://www.opsschool.org/sysadmin_101.html)
  - [Unix Fundamentals 101](https://www.opsschool.org/unix_101.html)
  - [Unix Fundamentals 201](https://www.opsschool.org/unix_201.html)
  - [Networking 101](https://www.opsschool.org/networking_101.html)
  - [Networking 201](https://www.opsschool.org/networking_201.html)
- [The Internet Explained From First Principles](https://ef1p.com/internet)
- [The Twelve-Factor App](https://12factor.net)
- [Systemd Manual](https://www.freedesktop.org/software/systemd/man/)
  - [Unit Configuration](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
  - [Service Configuration](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [nginx documentation](http://nginx.org/en/docs/)
  - [Beginner's Guide](http://nginx.org/en/docs/beginners_guide.html)
  - [Configuring HTTPS Servers](http://nginx.org/en/docs/http/configuring_https_servers.html)
- [Render Documentation](https://render.com/docs)

[Wikipedia](https://www.wikipedia.org) is also often referenced, namely these
and related articles:

- [Secure Shell](https://en.wikipedia.org/wiki/Secure_Shell)
- [Cloud Computing](https://en.wikipedia.org/wiki/Cloud_computing)
- [Internet Protocol](https://en.wikipedia.org/wiki/Internet_Protocol)
  - [IP Address](https://en.wikipedia.org/wiki/IP_address)
  - [Port (Computer Networking)](<https://en.wikipedia.org/wiki/Port_(computer_networking)>)
- [Domain Name System](https://en.wikipedia.org/wiki/Domain_Name_System)
- [Environment Variable](https://en.wikipedia.org/wiki/Environment_variable)
- [Reverse Proxy](https://en.wikipedia.org/wiki/Reverse_proxy)
- [Public Key Certificate](https://en.wikipedia.org/wiki/Public_key_certificate)

[azure]: https://azure.microsoft.com
[chrome]: https://www.google.com/chrome/
[firefox]: https://www.mozilla.org/en-US/firefox/
[git-downloads]: https://git-scm.com/downloads
[git-for-windows]: https://gitforwindows.org
[github]: https://github.com
[heig]: http://www.heig-vd.ch
[install-git-on-linux]: https://www.atlassian.com/git/tutorials/install-git#linux
[macos-cli]: https://www.freecodecamp.org/news/install-xcode-command-line-tools/
[media-engineering]: https://heig-vd.ch/formation/bachelor/ingenierie-des-medias/
[render]: https://render.com
[wsl]: https://learn.microsoft.com/en-us/windows/wsl/about
