#!/bin/bash
#
# The treasure hunt of the "Hello Shell" exercise of the ArchiDep course.
#
# This script builds the hunt in ~/treasure-hunt. It writes nothing anywhere
# else. Run it again to start over: it asks before it deletes the old hunt.
#
# Warning: spoilers. This file contains the whole hunt, solution included.
#
# It must run with the Bash 3.2 that macOS includes and with the GNU tools of
# the WSL, which is why it avoids associative arrays, "sed -i" and other
# things that differ between the two.

# Since Bash 5.2, an "&" in the replacement of ${value//pattern/replacement}
# stands for the text that matched, which would break the "&&" of the gates
# below. Bash 3.2 has no such option, and nothing to turn off.
shopt -u patsub_replacement 2> /dev/null

# The edition of the course this hunt belongs to. Every page of the site is
# published under the starting year of its academic year, so the year is the
# first segment of every address the hunt sends students to. It moves at the
# year-end rollover, with the rest of the edition.
CURRENT_YEAR=2026

# Where the command line cheatsheet is published, which every text that sends
# students there writes as @@CHEATSHEET@@, followed by the anchor of a section
# when there is one.
CHEATSHEET="https://archidep.ch/$CURRENT_YEAR/cheatsheets/command-line/"

# Reads a heredoc into the variable named by $1, exactly as written, leading
# spaces included.
text() {
  IFS= read -r -d '' "$1" || true
}

# The areas a gate opens are written into that gate, so that they cannot be
# found with ls before the gate opens. They are sealed with the cipher of
# Julius Caesar: every letter and digit is shifted 3 places further, and turned
# back when the gate opens. The areas are sealed inside one another, which
# shifts the innermost ones several times over: letters come back to where
# they started only after 26 shifts and digits after 10, and the deepest area
# is 5 levels down.
CAESAR_PLAIN='A-Za-z0-9'
CAESAR_SEALED='D-ZA-Cd-za-c3-90-2'

# The commands that work with sealed texts, which every gate includes, with the
# text on their input: reveal prints it unsealed, unpack <file> <mode> writes it
# unsealed, and seal prints it sealed.
UNPACK="reveal() { LC_ALL=C tr '$CAESAR_SEALED' '$CAESAR_PLAIN'; }
unpack() { reveal > \"\$1\" && chmod \"\$2\" \"\$1\"; }
seal() { LC_ALL=C tr '$CAESAR_PLAIN' '$CAESAR_SEALED'; }"

# The gold coin a gate drops, drawn with its number: @@COIN1@@, @@COIN2@@ and
# @@COIN3@@ in a text are the three coins.
text COIN <<'END_COIN'
     .-"""-.
    /  .-.  \
   |  ( @@DIGIT@@ )  |
    \  '-'  /
     '-...-'
END_COIN
# The coin is written on a line of its own, which already ends it.
COIN=${COIN%$'\n'}

# Prints a text with its placeholders replaced.
fill() {
  local value="$1"
  value=${value//@@HUNT@@/$HUNT}
  value=${value//@@CHEATSHEET@@/$CHEATSHEET}
  value=${value//@@UNPACK@@/$UNPACK}
  value=${value//@@COIN1@@/${COIN//@@DIGIT@@/$D1}}
  value=${value//@@COIN2@@/${COIN//@@DIGIT@@/$D2}}
  value=${value//@@COIN3@@/${COIN//@@DIGIT@@/$D3}}
  value=${value//@@D1@@/$D1}
  value=${value//@@D2@@/$D2}
  value=${value//@@D3@@/$D3}
  value=${value//@@SEALED_COMBINATION@@/$SEALED_COMBINATION}
  printf '%s' "$value"
}

# Prints a text, placeholders replaced, sealed with the cipher of Caesar. The
# gate holds it in a heredoc, which passes quotes, backslashes and dollars
# through untouched.
pack() {
  fill "$1" | LC_ALL=C tr "$CAESAR_PLAIN" "$CAESAR_SEALED"
}

# Seals the text in the variable named by $3 into the text in the variable
# named by $1, in place of the placeholder @@$2@@. The placeholder is the body
# of a heredoc ending with SEALED_$2, a line no sealed text can hold: it is
# shifted with the rest at every level.
embed() {
  local parent="${!1}" child
  heredoc_body child "${!3}"
  printf -v "$1" '%s' "${parent//@@$2@@/$child}"
}

# Sets the variable named by $1 to the text $2 sealed, as the body of a heredoc:
# without its last newline, which the heredoc gives it back.
heredoc_body() {
  local sealed
  # The x keeps the newlines the text ends with, which $(...) would remove.
  sealed=$(pack "$2"; echo x)
  sealed=${sealed%x}
  printf -v "$1" '%s' "${sealed%$'\n'}"
}

# Writes a text into a file: put <file> <text> [<mode>]
put() {
  fill "$2" > "$1" && chmod "${3:-644}" "$1"
}

fail() {
  echo "$*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# The start
# ---------------------------------------------------------------------------

text START <<'END_START'

                     |\
                     | \
                     |  \
                     |___\
                _____|_____
                \  o  o  o /
          ~~~~~~~\________/~~~~~~~
             ~~~~~~   ~~~~~~   ~~~~

         THE TREASURE OF SKULL ISLAND

Long ago, a pirate captain hid a treasure near this island.
Many explorers looked for it. Nobody found it.
Now it is your turn.

HOW TO PLAY

- Places are directories. Move from place to place with cd.
- Look around with ls. Read things with cat.
- Lost? pwd tells you where you are.
- Your bag is the directory named bag. Things you pick up go in it.
- Some things are programs. You run them with ./ before their name.
- Stuck? Every place has a hint in a hidden file named .hint. You
  cannot see it with ls, but you can read it: cat .hint

Every explorer carries a handbook. Read yours before you go:

    cat bag/explorers-handbook.txt

The adventure starts on the beach.
END_START

text HANDBOOK <<'END_HANDBOOK'
A small book, worn at the corners. Every explorer who ever landed on
this island carried one. Most of its pages are gone. These two are
still readable:

      _____________________ ______________________
     /                     |                      |
    |   THE EXPLORER'S     |  "Traveller, one day |
    |      HANDBOOK        |   you will forget a  |
    |                      |   word of the        |
    |    ~~~~~~~~~~~~~     |   sailors' tongue.   |
    |    ~~~~~~~~~~~       |   Everyone does.     |
    |    ~~~~~~~~~~~~~     |   Open the great     |
    |                      |   book, and it will  |
    |                      |   come back."        |
    |______________________|______________________|

The great book of commands is here:

    @@CHEATSHEET@@

Every command you need on this island is written in it. Keep this
handbook in your bag, and open the great book whenever you are stuck.
END_HANDBOOK

text START_HINT <<'END_START_HINT'
HINT

Go to the beach:

    cd beach

Then look around with ls, and read what you find with cat.
END_START_HINT

# ---------------------------------------------------------------------------
# Part 1: exploring
# ---------------------------------------------------------------------------

text SAND <<'END_SAND'
                                                   \   |   /
         __ _.--.  .--._ __                         .-"""-.
      .-'  _/    \/    \_  '-.                  -- (       ) --
     /   .'  _.-./\.-._  '.   \                     '-...-'
     '--'  .'   / () \   '.  '--'                  /   |   \
          /    /|    |\    \            ~~~
               '|    |'                       ~~~          ~~~
                 \   \
  ~~~~~~~~~~~~~~~ \   \ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ~~~~~~~        |   |   ~~~~~~~      ~~~~~~~~      ~~~~~~~      ~~~~~
  ~ ~ ~ ~ ~ ~ ~ ~ ~|   |~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
  . . : . . . . . /     \ . : . . . . . : . . . . : . . . . . : . . . .
   .  :  .  .  .:/       \: :  .   .  .  :  .   .  .  :  .   .   .  :
  : . . . : . . . . : . . . : . . . . : . . . . . : . . . : . . . . : .
   . . :  .  .  . :  .  .  . .  : . . . . * . .  : . .  .  :  .  . . .
  . : . . . . : . . . . : . . . : . . . . . . : . . . . . : . . . . : .

Sand. Only sand, as far as you can see.

Nothing here... or is there? Look closer.
END_SAND

text BOTTLE <<'END_BOTTLE'
                     ____________________
                    /                    \_____
            ~~     |  ~~~    ~~~~    ~~   _____[]
                    \____________________/
               ~~~~       ~~~~~~       ~~~~

You found a bottle! There is a message inside:

      ______________________________________________________
     (__)                                                   )
        |                                                  |
        |    If you want my treasure,                      |
        |    go to the old temple.                         |
        |                                                  |
        |                                 -- The Captain   |
        |__________________________________________________|
       (____________________________________________________)

