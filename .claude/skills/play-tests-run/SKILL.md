---
name: play-tests-run
description: Run an Unreal Engine game's play tests (made with play-tests-create) and report the results - builds the project, runs every test headless faster than real time, reads the results, and separates real regressions from flaky tests. Use when the user runs /play-tests-run, asks to run the tests, check that nothing broke, or test a change before committing or pushing. Runs only; to fix a failing test use play-tests-fix.
---

# Run the play tests

You are running the play tests that play-tests-create set up in this Unreal project, and telling the user plainly what
passed, what failed and what changed since the last run. You don't change tests or game code here: failures go to
play-tests-fix (`../play-tests-fix/SKILL.md`).

How the tests, results and report work: `../play-tests-create/framework.md` ("Results and the report", "Running"); its
traps: `../play-tests-create/pitfalls.md`.

## Steps

1. **Find the tests and see what this project's set-up can do.**
   - The run script: `Scripts/run_tests.ps1` (PowerShell) or `Scripts/run_tests.sh` (Git Bash), at the project's root.
   - The tests: a class deriving from `AFunctionalTest` in `Source/` (grep for `AFunctionalTest`) with a table of cases.
   - No script or no tests: the project has no play tests yet, so offer play-tests-create instead.
   - **Which features it has.** Projects set up with an earlier version of play-tests-create may lack some. Look:
     does the script take `-Repeat` / `--repeat` and `-BuildLevel` / `--build-level` (its `param(...)` block, or the `case`
     in the `.sh`)? Do the last run's `results.js` lines carry `version` and `mode`, and is there a `previous.js` beside
     them? Whatever is missing, use the fallbacks below, and tell the user at the end that play-tests-create can bring
     the set-up up to date (`../play-tests-create/SKILL.md`, "Upgrading an older set-up").

2. **Make sure the project's editor is closed.** The script builds the game, and the build can't replace its DLLs while
   the editor has them loaded. Look for an `UnrealEditor` process whose command line names this project's `.uproject`:
   `Get-CimInstance Win32_Process -Filter "Name like 'UnrealEditor%'" | Select-Object CommandLine` (from Git Bash:
   `powershell -NoProfile -Command "<that>"`). No output: it's closed. If it's open, don't kill it (unsaved work): ask the
   user to close it, or to run the tests inside it instead (Tools > Session Frontend > Automation, or the console:
   `Automation RunTests <test level>`).

3. **Pick the run.**
   - **Fast by default** (`-Fast` / `--fast`): nothing drawn, no videos, a fixed time step run as fast as the machine
     goes: minutes of gameplay take seconds. Right after a change, or when the user just wants to know if anything broke.
   - **With videos** (no flag) when the user wants to watch, for a report to share, or for the failures of a fast run
     (`-Filter <name>` / `<name>`): play-tests-fix needs the video. Videos need ffmpeg on the PATH (`ffmpeg -version`).
   - **Rebuild the level** (`-BuildLevel` / `--build-level`) when cases were added or renamed since the level was last
     built: a case in the table that no run has reported, or a run with fewer results than the table has cases. (Older
     scripts without the flag: run `Scripts/build_test_level.py` in a headless editor as framework.md, "The test level",
     shows.)
   - **A filter** when the user names a system or a test: the start of a case's name (`-Filter driving_brakes` /
     `driving_brakes`), several comma-separated in one run (`-Filter driving_brakes,collisions`; older scripts: one
     at a time). It's matched from the start: `brakes` doesn't find `driving_brakes_from_100`, so check the table's names.

4. **Run it** from the project's root and wait. A fast run of a dozen tests takes about half a minute plus the build; with
   videos, a few minutes; a first build after a change, a minute or more. Give the command a long timeout (10 minutes) or
   run it in the background and wait for it: a default 2-minute timeout cuts a video run off. Set `NO_OPEN=1` if the user
   doesn't want the report opened (or isn't at the screen).
   - It prints each result, the totals and the report's path (`Saved/TestRecordings/<date_time>/report.html`); the full
     log is `Saved/Logs/PlayTests.log`.
   - **A build failure** stops it before any test runs: show the compiler's error and stop there. The change doesn't
     compile; that's not a test result.
   - **"passed: 0, failed: 0"** means nothing ran: a filter that matched nothing, the test level missing or out of date,
     or the editor failing to start. Read the end of `Saved/Logs/PlayTests.log` for why; never report it as a pass.
   - The script exits 1 when anything failed or nothing ran (older scripts exit 0 either way: read the totals).

5. **Read the results** from the run folder's `results.js` (one `LW.push({...});` line per test) and `previous.js` (each
   case's earlier results). The report's summary is drawn by its page's JavaScript from these two files, so work it out
   from them rather than looking for it in the HTML:
   - passes, and failures with their message and the step that failed;
   - **regressions**: a case whose last earlier result was a pass and now fails, with the version it last passed at;
   - **fixed** cases (failed last time, pass now) and **new** cases (no earlier result);
   - **game times that moved**: a pass over 25% (and over a second) off its last five passes, **in the same mode** only
     (`mode`: `fast`, `recorded` or `editor`). Older set-ups write `"headless"` for both fast and recorded runs: tell
     them apart by whether the result has a `video`. There a recorded test's time includes a 1.5 s hold for the video,
     so compare fast with fast and recorded with recorded.

   No `previous.js` (an older set-up): compare with the earlier run folders' `results.js` yourself, newest first.

6. **Before calling anything a regression, rule out flakiness:** rerun just those cases three times on the same code
   (`-Fast -Repeat 3 -Filter <name>` / `--fast --repeat 3 <name>`; without `-Repeat`, run the fast filtered command three
   times). Passed and failed on the same version: flaky, a problem of its own (timing, physics, the nav mesh). Failed
   every time: a real regression.

7. **Tell the user:** passed and failed, how long it took, each regression (which test, what it checked, the failure
   message, the version it last passed at), anything flaky or slower, and the report's path. Then offer play-tests-fix
   for the failures, or go straight on to it if the user asked you to run and fix. If the set-up is missing features
   (step 1), say what they'd get from an upgrade.

Never edit a test, loosen a check or rerun until it happens to pass to make a run green.
