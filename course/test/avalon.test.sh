#!/bin/bash
#
# Plays the remote land of Avalon, the SSH follow-up of the treasure hunt in
# "Hello SSH", the way a student would: from a student's computer, against the
# SSH exercise server, each one a Docker container. Every gate refuses before
# its task is done, on the wrong machine or with the wrong login, and opens the
# next part once it is. Both ways in are played: from scratch with uname -a, and
# with the treasure of a treasure hunt played for real.
#
# It needs Docker. Run it with the Bash the prophecy is also read with, e.g. on
# macOS:
#
#     /bin/bash course/test/avalon.test.sh

set -u

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
COURSE="$(cd "$TEST_DIR/.." && pwd)"
CHAPTER="$COURSE/chapters/104-hello-ssh"
LAND="$CHAPTER/avalon"

IMAGE=archidep-avalon-test
NETWORK="archidep-avalon-$$"
SERVER="archidep-avalon-server-$$"
COMPUTER="archidep-avalon-computer-$$"
LOGIN=jde@ssh.archidep.ch

LOCAL="$(mktemp -d)"
cleanup() {
  docker rm -f "$SERVER" "$COMPUTER" > /dev/null 2>&1
  docker network rm "$NETWORK" > /dev/null 2>&1
  rm -rf "$LOCAL"
}
trap cleanup EXIT

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

# on_computer <command>: runs a shell command as the student, on their own
# computer, keeping its output in OUTPUT and its exit status in STATUS.
on_computer() {
  OUTPUT=$(docker exec -u student -w /home/student -e HOME=/home/student \
    "$COMPUTER" bash -c "$1" 2>&1 < /dev/null)
  STATUS=$?
}

# on_server <command>: runs a shell command on the server as root, to look at
# what the student cannot see from where they are.
on_server() {
  docker exec "$SERVER" bash -c "$1" > /dev/null 2>&1
}

# step <description> <expected status> <command>: runs a command as the
# student, on their own computer.
step() {
  local description="$1" expected="$2"
  on_computer "$3"
  if [ "$STATUS" -eq "$expected" ]; then
    pass "$description"
  else
    failed "$description (exit status $STATUS, expected $expected)"
    printf '%s\n' "$OUTPUT" | sed 's/^/        | /'
  fi
}

output_contains() { printf '%s' "$OUTPUT" | grep -q -- "$1"; }
output_lacks() { ! output_contains "$1"; }

# Passes when the output fits on a terminal of 80 × 24, the size macOS Terminal
# opens at, along with the command that printed it and the prompt after it.
fits_on_screen() {
  printf '%s\n' "$OUTPUT" | awk 'length > 80 { wide = 1 } END { exit wide || NR > 22 }'
}

# texts_fit_on_screen <file...>: the same, for texts a student reads with cat.
texts_fit_on_screen() {
  local file ok=0
  for file in "$@"; do
    OUTPUT=$(cat "$file")
    if ! fits_on_screen; then
      echo "        | $(basename "$file") does not fit on the screen"
      ok=1
    fi
  done
  return "$ok"
}

# The word the prophecy last gave.
word_of_the_prophecy() {
  printf '%s' "$OUTPUT" | sed -n 's/.*The word is: \([A-Z]*\).*/\1/p'
}

# restart: sends the student back to the dock, for a new Avalon.
restart() {
  on_computer "echo y | ssh $LOGIN dock --restart"
  [ "$STATUS" -eq 0 ] && on_server "test ! -e /home/jde/avalon/lady"
}

# The edition the land belongs to, and the port of the impostor, taken from the
# dock so that a change there is checked everywhere else.
CURRENT_YEAR=$(sed -n 's/^CURRENT_YEAR=//p' "$LAND/dock")
IMPOSTOR_PORT=$(sed -n 's/^IMPOSTOR_PORT=//p' "$LAND/dock")

echo "Bash $BASH_VERSION"
check "the dock names an edition" [ -n "$CURRENT_YEAR" ]

echo "The machines"
if ! docker build -q -t "$IMAGE" "$TEST_DIR/avalon" > /dev/null; then
  echo "Could not build the image of the machines."
  exit 1
