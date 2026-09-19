#!/bin/bash
#
# Plays the whole treasure hunt of the "Hello Shell" exercise, in a temporary
# home directory, the way a student would: every gate refuses before its task
# is done and opens the next area once it is.
#
# Run it with the Bash under test, e.g. on macOS:
#
#     /bin/bash course/test/treasure-hunt.test.sh
#
# and with the GNU tools of Ubuntu, which the WSL uses:
#
#     docker run --rm -v "$PWD/course:/course" ubuntu:24.04 \
#       bash /course/test/treasure-hunt.test.sh

set -u

SETUP="$(cd "$(dirname "$0")/../chapters/102-hello-shell" && pwd)/treasure-hunt.sh"

HOME="$(mktemp -d)"
export HOME
HUNT="$HOME/treasure-hunt"
trap 'rm -rf "$HOME"' EXIT

FAILURES=0
OUTPUT=""
STATUS=0

pass() { echo "  ok    $1"; }
failed() {
  echo "  FAIL  $1"
  FAILURES=$((FAILURES + 1))
}

# check <description> <command...>: passes if the command succeeds.
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else failed "$description"; fi
}

# run <directory> <command...>: runs a command from a directory, keeping its
# output in OUTPUT and its exit status in STATUS.
run() {
  local dir="$1"
  shift
  OUTPUT=$(cd "$dir" && "$@" 2>&1 < /dev/null)
  STATUS=$?
}

# gate <description> <expected status> <directory> <command...>
gate() {
  local description="$1" expected="$2"
  shift 2
  run "$@"
  if [ "$STATUS" -eq "$expected" ]; then
    pass "$description"
  else
    failed "$description (exit status $STATUS, expected $expected)"
    printf '%s\n' "$OUTPUT" | sed 's/^/        | /'
  fi
}

digit_of() { tr -cd '0-9' < "$1"; }
is_executable() { [ -x "$1" ]; }
is_not_executable() { [ -f "$1" ] && [ ! -x "$1" ]; }
output_contains() { printf '%s' "$OUTPUT" | grep -q -- "$1"; }

# The edition the hunt belongs to, and the address it sends students to, taken
# from the setup so that a rollover moves them both at once.
CURRENT_YEAR=$(sed -n 's/^CURRENT_YEAR=//p' "$SETUP")
CHEATSHEET="https://archidep.ch/$CURRENT_YEAR/cheatsheets/command-line/"

# Passes when no text of the hunt names an address of the site missing the
# edition, which the site publishes every page under.
addresses_carry_the_edition() {
  ! grep -rho 'archidep\.ch/[^ ]*' "$HUNT" | grep -qv "^archidep.ch/$CURRENT_YEAR/"
}

echo "Bash $BASH_VERSION"
check "the setup names an edition" [ -n "$CURRENT_YEAR" ]

echo "Setup"
OUTPUT=$(cat "$SETUP" | "$BASH" 2>&1)
STATUS=$?
check "the setup piped into bash succeeds" [ "$STATUS" -eq 0 ]
check "the setup tells students to cd into the hunt" output_contains "cd ~/treasure-hunt"
check "the hunt starts with start.txt" [ -f "$HUNT/start.txt" ]
check "the bag holds only the handbook" \
  [ "$(ls "$HUNT/bag")" = explorers-handbook.txt ]
check "the handbook points to the command line cheatsheet of the edition" \
  grep -qF "$CHEATSHEET" "$HUNT/bag/explorers-handbook.txt"
check "every address the hunt shows carries the edition" addresses_carry_the_edition
check "the start tells students to read the handbook" \
  grep -q "cat bag/explorers-handbook.txt" "$HUNT/start.txt"
check "the bottle is hidden on the beach" [ -f "$HUNT/beach/.bottle.txt" ]
check "the beach's hint shows how to read the bottle" \
  grep -q "cat .bottle.txt" "$HUNT/beach/.hint"
check "the boat waits for somewhere to sail to" \
  grep -q "Nobody has told you yet" "$HUNT/beach/boat/oars.txt"
check "the temple's name has a space" [ -d "$HUNT/old temple" ]
for place in . beach beach/boat "old temple" jungle jungle/river \
  jungle/river/waterfall jungle/ruins jungle/ruins/catacombs shipwreck cave \
  fortress; do
  check "there is a hint in $place" [ -f "$HUNT/$place/.hint" ]
