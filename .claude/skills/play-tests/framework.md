# The framework

One C++ class does it all: a test actor (`APlayTest`, a subclass of Unreal's `AFunctionalTest`) with a `Case` name. Its
cases live in one table in its .cpp: each builds an arena around the test actor and lists steps. A test level holds one
test actor per case, each on its own floor. Unreal's automation runs them (`Automation RunTests <Level>`), in the editor
or headless.

Name things in the game's style; below, `APlayTest` and the `Game` module stand for whatever fits.

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
    TArray<FStep> Steps;
    int32 StepIndex = 0;
    float StepTime = 0.f, RunTime = 0.f;
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
    void Check(const FString& What, TFunction<FString()> Problem);   // fails the test with what Problem returns, unless empty
    // ... the game's own actions as steps (see writing-tests.md), and the screen (test-screen.md)
};
```

**The case table**: a static array of `{ name, lambda }`. Each lambda builds the arena and adds steps:

```cpp
{ "door_stays_locked", [](T& t) {
    ACharacter* Hero = t.Hero(FVector::ZeroVector);
    ADoor* Door = t.Spawn<ADoor>(FVector(400, 0, 0)); Door->bLocked = true;
    t.Use(Hero, Door);                                     // an action step: starts it, waits until it's over
    t.Check("it stays shut", [Door] { return Door->IsOpen() ? FString(TEXT("it opened")) : FString(); });
} },
```

**Steps**: each frame the current step's `Done()` runs; true moves on (recording its label and time into `Ran`). A step
over its `Timeout` fails the test, naming the step and what the actors were doing. An action step starts its action the
first time it runs (keep a `TSharedRef<bool> Given` in the lambda), sets `Doing`, then returns true once the action is
over and the actor has settled. A check step calls `Finish(Failed, ...)` with its problem and returns true.

**Finishing**: `Finish` doesn't end the test at once: it holds the result on the screen 1.5 s (so the video shows it),
writes the result to the report, then calls `FinishTest`. Headless with no screen, it ends at once.

**StartTest**: reset the steps; set the world's speed (below); mark the test's floor for a nav rebuild (pitfalls.md:
never rely on nav data saved in the level); start the screen; find the case in the table and run it (no such case: an
error result).

**Speed**: `GetWorldSettings()->SetTimeDilation(...)` in StartTest (a level's Time Dilation isn't saved: it's transient).
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

A run is a folder `Saved/TestRecordings/<yyyy-mm-dd_hh-mm-ss>/`; a new one starts when the last test ended over a minute
ago. When the first test of a run starts, copy `templates/report.html` (keep it in the project, e.g.
`Scripts/report.html`) into the folder. When each test finishes, append one line to the folder's `results.js`:

```js
LW.push({"case":"door_stays_locked","category":"Doors","result":"pass","message":"3 steps","seconds":4.2,
  "mode":"headless","speed":1,"ended":"2026-11-25 13:47:42","video":"door_stays_locked.mp4",
  "steps":[{"label":"Hero: use the door","state":"done","seconds":2.1},{"label":"check: it stays shut","state":"done","seconds":0.03}],
  "robots":[{"name":"Hero","memory":["..."]}]});
```

- `result` is `pass` or `fail`; `message` the failure (or "N steps"); `seconds` the game time.
- `steps[].state` is `done`, `failed` or `not reached`; `seconds` for the done and failed ones.
- `video` only when the test was recorded (the page shows a still, `<case>.jpg`, made with the video).
- `robots` is optional: anything the actors can tell about themselves (an AI's last memories, a vehicle's state). The
  page shows each as a box of lines; rename the field in both places if "robots" doesn't fit the game.
- `category`: from the case name's prefix (`train_` gives "Trains"), or a column in the table. The report gets a
  section and a summary row per category.

Write it with `FJsonObject` and `FJsonSerializer` (condensed), as `LW.push(<json>);\n`, appended
(`FILEWRITE_Append`). The page loads `results.js` with a `<script>` tag, which works from `file://`, so no server is needed. Log
the report's path (`UE_LOG`) so the runner can open it.

## The test level

A Python script (run in the editor) builds it: delete everything, add light (test-screen.md: lighting), then for each
case in `APlayTest::Cases()` a floor (a scaled cube with a plain grey material), a `NavMeshBoundsVolume` over it, and a
test actor whose label is the case name (that's its name in the automation list) and whose `Case` is set. Floors 30 x 30 m
on a 40 m grid suit characters; give long things (vehicles, trains) their own longer floors in a separate area. Set the
level's game mode to the test game mode (test-screen.md). Rerun it whenever a case is added or renamed; it needs the
editor (pitfalls.md: commandlet saves).

## Running

- **Headless** (the default, and what CI would run): `templates/run_tests.sh` / `run_tests.ps1`: builds, runs
  `UnrealEditor-Cmd <project> -RenderOffscreen -unattended -UseFixedTimeStep -FPS=30 -ExecCmds="Automation RunTests
  <Level>" -TestExit="Automation Test Queue Empty"`, prints each result and opens the report. `--fast` uses `-nullrhi`
  instead: nothing drawn, no videos, much quicker. The editor must be closed (it holds the game's DLLs).
- **In the editor**: open the test level, then the console `Automation RunTests <Level>` (or Tools > Session Frontend >
  Automation). Its window must be in front or unthrottled (pitfalls.md).
