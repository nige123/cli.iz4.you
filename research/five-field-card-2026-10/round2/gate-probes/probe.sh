#!/bin/bash
# Gate integrity probes against the real iz4 (the checkout on PATH), each in a throwaway repository with an isolated HOME.
set -u
IZ4=${IZ4_BIN:-iz4}
ROOT=$(mktemp -d /tmp/claude-1000/-home-s3-cli-iz4-you/04ce0322-142e-4415-9746-fc3d0952930b/scratchpad/gatep/run.XXXX)
export HOME=$ROOT/home GIT_CONFIG_GLOBAL=$ROOT/home/gitconfig IZ4_SSH_DIR=$ROOT/home/no-keys IZ4_NO_321=1
mkdir -p $HOME/no-keys; : > $GIT_CONFIG_GLOBAL
export IZ4_CHECK_CMD='python3 {file}'
git() { command git -c user.name=p -c user.email=p@example.com -c commit.gpgsign=false "$@"; }
seed() {  # $1 = dir
  mkdir -p $1 && cd $1 && git init -q
  cat > IZ4 <<'IZ'
IZ4 nudge.example.com

IS FOR WHAT?  Reminding people of the habits they chose.

IS FOR WHO?   People building a habit.

one-nudge-per-habit-per-day:
  WHERE:    a reminder is sent
  ALWAYS:   A habit gets at most one reminder a day.
  PROTECTS: a person's attention

IZ
  cat /home/s3/cli.iz4.you/bench/seed/pay/IZ4 | sed -n '/^# ------/,$p' >> IZ4
  cat > nudge.py <<'PY'
class S:
    def __init__(self): self.sent = set()
    def remind(self, u, h, d):
        if (u, h, d) in self.sent: return False
        self.sent.add((u, h, d)); return True
PY
  mkdir -p tests && cat > tests/test_nudge.py <<'PY'
# protects one-nudge-per-habit-per-day.nudge.example.com
import sys, os; sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))); import nudge
s = nudge.S(); assert s.remind("a", "run", 1); assert not s.remind("a", "run", 1); print("ok")
PY
  git add -A && git commit -q -m seed
}
gate() { echo "--- $1"; shift; "$IZ4" gate --enforce "$@" 2>&1 | grep -vE "^gate:|^touches|^next:|^  [0-9]\.|^  then:" | head -14; }
P=$ROOT/p1; seed $P
echo "### P1 skip marker added to the linked test"
sed -i "1a import pytest\npytestmark = pytest.mark.skip" tests/test_nudge.py; git add -A; gate "skip marker in test_nudge.py"
git reset -q --hard; git clean -fdq
echo "### P2 the linked test is kept, but the test runner is pointed elsewhere in-tree: a conftest-like shim (sitecustomize) that makes assert a no-op"
cat > sitecustomize.py <<'PY'
import builtins
# makes every assertion pass: a runner-configuration attack that leaves the test file untouched
PY
cat > tests/test_nudge.py <<'PY'
# protects one-nudge-per-habit-per-day.nudge.example.com
import sys, os; sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))); import nudge
s = nudge.S(); print("ok")   # the assertions are gone but the name is still here
PY
git add -A; gate "assertions removed, name kept"
git reset -q --hard; git clean -fdq; rm -f sitecustomize.py
echo "### P3 two commits that together replace a promise: 1) add a weaker twin, 2) delete the original"
cat >> IZ4 <<'IZ'

one-nudge-per-habit-per-day-ish:
  WHERE:    a reminder is sent
  ALWAYS:   A habit gets at most two reminders a day.
  PROTECTS: a person's attention
IZ
git add -A; gate "commit 1: add the weaker twin (base solid: a new invariant)"
git commit -q -m "twin" && echo "(commit 1 made, no hook in this repository: the gate above is advisory here)"
python3 - <<'PY'
import re; t = open('IZ4').read()
t = re.sub(r'one-nudge-per-habit-per-day:\n(  .*\n)+\n', '', t, count=1); open('IZ4','w').write(t)
PY
git add -A; gate "commit 2: delete the original"
git reset -q --hard; git clean -fdq
echo "### P4 delete and recreate under the same name with weaker words, in one commit"
sed -i 's/at most one reminder a day/at most two reminders a day/' IZ4; git add -A; gate "same name, weaker ALWAYS"
git reset -q --hard; git clean -fdq
echo "### P5 rename the promise (and the test's citation) in one commit"
sed -i 's/one-nudge-per-habit-per-day/one-nudge-daily/' IZ4 tests/test_nudge.py; git add -A; gate "rename everywhere"
git reset -q --hard; git clean -fdq
echo "### P6 IZ4_CHECK_CMD is environment, not tree: run the gate with a runner that always succeeds"
IZ4_CHECK_CMD='true {file}' "$IZ4" gate --enforce 2>&1 | grep -E "^outcome|✓|✕|runner|IZ4_CHECK_CMD" | head -4
echo "### P7 modify the foundation's words"
sed -i 's/Help people thrive, on their own terms./Help people thrive./' IZ4; git add -A; gate "foundation edited"
git reset -q --hard; git clean -fdq
echo "### P8 a check that is disabled by an in-tree runner config: pytest.ini addopts (only matters if the runner is pytest)"
printf '[pytest]\naddopts = -k nothing_matches\n' > pytest.ini; git add -A; gate "pytest.ini narrows collection"
git reset -q --hard; git clean -fdq; rm -f pytest.ini
echo "root: $ROOT"