done
for area in cave/lair fortress/courtyard skull-island; do
  check "$area does not exist yet" [ ! -e "$HUNT/$area" ]
done

echo "Placeholders"
check "no placeholder is left in the hunt" \
  [ -z "$(grep -rl '@@[A-Z0-9_]*@@' "$HUNT")" ]

echo "The diary"
lines=$(wc -l < "$HUNT/shipwreck/diary.txt" | tr -d ' ')
clue=$(grep -n 'buried the key' "$HUNT/shipwreck/diary.txt" | cut -d: -f1)
check "the diary has about 500 lines ($lines)" [ "$lines" -ge 450 -a "$lines" -le 550 ]
check "the clue is in the middle (line $clue)" [ "$clue" -ge 200 -a "$clue" -le 300 ]
check "only the clue and the help at the end say dragon" \
  [ "$(grep -c dragon "$HUNT/shipwreck/diary.txt")" -eq 2 ]
check "the top of the diary explains how to quit less" \
  [ -n "$(head -n 15 "$HUNT/shipwreck/diary.txt" | grep 'Press q')" ]
check "the end of the diary points to less" \
  [ -n "$(tail -n 10 "$HUNT/shipwreck/diary.txt" | grep 'less diary.txt')" ]

echo "The catacombs"
idols=$(cd "$HUNT/jungle/ruins/catacombs" && find . -name golden-idol)
depth=$(printf '%s' "$idols" | tr -cd '/' | wc -c | tr -d ' ')
check "there is exactly one golden idol" [ "$(printf '%s\n' "$idols" | grep -c golden-idol)" -eq 1 ]
check "the idol is deep ($depth levels)" [ "$depth" -ge 30 ]

echo "The dragon"
set -m
(cd "$HUNT/cave" && exec ./dragon > "$HOME/dragon.out" 2>&1) &
dragon=$!
set +m
sleep 1
check "the dragon does not flee by itself" [ ! -e "$HUNT/cave/lair" ]
# What a gate says is sealed, so the placeholder check above cannot see an
# address a gate shows: reading one back from a gate that ran is what tells us
# the placeholders of sealed texts were filled in.
check "the dragon sends students to the great book of commands" \
  grep -qF "$CHEATSHEET" "$HOME/dragon.out"
kill -INT "$dragon"
wait "$dragon"
STATUS=$?
check "Ctrl-C makes the dragon flee (exit status $STATUS)" [ "$STATUS" -eq 0 ]
check "the lair appears" [ -f "$HUNT/cave/lair/rusty-key" ]
check "the lair has a hint" [ -f "$HUNT/cave/lair/.hint" ]
gate "the dragon is gone afterwards" 0 "$HUNT/cave" ./dragon

echo "The door"
gate "the door is locked without a key" 1 "$HUNT/fortress" ./door
touch "$HUNT/fortress/key"
gate "the door refuses a key that is not the rusty key" 1 "$HUNT/fortress" ./door
rm "$HUNT/fortress/key"
(cd "$HUNT/cave" && mv lair/rusty-key ../bag/)
(cd "$HUNT/fortress" && mv ../bag/rusty-key key)
gate "the door opens with the rusty key" 0 "$HUNT/fortress" ./door
check "the courtyard appears with the guardian" is_executable "$HUNT/fortress/courtyard/guardian"
check "the door drops coin 1" [ -n "$(digit_of "$HUNT/bag/coin-1")" ]
check "the rest does not exist yet" [ ! -e "$HUNT/fortress/courtyard/rest" ]

COURTYARD="$HUNT/fortress/courtyard"

echo "The guardian"
gate "the guardian wants a copy of the map" 1 "$COURTYARD" ./guardian
(cd "$COURTYARD" && mv ../../shipwreck/map.txt map-copy.txt)
gate "the guardian refuses when the original was moved" 1 "$COURTYARD" ./guardian
(cd "$COURTYARD" && mv map-copy.txt ../../shipwreck/map.txt)
echo "a fake map" > "$COURTYARD/map-copy.txt"
gate "the guardian refuses something that is not a copy" 1 "$COURTYARD" ./guardian
(cd "$COURTYARD" && cp ../../shipwreck/map.txt map-copy.txt)
gate "the guardian accepts a copy" 0 "$COURTYARD" ./guardian
check "the rest appears" is_executable "$COURTYARD/rest"

