---
name: play-tests-fix
description: Work out why an Unreal Engine play test failed and fix the right thing - watches the failing test's video, reads what each check measured, decides whether the game has a bug, the test is wrong, an Unreal trap bit, or the test is flaky, then fixes the test (or, with the user's say-so, the game) and reruns. Use when the user runs /play-tests-fix, says they broke something, a play test fails or is flaky, or play-tests-run hands over failures.
---

# Fix a failing play test

A red test means one of four things, and the job is to find out which before touching anything: the game is wrong (the
test did its job), the test is wrong, an Unreal trap, or the test is flaky; or, where its limit was only a guess, a
question for the user. Making it green is not the goal; making it right is. Never loosen a check to get a pass
without telling the user why the old number was wrong.

What you'll read: `../play-tests-create/framework.md` (the test actor, steps, results), `../play-tests-create/writing-tests.md`
(what a good test checks, and how), `../play-tests-create/pitfalls.md` (Unreal traps: read it for every strange failure),
and `../play-tests-run/SKILL.md` to run them.

## Steps

1. **Get a failing run to work from.** If play-tests-run just handed you failures, use that run. Otherwise (the user
   says they broke something, or the newest run is older than their change, or it passed), run the suite fast first with
   play-tests-run. If everything passes, say so: the tests don't cover what broke, and play-tests-create can add a case
   for it. Note whether the set-up is an older one (play-tests-run, step 1): no `-Repeat`, no `version`, no
   `previous.js`, and a script that exits 0 even when tests fail.

2. **Gather the evidence for each failing case.**
   - **Its result** in the run folder's `results.js` (`Saved/TestRecordings/<date_time>/`): the failure message, the step
     it failed on, each step's label (passing checks print what they measured), its game time, and any actors' last
     memory or state lines. Often the numbers alone tell the story (a car still doing 7 km/h after 15 s of braking).
   - **Its last pass**: the same case in earlier runs (`previous.js`, or the earlier folders' `results.js`, newest first).
     What did each check measure then? The difference is the clue (stopped in 26 m then, never now).
   - **What changed since**: with git, `git diff <the version it last passed at>`; without git or a recorded version,
     the files under `Source/` and `Config/` modified after that last passing run's `ended` time
     (`find Source Config -newer <that run's results.js>`).
   - **Its video.** If the run was fast (no videos), rerun the failing cases with videos (play-tests-run: the filter
     takes several comma-separated names in one run on an up-to-date set-up; older scripts take one at a time). Video
     time is game time (recorded at 1x): a step starts at the sum of the earlier steps' `seconds`. Pull frames around
     the failing step (`ffmpeg -ss <seconds> -i <case>.mp4 -frames:v 1 frame.png`) and look at them. The cameras show
     what happened (fell over, blocked, stuck in a wall, wrong door, sliding); they follow the actor, so for speed and
     distance the measured numbers are the evidence and the frames only rule things out (upright, nothing in the way).
   - **Its case** in the table, and the game code it drives: follow the functions its steps call (`Car->DoBrake`), then
     their other callers (the input bindings, the AI), so you know what else the same bug breaks.

3. **Decide which it is: one of four, or a question for the user.** First rule out flakiness: rerun the case three times fast on the same code
   (`-Fast -Repeat 3 -Filter <name>`; without `-Repeat`, the fast filtered command three times). Passed and failed on the
   same code: **flaky**. Failed the same way every time: one of the other three.
   - **The game is wrong**: it did what the test says it shouldn't (the car never brakes, the door opens without its
     key) or didn't do what it should. The test found a bug; that's its job. A regression usually lines up with a
     change from step 2.
   - **The test is wrong**: a mistake in the arena (the floor too short, a wall in the path), a number tighter than the
     design (or measured from the wrong point), a step that waits for something that never comes, a check of the wrong
     thing. The video usually shows it: the car parked nose to the wall it was told to stop before, from a start too
     close to it.
   - **An Unreal trap** (`pitfalls.md`): nav mesh not rebuilt, time dilation not set, a bound read from the wrong
     component, a hitch at speed. Strange failures that the game and the test both look right for, often several cases
     at once.
   - **Flaky**: timing, physics or the nav mesh, waited on by time instead of by state.
   - **A design question**: the limit was a guess agreed when the case was written (the game had no design number), and
     the game misses it by a clear, steady margin (a handbrake turn slides the tail 16 degrees against a guessed 20).
     Neither side is proven wrong: the user decides what the game should do.

4. **Fix the right thing.**
   - **The game**: tell the user what the test found, with the evidence (the measured numbers then and now, the frames,
     the code that does it, the change that broke it). Fix the game only if they want you to; ask, and if they meant the
     change (a softer brake on purpose), ask what it should do. The test stays as it is, red until the game is right.
   - **The test**: fix it and say what was wrong and why the new arena or number is the right one (from the design or
     the code, not from what the game happens to do now). A check that now passes must still fail on the bug it guards:
     where it matters, break that on purpose once and see it go red, then put the code back exactly.
   - **A trap**: fix it, and add a line to `pitfalls.md` if it's a new one.
   - **Flaky**: fix the cause (wait for the state, not for time; settle physics first; rebuild the nav mesh), never
     retries that hide it.
   - **A design question**: show the measured value against the guess, and the same measurement without the feature
     where there is one. Ask whether the game should change (it stays red until it does) or the number should (then set
     it to the one they give, with where it came from in a comment). Leave it red meanwhile.
   - After breaking or changing game code on purpose and putting it back, touch the file so the next build recompiles
     it (`pitfalls.md`).

5. **Rerun** after a fix: the fixed cases with videos (watch them), then the whole suite fast, so nothing else broke.

6. **Tell the user** for each case: which it was and why, the evidence, and what you changed with the run
   that shows it now. For a game bug waiting on their answer: the failing run, your question, and what you'll do once
   they agree (fix, rerun with videos, then the whole suite fast). Mention an older set-up if you found one:
   play-tests-create can bring it up to date.

A bug found outside the tests gets its case first (`writing-tests.md`, "Every bug gets a case"): a test that fails on
the bug, then the fix, then the test passing. Use play-tests-create to add it.