fi
docker network create "$NETWORK" > /dev/null
docker run -d --name "$SERVER" --hostname ssh.archidep.ch \
  --network "$NETWORK" --network-alias ssh.archidep.ch \
  -v "$LAND/dock:/usr/local/bin/dock:ro" \
  -v "$LAND/impostor/sshd_config:/etc/ssh/avalon-impostor/sshd_config:ro" \
  -v "$LAND/impostor/banner.txt:/etc/ssh/avalon-impostor/banner.txt:ro" \
  -v "$TEST_DIR/avalon/sshd.conf:/etc/ssh/sshd_config.d/00-avalon.conf:ro" \
  "$IMAGE" bash -c "
    ssh-keygen -q -t ed25519 -N '' -f /etc/ssh/avalon-impostor/ssh_host_ed25519_key &&
    /usr/sbin/sshd -f /etc/ssh/avalon-impostor/sshd_config &&
    exec /usr/sbin/sshd -D -e" > /dev/null
docker run -d --name "$COMPUTER" --network "$NETWORK" \
  -v "$COURSE:/course:ro" "$IMAGE" sleep infinity > /dev/null

for attempt in $(seq 1 40); do
  if docker exec "$COMPUTER" ssh-keyscan -T 1 ssh.archidep.ch > /dev/null 2>&1 &&
    docker exec "$COMPUTER" ssh-keyscan -T 1 -p "$IMPOSTOR_PORT" ssh.archidep.ch > /dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
check "both SSH servers answer" [ "$attempt" -lt 40 ]

# The fingerprint the dashboard shows, which the student checks the first
# time they connect.
DASHBOARD=$(docker exec "$SERVER" ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | cut -d ' ' -f 2)
IMPOSTOR=$(docker exec "$SERVER" ssh-keygen -lf /etc/ssh/avalon-impostor/ssh_host_ed25519_key.pub | cut -d ' ' -f 2)
check "the impostor has keys of its own" [ -n "$IMPOSTOR" -a "$IMPOSTOR" != "$DASHBOARD" ]

# The student's SSH settings. BatchMode makes a command that would ask for a
# password fail rather than wait for one: the commands that type a password
# turn it off.
step "the student checks the fingerprint and trusts the server" 0 "
  mkdir -m 700 -p ~/.ssh &&
  printf 'Host ssh.archidep.ch\n  BatchMode yes\n  ConnectTimeout 5\n' > ~/.ssh/config &&
  ssh-keyscan -t ed25519 ssh.archidep.ch 2> /dev/null > ~/.ssh/known_hosts &&
  ssh-keygen -lf ~/.ssh/known_hosts"
check "the fingerprint is the dashboard's" output_contains "$DASHBOARD"

PASSWORD_SSH="sshpass -p secret ssh -o BatchMode=no -o PubkeyAuthentication=no"

echo "The dock"
step "the student logs in with their password" 0 "$PASSWORD_SSH $LOGIN hostname"
check "they are on the server" [ "$OUTPUT" = ssh.archidep.ch ]
step "the dock stays closed to a password" 1 "$PASSWORD_SSH $LOGIN dock"
check "the dock says the student came with a password" output_contains "with your password"
check "Avalon does not exist yet" on_server "test ! -e /home/jde/avalon"
OUTPUT=$(docker exec -u jde -w /home/jde "$SERVER" dock 2>&1)
check "the dock refuses someone who did not come with SSH" output_contains "SSH. You did not"
step "the student gives the server their public key" 0 "
  ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519 &&
  sshpass -p secret ssh-copy-id -o BatchMode=no $LOGIN"
step "the dock opens to the key" 0 "ssh $LOGIN dock"
check "the student arrives on Avalon" output_contains "THE REMOTE LAND OF AVALON"
check "the arrival fits on the screen" fits_on_screen
check "Merlin waits on Avalon" on_server "test -x /home/jde/avalon/merlin"
check "there is a hint on Avalon" on_server "test -f /home/jde/avalon/.hint"
check "the hint on Avalon tells how to talk to Merlin" \
  on_server "grep -q './merlin' /home/jde/avalon/.hint"
check "the home directory the student lands in has a hint too" \
  on_server "grep -q 'cd ~/avalon' /home/jde/.hint"
docker cp "$SERVER:/home/jde/.hint" "$LOCAL/home-hint" > /dev/null
docker cp "$SERVER:/home/jde/avalon/.hint" "$LOCAL/dock-hint" > /dev/null
for thing in prophecy lady message.txt; do
  check "$thing does not exist yet" on_server "test ! -e /home/jde/avalon/$thing"
done
step "the dock stays closed to a password, even once the key works" 1 "$PASSWORD_SSH $LOGIN dock"
step "the dock says Avalon is already there" 0 "ssh $LOGIN dock"
check "the dock sends the student to Avalon" output_contains "cd ~/avalon"

