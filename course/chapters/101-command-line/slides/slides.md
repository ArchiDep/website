---
title: Command Line
---

# Command Line

Architecture & Deployment <!-- .element: class="subtitle" -->

---

## A short history of computers & computer interfaces

For old time's sake.

---

### The first general-purpose computer (1837)

The Analytical Engine, proposed by Charles Babbage <!-- .element: class="subtitle" -->

<div class="grid grid-cols-9 gap-4">
  <div class="col-span-3 col-start-2">
    <img src="{{ 'images/analytical-engine.jpg' | relative_file_url }}" alt="Analytical Engine">
  </div>
  <div class="col-span-1">&nbsp;</div>
  <div class="col-span-3">
    <img src="{{ 'images/charles-babbage.jpg' | relative_file_url }}" alt="Charles Babbage">
  </div>
</div>

**Notes:**

[Charles Babbage][charles-babbage], an English mathematician, proposed the
mechanical [Analytical Engine][analytical-engine]: the first [digital][digital]
[programmable][programmable], [general-purpose
computer][general-purpose-computer].

---

### The first programmer (1842)

Ada Lovelace publishes the first algorithm <!-- .element: class="subtitle" -->

<div class="grid grid-cols-10">
  <div class="col-span-4 col-start-4">
    <img src="{{ 'images/ada-lovelace.png' | relative_file_url }}" alt="Ada Lovelace">
  </div>
</div>

**Notes:**

In 1842, [Ada Lovelace][ada-lovelace] translated into English and extensively
annotated a description of the engine, including a way to calculate [Bernoulli
numbers][bernoulli-numbers] using the machine (widely considered to be the
[first complete computer program][note-g]). She has been described as the first
computer programmer.

---

### A century later (1940s)

Alan Turing formalizes algorithms and computation <!-- .element: class="subtitle" -->

<div class="grid grid-cols-10">
  <div class="col-span-4 col-start-4">
    <img src="{{ 'images/alan-turing.jpg' | relative_file_url }}" alt="Alan Turing">
  </div>
</div>

> Did you see [The Imitation Game][the-imitation-game]?

**Notes:**

[**Alan Turing**][alan-turing] formalized the concepts of [algorithm][algorithm]
and [computation][computation] with the [Turing machine][turing-machine]. He is
widely considered to be the father of theoretical [computer
science][computer-science] and [artificial
intelligence][artificial-intelligence].

---

### ENIAC (1946)

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/eniac.jpg' | relative_file_url }}" alt="ENIAC">
  </div>
</div>

**Notes:**

At that time, there was no such thing as a stored computer program. Programs
were **physically hard-coded**. On the [ENIAC][eniac], this was done using
function tables with **hundreds of ten-way switches**, which took weeks.

---

### The first bug that was caught (1947)

<div class="grid grid-cols-6">
  <div class="col-span-4 col-start-2">
    <img src="{{ 'images/bug.jpg' | relative_file_url }}" alt="Bug">
  </div>
</div>

**Notes:**

Computers like these are [electro-mechanical
computers][electro-mechanical-computers] because they were based on switches and
relays, as opposed to the [transistors][transistor] our current electronic
computers are based on.

When you had a bug in one of these computers, _debugging_ meant getting your
hands dirty and finding the [actual bug][bug] in the physical machine.

---

### Stored computer programs (1950s)

The Automated Computing Engine, designed by Alan Turing <!-- .element: class="subtitle" -->

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/ace.jpg' | relative_file_url }}" alt="Automated Computing Engine">
  </div>
</div>

**Notes:**

The [Automatic Computing Engine (ACE)][ace] was a British early electronic
serial [stored-program computer][stored-program-computer] designed by [Alan
Turing][alan-turing]. It used [mercury delay lines for its main
memory][delay-line-memory].

---

### Mercury delay line memory (1950s)

Better not spill it... <!-- .element: class="subtitle italic" -->

<div class="grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/mercury-delay-line-memory.jpg' | relative_file_url }}" alt="Mercury Delay Line Memory">
  </div>
</div>

---

### Punched cards (1950s)

One of the first user interfaces <!-- .element: class="subtitle" -->

<div class="grid grid-cols-12 gap-8">
  <div class="grid-5">&nbsp;</div>
  <div class="col-span-5 col-start-2">
    <img src="{{ 'images/punched-card.jpg' | relative_file_url }}" alt="Punched Card">