The old temple is next to the beach.
Be careful: its name has a space in it.
END_BOTTLE

text BEACH_HINT <<'END_BEACH_HINT'
HINT

Some files are hidden: their name starts with a dot, like this hint.
ls does not show them.

Commands have options that change what they do. The -a option of ls
shows all files, the hidden ones too:

    ls -a

One of the hidden files is a bottle. Read it like any other file:

    cat .bottle.txt

To go to the old temple from here, go up with .. first. A name with a
space must be in quotes:

    cd "../old temple"

Or type cd ../old and press Tab: the shell completes the name for you.
END_BEACH_HINT

text OARS <<'END_OARS'
Two old oars. This boat could take you far away.
But where? Nobody has told you yet.
END_OARS

text BOAT_HINT <<'END_BOAT_HINT'
HINT

Nothing to do here yet. Come back when someone tells you to.
END_BOAT_HINT

text INSCRIPTION <<'END_INSCRIPTION'
Words are carved in the old stone:

           _.-------------------------------------------._
        .-'   .       '         .          ,       .      '-.
       /  '        .                  '         .     '     \
      |     .                                         .      |
      |  ,      FOLLOW THE RIVER INTO THE JUNGLE,         '  |
      |    '    ALL THE WAY TO THE WATERFALL.        .       |
      |  .                                                 , |
       \      '        .            ,          '     .      /
        \____.______________'_____________.________________/
     ___/_______________________________________________\___
    /_______________________________________________________\
END_INSCRIPTION

text TEMPLE_HINT <<'END_TEMPLE_HINT'
HINT

The jungle is next to the temple: go up with .., then into jungle.

You can go through several directories with one cd, for example:

    cd ../jungle/river

Look around with ls at each step.
END_TEMPLE_HINT

text JUNGLE_HINT <<'END_JUNGLE_HINT'
HINT

Follow the river, all the way to the waterfall.
END_JUNGLE_HINT

text RIVER_HINT <<'END_RIVER_HINT'
HINT

The waterfall is further down the river: cd waterfall
END_RIVER_HINT

text CARVING <<'END_CARVING'
There is a carving behind the falling water:

      ~~~~~~   ~~~~~~   ~~~~~~   ~~~~~~   ~~~~~~   ~~~~~~
   _____________________________________________________________
  /' | : | ' | : | ' | : | ' | : | ' | : | ' | : | ' | : | ' | :\
  |: | ' | : | ' | : | ' | : | ' | : | ' | : | ' | : | ' | : | '|
  |' | : | ' | : .-------------------------------. ' | : | ' | :|
  |: | ' | : | ' |                               | : | ' | : | '|
  |' | : | ' | : |    GO BACK TWO PLACES.        | ' | : | ' | :|
  |: | ' | : | ' |    THEN ENTER THE RUINS.      | : | ' | : | '|
  |' | : | ' | : |                               | ' | : | ' | :|
  |: | ' | : | ' '-------------------------------' : | ' | : | '|
  |' | : | ' | : | ' | : | ' | : | ' | : | ' | : | ' | : | ' | :|
  |: | ' | : | ' | : | ' | : | ' | : | ' | : | ' | : | ' | : | '|
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     ~   o    ~   o    ~   o    ~   o    ~   o    ~   o    ~
END_CARVING

text WATERFALL_HINT <<'END_WATERFALL_HINT'
HINT

.. is the directory above the one you are in. ../.. is two levels
above. A path can go up, then down again:

    cd ../../ruins

Use pwd to check where you are.
END_WATERFALL_HINT

text STONE <<'END_STONE'
A big stone with a message on it:

            _.----------------------------------------._
        _.-'    .          '         .          ,       '-._
      .'  '                      .                     '    '.
     / ,       THE CAPTAIN'S SHIP BROKE ON THE ROCKS.      .  \
    |    .            '                       ,           '    |
    |      FROM HERE, THE SHIPWRECK IS AT ../../shipwreck    . |
     \      ,                 '                   .           /
      '-._________.________________'____________.__________.-'

Next to the stone, stairs go down into the dark: the catacombs.
Someone wrote on the wall:

    ______
          |______
                |______
                      |______
      "A GOLDEN IDOL        |______
       IS LOST                    |______
       DOWN THERE."                     |______
                                              |::::::::::::::
                                              |::::::::::::::
END_STONE

text RUINS_HINT <<'END_RUINS_HINT'
HINT

Read the path one piece at a time: .. (up once), .. (up again), then
shipwreck:

    cd ../../shipwreck

Lost? cd with nothing after it always takes you home, to ~. From
there:

    cd
    cd treasure-hunt

The catacombs are optional. You can come back for the idol later.
END_RUINS_HINT

text CATACOMBS_SIGN <<'END_CATACOMBS_SIGN'
DANGER! These catacombs are very, very deep.

The golden idol is somewhere down there. Put it in your bag, and your
treasure will be bigger.
END_CATACOMBS_SIGN

text CATACOMBS_HINT <<'END_CATACOMBS_HINT'
HINT

Do not search by hand: there are too many tunnels. The find command
searches a directory and everything inside it:

    find . -name golden-idol

