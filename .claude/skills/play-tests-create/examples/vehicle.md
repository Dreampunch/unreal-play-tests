# Worked example: cars (Epic's Vehicle template)

Ten play tests a fresh Claude wrote with this skill for Epic's C++ Vehicle template (`TP_VehicleAdv`, UE 5.8), on its
own Blueprint cars, in about 40 minutes from `/play-tests` (now `/play-tests-create`) to a green report. All pass headless, recorded.

## How the cars are driven and measured

- **Through the game's own input functions** (`DoThrottle`, `DoBrake`, `DoSteering`, `DoResetVehicle`: what the Enhanced
  Input actions call), on the real Blueprint cars (`BP_SportsCar_Pawn`, `BP_OffroadCar_Pawn`), not by setting the
  movement component's state.
- **A Chaos vehicle needs a controller to take inputs** (`bRequiresControllerForInputs` is on by default): spawn the
  car's default controller (`SpawnDefaultController()`) before driving it.
- **Measured from the world, every frame**: speed from the change in position (not the component's speedometer), the
  heading unwrapped (so a 370 degree spin isn't 10), tilt from the actor's up vector, and the front of the car from every
  visible primitive component's box: the template's skeletal mesh box is 2.5 cm, as the bodywork is separate components.
- **"Settled"** is still for half a second (speed under a few cm/s), with a timeout.
- **Floors** 400 m x 60 m, 100 m behind the start (a reversing car went 78 m back), with the engine's grid material so
  speed shows on camera.
- **Limits from the game's design.** None existed here, so they were guesses and far looser than this arcade car
  (100 km/h in 3.6 s against a limit of 8). Agree them with the developer first.

## The cases

| Case | Arena and action | Checks (measured in the trial) |
| --- | --- | --- |
| `driving_settles_on_its_wheels` | dropped from 1 m, nothing done for 4 s | upright within 2 deg (0.4), creeps under 5 cm in the last 2 s |
| `driving_accelerates_to_100` | full throttle from rest | 100 km/h within 8 s (3.6), within 1 m of its line, heading within 2 deg, changed up a gear |
| `driving_brakes_from_100` | throttle to 100 km/h, then full brake | stops within 45 m (26.2), within 1 m of its line, heading within 5 deg |
| `driving_reverses_on_held_brake` | hold the brake 4 s (the template's auto reverse) | backs up at least 3 m (60.5), heading within 5 deg |
| `driving_turns_left` / `_right` | 40 km/h, then full lock 3 s | turns 60 deg or more (147), radius from its path 15 m or less (11.9) |
| `collisions_stops_at_a_wall` | full throttle into a wall 40 m ahead | at the hit (87 km/h) never more than 50 cm into the wall (27), at rest within 5 cm of its face (4), ends in front of it, upright |
| `recovery_flipped_car_rights_itself` | dropped on its roof | back on its wheels within 8 s (6.1: the game's 3 s flip check) |
| `recovery_respawns_when_destroyed` | the game's controller driving; the car destroyed | a new car within 1 s, at a PlayerStart (0.44 m), facing its way |
| `offroad_climbs_a_ramp` | the offroad car before a 15 deg ramp to a 2 m deck | on the deck within 10 s (2.7), never rolls past 30 deg |

## What the trial found

- **Test mistakes, fixed**: the wall hit was never seen (it waited for the skeletal mesh's front, which stops short of
  the bodywork); the respawn test assumed its PlayerStart was the only one, but the editor adds a `PlayerStartPIE` to a
  level without one (pitfalls.md).
- **A hollow pass, caught** only because passing checks print what they measured: the car's "front" was 2.2 m off.
- **Broken on purpose**: brakes at 30% still stopped in 26 m (grip, not brake force, limits it), so the brake test
  wasn't proving the brakes; brakes removed turned it red, as it should.
- **For the developer** (not failing tests): the car respawns at whichever PlayerStart the world lists first, not the
  player's own; holding the brake reverses at full power (80+ km/h in 5 s); the Time Trial controller uses its UI widget
  and finish line without checking them (a crash in any world without them).