Invented in 1725 <!-- .element: style="margin-top: 0;" -->

  </div>
  <div class="col-span-5 col-start-7">
    <img src="{{ 'images/keypunch-machine.jpg' | relative_file_url }}" alt="Keypunch Machine">
  </div>
</div>

**Notes:**

Many early general-purpose digital computers used [punched cards][punched-card]
for data input, output and storage. Someone had to use a [keypunch][keypunch]
machine to write your cards, then feed them to the computer.

Punched cards are much older than computers. They were first invented around
1725 to control mechanical [looms][loom].

---

### A typical program (1950s)

<p class="subtitle italic">Whatever you do, <strong>DON'T</strong> drop it!</p>

<div class="grid grid-cols-10">
  <div class="col-span-6 col-start-3">
    <img src="{{ 'images/punched-cards-program.jpg' | relative_file_url }}" alt="Punched Card Program">
  </div>
</div>

---

### TeleTYpewriter (1960s)

<p class="subtitle">The first <strong>command line interfaces (CLI)</strong></p>

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/tty.jpg' | relative_file_url }}" alt="TeleTYpewriter">
  </div>
</div>

**Notes:**

Teletypewriters (TTYs) became the most popular **computer terminals** in the
1960s. They were basically electromechanical typewriters adapted as a user
interface for early [mainframe computers][mainframe].

This is when the first **command line interfaces (CLI)** were created. As you
typed commands, a program running on the computer would interpret that input,
and the output would be printed on physical paper.

---

### Video terminals (1970s)

<div class="grid grid-cols-10">
  <div class="col-span-6 col-start-3">
    <img src="{{ 'images/vt102.jpg' | relative_file_url }}" alt="VT102">
  </div>
</div>

**Notes:**

As available memory increased, **video terminals** such as the [VT100][vt100]
replaced TTYs in the 1970s. Initially they only displayed text. Hence they were
fundamentally the same as TTYs: textual input/output devices.

---

### Unix (1970s)

The first portable operating system <!-- .element: class="subtitle" -->

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/unix.png' | relative_file_url }}" alt="Unix">
  </div>
</div>

**Notes:**

It's also in this period that the [Unix][unix] operating system was developed.
Compared to earlier systems, Unix was the first **portable operating system**
because it was written in the [C programming language][c], allowing it to be
installed on multiple platforms.

Unix is the ancestor of [Linux][linux]. [FreeBSD][freebsd], a Unix-like system,
is also used as the basis for [macOS][macos] (since Mac OS X).

---

### Shells (1970s)

Text-based at that time <!-- .element: class="subtitle" -->

<div class="grid grid-cols-10">
  <div class="col-span-6 col-start-3">
    <img src="{{ 'images/shell.png' | relative_file_url }}" alt="Shell">
  </div>
</div>

**Notes:**

In Unix-like systems, the program serving as the **command line interpreter**
(handling input/output from the terminal) is called a [**shell**][unix-shell].
It is called this way because it is the outermost layer around the operating
system; it wraps and hides the lower-level kernel interface.

---

### Graphical User Interfaces (1980s)

Also a type of shell <!-- .element: class="subtitle" -->

<div class="grid grid-cols-12">
  <div class="col-span-6 col-start-4">
    <img src="{{ 'images/xerox-star.jpg' | relative_file_url }}" alt="Shell">
  </div>
</div>

**Notes:**

Eventually, [graphical user interfaces (GUIs)][gui] were introduced in reaction
to the perceived steep learning curve of command line interfaces. They are one
of the most common end user computer interface today.

Note that the GUI of a computer is also a shell. It's simply a different way to
interact with the kernel (graphical instead of textual).

---

### Motion sensing user interfaces (2000s)

Invented 1940s, on TV 1950s, in wise use 2000s

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/motion-sensing-interface.png' | relative_file_url }}" alt="Motion Sensing User Interface">
  </div>
</div>

**Notes:**

[Motion sensing][motion-sensing]

---

### Touch user interfaces (2000s)

Invented 1960s, on TV 1980s, in wise use 2000s

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/touch-user-interface.jpg' | relative_file_url }}" alt="Touch User Interface">
  </div>
</div>

**Notes:**

[Touch user interface][tui]

---

### Voice user interfaces (2010s)

Invented 1950s, on TV 1960s, in wise use 2010s

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/voice-user-interface.png' | relative_file_url }}" alt="Voice User Interface">
  </div>
</div>

**Notes:**

[Voice user interface][vui]

---

### Augmented reality (2010s)

Invented 1960s, on TV 1970s, in wise use 2010s