Then move the idol into your bag with mv, using the path that find
gave you:

    mv ./left/right/.../golden-idol ~/treasure-hunt/bag/

Tab completion helps with long paths.

See "Find files" in the command line cheatsheet:
@@CHEATSHEET@@#find-files-find
END_CATACOMBS_HINT

text BONES <<'END_BONES'
Only old bones here. This tunnel ends.
Go back up with cd .. and try another one.
END_BONES

text IDOL <<'END_IDOL'
         .-"-.
        / o o \
        \  ^  /
        /`---'\
       |  ***  |
       |_______|

The golden idol! It is heavy, and it shines in the dark.

Do not leave it in the dark: put it in your bag.
END_IDOL

text SHIPWRECK_HINT <<'END_SHIPWRECK_HINT'
HINT

The diary is long. cat prints all of it, and you only see the end.
Read the end first: it tells you what to do.
END_SHIPWRECK_HINT

text MAP <<'END_MAP'
                    THE CAPTAIN'S MAP

   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ~~       ______________________________            ~~
   ~~      /   jungle         ruins       \___        ~~
   ~~     |   ~~~river~~~      [##]           \       ~~
   ~~     |                                    |      ~~
   ~~     |   old temple   cave    fort        |      ~~
   ~~      \     [^]       (@@)    [==]       /       ~~
   ~~       \______beach________shipwreck___/         ~~
   ~~                                         X       ~~
   ~~                                  skull island   ~~
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

   Do not lose this map.
END_MAP

# The diary is built line by line when the hunt is set up: see diary(). The
# help for less is at the top, so that it is the first thing less shows.
text DIARY_START <<'END_DIARY_START'
THE DIARY OF THE CAPTAIN

  +----------------------------------------------------------+
  |  How to read a long file with less:                      |
  |                                                          |
  |  - Arrow keys or Space: move down and up.                |
  |  - Type /octopus and press Enter: search for "octopus".  |
  |  - Press n: go to the next match.                        |
  |  - Press q: quit less, and go back to your shell.        |
  +----------------------------------------------------------+

END_DIARY_START

text DIARY_CLUE <<'END_DIARY_CLUE'
We reached the island at last. I buried the key in the sea cave,
behind the octopus. Nobody will ever take it: the octopus never
wakes up.
END_DIARY_CLUE

text DIARY_END <<'END_DIARY_END'
--------------------------------------------------------------------

This is the END of a long diary. The captain wrote a lot!
cat printed the whole file, so the first pages went by too fast.

To read a long file from the beginning, use less. The first lines of
the diary explain how to move in less, and how to quit it. Then type:

    less diary.txt
END_DIARY_END

# ---------------------------------------------------------------------------
# The octopus
# ---------------------------------------------------------------------------

text CAVE_HINT <<'END_CAVE_HINT'
HINT

The octopus is a program. To run a program in the directory you are
in, write ./ before its name:

    ./octopus

This one never stops by itself. To interrupt a program that is
running, press Ctrl-C.

See "Run a program" in the command line cheatsheet:
@@CHEATSHEET@@#run-a-program-program
END_CAVE_HINT

text OCTOPUS <<'END_OCTOPUS'
#!/bin/bash
# A giant octopus. It is sleeping. Do not wake it up.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -d "$HUNT/cave/den" ]; then
  reveal <<'SEALED'
The octopus is gone. Only its den is left.
SEALED
  exit 0
fi

wake_up() {
  echo
  reveal <<'SEALED'
The octopus opens one eye. You interrupted its sleep!

It turns white, then red. It fills the water with ink, and it is
gone: eight arms into a crack in the rock, and a quieter pool on the
other side.

               _.-"""-._
             .'  o   o  '.         ::::::::::::
            (      _      )      ::::::::::::::::
             \ \   |   / /        ::::::::::::
              '  '  '  '

Where it slept, there is a hole in the rock: its den. An octopus
keeps its treasures at the door, and this one kept shells, a crab
claw, and something else.
SEALED
  mkdir "$HUNT/cave/den" &&
  unpack "$HUNT/cave/den/rusty-key" 644 <<'SEALED_RUSTY_KEY' &&
@@RUSTY_KEY@@
SEALED_RUSTY_KEY
  unpack "$HUNT/cave/den/.hint" 644 <<'SEALED_DEN_HINT'
@@DEN_HINT@@
SEALED_DEN_HINT
  exit 0
}

trap wake_up INT

reveal <<'SEALED'
              .-"""""-.
            .'  -   -  '.
           (      ~      )
            '-.._____..-'
            /  /  |  \  \
           (  (   |   )  )
      ~~~~~~~~~~~~~~~~~~~~~~~~

The sea comes into this cave. In the pool at the back, a giant
octopus sleeps. Nothing can wake it up...

Words are scratched on the wall of the cave:

    "NO NOISE WILL EVER WAKE THE OCTOPUS.
     BUT A PROGRAM, EVEN AN OCTOPUS, CAN BE STOPPED
     WITH TWO KEYS PRESSED TOGETHER.
     THE GREAT BOOK OF COMMANDS KNOWS WHICH ONES."

     @@CHEATSHEET@@

SEALED

# The bubbles grow on one line before the next one starts, so that the octopus
# stays on screen for a while.
while true; do
  printf '   '
  for bubble in . o O o O; do
    printf ' %s' "$bubble"
    sleep 1
  done
  echo
done
END_OCTOPUS

text RUSTY_KEY <<'END_RUSTY_KEY'
   .---.
  /  _  \______________________
 |  (_)   _____________________|
  \     /           |_|  |_| |_|
   '---'

RUSTY KEY

An old, heavy key, green with salt. A word is written on it: FORT.

Do not leave it lying here: put it in your bag.
END_RUSTY_KEY

text DEN_HINT <<'END_DEN_HINT'
HINT

You found a key! Pick it up: move it into your bag with mv. Your bag
is in ~/treasure-hunt/bag. From here, that is two levels up:

    mv rusty-key ../../bag/

Then take the key to the fort.

See "Move stuff" in the command line cheatsheet:
@@CHEATSHEET@@#move-stuff-mv
END_DEN_HINT

# ---------------------------------------------------------------------------
# Part 2: changing things
# ---------------------------------------------------------------------------

text FORT_HINT <<'END_FORT_HINT'
HINT

The door of the fort is a program. To run a program in the
directory you are in, write ./ before its name:

    ./door

It needs a file named key, next to it. Your key is in your bag, and
its name is rusty-key.

mv moves a file. It can also give it a new name, at the same time:

    mv ../bag/rusty-key key

Then run ./door again.
END_FORT_HINT

text DOOR <<'END_DOOR'
#!/bin/bash
# The door of the fort. It is locked.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -d "$HUNT/fort/courtyard" ]; then
  reveal <<'SEALED'
The door is open. The courtyard is behind it.
SEALED
  exit 0
fi

if [ ! -f "$HUNT/fort/key" ]; then
  reveal <<'SEALED'
            _________
          .'    |    '.
         /      |      \
        |       |       |
        |    o  |  o    |
        |       |       |
        |       |       |
        |_______|_______|

The door is locked. There is a keyhole.

A key must be in the lock: a file named key, next to the door.
SEALED
  exit 1
fi

if ! grep -q 'RUSTY KEY' "$HUNT/fort/key"; then
  reveal <<'SEALED'
This is not the right key. It does not turn.
SEALED
  exit 1
fi

mkdir "$HUNT/fort/courtyard" &&
unpack "$HUNT/fort/courtyard/mapmaker" 755 <<'SEALED_MAPMAKER' &&
@@MAPMAKER@@
SEALED_MAPMAKER
unpack "$HUNT/fort/courtyard/.hint" 644 <<'SEALED_MAPMAKER_HINT' || exit 1
@@MAPMAKER_HINT@@
SEALED_MAPMAKER_HINT

mkdir -p "$HUNT/bag"
reveal > "$HUNT/bag/coin-1" <<'SEALED'
A gold coin. A number is carved on it: @@D1@@
SEALED

reveal <<'SEALED'
Click. The key turns, and the heavy door opens.

            _________
          .'         '.
         /             \
        |               |
        |               |
        |               |
        |               |
        |_______________|

A gold coin falls out of the lock. You put it in your bag.

@@COIN1@@

Behind the door is the courtyard of the fort. Someone is waiting for
you there:

          ___
         /___\
         (o o)
        (  ~  )
      ___|   |___
     /   |   |   \
    (____|___|____)
SEALED
END_DOOR

text MAPMAKER_HINT <<'END_MAPMAKER_HINT'
HINT

The mapmaker is a program. Talk to the mapmaker by running it:

    ./mapmaker

The mapmaker wants a copy of the captain's map. cp copies a file.
The copy can have another name, and be in another place. mv would
move the original, and the original must stay in the shipwreck.

From the courtyard, the shipwreck is two levels up, then down:

    cp ../../shipwreck/map.txt map-copy.txt

Then run ./mapmaker again.

See "Copy stuff" in the command line cheatsheet:
@@CHEATSHEET@@#copy-stuff-cp
END_MAPMAKER_HINT

text MAPMAKER <<'END_MAPMAKER'
#!/bin/bash
# The mapmaker, left on this island a long time ago. Loves maps.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fort/courtyard"
original="$HUNT/shipwreck/map.txt"
copy="$here/map-copy.txt"

if [ -f "$here/rest" ]; then
  reveal <<'SEALED'
The mapmaker nods. You may pass.
SEALED
  exit 0
fi

reveal <<'SEALED'
                ___
               /___\
               (o o)
              (  ~  )
            ___|   |___
           /   |   |   \
          /    |   |    \
         (_____|   |_____)
               |   |
              /|   |\
               |   |
              _/   \_
             (__) (__)
        ___     ___     ___
       /__/    /__/    /__/

An old mapmaker, in rags, left on this island long before you came.
Papers everywhere: every stone of the island, drawn again and again.

SEALED

if [ ! -f "$original" ]; then
  reveal <<'SEALED'
"Where is the captain's map? A map that is taken is a map that is
 lost! Put it back in the shipwreck. Then bring me a copy."
SEALED
  exit 1
fi

if [ ! -f "$copy" ]; then
  reveal <<'SEALED'
The mapmaker stands in your way.

"Stop there. I have drawn this island for thirty years, but never the
 sea around it, and the captain's map has the sea on it.

 Bring me a copy of that map. Put it here, next to me, and name it
 map-copy.txt. A copy, mind: the map itself stays in the shipwreck."
SEALED
  exit 1
fi

if ! cmp -s "$original" "$copy"; then
  reveal <<'SEALED'
"This is not a copy of the captain's map!"
SEALED
  exit 1
fi

unpack "$here/rest" 755 <<'SEALED_REST' &&
@@REST@@
SEALED_REST
unpack "$here/.hint" 644 <<'SEALED_REST_HINT' || exit 1
@@REST_HINT@@
SEALED_REST_HINT

reveal <<'SEALED'
The mapmaker looks at the copy for a long time, and nods.

"Two maps now, and neither of them lost. You may pass. But night is
 falling. You should rest first."
SEALED
END_MAPMAKER

text REST_HINT <<'END_REST_HINT'
HINT

Resting is a program. Lie down by running it:

    ./rest

You cannot rest without a camp and a lit fire. mkdir makes a
directory. touch makes an empty file. echo with > writes text into a
file:

    mkdir camp
    touch camp/fire
    echo lit > camp/fire

(You do not really need touch here: > makes the file if it does not
exist yet.) Then run ./rest again.
END_REST_HINT

text REST <<'END_REST'
#!/bin/bash
# A good place to sleep, if you have a fire.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fort/courtyard"

if [ -f "$here/lever" ]; then
  reveal <<'SEALED'
It is morning. The drawbridge is waiting.
SEALED
  exit 0
fi

# The sun sets behind the walls of the fort until the camp is ready.
sunset() {
  reveal <<'SEALED'
        .              *                .           *
   *            .               .                .
                        \   |   /
                   --   .-"""""-.   --
  _   _   _   _   _   _   _   _   _   _   _   _
 | |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |
 |                                             |

SEALED
}

if [ ! -d "$here/camp" ]; then
  sunset
  reveal <<'SEALED'
Night is falling. It is getting dark and cold. You cannot rest without
a camp and a fire.

Make a directory named camp, here. In it, make a file named fire.
The fire is lit when the file contains the word: lit
SEALED
  exit 1
fi

if [ ! -f "$here/camp/fire" ]; then
  sunset
  reveal <<'SEALED'
Your camp has no fire. Make a file named fire in the camp.
SEALED
  exit 1
fi

if ! grep -q 'lit' "$here/camp/fire"; then
  sunset
  reveal <<'SEALED'
The fire is not lit. The fire file must contain the word: lit
SEALED
  exit 1
fi

unpack "$here/drawbridge.conf" 644 <<'SEALED_DRAWBRIDGE_CONF' &&
@@DRAWBRIDGE_CONF@@
SEALED_DRAWBRIDGE_CONF
unpack "$here/lever" 755 <<'SEALED_LEVER' &&
@@LEVER@@
SEALED_LEVER
unpack "$here/.hint" 644 <<'SEALED_DRAWBRIDGE_HINT' || exit 1
@@DRAWBRIDGE_HINT@@
SEALED_DRAWBRIDGE_HINT

reveal <<'SEALED'
              (
          )    )  (
         (  ) (    )
          ) (  )  (
         (  _)_(_  )
        __(__)_(__)__
       (___(____)____)

The fire is warm. You lie down next to it, and you fall asleep.

SEALED

# The snores grow on one line, as the octopus's bubbles do, but they stop on
# their own after three seconds: the octopus never stops, and a student who met
# it first is quick to reach for Ctrl-C. They only take their time in a
# terminal, where someone is watching them.
printf '   '
for snore in z zz Zzz; do
  printf ' %s' "$snore"
  [ -t 1 ] && sleep 1
done
echo

reveal <<'SEALED'

In the morning, you see what you could not see in the dark: a big
drawbridge, closed, and a lever to open it.

    _   _   _   _   _   _   _
   | |_| |_| |_| |_| |_| |_| |
   |  \                   /  |
   |   \   ___________   /   |
   |    \_|===========|_/    |
   |      |===========|      |
   |      |===========|      |          O
   |      |===========|      |         /
   |      |===========|      |        /
   |      |===========|      |      _/_
 ~~|______|===========|______|~~   |___|
   ~~~~~  ~~~~~~  ~~~~~~  ~~~~~~

There is also a file with the settings of the drawbridge.
SEALED
END_REST

text DRAWBRIDGE_CONF <<'END_DRAWBRIDGE_CONF'
# Settings of the drawbridge.
# The lever reads this file before it moves.
#
# Using nano? A wise choice, traveller. The keys you need are written at
# the bottom of the screen: ^O means Ctrl-O (save), ^X means Ctrl-X (quit).
#
# Using Vim? You chose the most dangerous path. Many adventurers went into
# Vim, and few came out. We hope you know the magic words.
#
chains=rusty
state=closed
END_DRAWBRIDGE_CONF

text DRAWBRIDGE_HINT <<'END_DRAWBRIDGE_HINT'
HINT

The lever is a program. Pull it by running it:

    ./lever

It will not move while drawbridge.conf says the drawbridge is closed.
Open that settings file with the nano editor:

    nano drawbridge.conf

Move with the arrow keys. Change closed to open. Save with Ctrl-O,
then Enter. Quit with Ctrl-X. (Vim works too, if you know it.)

Then run ./lever again.
END_DRAWBRIDGE_HINT

text LEVER <<'END_LEVER'
#!/bin/bash
# The lever of the drawbridge.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fort/courtyard"

if [ -d "$here/tower" ]; then
  reveal <<'SEALED'
The drawbridge is down. The tower is open.
SEALED
  exit 0
fi

if ! grep -Eq '^[[:space:]]*state[[:space:]]*=[[:space:]]*open[[:space:]]*$' "$here/drawbridge.conf" 2>/dev/null; then
  reveal <<'SEALED'
You pull the lever as hard as you can. It does not move.

The settings of the drawbridge, in drawbridge.conf, say that it is
closed. Change them to open.
SEALED
  exit 1
fi

mkdir "$here/tower" &&
unpack "$here/tower/cursed-chest.txt" 644 <<'SEALED_CURSED_CHEST' &&
@@CURSED_CHEST@@
SEALED_CURSED_CHEST
unpack "$here/tower/trap-spikes.txt" 644 <<'SEALED_TRAP_SPIKES' &&
@@TRAP_SPIKES@@
SEALED_TRAP_SPIKES
unpack "$here/tower/trap-snakes.txt" 644 <<'SEALED_TRAP_SNAKES' &&
@@TRAP_SNAKES@@
SEALED_TRAP_SNAKES
unpack "$here/tower/trap-spiders.txt" 644 <<'SEALED_TRAP_SPIDERS' &&
@@TRAP_SPIDERS@@
SEALED_TRAP_SPIDERS
unpack "$here/tower/stairs" 755 <<'SEALED_STAIRS' &&
@@STAIRS@@
SEALED_STAIRS
unpack "$here/tower/.hint" 644 <<'SEALED_TOWER_HINT' || exit 1
@@TOWER_HINT@@
SEALED_TOWER_HINT

mkdir -p "$HUNT/bag"
reveal > "$HUNT/bag/coin-2" <<'SEALED'
A gold coin. A number is carved on it: @@D2@@
SEALED

# Each part of what happens waits a little before the next one, in a
# terminal, where someone is watching.
pause() {
  if [ -t 1 ]; then sleep 1; fi
}

reveal <<'SEALED'
The chains turn. Slowly, the drawbridge goes down.

    _   _   _   _   _   _   _
   | |_| |_| |_| |_| |_| |_| |
   |  \                   /  |
   |    \    _______    /    |
   |      \ |       | /      |          O
   |        |       |        |           \
   |        |       |        |            \
 ~~|________|       |________|~~          _\_
  ~~~~~~~~ /=========\ ~~~~~~~~          |___|
   ~~~~~  /===========\  ~~~~~

SEALED
pause
reveal <<'SEALED'
A gold coin was hidden under the lever. You put it in your bag.

@@COIN2@@

SEALED
pause
reveal <<'SEALED'
On the other side of the drawbridge, there is a tall tower.

           |>>>
           |
       _  _|_  _
      | |_| |_| |
      |         |
      |   [ ]   |
      |   ___   |
     _|__|   |__|_
SEALED
END_LEVER

text CURSED_CHEST <<'END_CURSED_CHEST'
         _______________
        /              /|
       /______________/ |
       |     .-.      | |
       |    (x.x)     | |
       |     |=|      | |
       |______________|/

A small chest, covered with skulls. It is cursed!

Nobody can climb the stairs of the tower while it is here.
END_CURSED_CHEST

text TRAP_SPIKES <<'END_TRAP_SPIKES'
      /\  /\  /\  /\  /\  /\  /\
     /  \/  \/  \/  \/  \/  \/  \
    |____________________________|

A trap full of spikes. Remove it before you climb.
END_TRAP_SPIKES

text TRAP_SNAKES <<'END_TRAP_SNAKES'
         _____
        /  o  \__
        \_____ __>-<
          / /
         ( (
          \ \_______
           \________)

A trap full of snakes. Remove it before you climb.
END_TRAP_SNAKES

text TRAP_SPIDERS <<'END_TRAP_SPIDERS'
           |           |
           |           |
       \ \ | / /   \ \ | / /
      __\_(oo)_/__ __\_(oo)_/__
        / (  ) \     / (  ) \
       / /    \ \   / /    \ \

A trap full of spiders. Remove it before you climb.
END_TRAP_SPIDERS

text TOWER_HINT <<'END_TOWER_HINT'
HINT

The stairs of the tower are a program. Climb them by running them:

    ./stairs

Nothing can climb while the cursed chest and the traps are here. rm
deletes a file:

    rm cursed-chest.txt

Careful: there is no bin. A deleted file is gone forever. Read the
name twice before you press Enter. Delete each trap the same way,
then run ./stairs again.

One command could clear all the traps at once: rm trap-*.txt. The *
matches any text. It is fast, but one typo can delete much more than
you wanted. Name each file to be more careful.

See "Delete stuff" in the command line cheatsheet:
@@CHEATSHEET@@#delete-stuff-rm
END_TOWER_HINT

text STAIRS <<'END_STAIRS'
#!/bin/bash
# The stairs of the tower.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fort/courtyard/tower"

if [ -d "$here/top" ]; then
  reveal <<'SEALED'
You already climbed the stairs. The top of the tower is open.
SEALED
  exit 0
fi

remaining=""
for thing in cursed-chest.txt trap-spikes.txt trap-snakes.txt trap-spiders.txt; do
  if [ -e "$here/$thing" ]; then
    remaining="$remaining    $thing
"
  fi
done

if [ -n "$remaining" ]; then
  reveal <<'SEALED'
You cannot climb the stairs. These are still here:
SEALED
  echo
  printf '%s' "$remaining"
  exit 1
fi

mkdir "$here/top" &&
unpack "$here/top/parrot.txt" 644 <<'SEALED_PARROT' &&
@@PARROT@@
SEALED_PARROT
unpack "$here/top/.hint" 644 <<'SEALED_TOP_HINT' || exit 1
@@TOP_HINT@@
SEALED_TOP_HINT

reveal <<'SEALED'
The curse is gone. You climb the stairs, all the way to the top.

                        o               ______
                       /|\        ______|
                       / \  ______|
                      ______|
                ______|
          ______|
    ______|

Someone is waiting for you there.
SEALED
END_STAIRS

text PARROT <<'END_PARROT'
         ,
        (o>    A parrot is sitting at the top of the tower.
        //\    It looks at you and speaks:
        V_/_
         ||

    "SQUAWK! Want the treasure? Take the boat!
     From here, go to ../../../../beach/./boat
     and ring the bell! SQUAWK!"

The bell? It is back where the hunt started: ~/treasure-hunt/bell
END_PARROT

text TOP_HINT <<'END_TOP_HINT'
HINT

Read the path one piece at a time, starting from here:

    ..               up once: the tower
    ../..            up twice: the courtyard
    ../../..         the fort
    ../../../..      the start of the hunt
    beach            then into the beach
    .                "the directory I am in": this changes nothing
    boat             then into the boat

When you are in the boat, ring the bell with its full path. A full
(absolute) path works from anywhere:

    ~/treasure-hunt/bell
END_TOP_HINT

text BELL <<'END_BELL'
#!/bin/bash
# The ship's bell. It must be rung from the right place.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -d "$HUNT/skull-island" ]; then
  reveal <<'SEALED'
DING! You already went to Skull Island.
SEALED
  exit 0
fi

if [ ! -f "$HUNT/fort/courtyard/tower/top/parrot.txt" ]; then
  reveal <<'SEALED'
DING! Nothing happens. It is not the right time.
SEALED
  exit 1
fi

boat=$(cd "$HUNT/beach/boat" 2>/dev/null && pwd -P)
if [ -z "$boat" ] || [ "$(pwd -P)" != "$boat" ]; then
  reveal <<'SEALED'
DING! Nothing happens.

The parrot said to ring the bell from the boat. Where are you? pwd
tells you.
SEALED
  exit 1
fi

mkdir "$HUNT/skull-island" &&
unpack "$HUNT/skull-island/chest" 644 <<'SEALED_CHEST' &&
@@CHEST@@
SEALED_CHEST
unpack "$HUNT/skull-island/.hint" 644 <<'SEALED_ISLAND_HINT' &&
@@ISLAND_HINT@@
SEALED_ISLAND_HINT
unpack "$HUNT/beach/boat/oars.txt" 644 <<'SEALED_OARS_AFTER' &&
@@OARS_AFTER@@
SEALED_OARS_AFTER
unpack "$HUNT/beach/boat/.hint" 644 <<'SEALED_BOAT_HINT_AFTER' || exit 1
@@BOAT_HINT_AFTER@@
SEALED_BOAT_HINT_AFTER

mkdir -p "$HUNT/bag"
reveal > "$HUNT/bag/coin-3" <<'SEALED'
A gold coin. A number is carved on it: @@D3@@
SEALED

# Each part of the trip waits a little before the next one, in a terminal,
# where someone is watching.
pause() {
  if [ -t 1 ]; then sleep 1; fi
}

reveal <<'SEALED'
DING! DING! DING!

The parrot lands on the boat.

             ,
            (o>
            //\
            V_/_
       ______||_______
       \  o   o   o  /
    ~~~~\___________/~~~~
       ~~~~~    ~~~~~

SEALED
pause
reveal <<'SEALED'
"SQUAWK! Row! Row!"
You row for a long time. Then you see it: Skull Island.

                 __ _.--.  .--._ __
              .-'  _/    \/    \_  '-.
             /   .'  _.-./\.-._  '.   \
             '--'  .'   /()\   '.  '--'
                        \  \
                         |  |
              ___________|  |___________
      ~~~~~~ /    .    '    '   .    .  \ ~~~~~~
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SEALED
pause
reveal <<'SEALED'
A gold coin was stuck in the bell. You put it in your bag.

@@COIN3@@

Skull Island is in ~/treasure-hunt/skull-island. There is a chest.
SEALED
END_BELL

# What the boat says once the bell has taken you across, in place of the oars
# and the hint that wait for the parrot to tell you where to sail.
text OARS_AFTER <<'END_OARS_AFTER'
Two old oars, still wet. This boat has taken you to Skull Island.

The island is in ~/treasure-hunt/skull-island. There is a chest
waiting for you there.
END_OARS_AFTER

text BOAT_HINT_AFTER <<'END_BOAT_HINT_AFTER'
HINT

You have already sailed. Skull Island is two levels up from the boat,
then down into the island:

    cd ../../skull-island
END_BOAT_HINT_AFTER

# ---------------------------------------------------------------------------
# Part 3: the treasure
# ---------------------------------------------------------------------------

# This hint names the section of the cheatsheet it wants but addresses the one
# above it, which holds it: the address of "Make a file executable" is longer
# than the width of the smallest terminal the hunt fits in, and would wrap.
text ISLAND_HINT <<'END_ISLAND_HINT'
HINT

The chest is a program. Open it by running it:

    ./chest

"Permission denied" means you are not allowed to do this: the chest
is not executable yet. chmod +x makes a file executable:

    chmod +x chest

You will learn about permissions later in the course.

See "Make a file executable" in the command line cheatsheet:
@@CHEATSHEET@@#running-programs

Then run ./chest again. It asks for a combination: look at the coins
in your bag.
END_ISLAND_HINT

text CHEST <<'END_CHEST'
#!/bin/bash
# The captain's chest. It has a combination lock.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -f "$HUNT/bag/treasure" ]; then
  reveal <<'SEALED'
The chest is empty. The treasure is in your bag.
SEALED
  exit 0
fi

reveal <<'SEALED'
         ____________________
        /                   /|
       /___________________/ |
       |     [ ? ? ? ]     | |
       |___________________|/

The captain's chest! It has a lock with three numbers.
SEALED

# The question ends with a space instead of a newline, so that the answer is
# typed after it.
reveal <<'SEALED' | tr -d '\n'
Enter the combination (coin 1, coin 2, coin 3):
SEALED
printf ' '
read -r answer
answer=$(printf '%s' "$answer" | tr -cd '0-9')

# The combination is sealed too: the answer is sealed the same way before the
# two are compared.
if [ "$(printf '%s' "$answer" | seal)" != '@@SEALED_COMBINATION@@' ]; then
  reveal <<'SEALED'

Click... The lock does not open. Look at the coins in your bag.
SEALED
  exit 1
fi

mkdir -p "$HUNT/bag"
unpack "$HUNT/bag/treasure" 755 <<'SEALED_TREASURE' || exit 1
@@TREASURE@@
SEALED_TREASURE

reveal <<'SEALED'

CLICK! The chest opens. The treasure is inside!

You put it in your bag: ~/treasure-hunt/bag/treasure. It is a
program. From here, run it with:

    ../bag/treasure

Can you run it from anywhere, just by typing treasure? Go back to
the exercise, to "Take the treasure home", and find out.
SEALED
END_CHEST

text TREASURE <<'END_TREASURE'
#!/bin/bash
# The treasure of Skull Island.
HUNT='@@HUNT@@'
@@UNPACK@@

reveal <<'SEALED'

          *             .              *
                o       o       o
      .        /\      /\      /\        .
              /  \    /  \    /  \
             /    \__/    \__/    \
            |   <>     ()     <>   |
     *      |______________________|      *
          (o)(O)(o)(O)(o)(O)(o)(O)(o)
       (O)(o)(O)(o)(O)(o)(O)(o)(O)(o)(O)
    (o)(O)(o)(O)(o)(O)(o)(O)(o)(O)(o)(O)(o)

      YOU FOUND THE TREASURE OF SKULL ISLAND!
      The crown and the gold of the captain are yours.

SEALED

if [ -e "$HUNT/bag/golden-idol" ]; then
  reveal <<'SEALED'
                 .-"-.
                / o o \
                \  ^  /
                /`---'\
               |  ***  |
               |_______|

   And the golden idol from the catacombs! You found everything.