echo "The camp"
gate "the rest needs a camp" 1 "$COURTYARD" ./rest
mkdir "$COURTYARD/camp"
gate "the rest needs a fire" 1 "$COURTYARD" ./rest
touch "$COURTYARD/camp/fire"
gate "the rest needs a lit fire" 1 "$COURTYARD" ./rest
echo lit > "$COURTYARD/camp/fire"
gate "the rest works with a lit fire" 0 "$COURTYARD" ./rest
check "the lever appears" is_executable "$COURTYARD/lever"
check "the drawbridge settings appear" [ -f "$COURTYARD/drawbridge.conf" ]

echo "The drawbridge"
gate "the lever does not move while the drawbridge is closed" 1 "$COURTYARD" ./lever
conf=$(cat "$COURTYARD/drawbridge.conf")
printf '%s\n' "${conf/state=closed/state=open}" > "$COURTYARD/drawbridge.conf"
gate "the lever moves once the drawbridge is open" 0 "$COURTYARD" ./lever
check "the lever drops coin 2" [ -n "$(digit_of "$HUNT/bag/coin-2")" ]
check "the tower appears with its stairs" is_executable "$COURTYARD/tower/stairs"

TOWER="$COURTYARD/tower"

echo "The curse"
gate "the stairs refuse while the curse is there" 1 "$TOWER" ./stairs
(cd "$TOWER" && rm cursed-chest.txt trap-spikes.txt trap-snakes.txt)
gate "the stairs refuse while a trap is left" 1 "$TOWER" ./stairs
check "the stairs name the trap that is left" output_contains trap-spiders.txt
(cd "$TOWER" && rm trap-spiders.txt)
gate "the stairs let you climb once everything is gone" 0 "$TOWER" ./stairs
check "the parrot appears" [ -f "$TOWER/top/parrot.txt" ]

echo "The bell"
gate "the bell does nothing from the tower" 1 "$TOWER/top" "$HUNT/bell"
gate "the bell does nothing from the beach" 1 "$HUNT/beach" "$HUNT/bell"
gate "the bell rings from the boat, by its full path" 0 \
  "$TOWER/top/../../../../beach/./boat" "$HUNT/bell"
check "skull island appears with a chest that cannot run" \
  is_not_executable "$HUNT/skull-island/chest"
check "the bell drops coin 3" [ -n "$(digit_of "$HUNT/bag/coin-3")" ]
check "the oars no longer wait for somewhere to sail to" \
  grep -q "taken you to Skull Island" "$HUNT/beach/boat/oars.txt"
check "the boat's hint points at the island it sailed to" \
  grep -q "cd ../../skull-island" "$HUNT/beach/boat/.hint"