MERLIN="ssh $LOGIN 'cd avalon && ./merlin'"

echo "Merlin, from scratch"
step "Merlin wants a gift" 1 "$MERLIN"
check "Merlin asks for the treasure, or for uname -a" output_contains "uname -a"
check "Merlin's welcome fits on the screen" fits_on_screen
step "Merlin refuses the server's own uname -a" 1 "
  ssh $LOGIN 'uname -a > avalon/land.txt' && $MERLIN"
check "Merlin says it comes from Avalon itself" output_contains "Avalon itself"
step "Merlin refuses something that is not uname -a" 1 "
  echo hello > land.txt && scp -q land.txt $LOGIN:avalon/ && $MERLIN"
step "Merlin accepts uname -a from the student's computer" 0 "
  uname -a > land.txt && scp -q land.txt $LOGIN:avalon/ && $MERLIN"
check "Merlin tells where the student comes from" output_contains "much like this one"
check "Merlin's answer fits on the screen" fits_on_screen
check "the prophecy appears, executable" \
  on_server "test -x /home/jde/avalon/prophecy"
check "the Lady of the Lake appears" on_server "test -x /home/jde/avalon/lady"
docker cp "$SERVER:/home/jde/avalon/.hint" "$LOCAL/merlin-hint" > /dev/null
step "Merlin gave the prophecy already" 0 "$MERLIN"

echo "The prophecy"
step "the prophecy is blank on the server" 1 "ssh $LOGIN './avalon/prophecy'"
check "no word on the server" output_lacks "The word is"
# scp carries the mode of the prophecy across, so it usually arrives ready to
# run; an old scp or a strict umask could still strip it, which is why the hint
# keeps chmod as a fallback and this step accepts both.
step "the prophecy reads on the student's computer" 0 "
  scp -q $LOGIN:avalon/prophecy . &&
  { ./prophecy || { chmod +x prophecy && ./prophecy; }; }"
WORD=$(word_of_the_prophecy)
check "the prophecy gives a word ($WORD)" [ -n "$WORD" ]
check "the prophecy fits on the screen" fits_on_screen
docker cp "$COMPUTER:/home/student/prophecy" "$LOCAL/prophecy" > /dev/null
OUTPUT=$("$BASH" "$LOCAL/prophecy" 2>&1)
check "the prophecy reads with Bash $BASH_VERSION too" output_contains "The word is: $WORD"

echo "The Lady of the Lake"
step "she does not speak to someone logged in" 1 "ssh -tt $LOGIN ./avalon/lady $WORD"
check "she tells them to leave" output_contains "stay on Avalon"
# The student, logged in, calls her across the sea from the server itself: by
# the server's name, and by localhost.
for address in ssh.archidep.ch localhost; do
  step "she does not speak to a call from the server itself ($address)" 1 "
    ssh $LOGIN 'sshpass -p secret ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no \
      jde@$address ./avalon/lady $WORD'"
  check "she says the call comes from the server ($address)" \
    output_contains "you sent it from this server"
done
check "no message appears on the shore yet" \
  on_server "test ! -e /home/jde/avalon/message.txt"
step "she wants the word" 1 "ssh $LOGIN ./avalon/lady"
step "she refuses a wrong word" 1 "ssh $LOGIN ./avalon/lady NOTTHEWORD"
lower=$(printf '%s' "$WORD" | tr 'A-Z' 'a-z')
step "she answers the word, from the student's computer, in any case" 0 \
  "ssh $LOGIN ./avalon/lady $lower"
check "she tells where the parrot is" output_contains "SQUAWK"
check "her answer fits on the screen" fits_on_screen
check "she remembers the words of the student's land" output_contains "words of your own land"
check "she says nothing about a treasure" output_lacks "Skull Island"
check "a message appears on the shore" \
  on_server "grep -q 'ssh -p $IMPOSTOR_PORT $LOGIN' /home/jde/avalon/message.txt"
check "the hint turns to the message" \
  on_server "grep -q 'message on the shore' /home/jde/avalon/.hint"

echo "Programs read with cat"
# ends_with_banner <file> <command>: the end of the file, which is what cat
# leaves on screen, tells how to run it.
ends_with_banner() {
  tail -n 20 "$1" | grep -q "HALT, TRAVELLER" && tail -n 20 "$1" | grep -qF -- "$2"
}
for program in merlin lady prophecy; do
  docker cp "$SERVER:/home/jde/avalon/$program" "$LOCAL/$program" > /dev/null