<div class="grid grid-cols-10">
  <div class="col-span-8 col-start-2">
    <img src="{{ 'images/augmented-reality.webp' | relative_file_url }}" alt="Augmented Reality">
  </div>
</div>

**Notes:**

[Augmented reality][augmented-reality]

---

### Virtual reality (2010s)

Invented 1960s, on TV 1980s, in wise use 2010s

<div class="grid grid-cols-12">
  <div class="col-span-10 col-start-2">
    <img src="{{ 'images/virtual-reality.webp' | relative_file_url }}" alt="Virtual Reality">
  </div>
</div>

**Notes:**

[Virtual reality][virtual-reality]

---

### Tomorrow?

<div class="grid grid-cols-10">
  <div class="col-span-6 col-start-3">
    <img src="{{ 'images/brain-computer-interface.png' | relative_file_url }}" alt="Brain Computer Interface">
  </div>
</div>

**Notes:**

[Brain-computer interface?][brain-interface]

[ace]: https://en.wikipedia.org/wiki/Automatic_Computing_Engine
[ada-lovelace]: https://en.wikipedia.org/wiki/Ada_Lovelace
[alan-turing]: https://en.wikipedia.org/wiki/Alan_Turing
[algorithm]: https://en.wikipedia.org/wiki/Algorithm
[analytical-engine]: https://en.wikipedia.org/wiki/Analytical_Engine
[artificial-intelligence]: https://en.wikipedia.org/wiki/Artificial_intelligence
[augmented-reality]: https://en.wikipedia.org/wiki/Augmented_reality
[bash]: https://en.wikipedia.org/wiki/Bash_(Unix_shell)
[bernoulli-numbers]: https://en.wikipedia.org/wiki/Bernoulli_number
[brain-interface]: https://en.wikipedia.org/wiki/Brain–computer_interface
[bug]: https://en.wikipedia.org/wiki/Bug_(engineering)#History
[building-the-future-of-the-command-line]: https://github.com/readme/featured/future-of-the-command-line
[c]: https://en.wikipedia.org/wiki/C_(programming_language)
[charles-babbage]: https://en.wikipedia.org/wiki/Charles_Babbage
[cli]: https://en.wikipedia.org/wiki/Command-line_interface
[computation]: https://en.wikipedia.org/wiki/Computation
[computer-science]: https://en.wikipedia.org/wiki/Computer_science
[delay-line-memory]: https://en.wikipedia.org/wiki/Delay-line_memory
[digital]: https://en.wikipedia.org/wiki/Digital_data
[electro-mechanical-computers]: https://en.wikipedia.org/wiki/Mechanical_computer#Electro-mechanical_computers
[eniac]: https://en.wikipedia.org/wiki/ENIAC
[freebsd]: https://en.wikipedia.org/wiki/FreeBSD
[general-purpose-computer]: https://en.wikipedia.org/wiki/Computer
[gui]: https://en.wikipedia.org/wiki/Graphical_user_interface
[keypunch]: https://en.wikipedia.org/wiki/Keypunch
[linux]: https://en.wikipedia.org/wiki/Linux
[loom]: https://en.wikipedia.org/wiki/Loom
[macos]: https://en.wikipedia.org/wiki/MacOS
[mainframe]: https://en.wikipedia.org/wiki/Mainframe_computer
[motion-sensing]: https://en.wikipedia.org/wiki/Motion_detection
[note-g]: https://en.wikipedia.org/wiki/Note_G
[powershell]: https://en.wikipedia.org/wiki/PowerShell
[programmable]: https://en.wikipedia.org/wiki/Computer_program
[punched-card]: https://en.wikipedia.org/wiki/Punched_card
[stored-program-computer]: https://en.wikipedia.org/wiki/Stored-program_computer
[the-imitation-game]: https://en.wikipedia.org/wiki/The_Imitation_Game
[transistor]: https://en.wikipedia.org/wiki/Transistor
[tty]: https://en.wikipedia.org/wiki/Teleprinter
[tui]: https://en.wikipedia.org/wiki/Touch_user_interface
[turing-machine]: https://en.wikipedia.org/wiki/Turing_machine
[unix]: https://en.wikipedia.org/wiki/Unix
[unix-shell]: https://en.wikipedia.org/wiki/Unix_shell
[virtual-reality]: https://en.wikipedia.org/wiki/Virtual_reality
[vt100]: https://en.wikipedia.org/wiki/VT100
[vui]: https://en.wikipedia.org/wiki/Voice_user_interface