echo "The chest"
gate "the chest cannot run before chmod" 126 "$HUNT/skull-island" ./chest
chmod +x "$HUNT/skull-island/chest"
combination="$(digit_of "$HUNT/bag/coin-1")$(digit_of "$HUNT/bag/coin-2")$(digit_of "$HUNT/bag/coin-3")"
wrong=$(printf '%03d' $(((10#$combination + 1) % 1000)))
OUTPUT=$(cd "$HUNT/skull-island" && echo "$wrong" | ./chest 2>&1)
STATUS=$?
check "the chest refuses a wrong combination" [ "$STATUS" -eq 1 ]
check "no treasure for a wrong combination" [ ! -e "$HUNT/bag/treasure" ]
OUTPUT=$(cd "$HUNT/skull-island" && echo "${combination:0:1} ${combination:1:1} ${combination:2:1}" | ./chest 2>&1)
STATUS=$?
check "the chest opens with the combination of the coins" [ "$STATUS" -eq 0 ]
check "the treasure is in the bag, executable" is_executable "$HUNT/bag/treasure"

echo "Taking the treasure home"
OUTPUT=$(cd / && PATH="$PATH:$HUNT/bag" treasure 2>&1)
check "treasure runs from anywhere once the bag is in the PATH" output_contains "YOU FOUND THE TREASURE"
check "no bonus without the idol" eval '! output_contains "golden idol"'
(cd "$HUNT/jungle/ruins/catacombs" && mv "$idols" ~/treasure-hunt/bag/)
OUTPUT=$(cd / && PATH="$PATH:$HUNT/bag" treasure 2>&1)
check "the idol gives a bonus" output_contains "golden idol"
check "the parrot flies away over the sea" output_contains "Follow me"
# The treasure is a file: copied to another machine, it runs there and knows
# the island is not around.
mv "$HUNT" "$HOME/sailed-away"
OUTPUT=$(cd / && "$HOME/sailed-away/bag/treasure" 2>&1)
check "far from the island, the parrot is already there" \
  output_contains "You followed me"
check "far from the island, it is still the treasure" \
  output_contains "YOU FOUND THE TREASURE"
mv "$HOME/sailed-away" "$HUNT"

echo "Programs read with cat"
# ends_with_banner <file> <command>: the end of the file, which is what cat
# leaves on screen, tells how to run it.
ends_with_banner() {
  tail -n 20 "$1" | grep -q "HALT, EXPLORER" && tail -n 20 "$1" | grep -qF "    $2"
}
for program in "cave/dragon ./dragon" "fortress/door ./door" \
  "fortress/courtyard/guardian ./guardian" "fortress/courtyard/rest ./rest" \
  "fortress/courtyard/lever ./lever" "fortress/courtyard/tower/stairs ./stairs" \
  "bell ~/treasure-hunt/bell" "skull-island/chest ./chest" \
  "bag/treasure ~/treasure-hunt/bag/treasure"; do
  set -- $program
  check "$1 ends by telling how to run it" ends_with_banner "$HUNT/$1" "$2"
  check "$1 says nothing in plain text" eval "! grep -q 'carved on it\|You put it in your bag\|DING!\|The chest\|YOU FOUND' '$HUNT/$1'"
done
check "the combination cannot be read in the chest" eval "! grep -q '$combination' '$HUNT/skull-island/chest'"

echo "Restarting"
if ! { : < /dev/tty; } 2>/dev/null; then
  OUTPUT=$(cat "$SETUP" | "$BASH" 2>&1)
  STATUS=$?
  check "without a terminal, the setup refuses to delete the hunt" [ "$STATUS" -eq 1 ]
  check "the old hunt is left as it was" [ -d "$HUNT/skull-island" ]
else
  echo "  skip  there is a terminal: the question would be asked"
fi
OUTPUT=$(cat "$SETUP" | TREASURE_HUNT_RESTART=yes "$BASH" 2>&1)
STATUS=$?
check "the setup rebuilds the hunt when told to" [ "$STATUS" -eq 0 ]
check "the rebuilt hunt starts over" \
  [ ! -e "$HUNT/skull-island" -a "$(ls "$HUNT/bag")" = explorers-handbook.txt ]

echo "Terminal size"
# setup_in_terminal <lines> <columns>: runs the setup in a pseudo-terminal of
# that size, with the script command of macOS or of Linux.
setup_in_terminal() {
  local command="stty rows $1 cols $2; cat '$SETUP' | TREASURE_HUNT_RESTART=yes '$BASH'"
  if script -q /dev/null true < /dev/null > /dev/null 2>&1; then
    OUTPUT=$(script -q /dev/null "$BASH" -c "$command" < /dev/null 2>&1)
  else
    OUTPUT=$(script -qc "$BASH -c \"$command\"" /dev/null < /dev/null 2>&1)
  fi
}
if command -v script > /dev/null; then
  setup_in_terminal 24 80
  check "a terminal with too few lines is warned about" output_contains "WARNING"
  setup_in_terminal 40 70
  check "a terminal with too few columns is warned about" output_contains "WARNING"
  setup_in_terminal 40 100
  check "a big enough terminal is not warned about" eval '! output_contains "WARNING"'
  setup_in_terminal 0 0
  check "a terminal that does not know its size is not warned about" eval '! output_contains "WARNING"'
else
  echo "  skip  no script command to make a terminal with"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All good."
else
  echo "$FAILURES check(s) failed."
  exit 1
fi