done
check "merlin ends by telling how to run it" ends_with_banner "$LOCAL/merlin" "./merlin"
check "the prophecy ends by telling how to run it" ends_with_banner "$LOCAL/prophecy" "./prophecy"
check "the lady ends by telling how to call her" ends_with_banner "$LOCAL/lady" "ssh $LOGIN ./avalon/lady"
for program in merlin lady prophecy; do
  check "$program says nothing in plain text" \
    eval "! grep -q '$WORD\|The word is\|SQUAWK\|Merlin smiles\|Morgan' '$LOCAL/$program'"
done

echo "What Avalon says"
check "no placeholder is left on Avalon" \
  on_server "! grep -rl '@@[A-Z0-9_]*@@' /home/jde/avalon"
docker cp "$SERVER:/home/jde/avalon/.hint" "$LOCAL/shore-hint" > /dev/null
docker cp "$SERVER:/home/jde/avalon/message.txt" "$LOCAL/message.txt" > /dev/null
check "the texts read with cat fit on the screen" texts_fit_on_screen \
  "$LOCAL/home-hint" "$LOCAL/dock-hint" "$LOCAL/merlin-hint" "$LOCAL/shore-hint" \
  "$LOCAL/message.txt" "$LAND/impostor/banner.txt"
# Passes when every address of the site Avalon names carries the edition, and
# its anchor is a heading of the exercise.
addresses_lead_to_the_exercise() {
  local anchor ok=0
  for anchor in $(sed -n 's/.*@@EXERCISE@@#\([a-z0-9-]*\).*/\1/p' "$LAND/dock"); do
    if ! sed -n 's/^#\{2,\} *//p' "$CHAPTER/exercise.md" |
      sed -e 's/:[a-z_]*: *//g' -e 's/`//g' |
      tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-\n' | grep -qx "$anchor"; then
      echo "        | no heading of the exercise for #$anchor"
      ok=1
    fi
  done
  return "$ok"
}
check "every anchor Avalon links to is a heading of the exercise" addresses_lead_to_the_exercise
check "the hints link to the exercise of the edition" \
  on_server "grep -q 'https://archidep.ch/$CURRENT_YEAR/course/104-hello-ssh/#' /home/jde/avalon/.hint"

echo "Restarting"
step "without an answer, the dock leaves Avalon as it was" 1 "ssh $LOGIN dock --restart"
check "Avalon is as it was" on_server "test -x /home/jde/avalon/lady"
check "the dock rebuilds Avalon when told to" restart
check "Merlin waits again" on_server "test -x /home/jde/avalon/merlin"

echo "The treasure hunt, played on the student's computer"
docker exec -i -u student -w /home/student -e HOME=/home/student "$COMPUTER" \
  bash -s > "$LOCAL/hunt.log" 2>&1 <<'END_HUNT'
set -e
bash /course/chapters/102-hello-shell/treasure-hunt.sh
H=~/treasure-hunt
set -m
(cd "$H/cave" && exec ./octopus > /dev/null 2>&1) &
octopus=$!
set +m
sleep 1
kill -INT "$octopus"
wait "$octopus" || true
mv "$H/cave/den/rusty-key" "$H/bag/"
mv "$H/bag/rusty-key" "$H/fort/key"
cd "$H/fort" && ./door
cd courtyard && cp ../../shipwreck/map.txt map-copy.txt && ./mapmaker
mkdir camp && echo lit > camp/fire && ./rest
sed -i 's/state=closed/state=open/' drawbridge.conf && ./lever
cd tower && rm cursed-chest.txt trap-*.txt && ./stairs
cd "$H/beach/boat" && "$H/bell"
cd "$H/skull-island" && chmod +x chest
coin() { tr -cd 0-9 < "$H/bag/$1"; }
echo "$(coin coin-1)$(coin coin-2)$(coin coin-3)" | ./chest
test -x "$H/bag/treasure"
END_HUNT
STATUS=$?
check "the student found the treasure" [ "$STATUS" -eq 0 ]
[ "$STATUS" -eq 0 ] || sed 's/^/        | /' "$LOCAL/hunt.log"

echo "Merlin, after the treasure hunt"
step "treasure is not a command on the server" 127 "ssh $LOGIN treasure"
step "Merlin accepts the treasure" 0 "
  scp -q ~/treasure-hunt/bag/treasure $LOGIN:avalon/ && $MERLIN"
