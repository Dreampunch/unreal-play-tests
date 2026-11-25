---
name: play-tests
description: Set up automated play tests for an Unreal Engine C++ game - tests that build a small arena, play the game's own systems (characters, vehicles, doors, pickups, AI orders), check the world afterwards, record every test to video from five cameras and write an HTML report. Use when the user runs /play-tests, asks for tests, unit tests, functional tests, regression tests or a test report for their Unreal game, or wants a new feature covered by tests.
---

# Play tests for an Unreal game

You are adding play tests to the user's Unreal Engine C++ project: Unreal Functional Tests (`AFunctionalTest`) that each
build their own small arena, drive the game's real code the way the game does, and check the world afterwards. Every
test shows a five-camera test screen while it runs, records it to video, and adds its result to an HTML report.

Nobody wants to write tests by hand. That's the point of this skill: you read the game, propose what to test, and write
it; the user decides what matters and looks at the report.

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

## Steps

1. **Read the project.** The `.uproject` (engine version, modules, plugins), `Source/` (the game's actors, components,
   AI, input, the systems a player or an AI uses), `Config/` (navigation, rendering), and any design notes. List the
   game's abilities and systems in plain words: "a character walks to a point", "a door opens and stays locked without
   its key", "a train stops at a signal".

2. **Propose a test plan and agree it with the user before writing code.** Group cases into categories (one per system:
   Characters, Doors, Vehicles...). For each case: one line on the arena, what is done, and what is checked, with
   numbers ("stops within 10 cm of its end", "arrives within 5% of the time its speeds give"). Start with 5-15 cases that
   cover what the user cares about most; say what you left out. Ask which matter most and whether anything is missing.

3. **Build the framework** if the project doesn't have it yet (`framework.md`, then `test-screen.md`): a test actor
   class, its test screen, the test level with one test actor per case, the report template and the run scripts. Use the
   game's naming style. Put it where a Shipping build won't link it (`FunctionalTesting` is a Developer module: see
   framework.md, "Where it lives"). Enable the Python Editor Script Plugin (`PythonScriptPlugin`, off by default) for
   the level builder. The project's own editor needn't be open: everything here runs headless.

4. **Write the cases** (`writing-tests.md`). Drive the game's real code (its components, AI orders, input actions), not
   shortcuts that set the outcome. Check from the world afterwards, measured independently of the code under test.

5. **Build and run them headless** with the run script (`--build-level` / `-BuildLevel` the first time and whenever a
   case is added or renamed; this project's editor must be closed for a build). Read every failure:
   - a real bug in the game: tell the user what the test found, with the video; fix it only if they want you to;
   - a mistake in the test (wrong arena, too tight a number, a step that never finishes): fix the test and say so;
   - an Unreal trap (`pitfalls.md`): fix it and note it.
   Never loosen a check just to make it pass without telling the user why the old number was wrong.

6. **Open the report** (the run's `report.html`) and look at the videos of anything surprising: a passing test can
   still look wrong (a character sliding, a car hovering beside its rails). Read what each passing check measured (it's
   in the step's label): a number far from anything plausible is a hollow pass. For the tests that matter most, break
   the feature on purpose once and watch the test go red, then put the code back exactly.

7. **Hand over:** what's covered, what each category found, the one command to rerun everything, how to add a case.

## When a feature is added later

Add its cases to the table (`framework.md`), place their test actors in the test level, run everything, and tell the
user if anything that used to pass now fails: that's a regression, the reason these tests exist.
