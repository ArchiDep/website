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

# The areas a gate opens are written into that gate as base64, so that they
# cannot be found with ls before the gate opens. This is the command that
# decodes them, which every gate includes.
UNPACK='unpack() { printf '"'"'%s'"'"' "$1" | base64 --decode > "$2" && chmod "$3" "$2"; }'

# Reads a heredoc into the variable named by $1, exactly as written, leading
# spaces included.
text() {
  IFS= read -r -d '' "$1" || true
}

# Prints a text with its placeholders replaced.
fill() {
  local value="$1"
  value=${value//@@HUNT@@/$HUNT}
  value=${value//@@UNPACK@@/$UNPACK}
  value=${value//@@D1@@/$D1}
  value=${value//@@D2@@/$D2}
  value=${value//@@D3@@/$D3}
  value=${value//@@COMBINATION@@/$D1$D2$D3}
  printf '%s' "$value"
}

# Prints a text, placeholders replaced, as base64 on one line.
pack() {
  fill "$1" | base64 | tr -d '\n'
}

# Writes the text in the variable named by $3 into the text in the variable
# named by $1, in place of the placeholder @@$2@@.
embed() {
  local parent="${!1}" child
  child=$(pack "${!3}")
  printf -v "$1" '%s' "${parent//@@$2@@/$child}"
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
- You have a bag: it is the directory named bag. Things you pick up
  go in your bag.
- Some things are programs. You run them with ./ before their name.
- Stuck? Every place has a hint in a hidden file named .hint.
  You cannot see it with ls, but you can read it:

      cat .hint

The adventure starts on the beach.
END_START

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
Sand. Only sand, as far as you can see.

Nothing here... or is there? Look closer.
END_SAND

text BOTTLE <<'END_BOTTLE'
You found a bottle! There is a message inside:

    "If you want my treasure, go to the old temple.
                                     -- The Captain"

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

    FOLLOW THE RIVER INTO THE JUNGLE,
    ALL THE WAY TO THE WATERFALL.
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

    GO BACK TWO PLACES.
    THEN ENTER THE RUINS.
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

    THE CAPTAIN'S SHIP BROKE ON THE ROCKS.
    FROM HERE, THE SHIPWRECK IS AT ../../shipwreck

Next to the stone, stairs go down into the dark: the catacombs.
Someone wrote on the wall: "A GOLDEN IDOL IS LOST DOWN THERE."
END_STONE

text RUINS_HINT <<'END_RUINS_HINT'
HINT

Read the path one piece at a time: .. (up once), .. (up again), then
shipwreck.

Lost? cd with nothing after it always takes you home, to ~. From
there:

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

Tab completion helps with long paths. See "Find files" in the command
line cheatsheet: https://archidep.ch/cheatsheets/command-line/#find-files-find
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
END_IDOL

text SHIPWRECK_HINT <<'END_SHIPWRECK_HINT'
HINT

The diary is long. cat prints all of it, and you only see the end.
Read the end first: it tells you what to do.
END_SHIPWRECK_HINT

text MAP <<'END_MAP'
                    THE CAPTAIN'S MAP

   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   ~~       ______________________________          ~~
   ~~      /   jungle         ruins       \___      ~~
   ~~     |   ~~~river~~~      [##]           \     ~~
   ~~     |                                    |    ~~
   ~~     |   old temple   cave   fortress     |    ~~
   ~~      \     [^]       (@@)    [==]       /     ~~
   ~~       \______beach________shipwreck___/       ~~
   ~~                                         X     ~~
   ~~                                  skull island ~~
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

   Do not lose this map.
END_MAP

# The diary is built line by line when the hunt is set up: see diary().
text DIARY_CLUE <<'END_DIARY_CLUE'
We reached the island at last. I buried the key in the cave, behind
the dragon. Nobody will ever take it: the dragon never wakes up.
END_DIARY_CLUE

text DIARY_END <<'END_DIARY_END'
--------------------------------------------------------------------

You are reading the END of a long diary. The captain wrote a lot!
cat printed the whole file, so the first pages went by too fast.

To read a long file from the top, use less:

    less diary.txt

In less:

- Use the arrow keys (or Space) to move.
- Type /dragon and press Enter to search for the word "dragon".
- Press n to go to the next match.
- Press q to quit.

(You can also scroll up in your terminal. But less is better.)
END_DIARY_END

# ---------------------------------------------------------------------------
# The dragon
# ---------------------------------------------------------------------------

text CAVE_HINT <<'END_CAVE_HINT'
HINT

The dragon is a program. To run a program in the directory you are
in, write ./ before its name:

    ./dragon

This one never stops by itself. To interrupt a program that is
running, press Ctrl-C.
END_CAVE_HINT

text DRAGON <<'END_DRAGON'
#!/bin/bash
# A dragon. It is sleeping. Do not wake it up.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -d "$HUNT/cave/lair" ]; then
  echo "The dragon is gone. Only its lair is left."
  exit 0
fi

wake_up() {
  echo
  cat <<'EOF'
The dragon opens one eye. You interrupted its sleep!

It is very angry... and very lazy. It flies away to sleep somewhere
quieter. Behind the place where it slept, there is a hole in the
rock: its lair.
EOF
  mkdir "$HUNT/cave/lair" &&
  unpack '@@RUSTY_KEY@@' "$HUNT/cave/lair/rusty-key" 644 &&
  unpack '@@LAIR_HINT@@' "$HUNT/cave/lair/.hint" 644
  exit 0
}

trap wake_up INT

cat <<'EOF'
              /\___/\
       ___   (  -.-  )   z
      /   \_/         \ z
     <  ~~~            >~~~~~
      \_______________/

A huge dragon sleeps in the cave. Nothing can wake it up...
EOF

while true; do
  echo "    Zzz..."
  sleep 1
  echo "        ...zzZZZ"
  sleep 1
done
END_DRAGON

text RUSTY_KEY <<'END_RUSTY_KEY'
RUSTY KEY

An old, heavy key. A word is written on it: FORTRESS.
END_RUSTY_KEY

text LAIR_HINT <<'END_LAIR_HINT'
HINT

You found a key! Pick it up: move it into your bag with mv. Your bag
is in ~/treasure-hunt/bag. From here, that is two levels up:

    mv rusty-key ../../bag/

Then take the key to the fortress. See "Move stuff" in the command
line cheatsheet: https://archidep.ch/cheatsheets/command-line/#move-stuff-mv
END_LAIR_HINT

# ---------------------------------------------------------------------------
# Part 2: changing things
# ---------------------------------------------------------------------------

text FORTRESS_HINT <<'END_FORTRESS_HINT'
HINT

The door needs a file named key, next to it. Your key is in your bag,
and its name is rusty-key.

mv moves a file. It can also give it a new name, at the same time:

    mv ../bag/rusty-key key

Then run ./door again.
END_FORTRESS_HINT

text DOOR <<'END_DOOR'
#!/bin/bash
# The door of the fortress. It is locked.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -d "$HUNT/fortress/courtyard" ]; then
  echo "The door is open. The courtyard is behind it."
  exit 0
fi

if [ ! -f "$HUNT/fortress/key" ]; then
  cat <<'EOF'
The door is locked. There is a keyhole.

A key must be in the lock: a file named key, next to the door.
EOF
  exit 1
fi

if ! grep -q 'RUSTY KEY' "$HUNT/fortress/key"; then
  echo "This is not the right key. It does not turn."
  exit 1
fi

mkdir "$HUNT/fortress/courtyard" &&
unpack '@@GUARDIAN@@' "$HUNT/fortress/courtyard/guardian" 755 &&
unpack '@@GUARDIAN_HINT@@' "$HUNT/fortress/courtyard/.hint" 644 || exit 1

mkdir -p "$HUNT/bag"
echo "A gold coin. A number is carved on it: @@D1@@" > "$HUNT/bag/coin-1"

cat <<'EOF'
Click. The key turns, and the heavy door opens.

A gold coin falls out of the lock. You put it in your bag.

Behind the door is the courtyard of the fortress. Someone is waiting
for you there.
EOF
END_DOOR

text GUARDIAN_HINT <<'END_GUARDIAN_HINT'
HINT

cp copies a file. The copy can have another name, and be in another
place. mv would move the original, and the guardian wants it to stay
in the shipwreck.

From the courtyard, the shipwreck is two levels up, then down:

    cp ../../shipwreck/map.txt map-copy.txt

Then run ./guardian again. See "Copy stuff" in the command line
cheatsheet: https://archidep.ch/cheatsheets/command-line/#copy-stuff-cp
END_GUARDIAN_HINT

text GUARDIAN <<'END_GUARDIAN'
#!/bin/bash
# The guardian of the fortress. It loves maps.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fortress/courtyard"
original="$HUNT/shipwreck/map.txt"
copy="$here/map-copy.txt"

if [ -f "$here/rest" ]; then
  echo "The guardian nods. You may pass."
  exit 0
fi

if [ ! -f "$original" ]; then
  cat <<'EOF'
"Where is the captain's map? The original must stay in the shipwreck!
 Put it back there. Then bring me a copy."
EOF
  exit 1
fi

if [ ! -f "$copy" ]; then
  cat <<'EOF'
The guardian blocks your way.

"Halt! Bring me a copy of the captain's map. Put it here, next to me,
 and name it map-copy.txt. The original must stay in the shipwreck."
EOF
  exit 1
fi

if ! cmp -s "$original" "$copy"; then
  echo '"This is not a copy of the captain'"'"'s map!"'
  exit 1
fi

unpack '@@REST@@' "$here/rest" 755 &&
unpack '@@REST_HINT@@' "$here/.hint" 644 || exit 1

cat <<'EOF'
The guardian looks at the map for a long time. Then it nods.

"You may pass. But night is falling. You should rest first."
EOF
END_GUARDIAN

text REST_HINT <<'END_REST_HINT'
HINT

mkdir makes a directory. touch makes an empty file. echo with >
writes text into a file:

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

here="$HUNT/fortress/courtyard"

if [ -f "$here/crank" ]; then
  echo "It is morning. The drawbridge is waiting."
  exit 0
fi

if [ ! -d "$here/camp" ]; then
  cat <<'EOF'
It is dark and cold. You cannot rest without a camp and a fire.

Make a directory named camp, here. In it, make a file named fire.
The fire is lit when the file contains the word: lit
EOF
  exit 1
fi

if [ ! -f "$here/camp/fire" ]; then
  echo "Your camp has no fire. Make a file named fire in the camp."
  exit 1
fi

if ! grep -q 'lit' "$here/camp/fire"; then
  echo "The fire is not lit. The fire file must contain the word: lit"
  exit 1
fi

unpack '@@DRAWBRIDGE_CONF@@' "$here/drawbridge.conf" 644 &&
unpack '@@CRANK@@' "$here/crank" 755 &&
unpack '@@DRAWBRIDGE_HINT@@' "$here/.hint" 644 || exit 1

cat <<'EOF'
You sleep next to the fire.

In the morning, you see what you could not see in the dark: a big
drawbridge, and a crank to open it. There is also a file with the
settings of the drawbridge.
EOF
END_REST

text DRAWBRIDGE_CONF <<'END_DRAWBRIDGE_CONF'
# Settings of the drawbridge.
# The crank reads this file before it moves.
chains=rusty
state=closed
END_DRAWBRIDGE_CONF

text DRAWBRIDGE_HINT <<'END_DRAWBRIDGE_HINT'
HINT

Open the settings file with the nano editor:

    nano drawbridge.conf

Move with the arrow keys. Change closed to open. Save with Ctrl-O,
then Enter. Quit with Ctrl-X. (Vim works too, if you know it.)

Then run ./crank again.
END_DRAWBRIDGE_HINT

text CRANK <<'END_CRANK'
#!/bin/bash
# The crank of the drawbridge.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fortress/courtyard"

if [ -d "$here/tower" ]; then
  echo "The drawbridge is down. The tower is open."
  exit 0
fi

if ! grep -Eq '^[[:space:]]*state[[:space:]]*=[[:space:]]*open[[:space:]]*$' "$here/drawbridge.conf" 2>/dev/null; then
  cat <<'EOF'
You turn the crank as hard as you can. It does not move.

The settings of the drawbridge, in drawbridge.conf, say that it is
closed. Change them to open.
EOF
  exit 1
fi

mkdir "$here/tower" &&
unpack '@@CURSED_CHEST@@' "$here/tower/cursed-chest.txt" 644 &&
unpack '@@TRAP_SPIKES@@' "$here/tower/trap-spikes.txt" 644 &&
unpack '@@TRAP_SNAKES@@' "$here/tower/trap-snakes.txt" 644 &&
unpack '@@TRAP_SPIDERS@@' "$here/tower/trap-spiders.txt" 644 &&
unpack '@@STAIRS@@' "$here/tower/stairs" 755 &&
unpack '@@TOWER_HINT@@' "$here/tower/.hint" 644 || exit 1

mkdir -p "$HUNT/bag"
echo "A gold coin. A number is carved on it: @@D2@@" > "$HUNT/bag/coin-2"

cat <<'EOF'
The chains turn. Slowly, the drawbridge goes down.

A gold coin was stuck in the crank. You put it in your bag.

On the other side of the drawbridge, there is a tall tower.
EOF
END_CRANK

text CURSED_CHEST <<'END_CURSED_CHEST'
A small chest, covered with skulls. It is cursed!

Nobody can climb the stairs of the tower while it is here.
END_CURSED_CHEST

text TRAP_SPIKES <<'END_TRAP_SPIKES'
A trap full of spikes. Remove it before you climb.
END_TRAP_SPIKES

text TRAP_SNAKES <<'END_TRAP_SNAKES'
A trap full of snakes. Remove it before you climb.
END_TRAP_SNAKES

text TRAP_SPIDERS <<'END_TRAP_SPIDERS'
A trap full of spiders. Remove it before you climb.
END_TRAP_SPIDERS

text TOWER_HINT <<'END_TOWER_HINT'
HINT

rm deletes a file:

    rm cursed-chest.txt

Careful: there is no bin. A deleted file is gone forever. Read the
name twice before you press Enter. Delete each trap the same way.

You may see rm trap-*.txt somewhere. The * matches any text, so this
deletes all the traps at once. It is fast, but one typo can delete
much more than you wanted. Name each file for now.

See "Delete stuff" in the command line cheatsheet:
https://archidep.ch/cheatsheets/command-line/#delete-stuff-rm
END_TOWER_HINT

text STAIRS <<'END_STAIRS'
#!/bin/bash
# The stairs of the tower.
HUNT='@@HUNT@@'
@@UNPACK@@

here="$HUNT/fortress/courtyard/tower"

if [ -d "$here/top" ]; then
  echo "You already climbed the stairs. The top of the tower is open."
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
  echo "You cannot climb the stairs. These are still here:"
  echo
  printf '%s' "$remaining"
  exit 1
fi

mkdir "$here/top" &&
unpack '@@PARROT@@' "$here/top/parrot.txt" 644 &&
unpack '@@TOP_HINT@@' "$here/top/.hint" 644 || exit 1

cat <<'EOF'
The curse is gone. You climb the stairs, all the way to the top.

Someone is waiting for you there.
EOF
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
    ../../..         the fortress
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
  echo "DING! You already went to Skull Island."
  exit 0
fi

if [ ! -f "$HUNT/fortress/courtyard/tower/top/parrot.txt" ]; then
  echo "DING! Nothing happens. It is not the right time."
  exit 1
fi

boat=$(cd "$HUNT/beach/boat" 2>/dev/null && pwd -P)
if [ -z "$boat" ] || [ "$(pwd -P)" != "$boat" ]; then
  cat <<'EOF'
DING! Nothing happens.

The parrot said to ring the bell from the boat. Where are you? pwd
tells you.
EOF
  exit 1
fi

mkdir "$HUNT/skull-island" &&
unpack '@@CHEST@@' "$HUNT/skull-island/chest" 644 &&
unpack '@@ISLAND_HINT@@' "$HUNT/skull-island/.hint" 644 || exit 1

mkdir -p "$HUNT/bag"
echo "A gold coin. A number is carved on it: @@D3@@" > "$HUNT/bag/coin-3"

cat <<'EOF'
DING! DING! DING!

The parrot lands on the boat. "SQUAWK! Row! Row!"
You row for a long time. Then you see it: Skull Island.

A gold coin was stuck in the bell. You put it in your bag.

Skull Island is in ~/treasure-hunt/skull-island. There is a chest.
EOF
END_BELL

# ---------------------------------------------------------------------------
# Part 3: the treasure
# ---------------------------------------------------------------------------

text ISLAND_HINT <<'END_ISLAND_HINT'
HINT

"Permission denied" means you are not allowed to do this. The chest
is a program, but it is not executable yet. chmod +x makes a file
executable:

    chmod +x chest

You will learn about permissions later in the course.

The chest asks for a combination. Look at the coins in your bag.
END_ISLAND_HINT

text CHEST <<'END_CHEST'
#!/bin/bash
# The captain's chest. It has a combination lock.
HUNT='@@HUNT@@'
@@UNPACK@@

if [ -f "$HUNT/bag/treasure" ]; then
  echo "The chest is empty. The treasure is in your bag."
  exit 0
fi

cat <<'EOF'
         ____________________
        /                   /|
       /___________________/ |
       |     [ ? ? ? ]     | |
       |___________________|/

The captain's chest! It has a lock with three numbers.
EOF

printf 'Enter the combination (coin 1, coin 2, coin 3): '
read -r answer
answer=$(printf '%s' "$answer" | tr -cd '0-9')

if [ "$answer" != '@@COMBINATION@@' ]; then
  echo "Click... The lock does not open. Look at the coins in your bag."
  exit 1
fi

mkdir -p "$HUNT/bag"
unpack '@@TREASURE@@' "$HUNT/bag/treasure" 755 || exit 1

cat <<'EOF'
CLICK! The chest opens. The treasure is inside!

You put it in your bag: ~/treasure-hunt/bag/treasure. It is a
program. From here, run it with:

    ../bag/treasure

Can you run it from anywhere, just by typing treasure?
Go back to the exercise to find out how.
EOF
END_CHEST

text TREASURE <<'END_TREASURE'
#!/bin/bash
# The treasure of Skull Island.
HUNT='@@HUNT@@'

cat <<'EOF'

          *     .   *       .    *     .
       .    ______________________    *
           /   $    $    $    $  /|
     *    /_____________________/ |   .
          |  ____    __    ____ | |
          | |____|  (__)  |____|| |
          |_____________________|/    *
      .        *      .        .

      YOU FOUND THE TREASURE OF SKULL ISLAND!

EOF

if [ -e "$HUNT/bag/golden-idol" ]; then
  cat <<'EOF'
                 .-"-.
                / o o \
                \  ^  /
                /`---'\
               |  ***  |
               |_______|

   And the golden idol from the catacombs! You found everything.

EOF
fi
END_TREASURE

# ---------------------------------------------------------------------------
# Building the hunt
# ---------------------------------------------------------------------------

# The captain's diary: about 500 lines, the clue in the middle and the help
# for less at the end. No line but the clue and the help says "dragon".
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

  echo "THE DIARY OF THE CAPTAIN"
  echo
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

build() {
  embed CHEST TREASURE TREASURE
  embed BELL CHEST CHEST
  embed BELL ISLAND_HINT ISLAND_HINT
  embed STAIRS PARROT PARROT
  embed STAIRS TOP_HINT TOP_HINT
  embed CRANK CURSED_CHEST CURSED_CHEST
  embed CRANK TRAP_SPIKES TRAP_SPIKES
  embed CRANK TRAP_SNAKES TRAP_SNAKES
  embed CRANK TRAP_SPIDERS TRAP_SPIDERS
  embed CRANK STAIRS STAIRS
  embed CRANK TOWER_HINT TOWER_HINT
  embed REST DRAWBRIDGE_CONF DRAWBRIDGE_CONF
  embed REST CRANK CRANK
  embed REST DRAWBRIDGE_HINT DRAWBRIDGE_HINT
  embed GUARDIAN REST REST
  embed GUARDIAN REST_HINT REST_HINT
  embed DOOR GUARDIAN GUARDIAN
  embed DOOR GUARDIAN_HINT GUARDIAN_HINT
  embed DRAGON RUSTY_KEY RUSTY_KEY
  embed DRAGON LAIR_HINT LAIR_HINT

  mkdir -p \
    "$HUNT/bag" \
    "$HUNT/beach/boat" \
    "$HUNT/old temple" \
    "$HUNT/jungle/river/waterfall" \
    "$HUNT/jungle/ruins/catacombs" \
    "$HUNT/shipwreck" \
    "$HUNT/cave" \
    "$HUNT/fortress" || return 1

  put "$HUNT/start.txt" "$START"
  put "$HUNT/.hint" "$START_HINT"
  put "$HUNT/bell" "$BELL" 755

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

  put "$HUNT/cave/dragon" "$DRAGON" 755
  put "$HUNT/cave/.hint" "$CAVE_HINT"

  put "$HUNT/fortress/door" "$DOOR" 755
  put "$HUNT/fortress/.hint" "$FORTRESS_HINT"
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

main() {
  if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ] || [ ! -d "$HOME" ]; then
    fail "Your home directory was not found. Nothing was changed."
  fi

  HUNT="$HOME/treasure-hunt"
  D1=$((RANDOM % 10))
  D2=$((RANDOM % 10))
  D3=$((RANDOM % 10))

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
}

# Everything above only defines things. Nothing runs before this last line, so
# a download cut short in the middle runs nothing at all.
main "$@"