check "Merlin reads where the student's home is" output_contains "homes are in /home"
check "Merlin sends the student to try treasure" output_contains "Command not found"
check "Merlin's answer to the treasure fits on the screen" fits_on_screen
step "the treasure runs on Avalon by its path" 0 "ssh $LOGIN 'cd avalon && ./treasure'"
check "it is the treasure" output_contains "YOU FOUND THE TREASURE"
check "the parrot is waiting on Avalon" output_contains "You followed me"
step "the prophecy reads on the student's computer" 0 "
  scp -q $LOGIN:avalon/prophecy . && chmod +x prophecy && ./prophecy"
WORD=$(word_of_the_prophecy)
step "the Lady of the Lake answers the word" 0 "ssh $LOGIN ./avalon/lady $WORD"
check "she remembers the treasure" output_contains "treasure of Skull Island"
check "her answer to the treasure fits on the screen" fits_on_screen

echo "Merlin, meeting other lands"
check "the dock rebuilds Avalon" restart
step "Merlin recognises a treasure from a Mac" 0 "
  mkdir -p mac && sed \"s#^HUNT='/home/student/#HUNT='/Users/student/#\" \
    ~/treasure-hunt/bag/treasure > mac/treasure &&
  scp -q mac/treasure $LOGIN:avalon/ && $MERLIN"
check "Merlin says it comes from a Mac" output_contains "homes are in /Users"
check "the dock rebuilds Avalon" restart
step "Merlin recognises uname -a from a Mac" 0 "
  echo 'Darwin MacBook-Pro.local 24.6.0 Darwin Kernel Version 24.6.0 arm64' > land.txt &&
  scp -q land.txt $LOGIN:avalon/ && $MERLIN"
check "Merlin says it comes from a Mac" output_contains "You come from a Mac"
check "the dock rebuilds Avalon" restart
step "Merlin recognises uname -a from the WSL" 0 "
  echo 'Linux DESKTOP-4 5.15.167.4-microsoft-standard-WSL2 #1 SMP x86_64 GNU/Linux' > land.txt &&
  scp -q land.txt $LOGIN:avalon/ && $MERLIN"
check "Merlin says it comes from the WSL" output_contains "the WSL, on Windows"

echo "The impostor"
check "the impostor is on the port of the dock" \
  grep -q "^Port $IMPOSTOR_PORT$" "$LAND/impostor/sshd_config"
check "the impostor's banner forgets the right port" \
  grep -qF "ssh-keygen -R '[ssh.archidep.ch]:$IMPOSTOR_PORT'" "$LAND/impostor/banner.txt"
step "a careful student refuses the impostor" 255 \
  "ssh -p $IMPOSTOR_PORT -o StrictHostKeyChecking=yes $LOGIN true"
check "the host key cannot be verified" output_contains "Host key verification failed"
check "the impostor says nothing to them" output_lacks "Morgan"
step "their computer does not trust the impostor" 1 \
  "ssh-keygen -F '[ssh.archidep.ch]:$IMPOSTOR_PORT'"
step "a student who accepts cannot log in" 255 \
  "ssh -p $IMPOSTOR_PORT -o StrictHostKeyChecking=accept-new $LOGIN true"
check "the impostor tells them what they did" output_contains "I am Morgan le Fay"
check "the impostor only offers public keys" output_contains "Permission denied (publickey)"
step "their computer now trusts the impostor" 0 \
  "ssh-keygen -F '[ssh.archidep.ch]:$IMPOSTOR_PORT'"
step "any username gets the same answer" 255 \
  "ssh -p $IMPOSTOR_PORT nobody-at-all@ssh.archidep.ch true"
check "the impostor tells them what they did" output_contains "I am Morgan le Fay"
step "the impostor never asks for a password" 255 \
  "sshpass -p secret ssh -p $IMPOSTOR_PORT -o BatchMode=no -o PubkeyAuthentication=no $LOGIN true"
check "only public keys are offered" output_contains "Permission denied (publickey)"
step "the student makes their computer forget the impostor" 0 \
  "ssh-keygen -R '[ssh.archidep.ch]:$IMPOSTOR_PORT' && ! ssh-keygen -F '[ssh.archidep.ch]:$IMPOSTOR_PORT'"
step "the real server is still trusted" 0 "ssh $LOGIN true"
check "the real server shows no banner" output_lacks "Morgan"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All good."
else
  echo "$FAILURES check(s) failed."
  exit 1
fi
