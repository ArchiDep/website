---
title: Hello Shell
excerpt_separator: <!-- more -->
---

In this exercise, you go on a treasure hunt on your own computer. A script
prepares the hunt for you: an island where places are directories, clues are
files, and a few things are programs. You explore it with the [Command
Line][command-line]. On the way, you meet a few new commands.

<!-- more -->

{% callout type: exercise %}

**The rule of the hunt.** The goal of this exercise is to learn to use the
command line, so do everything in your terminal: the Terminal on macOS, the WSL
on Windows. Do not look at the files of the hunt in the Finder, the Windows file
explorer or a graphical editor.

Do not remember a command? Look it up in the **Command Line** cheatsheet, in the
sidebar. It is there for that, and the hunt will send you there too.

{% endcallout %}

## :exclamation: Prepare the hunt

Run this command:

```bash
$> curl -fsSL https://raw.githubusercontent.com/ArchiDep/website/main/course/chapters/103-hello-shell/treasure-hunt.sh | bash
```

`curl` downloads a script. The pipe (`|`) sends that script to `bash`, which
runs it. The script creates a directory named `treasure-hunt` in your home
directory, and everything the hunt needs inside it.

{% callout type: warning %}

**Be careful with `curl … | bash`.** It runs a program from the internet on your
computer, and you do not see what it does before it runs. Only do this with a
script from someone you trust. You can [read this one](treasure-hunt.sh) before
you run it. It only writes in `~/treasure-hunt`.

{% endcallout %}

At the end, the script tells you to type this command:

```bash
$> cd ~/treasure-hunt
```

The script cannot do it for you. `bash` runs the script in a new shell, which is
a separate program. When the script changes directory, it only changes the
directory of that other shell, not yours.

{% note type: tip %}

Want to start over? Run the same `curl` command again. It asks before it deletes
your hunt.

{% endnote %}

## :exclamation: Explore the island

Read `start.txt`, then follow the clues. Your goal for this part: find out where
the captain hid the key, and get past the dragon.

On the way, you will:

- Move around with `cd`, look around with `ls`, and read with `cat`.
- Find hidden files with `ls -a`.
- Go into a directory whose name has a space, with quotes or with Tab
  completion.
- Use relative paths with `..`, and `cd` with nothing after it.
- Read a long file with `less`. It is new: see "What's in this file?" in the
  **Command Line** cheatsheet, in the sidebar.
- Run a program with `./`, and stop it with `Ctrl-C`.

{% note type: tip %}

Stuck? Every place has a hint in a hidden file: `cat .hint`.

{% endnote %}

{% solution %}

```bash
$> cd ~/treasure-hunt
$> cat start.txt
$> cd beach
$> ls -a
$> cat .bottle.txt
$> cd "../old temple"
$> cat inscription.txt
$> cd ../jungle/river/waterfall
$> cat carving.txt
$> cd ../../ruins
$> cat stone.txt
$> cd ../../shipwreck
$> less diary.txt       # then type /dragon, press Enter, and q to quit
$> cd ../cave
$> ./dragon             # then press Ctrl-C
$> ls lair
```

{% endsolution %}

### :question: The golden idol (optional)

The catacombs, under the ruins, are very deep. A golden idol is lost somewhere
down there. Bring it back in your bag, and your treasure will be bigger. Do not
search by hand: use `find` (see "Find files" in the **Command Line**
cheatsheet).

{% solution %}

```bash
$> cd ~/treasure-hunt/jungle/ruins/catacombs
$> find . -name golden-idol
./left/right/left/.../golden-idol
$> mv ./left/right/left/.../golden-idol ~/treasure-hunt/bag/
```

Your path is different: the catacombs are different each time the hunt is
prepared. Copy the one `find` gives you.

{% endsolution %}

## :exclamation: Change things

In this part, you do not only look at the island: you change it. Take the key
to the fortress and get to the top of its tower.

On the way, you will:

- Move a file with `mv`, and rename it with `mv` too.
- Copy a file with `cp`, and see how it is different from `mv`.
- Create a directory with `mkdir` and a file with `touch`, and write in a file
  with `echo … >`.
- Edit a file with nano (or Vim). You will do this a lot on your server later in
  the course.
- Delete files with `rm`.

`cp`, `mv` and `rm` are new: see "Copy stuff", "Move stuff" and "Delete stuff"
in the **Command Line** cheatsheet.

{% callout type: warning %}

`rm` deletes a file forever. There is no bin to get it back from. Read the name
twice before you press Enter.

{% endcallout %}

{% solution %}

