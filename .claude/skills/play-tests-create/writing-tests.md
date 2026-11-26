# Writing play tests

A play test builds a small world, makes something happen through the game's own code, and checks the world afterwards.
It's slower than a unit test and finds what unit tests can't: a character that faces the wall after walking to a door, a
doorway too narrow for the nav mesh, a train car that drifts off its coupling on a curve.

## Rules that keep them honest

- **One behaviour per case, named for it**: `door_stays_locked`, `train_stops_at_a_set_end`. The name is what the report
  and the automation list show.
- **Drive the real code.** Give the order the game gives (the AI's task, the input action, the component's function), not
  a shortcut that sets the outcome. A test that teleports the character to the door tests nothing.
- **Measure from the world, independently.** Check where an actor is from its location (projected onto the track, the
  nav mesh, the arena), not from the variable the code under test wrote. A train's "distance" field can be right while
  the train is drawn somewhere else.
- **Numbers with tolerances, from the design**: "within 10 cm of its end", "on time within 5% of the trip its speeds
  give", "its body within 3 degrees of where it faces". A tolerance that has to be loosened is a finding: say why.
- **Wait for settled, not for time.** An action step is done when the action is over and things have stopped moving (the
  AI waiting for its next order, speeds at zero), with a timeout, not after a fixed number of seconds.
- **Watch during, check after.** Some things are only visible while they happen (a body snapping round, a car's gap
  opening on a curve): a step can measure every frame and keep the worst value; a check afterwards compares it to its
  limit.
- **Make the arena force the behaviour.** A test of walking through a doorway needs a wall across the whole floor, or
  the character walks round its end and the test passes for the wrong reason.
- **Failure messages say what happened**: "it's 1.42 m along the track, not 0.80 m", "he's 37 degrees off; he
  remembers: walked to D3 (4.1 m)". Include what the actor knows about itself.
- **Passing checks say what they measured too** ("stopped in 26.2 m"): a pass with a number that makes no sense (a car
  front 2.2 m off) is a hollow pass, and only the number shows it.
- **Every test fails when the feature breaks.** When a new test passes first time, check its video, and if in doubt
  break the feature on purpose once and watch the test go red. Then put the code back and make sure the next build
  recompiles it (pitfalls.md: a restored file can keep its old time stamp).
- **A negative case where "nothing happens" needs proof it could.** "Holds against full throttle" with the car not
  moving passes just the same if the throttle never reached it. Run a control beside it (the same car without the
  handbrake, which must move), or break the feature once to see it go red, and print what was applied (the engine's
  rpm).

## Shapes of cases

**An action, then checks**:

```cpp
{ "walk_through_open_door", [](T& t) {
    ACharacter* Hero = t.Hero(FVector::ZeroVector);
    t.WallWithDoorway(400.f);                  // across the whole floor: the doorway is the only way through
    t.Door(FVector(400, 0, 0), /*locked*/ false, /*open*/ true);
    t.WaitForNav();                            // the open doorway rebuilt into the nav mesh
    t.Check("the doorway has nav mesh", [&t] { return t.NavAt(FVector(400, 0, 0)); });
    t.Walk(Hero, FVector(900, 0, 0));          // the game's own walk order
    t.Check("ends past the wall", [&t, Hero] { return t.Local(Hero).X > 470.f ? FString() : FString::Printf(TEXT("he's at x %.0f"), t.Local(Hero).X); });
} },
```

**A run watched all the way**: a step that starts the run, measures every frame (worst gap, worst distance off the
track, top speed) and finishes when it's over; then checks of those worst values.

**Two-sided**: something must happen *and* something mustn't: "heard at 5 m, not heard at 20 m"; "won't couple a car 20 m
off, then couples it from 60 cm".

**State over time**: "the coach rolls to a stop and stays put": record where it stopped, wait 2 s, check it hasn't moved.

**Against a control**: the same thing done twice side by side, once with the feature and once without ("stops with
the handbrake, while the coasting car beside it is still doing 42 km/h"). Measure every actor a case compares from the
world every frame, not only the test's subject: a small tracker per actor (speed, heading, worst slip) does it.

## Vehicles

- Drive through the game's input functions (what its input actions call: throttle, brake, steering), on its real
  vehicle Blueprints, possessed by a controller (pitfalls.md: Chaos needs one).
- Measure from the world every frame: speed from position change, heading unwrapped, tilt from the up vector, the front
  from the visible components' boxes.
- "Settled" means still for half a second.
- Long floors with room behind (reversing), a grid material so speed shows on camera.
- Limits from the game's design, not real cars: an arcade car beats real-car numbers by miles, and a limit it can't
  miss proves nothing. Break the feature once (no brakes) to see the test go red.
- `examples/vehicle.md` is ten worked cases.

## Boundary pairs

Bugs gather at limits. Read the game's code for its numbers (a reach, a hearing range, an angle, a step height, a
coupling distance) and test each from both sides in one case, just inside and just outside, close enough that a small
change to the limit fails one side. Two actors side by side, far enough apart not to reach each other's things, do both
at once. From a game of robots:

| Case | The limit in the code | Inside | Outside |
|---|---|---|---|
| `pick_reach_edge` | a thing's Reach, 150 cm | picks it up at 1.4 m | 1.6 m: "nothing within reach" |
| `pick_angle_edge` | 45 degrees either side of straight ahead | 40 degrees | 50 degrees |
| `say_heard_edge` | heard within 15 m | 14.6 m | 15.6 m: not heard |
| `train_couple_edge` | `CoupleReach`, 30 cm off the coupled place | 25 cm: couples | 35 cm: refused |

A boundary pair checks itself: if the limit moves, one side goes red, so it can't pass hollow the way a one-sided case
can. Name the limit and where it lives in a comment on the case, so whoever changes it finds the test.

**Limits with no two sides.** Not every limit can be stood either side of:
- **an on/off input** (a handbrake, a toggle): no threshold to straddle. Test on and off instead.
- **a margin no input can cross** (6000 Nm of handbrake against at most 4000 Nm the engine can put through a wheel):
  a negative case at the strongest input there is ("holds against full throttle").
- **a limit that comes out of the physics** (the steepest slope a parked car holds on, set by tyre grip, not by any
  number in the code): ask the developer for the design number ("parks on a 20% hill") and test that as a pair.

Say which it is when you propose the feature's cases, so "no boundary case" is a reason, not a gap.

## Every bug gets a case

When a bug is found (by a test, in play, by the user), write the case that shows it before fixing it, watch it fail, fix
the game, watch it pass. Tag it with where and when the bug showed (framework.md: `Tag`'s third argument). That's how
the suite grows from real failures rather than guesses, and the report's regression count keeps watch over it after.

## What to cover first

For each system the user cares about, all three kinds (framework.md):

- **positive**: the main thing working (walks there, opens, arrives on time);
- **negative**: the thing refusing when it should (locked, out of reach, nothing there, glass in the way, never past
  its end);
- **boundary**: each limit the code has, from both sides (above).

Then the awkward geometry (doorways, stairs, curves, glass), timing (on time, never over its speed), and anything that
has broken before. A system with no negative or no boundary case is a gap: say so in the plan, with why.
