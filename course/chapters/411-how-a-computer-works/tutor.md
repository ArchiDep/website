# Tutor notes: 411 How a computer works

## Scope

The chapter climbs from bits to a running deployment, and the slides and the
subject page split the climb between them.

The slides alone build the hardware, with its explanations in their speaker
notes: electricity, the telegraph and the relay; the logic gates built from
relays, with their symbols and truth tables; the half adder, full adder and
4-bit ripple-carry adder; the SR latch, D latch, selector, decoder and
addressable memory; the oscillator and the clock; the edge-triggered D
flip-flop, the frequency divider and the counter. They also hold the history
(the 1947 moth, relays then vacuum tubes then transistors), the word cloud of
what changed in processors since the 1970s, a modern x86-64 machine with
firmware, storage, disk controller and several cores, interrupts at boot, and
the coffee-queue analogy for concurrent and parallel programs. Outside its
appendices, the subject page shows only the relay AND, the half adder, the D
latch and the clock of these circuits.

Both cover what a byte can mean (a number, a gray level, an 8-bit color, a pixel
of an image or video, an ASCII or UTF-8 character) and that transforming data is
arithmetic; binary addition; the instruction set of the 8-bit machine, a small
JavaScript multiplication turned into its instructions, compilers and
interpreters; the machine stepping through that program; sequence, selection and
iteration, which its instructions are enough for; booting; what the
operating system does; and the four channels between isolated processes.

The subject page alone has "A particular place, at a particular time", the
chapter's main takeaway; "Programs and processes"; and "Your deployment, on the
machine", which steps through the architecture diagram of 410 and ends with what
the student should be able to draw.

The page says the student does not need to remember how switches are wired into
gates, what the gate symbols look like, or the boot stages and their program
names. What matters is what the circuits can do, what programs and processes
are, and that booting is a chain of ordinary programs.

The appendices of the subject page are optional depth:

- "What's in the box?": a shop's description of a desktop computer, each figure
  mapped to a part of the machine.
- "The cake is a lie": how the circuits the slides only name are built: a
  register, two's complement, the adder-subtractor and its flags (and so
  comparisons), a simplified ALU, adding numbers wider than the machine, the
  program counter, a larger memory from blocks, and the control unit, hardwired
  or microcoded.
- "Some assembly required": real instruction sets: operands, assembly language,
  the kinds of instructions, the stack (calls and returns, stack traces, stack
  overflows), x86-64 and ARM, emulators, bytecode and JIT compilation.
- "Harder, better, faster, stronger": what modern processors add for speed
  (caches, pipelining, branch prediction, cores) and for isolation (kernel and
  user mode, system calls, virtual memory, timer interrupts), and Spectre and
  Meltdown.
- "Two queues, one coffee machine": concurrency and parallelism in programs: why
  a program does not speed up with more cores on its own, Node.js's single
  thread, and how languages organize parallel work.
- "It's redstone all the way down": gates and computers built in Minecraft, and
  further resources.

## Left out

Taught later:

- Signals, `kill`, and process managers: "Process Management on Linux".
- systemd starting an application at boot: "Manage a PHP application with
  systemd as a Process Manager".
- Containers as isolated processes: "Docker".

Not in the course: transistor physics, floating-point numbers, multiplication
and division circuits, writing assembly, page tables and scheduling algorithms,
cache coherence, UTF-8 beyond its first 128 characters, and real hardware
beyond the figures of "What's in the box?".

## Key concepts and vocabulary

- **Bit** and **byte**: 0 or 1; eight bits, 256 values. **Nothing in the bits
  says what they mean**: the program that reads them decides.
- **Code point**: a character's number in **ASCII** or **UTF-8**.
- **1 means current, 0 means no current**: the convention from the relay slides
  on. A relay is a switch controlled by current.
- **Logic gate** and **truth table**. **Half adder** (XOR for the sum, AND for
  the carry), **full adder**, **ripple-carry adder**, **ALU**.
- **Latch** and **flip-flop**: circuits that remember a bit. **Selector** and
  **decoder** are the course's names for the multiplexer and demultiplexer.
- **Register**, **accumulator**, **program counter**, **instruction register**,
  **control unit**, **control signals**, **data bus** and **address bus**.
- **Instruction set**, **operation code** (opcode), and the
  **fetch, decode, execute** cycle. The three kinds of instructions: moving
  data, computing, and deciding which instruction runs next (jumps).
- **Sequence, selection, iteration**: the three building blocks of every
  program, which is why the machine's few instructions can run any program. On
  the machine: the program counter stepping through memory, `JUMPZ`, and a
  `JUMP` back.
