# Tutor notes: 401 Cloud Computing

## Scope

The slides are what is taught; the subject page is reading and reference.

- Slides: the server side of the client-server model; shared, dedicated and
  virtual hosting; virtualization, the hypervisor, host and guest machines, and
  isolation; cloud computing as a pool of resources, with its pros and cons;
  public clouds; the service models IaaS, PaaS, FaaS and SaaS, each with an
  example price, as a ladder of abstraction ("Level of abstraction"); then Linux:
  a kernel, its Unix ancestry, why it runs most servers, and its distributions.
- Subject page: "The client-server model", which students know from their
  first-year networking course; "Service models", the same four models as a
  table.

Optional: the appendix "Cloud deployment models" (private, public, hybrid and
distributed clouds), and the history of AWS in the notes of the "Public clouds"
slide.

## Left out

Taught later:

- Renting and setting up an IaaS virtual machine: "Run your own virtual server
  on Microsoft Azure".
- Containers, and how they differ from virtual machines: "Docker".
- Deploying to a PaaS: "Platform-as-a-Service (PaaS)" and the deployments to
  GitHub Pages, Netlify and Render after it.

Not in the course: writing or deploying functions on a FaaS, how a hypervisor
works inside, orchestration (Kubernetes and the like), the providers' pricing
details beyond the example prices, and the history of Unix and Linux beyond the
slides.

## Key concepts and vocabulary

- **Server side**: the course is about the server of the client-server model:
  setting it up, deploying to it and managing it.
- **Shared, dedicated and virtual hosting**: many sites sharing one server's
  resources; a whole physical server; a physical server divided into **virtual
  servers**.
- **Virtualization**: a **hypervisor** on the **host machine** shares its CPU,
  memory, network and storage between **virtual machines** (**guest machines**),
  each running its own operating system, **isolated** from the others.
- **Cloud computing**: a pool of configurable computing resources (servers,
  infrastructure, applications), rented over the Internet instead of owned. A
  **public cloud** is one open to anyone, run by a provider in its data centers.
- **Service models**, by increasing **level of abstraction**: **IaaS** (pay per
  machine; the customer is the system administrator), **PaaS** (pay per
  application; the platform runs it), **FaaS** (pay per execution time; nothing
  runs when nothing happens), **SaaS** (pay a subscription; the software is the
  product). Each level up is quicker to use and less flexible.
- **Linux**: strictly a kernel, first released in 1991 by Linus Torvalds;
  commonly, the family of operating systems built around it, the
  **distributions**, such as Ubuntu. It is **Unix-like**: modelled on Unix
  without being Unix.

## Misconceptions

- **Misconception:** "the cloud" is something other than computers.
  **Correction:** it is someone else's computers, rented. The slides open on
  that joke on purpose.
- **Misconception:** a virtual machine is a simulation, slower and less real
  than a server.
  **Correction:** it runs on real hardware, shared by the hypervisor. It has its
  own operating system and is isolated from the other machines on the same
  host. The slides do say it performs less well than a dedicated server.
- **Misconception:** with IaaS, the provider keeps the server's software up to
  date and secure.
  **Correction:** the provider runs the hardware and the virtualization; the
  operating system and everything on it are the customer's to manage. That is
  what the student takes on with their own server.
- **Misconception:** a higher level of abstraction is simply better.
  **Correction:** each level trades flexibility for speed. PaaS is quicker to
  deploy to, controls less and costs more at larger scales.
- **Misconception:** Linux is one operating system, or macOS is Linux.
  **Correction:** Linux is a family of distributions sharing a kernel. macOS is
  Unix-like too, but not Linux, which is why commands and defaults differ
  between a Mac and the server.

## Used in

The whole course from here on runs on, or compares itself to, the IaaS virtual
machine the student rents. Parts that later chapters lean on in particular:

- "Run your own virtual server on Microsoft Azure" rents the virtual machine,
  running Ubuntu, and makes the student its administrator.
- "Meet your server" shows that the server's own address is a private one in the
  provider's network.
- "Docker" compares containers with virtual machines.
- "Platform-as-a-Service (PaaS)" moves one step up the ladder, after the
  deployments the student did by hand on IaaS.