SEALED
fi

# The treasure is a file, so it can be copied to another machine and run
# there. It knows it is far from home when the island it was made on is not
# around, and the parrot says something else.
if [ -d "$HUNT" ]; then
  reveal <<'SEALED'
You hear wings behind you. The parrot lands on the open chest, picks
up one gold coin in its beak, and flies away over the sea, towards
the rising sun.

         ,
        (o>    "SQUAWK! Follow me... if you can!"
        //\
        V_/_

It is going somewhere no boat of yours can reach.

SEALED
else
  reveal <<'SEALED'
Wings again. The parrot is already here, waiting, on this side of the
sea.

         ,
        (o>    "SQUAWK! You followed me! What took you so long?"
        //\
        V_/_

It drops a gold coin at your feet. Skull Island is far away now: this
treasure crossed the sea as a file, and it still works here.

SEALED
fi
END_TREASURE

# ---------------------------------------------------------------------------
# Building the hunt
# ---------------------------------------------------------------------------

# The captain's diary: about 500 lines, the clue in the middle, the help for
# less at the top, and a pointer to it at the end, which is what cat leaves on
# screen. No line but the clue and the help says "octopus".
diary() {
  local sentences day i clue_day=83
  sentences=(
    "The sea is calm. The crew is bored."
    "Rain all day. We ate the last of the bread."
    "A seagull stole my hat. The crew laughed."
    "We fixed the sail again."
    "The cook burned the fish. Nobody said anything."
    "No land in sight. The water tastes of wood."
    "I counted the gold coins. They are all still there."
    "Strong wind from the north. We go fast."
    "The parrot learned a new word. A rude one."
    "I dreamed of home."
    "We played cards all night. I lost my boots."
    "Fog. We cannot see the front of the ship."
    "A whale swam next to us for an hour."
    "The first mate snores louder than the sea."
    "A hot day. Everyone sleeps on the deck."
    "We saw another ship far away. It did not see us."
    "I wrote a letter that I will never send."
    "Nothing happened today."
    "The rats ate a corner of the map. I drew it again."
    "The crew sings the same song every night."
  )

  fill "$DIARY_START"
  for ((day = 1; day <= 160; day++)); do
    echo "Day $day."
    if [ "$day" -eq "$clue_day" ]; then
      fill "$DIARY_CLUE"
    else
      i=$(((day * 7 + day / 3) % ${#sentences[@]}))
      echo "${sentences[$i]}"
    fi
    echo
  done
  fill "$DIARY_END"
}

# The catacombs: a path of about 30 tunnels, each with a dead end next to it,
# and the golden idol at the bottom.
catacombs() {
  local dir="$1" level next dead
  put "$dir/sign.txt" "$CATACOMBS_SIGN"
  put "$dir/.hint" "$CATACOMBS_HINT"
  for ((level = 1; level <= 30; level++)); do
    if [ $((RANDOM % 2)) -eq 0 ]; then
      next=left dead=right
    else
      next=right dead=left
    fi
    mkdir -p "$dir/$next" "$dir/$dead" || return 1
    put "$dir/$dead/bones.txt" "$BONES"
    dir="$dir/$next"
  done
  put "$dir/golden-idol" "$IDOL"
}

# The end of every program of the hunt, which is what cat leaves on screen
# when a student reads one instead of running it. @@RUN@@ is how to run it.
text SCRIPT_END <<'END_SCRIPT_END'









# ======================================================================
# ======================================================================
#
#    HALT, EXPLORER!
#
#    This is not a page to read. These are the captain's orders, and
#    you are looking at the words inside them. Reading orders does
#    nothing: they have to be carried out. Like this:
#
#        @@RUN@@
#
#    (Curious explorers are allowed to read the orders. Some find
#    interesting things inside. But nothing happens until you run it.)
#
# ======================================================================
# ======================================================================
END_SCRIPT_END

# Adds the end above to the program in the variable named by $1, which is run
# with $2.
script_end() {
  local script="${!1}"
  printf -v "$1" '%s%s' "$script" "${SCRIPT_END//@@RUN@@/$2}"
}

# Seals what the program in the variable named by $1 says. It is written here
# in plain text, in heredocs ending with a line that says SEALED, which is what
# reveal prints; their text is sealed here, so that reading the program does
# not tell what happens in the hunt.
seal_messages() {
  local program="${!1}" sealed="" line message="" body in_message=0
  while IFS= read -r line; do
    if [ "$in_message" -eq 1 ]; then
      if [ "$line" = "SEALED" ]; then
        heredoc_body body "$message"
        sealed="$sealed$body
SEALED
"
        message="" in_message=0
      else
        message="$message$line
"
      fi
    else
      sealed="$sealed$line
"
      case "$line" in
        *"<<'SEALED'"*) in_message=1 ;;
      esac
    fi
  # <<< ends the program with a newline of its own, one too many.
  done <<< "${program%$'\n'}"
  printf -v "$1" '%s' "$sealed"
}

build() {
  script_end OCTOPUS './octopus'
  script_end DOOR './door'
  script_end MAPMAKER './mapmaker'
  script_end REST './rest'
  script_end LEVER './lever'
  script_end STAIRS './stairs'
  script_end BELL '~/treasure-hunt/bell'
  script_end CHEST './chest'
  script_end TREASURE '~/treasure-hunt/bag/treasure'

  local program
  for program in OCTOPUS DOOR MAPMAKER REST LEVER STAIRS BELL CHEST TREASURE; do
    seal_messages "$program"
  done

  embed CHEST TREASURE TREASURE
  embed BELL CHEST CHEST
  embed BELL ISLAND_HINT ISLAND_HINT
  embed BELL OARS_AFTER OARS_AFTER
  embed BELL BOAT_HINT_AFTER BOAT_HINT_AFTER
  embed STAIRS PARROT PARROT
  embed STAIRS TOP_HINT TOP_HINT
  embed LEVER CURSED_CHEST CURSED_CHEST
  embed LEVER TRAP_SPIKES TRAP_SPIKES
  embed LEVER TRAP_SNAKES TRAP_SNAKES
  embed LEVER TRAP_SPIDERS TRAP_SPIDERS
  embed LEVER STAIRS STAIRS
  embed LEVER TOWER_HINT TOWER_HINT
  embed REST DRAWBRIDGE_CONF DRAWBRIDGE_CONF
  embed REST LEVER LEVER
  embed REST DRAWBRIDGE_HINT DRAWBRIDGE_HINT
  embed MAPMAKER REST REST
  embed MAPMAKER REST_HINT REST_HINT
  embed DOOR MAPMAKER MAPMAKER
  embed DOOR MAPMAKER_HINT MAPMAKER_HINT
  embed OCTOPUS RUSTY_KEY RUSTY_KEY
  embed OCTOPUS DEN_HINT DEN_HINT

  mkdir -p \
    "$HUNT/bag" \
    "$HUNT/beach/boat" \
    "$HUNT/old temple" \
    "$HUNT/jungle/river/waterfall" \
    "$HUNT/jungle/ruins/catacombs" \
    "$HUNT/shipwreck" \
    "$HUNT/cave" \
    "$HUNT/fort" || return 1

  put "$HUNT/start.txt" "$START"
  put "$HUNT/.hint" "$START_HINT"
  put "$HUNT/bell" "$BELL" 755
  put "$HUNT/bag/explorers-handbook.txt" "$HANDBOOK"

  put "$HUNT/beach/sand.txt" "$SAND"
  put "$HUNT/beach/.bottle.txt" "$BOTTLE"
  put "$HUNT/beach/.hint" "$BEACH_HINT"
  put "$HUNT/beach/boat/oars.txt" "$OARS"
  put "$HUNT/beach/boat/.hint" "$BOAT_HINT"

  put "$HUNT/old temple/inscription.txt" "$INSCRIPTION"
  put "$HUNT/old temple/.hint" "$TEMPLE_HINT"

  put "$HUNT/jungle/.hint" "$JUNGLE_HINT"
  put "$HUNT/jungle/river/.hint" "$RIVER_HINT"
  put "$HUNT/jungle/river/waterfall/carving.txt" "$CARVING"
  put "$HUNT/jungle/river/waterfall/.hint" "$WATERFALL_HINT"
  put "$HUNT/jungle/ruins/stone.txt" "$STONE"
  put "$HUNT/jungle/ruins/.hint" "$RUINS_HINT"
  catacombs "$HUNT/jungle/ruins/catacombs" || return 1

  diary > "$HUNT/shipwreck/diary.txt" || return 1
  put "$HUNT/shipwreck/map.txt" "$MAP"
  put "$HUNT/shipwreck/.hint" "$SHIPWRECK_HINT"

  put "$HUNT/cave/octopus" "$OCTOPUS" 755
  put "$HUNT/cave/.hint" "$CAVE_HINT"

  put "$HUNT/fort/door" "$DOOR" 755
  put "$HUNT/fort/.hint" "$FORT_HINT"
}

# Asks before deleting a hunt that already exists. The question is read from
# the terminal rather than from the script's input, because the input is the
# script itself when it is piped from curl.
confirm_restart() {
  local answer=""

  if [ "${TREASURE_HUNT_RESTART:-}" = "yes" ]; then
    return 0
  fi

  echo "You already have a treasure hunt in $HUNT."
  printf 'Delete it and start again from the beginning? [y/N] '
  if ! { read -r answer < /dev/tty; } 2>/dev/null; then
    echo
    fail "No terminal to ask the question. Nothing was changed."
  fi

  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) fail "Nothing was changed. Your hunt is still in $HUNT." ;;
  esac
}

# The smallest terminal the hunt fits in, rounded up to the standard width: its
# widest line is 72 characters, and start.txt, the tallest thing shown at once,
# is 31 lines.
MIN_COLUMNS=80
MIN_LINES=32

# Warns students whose terminal window is too small for the hunt. The size is
# read from the terminal, as the question above is. A script with no terminal,
# or a terminal that does not know its size and says 0, is not warned.
check_terminal_size() {
  local size lines columns

  size=$({ stty size < /dev/tty; } 2> /dev/null) || return 0
  lines=${size% *}
  columns=${size#* }
  case "$lines$columns" in
    '' | *[!0-9]*) return 0 ;;
  esac
  if [ "$lines" -eq 0 ] || [ "$columns" -eq 0 ]; then
    return 0
  fi

  if [ "$columns" -lt "$MIN_COLUMNS" ] || [ "$lines" -lt "$MIN_LINES" ]; then
    cat <<EOF

WARNING: your terminal window is small ($columns columns, $lines lines).
The hunt needs at least $MIN_COLUMNS columns and $MIN_LINES lines, or some
texts and drawings will not fit. Make the window bigger before you start.
EOF
  fi
}

main() {
  if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ] || [ ! -d "$HOME" ]; then
    fail "Your home directory was not found. Nothing was changed."
  fi

  HUNT="$HOME/treasure-hunt"
  D1=$((RANDOM % 10))
  D2=$((RANDOM % 10))
  D3=$((RANDOM % 10))
  SEALED_COMBINATION=$(printf '%s' "$D1$D2$D3" | LC_ALL=C tr "$CAESAR_PLAIN" "$CAESAR_SEALED")

  if [ -e "$HUNT" ]; then
    confirm_restart
    rm -rf "$HUNT" || fail "Could not delete $HUNT."
  fi

  build || fail "Something went wrong while building the hunt in $HUNT."

  cat <<'EOF'

                 _
       .--------' )     THE TREASURE HUNT IS READY!
      (  X  marks  )
       '--.   the  )
           '-spot-'

EOF
  echo "It is in $HUNT."
  cat <<'EOF'

To start, go there and read start.txt:

    cd ~/treasure-hunt
    cat start.txt

Good luck, explorer!
EOF

  check_terminal_size
}

# Everything above only defines things. Nothing runs before this last line, so
# a download cut short in the middle runs nothing at all.
main "$@"