- **Compiler**: translates a program into instructions, ahead of time or as it
  runs. **Interpreter**: a program made of instructions that reads your program
  as data.
- **Memory** (RAM, volatile, addressed by the processor) and **storage** (disk
  or SSD, persistent, reached through its controller).
- **Booting**: firmware (UEFI), bootloader (GRUB), kernel (Linux), the
  **init process** (systemd, PID 1), then everything else.
- **Program**: inert files in storage. **Process**: a program's instructions
  copied into memory, plus its data, executed by a processor, with its own
  memory.
- **Operating system**, **kernel**, **system call**: processes are isolated and
  communicate through **files**, **pipes**, **sockets** and **shared memory**.
- **Concurrent**: taking turns on one core. **Parallel**: running at the same
  time on several **cores**. A **thread** is one flow of instructions in a
  process.
- **Where and when a program runs**: which computer, in whose memory, on which
  processor, at what moment. This is the question the chapter asks the student
  to ask of every step of a deployment.

## Misconceptions

- **Misconception:** the processor decides or chooses what to do.
  **Correction:** the program decides. A conditional jump makes the next
  instruction depend on the last result, but that choice is written in the
  program, and the processor only carries it out.
- **Misconception:** a byte is a number, or a letter, by itself.
  **Correction:** the same byte is 83, `S`, a dark gray or a sky blue, depending
  on the program that reads it. An instruction is also a byte like any other.
  Question that reveals it: "What does `01010011` mean?"
- **Misconception:** computers use binary because they "think" in 0s and 1s.
  **Correction:** current and no current are easy to tell apart; ten levels of
  current would not be.
- **Misconception:** a gate cannot output 1 when all its inputs are 0, since
  the output current comes from the inputs.
  **Correction:** the current comes from a source the gate symbols do not draw.
  The inputs only control whether it reaches the output, so a NOT or a NOR
  outputs 1 when its inputs are 0.
- **Misconception:** memory and storage are the same thing, or a program runs
  straight from the disk.
  **Correction:** the processor runs instructions from memory only. A program
  is copied from storage into memory before it runs, and memory loses its
  contents without power.
- **Misconception:** a program is running because its files are on the server.
  **Correction:** a program is files; a process is a program being executed. A
  program that has stopped runs nowhere, however many copies of its files exist.
  Question that reveals it: "Guess It's files are on your server. Is Guess It
  running?"
- **Misconception:** two SSH sessions share one shell.
  **Correction:** they are two processes of the same program, each with its own
  memory.
- **Misconception:** Guess It runs on the student's computer, because the
  student sees it in the browser.
  **Correction:** the browser runs on the student's computer, with its
  processor and memory; Node.js and PostgreSQL run on the server, with its own.
  They communicate over a network connection.
  Question that reveals it: "You submit a guess. Which processor works out
  whether it is too high or too low?" (The server's, running Node.js. The
  browser only sends the form and displays the page it gets back; the secret
  number never leaves the server.)
- **Misconception:** the shell, `ls` or `ssh` are part of the operating system.
  **Correction:** they are ordinary programs that make system calls, like the
  programs the student writes.
- **Misconception:** an interpreted program never becomes instructions.
  **Correction:** the interpreter is itself instructions, which read the
  program as data. Either way, the processor runs only its own instructions.
- **Misconception:** concurrent and parallel mean the same thing, or more cores
  make any program faster.
  **Correction:** on one core, processes take turns; on several, they really
  run at the same time. A single flow of instructions uses one core however
  many there are.

The course deliberately simplifies the machine: one clock tick per step of the
cycle, a single shared bus, relays as switches, latches as memory cells, a
single register, and a 16-byte memory. The slides and the appendices each say
how a real processor differs, so a student who has read otherwise elsewhere is
not contradicted, only given more detail.

## Used in

Every deployment after this one is drawn as processes and connections, and
reading those diagrams relies on knowing which computer, which memory and which
processor each box stands for. Exercises that lean on particular parts:

- "Watch your processes" puts the chapter into practice on the student's server:
  a process starting and dying, the process tree up to PID 1, two shells with
  two memories, which computer runs a command, the server's processor, memory
  and disk, time spent computing or waiting, and processes taking turns on its
  cores.
- "Process Management on Linux" and "Manage a PHP application with systemd as a
  Process Manager" rely on the init process, systemd, starting everything else
  at boot.
- "Docker" compares the boot chain with what the Docker Engine replaces, and
  relies on process isolation.
