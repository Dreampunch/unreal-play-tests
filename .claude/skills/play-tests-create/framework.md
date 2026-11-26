# The framework

One C++ class does it all: a test actor (`APlayTest`, a subclass of Unreal's `AFunctionalTest`) with a `Case` name. Its
cases live in one table in its .cpp: each builds an arena around the test actor and lists steps. A test level holds one
test actor per case, each on its own floor. Unreal's automation runs them (`Automation RunTests <Level>`), in the editor
or headless.

Name things in the game's style; below, `APlayTest` and the `Game` module stand for whatever fits.

## Where it lives

`FunctionalTesting` is a Developer module: a game module that depends on it won't link for Shipping. Give the play tests
a module of their own, `<Game>PlayTests`, with `"Type": "DeveloperTool"` in the .uproject's `Modules` (built for the
editor and development builds, never for Shipping), depending on the game's module and on `FunctionalTesting`, `Json`,
`ImageWrapper`, `Slate` and `SlateCore`. Its classes: the test actor, the test game mode and HUD. (Putting them in the
game's own module works too, until the game is packaged for Shipping.) Enable the `PythonScriptPlugin` in the .uproject
for the level builder.

## The test actor

```cpp
UCLASS()
class GAME_API APlayTest : public AFunctionalTest
{
    GENERATED_BODY()
public:
    APlayTest();
    UPROPERTY(EditAnywhere, Category = "Test") FName Case;
    UFUNCTION(BlueprintCallable, Category = "Test") static TArray<FName> Cases();   // the level builder places one per case
    virtual void Tick(float DeltaSeconds) override;
protected:
    virtual void StartTest() override;
    virtual void CleanUp() override;
private:
    static const TArray<TPair<FName, TFunction<void(APlayTest&)>>>& Table();   // the cases
    struct FStep { FString Name; TFunction<bool()> Done; float Timeout = 30.f; bool bCheck = false; };
    TArray<FStep> Plan;                       // (not "Steps" or "RunTime": AFunctionalTest has members of those names)
    int32 StepIndex = 0;
    float StepTime = 0.f, GameTime = 0.f;
    struct FRan { FString Label; float Seconds = 0.f; };
    TArray<FRan> Ran;                         // each step done, and how long it took (the screen and the report)
    FString Doing;                            // the current step in words, set when an action starts ("Ann: walk to the door")
    TArray<TWeakObjectPtr<AActor>> Spawned;   // everything the arena made, destroyed in CleanUp
    void Finish(EFunctionalTestResult Outcome, const FString& Message);
    bool bFinishing = false; EFunctionalTestResult PendingResult; FString PendingMessage; float FinishHold = 0.f;
    // the arena, in the test actor's own frame (x ahead, floor at z 0)
    FVector At(const FVector& Local) const;   // GetActorTransform().TransformPosition(Local)
    AActor* Place(UClass* Class, const FVector& Local, float Yaw, TFunction<void(AActor*)> BeforeSpawn);
    // steps
    // fails the test with the problem Problem returns, unless empty; either way Measured (what it found: "26.2 m") goes
    // into the step's label, so a pass shows its number too
    void Check(const FString& What, TFunction<FString(FString& Measured)> Problem);
    // ... the game's own actions as steps (see writing-tests.md), and the screen (test-screen.md)
    // what the case proves, for the report: its feature, its one kind, and the bug it was written for, if any
    enum EKind : uint8 { None, Positive, Negative, Boundary };
    void Tag(const TCHAR* InFeature, EKind InKind, const TCHAR* InBug = TEXT("")) { Feature = InFeature; TestKind = InKind; Bug = InBug; }
    FString Feature, Bug;
    EKind TestKind = None;                    // (not "Kind": a game's own classes often have a Kind, and a clash won't compile)
};
```

**The case table**: a static array of `{ name, lambda }`. Each lambda builds the arena and adds steps:

```cpp
{ "door_stays_locked", [](T& t) {
    t.Tag(TEXT("Doors"), Negative);                        // what it proves (below)
    ACharacter* Hero = t.Hero(FVector::ZeroVector);
    ADoor* Door = t.Spawn<ADoor>(FVector(400, 0, 0)); Door->bLocked = true;
    t.Use(Hero, Door);                                     // an action step: starts it, waits until it's over
    t.Check("it stays shut", [Door] { return Door->IsOpen() ? FString(TEXT("it opened")) : FString(); });
} },
```

**Every case says what it proves**, on its first line: `t.Tag(feature, kind[, bug])`, reset to untagged in StartTest.
One kind per case, the one its name promises:

- **Positive**: it does what it should (walks there, opens, arrives on time).
- **Negative**: it refuses or stops when it should (locked, out of reach, nothing there, never past its end).
- **Boundary**: either side of a limit in the game's code, just inside and just outside (writing-tests.md).

A case that checks both sides is still one kind: the other side is a guard. "Only one robot gets the cabinet" is
negative, though the first one opening it is checked too. `bug` says where and when the bug the case was written for
showed ("L_Room: he walked to the door's edge and missed it (25 Nov)"). The report groups each category's cases by kind
and shows a table of features by kind, flagging any feature missing one: that table is how gaps get noticed.

**Steps**: each frame the current step's `Done()` runs; true moves on (recording its label and time into `Ran`). A step
over its `Timeout` fails the test, naming the step and what the actors were doing. An action step starts its action the
first time it runs (keep a `TSharedRef<bool> Given` in the lambda), sets `Doing`, then returns true once the action is
over and the actor has settled. A check step calls `Finish(Failed, ...)` with its problem and returns true; pass or
fail, its label gets what it measured ("check: stops within 45 m (26.2 m)"). A passing check that says nothing hides a
hollow pass: in a trial, a car's "front" was measured 2.2 m off and every check still passed until the numbers showed.

**Finishing**: `Finish` doesn't end the test at once: it holds the result on the screen 1.5 s (so the video shows it),
writes the result to the report, then calls `FinishTest`. Headless with no screen, it ends at once.

**StartTest**: reset the steps; set the world's speed (below); mark the test's floor for a nav rebuild (pitfalls.md:
never rely on nav data saved in the level); start the screen; find the case in the table and run it (no such case: an
error result).

**Speed**: `GetWorldSettings()->SetTimeDilation(...)` in StartTest (it exists in 5.8 and clamps; a level's Time
Dilation isn't saved: it's transient).
In the editor 4x by default from a console variable (`game.TestSpeed`), 1x when recording in the editor (see
test-screen.md); headless runs use a fixed time step instead (1x). Also set `GetWorldSettings()->MaxUndilatedFrameTime =
0.05f`: at 4x a hitch otherwise makes one huge step that physics or character movement can't take, and fails a test.

**CleanUp**: destroy everything in `Spawned` (controllers of pawns too), end the screen.

## The arena

Everything in the test's own frame, so a test works wherever its actor stands. `Place` spawns deferred, runs the
callback (set properties before BeginPlay), finishes spawning and adds the actor to `Spawned`. Helpers on top for the
game's things: `Block(Local, Size)` (a scaled cube, for walls and crates), the game's characters, doors, vehicles...
Moving things must not affect navigation (`SetCanEverAffectNavigation(false)`), or the nav mesh rebuilds round them all
the time.

## Results and the report

A run is a folder `Saved/TestRecordings/<yyyy-mm-dd_hh-mm-ss>/`. A new one starts with the first test of each editor
process (keep the folder in a static), so every launch of the runner, and each pass of `--repeat`, is a run of its own;
in an open editor, where the process lives on, also when the last test ended over a minute ago. When the first test of a run starts, copy `templates/report.html` (keep it in the project, e.g.
`Scripts/report.html`) into the folder. When each test finishes, append one line to the folder's `results.js`:

```js
LW.push({"case":"door_stays_locked","category":"Doors","result":"pass","message":"3 steps","feature":"Doors","kind":"negative","seconds":4.2,
  "mode":"recorded","speed":1,"ended":"2026-11-25 13:47:42","video":"door_stays_locked.mp4",
  "commit":"40710dd","branch":"main","version":"40710dd+4bd30533","uncommitted":6,
  "steps":[{"label":"Hero: use the door","state":"done","seconds":2.1},{"label":"check: it stays shut","state":"done","seconds":0.03}],
  "robots":[{"name":"Hero","memory":["..."]}]});
```

- `result` is `pass` or `fail`; `message` the failure (or "N steps"); `seconds` the game time up to the result, not
  counting any hold after it for the video (so a recorded run and a fast one give the same number).
- `mode`: `fast` (headless, nothing drawn: `-nullrhi`), `recorded` (headless, drawn offscreen and recorded) or `editor`
  (played in an open editor). Game times are only compared within one mode.
- `steps[].state` is `done`, `failed` or `not reached`; `seconds` for the done and failed ones.
- `video` only when the test was recorded (the page shows a still, `<case>.jpg`, made with the video).
- `robots` is optional: anything the actors can tell about themselves (an AI's last memories, a vehicle's state). The
  page shows each as a box of lines; rename the field in both places if "robots" doesn't fit the game.
- `feature`, `kind` (`positive`, `negative`, `boundary`, or empty when untagged) and `bug` (only when set): from `Tag`.
- `commit`, `branch`, `version` and `uncommitted`: the game's version the run tested (below), the same on every line of
  a run.
- `category`: from the case name's prefix (`train_` gives "Trains"), or a column in the table. The report gets a
  section and a summary row per category.

Write it with `FJsonObject` and `FJsonSerializer` (condensed), as `LW.push(<json>);\n`, appended
(`FILEWRITE_Append`). The page loads `results.js` with a `<script>` tag, which works from `file://`, so no server is needed. Log
the report's path (`UE_LOG`) so the runner can open it.

**The version tested**: when a run's folder is made, ask git (`FPlatformProcess::ExecProcess("git", "-C <project> ...")`)
for the commit (`rev-parse --short HEAD`), the branch (`rev-parse --abbrev-ref HEAD`) and the project's uncommitted files
(`status --porcelain --untracked-files=all -- .`; its paths are from the repo's top, `rev-parse --show-toplevel`). The
version is the commit, plus, when files are uncommitted, a code for them: a crc (`FCrc::StrCrc32`) of each changed file's
path, size and time stamp. Two runs of the same code then share a version, and any changed file makes a new one. Without
git, leave them empty: the report says "version unknown".

**Earlier results**: also write `previous.js` beside the report: `var LWPrev = {"<case>": [{"result":"pass","message":
"...","seconds":4.2,"mode":"fast","ended":"...","commit":"...","version":"...","run":"<folder>"}, ...], ...};`, each case's results in
every earlier run folder, oldest first, the last 30 (folders sorted by name are oldest first; read each `results.js`
line, strip `LW.push(` and `);`, parse it). A filtered run reruns only some cases, so a case's last result may be in any
folder. From it the page shows:

- **regressions** (passed in its last earlier result, fails now), fixed and new cases, each card marked, the failure
  table saying which version it last passed at: the bug is in the diff between the two;
- **flaky** cases: passed and failed on one version, so the result isn't the code's. Not counted as a regression.
  `run_tests --repeat 3` runs everything three times on the same code to find them; do it before trusting a regression;
- **a changed game time**: a pass that took 25% (and over a second) more or less than its last five passes in the same
  mode (a walk that wanders still passes);
- **a History section**: a row per case, a square per run for the last 14 (outlined where that version was flaky), and
  a line of its game time across them.

## The test level

`templates/build_test_level.py` builds it (copy it to `Scripts/` and set its names): delete everything, add light
(test-screen.md: lighting), then for each case in `APlayTest::Cases()` a floor (a scaled cube with the engine's grid
material, so movement shows on camera), a `NavMeshBoundsVolume` over it, and a test actor whose label is the case name
(that's its name in the automation list) and whose `Case` is set. Floors 30 x 30 m on a 40 m grid suit characters;
vehicles and trains get long floors (400 x 60 m, 100 m of it behind the start: a reversing car went 78 m back) in a
column of their own. It sets the level's game mode to the test game mode (test-screen.md).

It runs in a headless editor, not a commandlet (pitfalls.md), and quits it when done:
`UnrealEditor-Cmd <project> -ExecutePythonScript=<full path> -unattended -nosplash -nosound -NoP4 -RenderOffscreen`
(about 40 s; the run scripts' `--build-level` / `-BuildLevel`). Rerun it whenever a case is added or renamed.

## Running

- **Headless** (the default, and what CI would run): `templates/run_tests.sh` / `run_tests.ps1`: builds (with
  `-NoHotReloadFromIDE` and its own build log: pitfalls.md), runs
  `UnrealEditor-Cmd <project> -RenderOffscreen -unattended -UseFixedTimeStep -FPS=30 -ExecCmds="Automation RunTests
  <Level>" -TestExit="Automation Test Queue Empty"`, prints each result and opens the report. `--fast` uses `-nullrhi`
  instead: nothing drawn, no videos, much quicker. The editor must be closed (it holds the game's DLLs).
- **In the editor**: open the test level, then the console `Automation RunTests <Level>` (or Tools > Session Frontend >
  Automation). Its window must be in front or unthrottled (pitfalls.md).
