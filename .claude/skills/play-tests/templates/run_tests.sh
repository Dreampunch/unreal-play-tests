#!/usr/bin/env bash
# Builds the project, runs its play tests headless, prints each result and opens the run's report.
#   Scripts/run_tests.sh                   every case, each recorded to video (rendered offscreen)
#   Scripts/run_tests.sh door              the cases whose name contains "door"
#   Scripts/run_tests.sh --fast [filter]   nothing drawn, no videos (much quicker)
# The editor must be closed (it holds the game's DLLs). Needs ffmpeg on the PATH for the videos.
# A fixed time step: every frame is 1/30 s of game time, run as fast as the machine can, the same steps every run.
#
# Set these for the project (or export them before running):
ENGINE="${UE_ENGINE:-/c/Program Files/Epic Games/UE_5.8/Engine}"   # the engine's Engine folder
TARGET="${UE_TARGET:-MyGameEditor}"                                 # the editor target: <Module>Editor
LEVEL="${TEST_LEVEL:-L_PlayTests}"                                  # the test level's name (its tests are <LEVEL>.<case>)
set -u
cd "$(dirname "$0")/.."
PROJECT="$(cygpath -w "$PWD/$(ls *.uproject | head -1)")"
RENDER="-RenderOffscreen -ResX=640 -ResY=360"
if [ "${1:-}" = "--fast" ]; then RENDER="-nullrhi"; shift; fi
FILTER="$LEVEL${1:+.$1}"
LOG="PlayTests.log"   # under Saved/Logs

echo "building..."
"$ENGINE/Build/BatchFiles/Build.bat" "$TARGET" Win64 Development "-Project=$PROJECT" -WaitMutex > Saved/Logs/PlayTestsBuild.log 2>&1 \
  || { tail -20 Saved/Logs/PlayTestsBuild.log; echo "build failed (is the editor open?)"; exit 1; }

echo "running $FILTER..."
START=$(date +%s)
"$ENGINE/Binaries/Win64/UnrealEditor-Cmd.exe" "$PROJECT" -unattended $RENDER -nosplash -nosound -NoP4 \
  -UseFixedTimeStep -FPS=30 -ExecCmds="Automation RunTests $FILTER" -TestExit="Automation Test Queue Empty" -log="$LOG" > /dev/null 2>&1
grep -E "Test Completed|FinishTest TestResult=Failed" "Saved/Logs/$LOG" | sed -E 's/^\[[^]]*\]\[[^]]*\]//; s/ Path=\{[^}]*\}//'
echo "passed: $(grep -c 'Result={Success}' "Saved/Logs/$LOG"), failed: $(grep -c 'Result={Fail}' "Saved/Logs/$LOG"), $(( $(date +%s) - START )) s"

# the test actor logs "PlayTests: test report <path>" when a run starts (framework.md)
REPORT=$(grep -o "test report .*report.html" "Saved/Logs/$LOG" | tail -1 | sed 's/test report //')
if [ -n "$REPORT" ]; then echo "report: $REPORT"; [ -z "${NO_OPEN:-}" ] && cmd //c start "" "$REPORT"; fi
