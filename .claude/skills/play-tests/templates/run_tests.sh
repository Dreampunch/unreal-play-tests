#!/usr/bin/env bash
# Builds the project, runs its play tests headless, prints each result and opens the run's report.
#   Scripts/run_tests.sh                     every case, each recorded to video (rendered offscreen)
#   Scripts/run_tests.sh brakes              the cases whose name contains "brakes"
#   Scripts/run_tests.sh --fast [filter]     nothing drawn, no videos (much quicker)
#   Scripts/run_tests.sh --build-level ...   rebuild the test level first (after adding or renaming a case)
# The project's own editor must be closed (it holds the game's DLLs). Needs ffmpeg on the PATH for the videos.
# A fixed time step: every frame is 1/30 s of game time, run as fast as the machine can, the same steps every run.
#
# Set these for the project (or export them before running):
ENGINE="${UE_ENGINE:-/c/Program Files/Epic Games/UE_5.8/Engine}"   # the engine's Engine folder
TARGET="${UE_TARGET:-MyGameEditor}"                                 # the editor target: <Module>Editor
LEVEL="${TEST_LEVEL:-L_PlayTests}"                                  # the test level's name (its tests are <LEVEL>.<case>)
set -u
cd "$(dirname "$0")/.."
PROJECT="$(cygpath -w "$PWD/$(ls *.uproject | head -1)")"
EDITOR="$ENGINE/Binaries/Win64/UnrealEditor-Cmd.exe"
RENDER="-RenderOffscreen -ResX=640 -ResY=360"
BUILD_LEVEL=""
while [ "${1:-}" = "--fast" ] || [ "${1:-}" = "--build-level" ]; do
  [ "$1" = "--fast" ] && RENDER="-nullrhi"
  [ "$1" = "--build-level" ] && BUILD_LEVEL=1
  shift
done
FILTER="$LEVEL${1:+.$1}"
LOG="PlayTests.log"   # under Saved/Logs
mkdir -p Saved/Logs   # (a fresh project has no Saved/Logs yet)

echo "building..."
# -NoHotReloadFromIDE: without it the build refuses while ANY editor of this engine install has Live Coding on, even one
# open on another project. -Log: the build tool's own log here, not the per-user one every build shares (another build
# holding it fails this one).
"$ENGINE/Build/BatchFiles/Build.bat" "$TARGET" Win64 Development "-Project=$PROJECT" -WaitMutex -NoHotReloadFromIDE \
  "-Log=$(cygpath -w "$PWD/Saved/Logs/UnrealBuildTool.log")" > Saved/Logs/PlayTestsBuild.log 2>&1 \
  || { tail -20 Saved/Logs/PlayTestsBuild.log; echo "build failed (is this project's editor open?)"; exit 1; }

if [ -n "$BUILD_LEVEL" ]; then
  echo "building the test level..."
  "$EDITOR" "$PROJECT" -ExecutePythonScript="$(cygpath -w "$PWD/Scripts/build_test_level.py")" \
    -unattended -nosplash -nosound -NoP4 -RenderOffscreen -log=BuildLevel.log > /dev/null 2>&1
  grep -E "PlayTests: (built|building)" Saved/Logs/BuildLevel.log | sed -E 's/^\[[^]]*\]\[[^]]*\]//'
fi

echo "running $FILTER..."
START=$(date +%s)
"$EDITOR" "$PROJECT" -unattended $RENDER -nosplash -nosound -NoP4 \
  -UseFixedTimeStep -FPS=30 -ExecCmds="Automation RunTests $FILTER" -TestExit="Automation Test Queue Empty" -log="$LOG" > /dev/null 2>&1
grep -E "Test Completed|FinishTest TestResult=Failed" "Saved/Logs/$LOG" | sed -E 's/^\[[^]]*\]\[[^]]*\]//; s/ Path=\{[^}]*\}//'
echo "passed: $(grep -c 'Result={Success}' "Saved/Logs/$LOG"), failed: $(grep -c 'Result={Fail}' "Saved/Logs/$LOG"), $(( $(date +%s) - START )) s"

# the test actor logs "PlayTests: test report <path>" when a run starts (framework.md)
REPORT=$(grep -o "test report .*report.html" "Saved/Logs/$LOG" | tail -1 | sed 's/test report //')
if [ -n "$REPORT" ]; then echo "report: $REPORT"; [ -z "${NO_OPEN:-}" ] && cmd //c start "" "$REPORT"; fi
