---
title: Hello Shell
excerpt_separator: <!-- more -->
---

In this exercise, you go on a treasure hunt on your own computer. A script
prepares the hunt for you: an island where places are directories, clues are
files, and a few things are programs. You explore it with the [Command
Line][command-line]. On the way, you meet a few new commands.

{% callout type: exercise %}

**The rule of the hunt.** The goal of this exercise is to learn to use the
command line, so do everything in your terminal: the Terminal on macOS, the WSL
on Windows. Do not look at the files of the hunt in the Finder, the Windows file
explorer or a graphical editor.

Do not remember a command? Look it up in the [**Command Line**
cheatsheet][command-line-cheatsheet], in the sidebar. It is there for that, and
the hunt will send you there too.

{% endcallout %}

<!-- more -->

## :exclamation: Set your editor

You will edit a file during the hunt, and later in the course other programs
will open a text editor for you without asking. Tell them to use nano, so that
none of them opens Vim when you did not choose it.

Add the line to your shell's configuration file:

```bash
$> echo 'export EDITOR=nano' >> ~/.bashrc  # in the WSL
$> echo 'export EDITOR=nano' >> ~/.zshrc   # on macOS
```

Then close your terminal and open a new one.

{% note %}

See [setting nano as the default editor][command-line-editor].

{% endnote %}

## :exclamation: Prepare the hunt

Run this command:

```bash
$> curl -fsSL https://raw.githubusercontent.com/ArchiDep/website/main/course/chapters/102-hello-shell/treasure-hunt.sh | bash
```

`curl` downloads a script. The pipe (`|`) sends that script to `bash`, which
runs it. The script creates a directory named `treasure-hunt` in your home
directory, and everything the hunt needs inside it.

{% callout type: warning %}

