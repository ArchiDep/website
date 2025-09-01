---
title: Run your own virtual server on Microsoft Azure
---

This guide describes how to run a virtual server appropriate for the Media
Engineering Architecture & Deployment course on the [Microsoft Azure][microsoft-azure] cloud platform.

## :exclamation: Apply to Azure for Students
Apply to [Azure for Students][azure-for-students]
**with your `@hes-so.ch` email address**, which will provide you with free
Azure resources as a student.

![Azure for Students Landing Page](images/azure-for-students-signup.png)

## :exclamation: Get your public SSH key

You can display your public SSH key in your terminal with the following command:

```bash
$> cat ~/.ssh/id_e25519.pub
```

{% note type: tip %}

If you have an older SSH client, you may want to try displaying the contents of `~/.ssh/id_rsa.pub` instead.

{% endnote %}

## :exclamation: Launch a virtual server

Once you have your Azure account, you can launch the virtual server you will be using for the rest of the course.

- Access the [Azure portal][azure-portal] and go to the **Virtual machines** section:

![Azure Portal](images/azure-portal-menu.png)

- Create a new virtual machine, i.e. a new virtual server in the Microsoft Azure infrastructure:

![Azure: Create a new virtual machine](images/azure-create-vm.png)

- In the **Basics** settings, configure the **virtual machine details** (the machine's name, region, image and size):

![Azure: VM instance details](images/azure-vm-instance-details.png)

{% callout %}
**MAKE SURE TO SELECT THE `Ubuntu 24.04` IMAGE AND THE `B1s` SIZE.** If you select a VM size that is too expensive, **YOU WILL RUN OUT OF FREE CREDITS BEFORE THE END OF THE COURSE** You will then have pay 💸 for a new VM and will have to reinstall your VM from scratch (including all deployment exercises you may already have completed).

{% endcallout %}

If the correct size is not selected, you can select it from the complete list of VM sizes:

![Azure: virtual machine size](images/azure-vm-size.png)

{% note type: troubleshooting %}

If you cannot select the `B1s` size, try selecting another availability zone (or another region that is not too expensive).

{% endnote %}

{% note type: tip %}

Any region will do. Closer to where you are (or where your customers are) will reduce latency, and the North/West European regions are among the cheapest.

{% endnote %}

- Under the **Administrator account** settings, choose a username. For example, if your name is "John Doe", you might choose jde as a short, easy-to-type username.

{% note type: warning %}

**Your Unix username MUST NOT** contain spaces, accented characters (e.g. é), hyphens (-) or dots (.). If you use the same name later in the course as a subdomain, it **MUST NOT** contain any underscores (_). We suggest you choose a name that starts with a letter (a-z) and contains only alphanumeric characters (a-z and 0-9).

{% endnote %}

{% note type: tip %}

Choose a username that is simple to type because you will need to type it often. If necessary, you can [change it later][sysadmin-cheatsheet].

{% endnote %}

[azure-for-students]:https://azure.microsoft.com/en-us/free/students/
[azure-portal]:https://portal.azure.com
[microsoft-azure]:https://azure.microsoft.com
[sysadmin-cheatsheet]:../701-sysadmin-cheatsheet/