```bash
$> cd ~/treasure-hunt/cave
$> mv lair/rusty-key ../bag/
$> cd ../fortress
$> mv ../bag/rusty-key key
$> ./door
$> cd courtyard
$> ./guardian
$> cp ../../shipwreck/map.txt map-copy.txt
$> ./guardian
$> ./rest
$> mkdir camp
$> touch camp/fire
$> echo lit > camp/fire
$> ./rest
$> nano drawbridge.conf  # change state=closed to state=open, save and quit
$> ./lever
$> cd tower
$> rm cursed-chest.txt
$> rm trap-snakes.txt
$> rm trap-spiders.txt
$> rm trap-spikes.txt
$> ./stairs
$> cd top
$> cat parrot.txt
```

{% endsolution %}

## :exclamation: Find the treasure

The parrot at the top of the tower tells you where to go next, as a path.
Follow it, then ring the bell from the right place. Before you run anything,
work out where the path goes: count the `..` one by one.

On Skull Island, the chest is a program that you are not allowed to run yet.
`chmod +x` fixes that. You will learn about permissions later in the course. The
chest then asks for a combination: look at the coins in your bag.

{% solution %}

```bash
$> cd ../../../../beach/./boat
$> pwd
/Users/jde/treasure-hunt/beach/boat
$> ~/treasure-hunt/bell
$> cd ../../skull-island
$> ./chest
permission denied: ./chest
$> chmod +x chest
$> cat ../bag/coin-1 ../bag/coin-2 ../bag/coin-3
$> ./chest
$> ../bag/treasure
```

The combination is different for each student: it is chosen at random when the
hunt is prepared.

{% endsolution %}

## :exclamation: Take the treasure home

The treasure is a program in your bag. You can run it with its path:

```bash
$> ~/treasure-hunt/bag/treasure
```

But you cannot run it with its name only, like `ls` or `cd`:

```bash
$> treasure
command not found: treasure
```

Your shell looks for commands in the directories listed in your `PATH`, and your
bag is not one of them. Take your bag everywhere: add
`~/treasure-hunt/bag` to your `PATH`, as explained in [the `PATH`
variable][command-line-path] of "Command Line".

- Look at your `PATH` with `echo $PATH`.
- Open your shell's configuration file with nano: `~/.bashrc` in the WSL,
  `~/.zshrc` on macOS.
- Add this line at the end of the file, then save and quit:

  ```bash
  export PATH="$HOME/treasure-hunt/bag:$PATH"
  ```

- Close your terminal and open a new one.
- Run `treasure`, from any directory.

{% solution %}

```bash
$> nano ~/.zshrc         # or ~/.bashrc in the WSL
```

Add this line at the end, save and quit:

```bash
export PATH="$HOME/treasure-hunt/bag:$PATH"
```

Open a new terminal, then:

```bash
$> cd /
$> treasure
```

{% endsolution %}

## :question: Make your own hunt (optional)

Make a small hunt of your own, with three clues, and a script that plays it. The
[Shell Scripting][shell-scripting] chapter explains what you need.

- Create a directory with three places in it. Put a clue in each one.
- Write a script that goes through the places in order and shows each clue with
  `cat`. Wait two seconds between clues with `sleep 2`.
- Make the script executable, and run it.

{% solution %}

```bash
#!/bin/bash
cd ~/my-hunt || exit 1

show_clue() {
  cat "$1"
  sleep 2
}

show_clue cave/echo.txt
show_clue lake/fish.txt
show_clue forest/tree.txt
```

{% endsolution %}

## :question: Clean up (optional)

The hunt is over? You can remove it from your computer:

- Open your shell's configuration file with nano again, and delete the line you
  added to your `PATH`. Then open a new terminal.
- Delete the hunt:

  ```bash
  $> rm -r ~/treasure-hunt
  ```

  The `-r` option makes `rm` delete a directory and everything inside it. This is
  the most dangerous command of this exercise: check the path twice before you
  press Enter.

## :checkered_flag: What just happened?

You moved around directories with relative and absolute paths, and read files
with `cat` and `less`. You found hidden files and a file lost deep in a tree.
You moved, renamed, copied, created, edited and deleted files. You ran programs,
stopped one, and made another one executable. Finally, you added a directory to
your `PATH`, so that the shell finds the treasure from anywhere.

[command-line]: {% link chapters/101-command-line/subject.md %}
[command-line-path]: {% link chapters/101-command-line/subject.md %}#the-path-variable
[shell-scripting]: {% link chapters/102-shell-scripting/subject.md %}