**Be careful with `curl … | bash`.** It runs a program from the internet on your
computer, and you do not see what it does before it runs. Only do this with a
script from someone you trust. You can [read this
one](https://raw.githubusercontent.com/ArchiDep/website/main/course/chapters/102-hello-shell/treasure-hunt.sh)
before you run it. It only writes in `~/treasure-hunt`.

{% endcallout %}

At the end, the script tells you to type this command:

```bash
$> cd ~/treasure-hunt
```

Go ahead and do that. You will then be ready to explore the island.

{% note type: tip %}

Want to start over? Run the same `curl` command again. It asks before it deletes
your hunt.

{% endnote %}

## :exclamation: Explore the island

Read `start.txt`:

```bash
$> cat start.txt
```

Then follow the clues. Your goal for this part: find out where the captain hid
the key, and get past the dragon.

On the way, you will:

- Move around with `cd`, look around with `ls`, and read with `cat`.
- Find hidden files with `ls -a`.
- Go into a directory whose name has a space, with quotes or with Tab
  completion.
- Use relative paths with `..`.
- Read a long file with `less`.
- Run a program with `./`, and stop it.

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

$> cd "../old temple"   # or cd ../old\ temple
$> cat inscription.txt

$> cd ../jungle/river/waterfall
$> cat carving.txt

$> cd ../../ruins
$> cat stone.txt

$> cd ../../shipwreck
$> less diary.txt       # then type /dragon and press Enter,
                        # press n to go to the next match,
                        # and q to quit

$> cd ../cave
$> ./dragon             # then press Ctrl-C
$> ls lair
```

{% endsolution %}

### :question: The golden idol (optional)

The catacombs, under the ruins, are very deep. A golden idol is lost somewhere
down there. Bring it back in your bag, and your treasure will be bigger.

Do not search by hand: use `find` (see ["Find files" in the **Command Line**
cheatsheet][cheatsheet-find]).

{% solution %}

```bash
$> cd ~/treasure-hunt/jungle/ruins/catacombs

$> find . -name golden-idol
./left/right/left/.../golden-idol

# You have to copy the whole path find gives you, including
# the `./` at the beginning. Then you can move the golden
# idol to your bag:
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

`cp`, `mv` and `rm` are new: see ["Copy stuff"][cheatsheet-copy], ["Move
stuff"][cheatsheet-move] and ["Delete stuff"][cheatsheet-delete] in the
**Command Line** cheatsheet.

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

$> nano drawbridge.conf  # change state=closed to state=open,
                         # save and quit (use vim instead of
                         # nano if you want more of a challenge)
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

On Skull Island, the chest is a program that you are not allowed to run yet. See
["Make a file executable" in the **Command Line** cheatsheet][cheatsheet-chmod].
You will learn about permissions later in the course. The chest then asks for a
combination: look at the coins you've collected in your bag.

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
bag is not one of them. Take your bag everywhere: add `~/treasure-hunt/bag` to
your `PATH`, as explained in [the `PATH` variable][command-line-path] of
"Command Line".

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

## :checkered_flag: What have I done?

You interacted with your computer through nothing but text. The island you
explored is an ordinary directory in your home directory, and the Finder or the
Windows file explorer would have shown you the same files all along: same
computer, same file system, a different way of reaching it. Instead of seeing
things and clicking them, you named them and told a program what to do with
them.

The rule of the hunt is lifted, so go and see that for yourself: open the island
in your graphical interface. If your terminal is still open, the quickest way is
to ask for it there:

```bash
$> cd ~/treasure-hunt
$> open .            # on macOS
$> explorer.exe .    # in the WSL
```

There is the beach, there is the old temple with the space in its name, and
there is your bag with the treasure in it. Nothing you did happened in a
separate command line land that only exists inside the terminal: you were moving
these very icons around the whole time. Drag a file somewhere with the mouse,
then run `ls` in your terminal, and you will see the same change from both
sides.

On the way to the treasure, you:

- Moved around directories with relative and absolute paths.
- Read files with `cat` and `less`.
- Found hidden files and (possibly) a file lost deep in a tree.
- Moved, renamed, copied, created, edited and deleted files.
- Ran programs, stopped one, and made another one executable.
- Added a directory to your `PATH` so that the shell finds the treasure from
  anywhere.

Underneath those commands, you learned that your file system is a tree, and that
a path is an address in it: `.` is where you stand, `..` is one step up, `~` is
your home and `/` is the root that everything hangs from. Every file on your
computer has such an address, and once you can write it, you can reach anything
from anywhere. You also saw that the tree makes no distinction between kinds of
things: a clue, a key, a configuration file and a program were all just files,
and the same handful of commands worked on all of them.

You learned that a command is itself one of those files. `ls` and `cat` are not
magic words the terminal knows: they are programs, sitting in a directory, that
your shell found by looking through your `PATH`. That is why putting your bag in
your `PATH` turned `treasure` into a command exactly like them. There is no
privileged list of real commands that you are not allowed to add to.

Two things also work differently here than in a graphical interface, and both
are worth carrying with you:

- There is no trash bin and no undo: `rm` deletes a file forever, which is why
  you double-check each name before pressing Enter.
- Settings often live in plain text: you opened the drawbridge by editing
  `drawbridge.conf` in nano or vim, which is how a Unix system is typically
  configured.

That last point is why this chapter comes first. The server you will be given
later in the course has no Finder, no windows, no GUI at all: a text-based
command line is the only way in, and everything you just did on the island is
what you will be doing on it when you get there.

## :question: Clean up (optional)

The hunt is over? You can remove it from your computer:

- Open your shell's configuration file with nano again, and delete the line you
  added to your `PATH`. Then open a new terminal.
- Delete the hunt:

  ```bash
  $> rm -r ~/treasure-hunt
  ```

{% callout type: danger, animate: true %}

The `-r` option makes `rm` delete a directory and everything inside it. This is
the most dangerous command of this exercise: check the path twice before you
press Enter. If you insert a space in the wrong place, you could delete your
entire home directory.

{% endcallout %}

## :space_invader: Make your own hunt

You played someone else's hunt. Now build one, and make a friend play it.

Create a directory with three places in it. Put a clue in each one, each clue
pointing at the next place, and the treasure in the last place.

Then play your own hunt by hand, the way you played the one on the island: see
what's there (`ls`), read the first clue (`cat`), follow it to the next place
(`cd`), and go on until you dig up the treasure.

{% solution %}

Build the island: three places, a clue in each one, and the treasure at the end
of the trail.

```bash
$> mkdir -p ~/my-hunt/cave ~/my-hunt/lake ~/my-hunt/forest
$> cd ~/my-hunt

$> echo "An echo answers you: GO TO THE LAKE." > cave/echo.txt
$> echo "A fish jumps out and shouts: THE FOREST!" > lake/fish.txt
$> echo "The oldest tree whispers: DIG UNDER MY ROOTS." > forest/tree.txt
$> echo "A chest full of gold. The hunt is over!" > forest/treasure.txt
```

Check that the island looks the way you think it does:

```bash
$> find .
.
./cave
./cave/echo.txt
./forest
./forest/treasure.txt
./forest/tree.txt
./lake
./lake/fish.txt
```

Then play it, one clue at a time:

```bash
$> cd ~/my-hunt
$> cat cave/echo.txt
$> cat lake/fish.txt
$> cat forest/tree.txt
$> cat forest/treasure.txt
```

{% endsolution %}

### :space_invader: Automate it

You have to type those four commands, in that order, every single time you want
to see your hunt played, and so does everyone you show it to. Write that walk
down once instead, in a file the computer runs for you.

That is what a script is: anything you can type in your terminal, you can put in
a file and have the machine do for you, the same way every time, as often as you
want, on any machine. The treasure hunt you played on the island is itself such
a script: it typed several hundred `mkdir`, `echo` and `chmod` commands so that
you did not have to.

- Write a script that goes through the places in order and shows each clue with
  `cat`. Pause two seconds between clues for dramatic effect with `sleep 2`.
- Make the script executable (["Make a file executable"][cheatsheet-chmod]), then
  run it (["Run a program"][cheatsheet-run]).

{% note type: tip %}

The [Shell Scripting Cheatsheet][shell-scripting] has everything you need here —
the `#!/bin/bash` line every script starts with, how to define a function, and
how to run the finished script.

{% endnote %}

{% solution %}

Write the script with nano (or vim):

```bash
$> nano ~/my-hunt/play
```

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
cat forest/treasure.txt
```

Make it executable, and run it:

```bash
$> chmod +x ~/my-hunt/play
$> ~/my-hunt/play
```

The same four `cat` commands you typed by hand, in the same order, but written
down once. From now on, whenever you catch yourself typing the same commands
twice, that is a script asking to be written.

{% endsolution %}

[cheatsheet-chmod]: {% link cheatsheets/command-line/cheatsheet.md %}#make-a-file-executable-chmod-x
[cheatsheet-copy]: {% link cheatsheets/command-line/cheatsheet.md %}#copy-stuff-cp
[cheatsheet-delete]: {% link cheatsheets/command-line/cheatsheet.md %}#delete-stuff-rm
[cheatsheet-find]: {% link cheatsheets/command-line/cheatsheet.md %}#find-files-find
[cheatsheet-move]: {% link cheatsheets/command-line/cheatsheet.md %}#move-stuff-mv
[cheatsheet-run]: {% link cheatsheets/command-line/cheatsheet.md %}#run-a-program-program
[command-line]: {% link chapters/101-command-line/subject.md %}
[command-line-cheatsheet]: {% link cheatsheets/command-line/cheatsheet.md %}
[command-line-editor]: {% link chapters/101-command-line/subject.md %}#setting-nano-as-the-default-editor
[command-line-path]: {% link chapters/101-command-line/subject.md %}#the-path-variable
[shell-scripting]: {% link cheatsheets/shell-scripting/cheatsheet.md %}
