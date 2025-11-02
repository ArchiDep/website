---
title: The Image Gallery
---

An exercise to illustrate a security flaw.

## :exclamation: Get your public SSH key

You can display your public SSH key in your terminal with the following command:

```bash
$> cat ~/.ssh/id_ed25519.pub
```

You should copy the output of this command. You will need it later.

## :exclamation: Launch a virtual server

You will launch a virtual server to deploy the vulnerable application.

- Access the [Azure portal](https://portal.azure.com) and go to the **Virtual
  machines** section:

  ![Azure Portal](./images/azure-portal.png)

- Create a new virtual machine with these settings, then go to the
  **Disks** settings:

  ![Gallery virtual machine](./images/ex-gallery-azure.png)

- Keep the default **Disks** settings.

  Go to the **Networking** settings:

  ![Azure: go to the networking settings](./images/azure-vm-go-to-networking.png)

- In the **Networking** settings:
  - Make sure inbound ports 22 (SSH) and 80 (HTTP) are open.
  - Enable the option to automatically **Delete public IP and NIC when VM is
    deleted**.

  ![Gallery virtual machine](./images/ex-gallery-azure-networking.png)

- Create the VM.

## :exclamation: Set up the image gallery application

Follow the [instructions in this
repository](https://github.com/ArchiDep/vulnerable-image-gallery).

{% note type: warning %}

Be sure to do this on the gallery server you just launched, not on your main
cloud server.

{% endnote %}

You can connect to it with `ssh gallery@W.X.Y.Z` (where `W.X.Y.Z` is the IP
address of the server, which you can find in the Azure portal).
