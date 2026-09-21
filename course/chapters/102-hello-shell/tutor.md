# Tutor notes: 102 Hello Shell

## Starting point

- 101 Command Line: the hunt uses its commands, plus `cp`, `mv`, `rm`, `less`
  and `find`, which it sends students to the Command Line cheatsheet for.
- A Unix shell: the Terminal on macOS, the WSL on Windows (installed in 101).
  Everything is typed there, never in PowerShell or `cmd`.
- A terminal window of at least 80 columns and 32 lines, or the drawings break.
  The setup warns when it is smaller.

## Learning objectives

Using a computer through text only: moving around the tree with relative and
absolute paths, reading, creating, copying, moving, editing and deleting files,
running a program and stopping one, and adding a directory to the `PATH`. The
page's "What have I done?" states what the student should understand
afterwards; check their explanations against it.

Used as recipes, not explained: `chmod +x` and "Permission denied" ("Unix
Permissions"), `curl … | bash` ("Unix Processes"). A hint mentions the `*`
wildcard only to advise against it.

## Where it leads

The rest of the course is typed in a shell, and from "Run your own virtual
server on Microsoft Azure" on, files on the server are edited with nano, as a
settings file is here. In particular:

- Hello SSH has the student carry the treasure to a server, where it runs as a
  file but not as a command: the `PATH` stays at home. It also cleans up what
  this exercise leaves.
- `EDITOR=nano` keeps Git from opening Vim for a commit message.

## The treasure hunt

The page:

1. "Set your editor": one line appended to the shell configuration file.
2. "Prepare the hunt": a `curl … | bash` command builds `~/treasure-hunt`. The
   rule of the hunt: everything in the terminal, never the Finder or Explorer.
3. "Go on the hunt": guided by the hunt itself, below.
4. "Take the treasure home": adding `~/treasure-hunt/bag` to the `PATH`, so that
   `treasure` runs from anywhere. "What have I done?" then lifts the rule.
5. "Keep your treasure": Hello SSH needs it.
6. Optional: "Make your own hunt" and "Automate it", a first script.

How the hunt works:

- Places are directories, clues are text files, and some things are programs,
  run with `./name`. The `bag` directory is the inventory.
- **Each place has a hidden `.hint` giving the exact commands for its step.**
  It is the hunt's solution, one step at a time. A place's hint changes as the
  hunt moves on, so it is worth reading again.
- Most programs are gates. Each says what is missing; once the task is done, it
  creates the next area, with its hint. An area that is not open yet cannot be
  found with `ls`. A program's texts are encoded: reading one with `cat` shows
  code, ending with a banner that says how to run it.
- The chest's combination and the path to the golden idol differ per student.
- Starting over: run the same `curl … | bash` command again. It asks before it
  deletes the hunt, and everything is new, combination included. Most mistakes
  do not need it: the gates say what is wrong, and a file moved to the wrong
  place can be moved back. Only a needed file that was deleted does.
- The student plays. Do not read the hunt's files, and do not fetch the setup
  script: it holds the whole solution. Ask what their place says and what `pwd`
  prints.

What each part practises, and the question worth asking at it:

- **Exploring**: hidden files, a name with a space, relative paths up and down,
  a long file read with `less`, a program that never stops by itself, and,
  optionally, a file lost deep in a tree. Ask: why does `ls` not show
  everything here? Where will `cd ../..` take you, and how do you check?
- **Changing things**: renaming while moving, copying rather than moving,
  creating a directory and files, writing into a file, editing a settings file
  with nano, deleting files. Ask: what would `mv` have done to the original? How
  would you get a deleted file back?
- **The treasure**: a long relative path, a program run by its absolute path
  from a given place, a program that is not executable, and a combination read
  from the three coins gates dropped on the way. Ask: why does a program here
  need `./` when `ls` does not? Before the `PATH` change: what will `which
treasure` print, before and after, and why does it need a new terminal?

## Common pitfalls

- **The setup command fails.** Hint: which program is this terminal?
- **The configuration file lost its content.** Hint: compare the two operators
  in "The `echo` command" of 101.
- **`cd old temple` fails** (`too many arguments` in Bash,
  `string not in pwd` in Zsh). Hints: how many arguments did `cd` get? Quotes,
  a backslash, or `Tab`.
- **The hint does not match the task**, or a file is "not found": the student
  is in another place. Hints: `pwd`; `cd ~/treasure-hunt` starts over from the
  top.
- **`command not found` when running a program**: `./` is missing. **The
  program's code is shown**: it was read with `cat` instead of run.
- **The terminal seems frozen**: a program is running, which is the task at one
  point. Hint: what does the screen say about stopping it?
- **The map was moved instead of copied**: the gate asks for it back. Hint: move
  it back, then compare `cp` and `mv`.
- **"Permission denied" on Skull Island** is expected; the island's hint covers
  it.
- **Every command is now `not found`**, `nano` included. Hint: what did the
  line do to the list of directories?
