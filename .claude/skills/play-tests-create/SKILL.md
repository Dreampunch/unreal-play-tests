---
name: play-tests-create
description: Create automated play tests for an Unreal Engine C++ game, or add tests for a new feature - tests that build a small arena, play the game's own systems (characters, vehicles, doors, pickups, AI orders), check the world afterwards, record every test to video from five cameras and write an HTML report. The first time it sets up the framework (test actor, test screen, test level, report, run scripts). Use when the user runs /play-tests-create, asks for tests, unit tests, functional tests or regression tests for their Unreal game, or wants a new feature covered by tests. To run existing tests use play-tests-run; to fix failing ones, play-tests-fix.
---

# Create play tests for an Unreal game

You are adding play tests to the user's Unreal Engine C++ project: Unreal Functional Tests (`AFunctionalTest`) that each
build their own small arena, drive the game's real code the way the game does, and check the world afterwards. Every
test shows a five-camera test screen while it runs, records it to video, and adds its result to an HTML report.

Nobody wants to write tests by hand. That's the point of this skill: you read the game, propose what to test, and write
it; the user decides what matters and looks at the report.

This is one of three skills that work together: **play-tests-create** (this one: set up, add tests),
**play-tests-run** (run them and read the results) and **play-tests-fix** (work out why a test failed and fix the
right thing). They share the documents beside this file; the other two point here.

Read these as you need them (they're beside this file):

- `framework.md`: the test actor, steps and checks, the arena helpers, results, categories. Build this first.
- `test-screen.md`: the five cameras, the panel, recording to video, lighting for the cameras.
- `writing-tests.md`: what makes a good play test, with worked cases.
- `pitfalls.md`: Unreal traps that cost hours; read it before building and again when something fails strangely.
- `templates/`: `report.html` (copied into every run's folder), `build_test_level.py` (builds the test level in a
  headless editor), `run_tests.sh` and `run_tests.ps1` (build, optionally rebuild the level, run headless, open the
  report).
- `examples/vehicle.md` (cars: Epic's Vehicle template) and `examples/train.md` (a train on a track, coupling cars):
  complete worked examples, with what their tests found.

First see whether the project already has the framework (a test actor deriving from `AFunctionalTest` with a case table,
`Scripts/run_tests.ps1` or `.sh`, a test level). If it does, skip to **Adding tests for a feature** below; if it's an
older set-up missing later features, offer **Upgrading an older set-up** (at the end) first.

## Setting up (the first time)

1. **Read the project.** The `.uproject` (engine version, modules, plugins), `Source/` (the game's actors, components,
   AI, input, the systems a player or an AI uses), `Config/` (navigation, rendering), and any design notes. List the
   game's abilities and systems in plain words: "a character walks to a point", "a door opens and stays locked without
   its key", "a train stops at a signal".

2. **Propose a test plan and agree it with the user before writing code.** Group cases into categories (one per system:
   Characters, Doors, Vehicles...). For each case: one line on the arena, what is done, and what is checked, with
   numbers ("stops within 10 cm of its end", "arrives within 5% of the time its speeds give"), and its kind:
   - **positive** (it does what it should), **negative** (it refuses or stops when it should) or **boundary** (just
     inside and just outside a limit);
   - every feature gets all three. List the limits you found in the code (reach 150 cm, heard within 15 m, a step of
     35 cm) with a boundary pair for each (`writing-tests.md`, "Boundary pairs"), and say why for any kind a feature
     has none of.

   Start with 5-15 cases that cover what the user cares about most; say what you left out. Ask which matter most and
   whether anything is missing.

3. **Build the framework** (`framework.md`, then `test-screen.md`): a test actor class, its test screen, the test level
   with one test actor per case, the report template and the run scripts. Use the game's naming style. Put it where a
   Shipping build won't link it (`FunctionalTesting` is a Developer module: see framework.md, "Where it lives"). Enable
   the Python Editor Script Plugin (`PythonScriptPlugin`, off by default) for the level builder. The project's own
   editor needn't be open: everything here runs headless.

4. **Write the cases** (`writing-tests.md`). Drive the game's real code (its components, AI orders, input actions), not
   shortcuts that set the outcome. Check from the world afterwards, measured independently of the code under test.

5. **Run them and fix what fails:** follow play-tests-run (`../play-tests-run/SKILL.md`), with `--build-level` /
   `-BuildLevel` this first time, and play-tests-fix (`../play-tests-fix/SKILL.md`) for every failure, until the run is
   green or every red test is a real bug the user knows about.

6. **Check it tests what it claims.** Open the report and watch the videos of anything surprising: a passing test can
   still look wrong (a character sliding, a car hovering beside its rails). Read what each passing check measured (it's
   in the step's label): a number far from anything plausible is a hollow pass. Read the summary's table of features by
   kind: a feature flagged with a missing kind is a gap to fill or explain. For the tests that matter most, break the
   feature on purpose once and watch the test go red, then put the code back exactly.

7. **Hand over:** what's covered, what each category found, and the three commands from here on: `/play-tests-create`
   to add tests for a new feature, `/play-tests-run` (or the run script itself) to run them, `/play-tests-fix` when one
   fails.

## Adding tests for a feature

The framework exists; the user has added or changed a feature.

1. Read the feature's code and find its limits (reach, range, speeds, timings).
2. Propose its cases (positive, negative and a boundary pair per limit) and agree them, as in step 2 above. Where a
   kind is missing, say why: a limit may have no two sides (`writing-tests.md`, "Limits with no two sides"). Where the
   game has no design number for a limit, say the numbers you propose are guesses, and ask for the real ones.
3. Add them to the case table (`framework.md`) and write them (`writing-tests.md`). On an older set-up without `Tag`,
   write each case's kind in a comment on it.
4. Run everything fast with play-tests-run, with `--build-level` / `-BuildLevel` (new cases need their test actors
   placed in the level), then the new cases again with videos, and watch them. Fix failures with play-tests-fix. Tell
   the user if anything that used to pass now fails: the report counts it as a regression, the reason these tests
   exist.

When a bug turns up, its case comes first (`writing-tests.md`, "Every bug gets a case"): a test that fails on the bug,
then the fix, then the test passing.

## Upgrading an older set-up

A project set up with an earlier version of this skill may lack later features. Compare it with `framework.md`,
`test-screen.md` and `templates/`, list what's missing in plain words, and with the user's agreement bring it up to date,
keeping the project's names, cases and style:

- **kinds of test** (`Tag(feature, kind)` on each case, positive / negative / boundary) and the report's table of
  features by kind;
- **the version tested** (commit plus a code for uncommitted files) on every result, and **`previous.js`** (each case's
  earlier results), which give the report its regressions, fixed and new cases, flaky cases and History section;
- **`mode`** on every result (`fast`, `recorded`, `editor`), and `seconds` without the hold for the video;
- **a run folder per editor process**, so repeats don't share one;
- **the tests in a module of their own** (framework.md, "Where it lives"), if they're in the game's module: a module
  that depends on `FunctionalTesting` breaks a Shipping build, so this one matters most;
- the run scripts' **`-BuildLevel` / `--build-level`** and **`-Repeat` / `--repeat`**, filters that take several
  comma-separated names (each the start of a case's name), and their exit code (1 when anything failed or nothing
  ran): copy the templates over the project's scripts and set its names again;
- the latest `report.html` template (into `Scripts/`).

Then run everything (play-tests-run) and check the report shows what it should. Old run folders stay readable: the
report treats a missing field as unknown.
