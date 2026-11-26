# Pitfalls

Each of these cost real time on Unreal Engine 5.8. Read them before building, and again when something fails strangely.

## Running tests

- **"Waiting for interactive frame rate"**: automation waits for the editor to hold 10 fps for 5 s before it starts. An
  editor window in the background is throttled to a few fps (Editor Preferences > Performance > Use Less CPU when in
  Background): bring it to the front or turn that off.
- **Errors logged by anything fail the running test.** Not only the test's own: an asset failing to save, a material
  complaining, another tool working in the same editor. When every check passed but the test failed, read the log lines
  between `BeginEvents` and `EndEvents` for that test.
- **A Fab pack's material can log an error the first time it draws** ("Material X expects texture Y to be Virtual"),
  failing whichever test draws it first: turn on the texture's `virtual_texture_streaming` (or fix the sampler).
- **Time Dilation is transient**: a level's World Settings value isn't saved; set it in code when the test starts. Cap
  `MaxUndilatedFrameTime` (0.05 s), or a hitch at 4x makes one huge step and character movement fails ("Max iterations").
- **Movement that integrates per frame changes with the frame rate**: a vehicle stepped a frame at a time arrived 6%
  early at 4x in the editor and on time headless. Integrate in fixed small steps (1/120 s) inside Tick.
- **The editor holds the game's DLLs**: build with the editor closed (`Build.bat`), or use Live Coding for function-body
  changes; header changes need a full build.
- **"Unable to build while Live Coding is active"**, with this project's editor closed: an editor of the same engine
  install on *another* project has Live Coding on, and the build tool refuses every build. Pass `-NoHotReloadFromIDE`
  to `Build.bat` (the run scripts do).
- **Another build at the same moment** fails this one ("IOException ... The process cannot access the file": the build
  tool's per-user log, `%LOCALAPPDATA%\UnrealBuildTool\Log.txt`, is shared by every build): pass
  `-Log=<project>\Saved\Logs\UnrealBuildTool.log`.
- **A fresh project has no `Saved/Logs`** until the editor has run once: create it before redirecting output into it.
- **`AFunctionalTest` already has `Steps` and `RunTime` members**: name the test's own something else.
- **A restored file can leave the broken build in place.** After breaking a feature on purpose, putting the file back
  from a copy that keeps its old time stamp (`cp -p`, `Copy-Item`, an old `git checkout`) makes it older than the object
  built from the broken version, and the build can skip it: every later run tests the broken game. Touch the file after
  restoring it (`touch`, or `(Get-Item f).LastWriteTime = Get-Date`).

## Navigation

- **Don't rely on nav data saved in the test level.** Mark each test's floor dirty when it starts
  (`UNavigationSystemV1::AddDirtyArea(floorBox, ENavigationDirtyFlag::All)`) and have actions wait until there is nav
  mesh under the test (`ProjectPointToNavigation`) and no build is in progress. A runtime (dynamic) nav mesh only builds
  where something changed; a level saved without its nav data left plain floors with none, and walks failed.
- **Cell size in 5.8**: `CellSize` under `[/Script/NavigationSystem.RecastNavMesh]` is deprecated and ignored. Set
  `NavMeshResolutionParams[0..2]=(CellSize=10,CellHeight=10,AgentMaxStepHeight=...)`; with the default 19 cm cells a 1 m
  doorway lost its nav mesh to the agent radius.
- **Doors**: a swinging panel shouldn't affect navigation; block the doorway with a box nav modifier (`NavArea_Null`,
  dynamic obstacle) while it's shut, and call `AddDirtyArea` over the doorway when it opens or shuts: moving a component
  doesn't rebuild the nav mesh by itself.

## The world a test plays in

- **The editor adds a `PlayerStartPIE`** to a level that has none when it plays it, so a test world always has a
  PlayerStart you didn't place. Anything that picks "the first PlayerStart" (a respawn) may pick it: in a trial a car
  respawned 800 m from the PlayerStart its test placed.
- **A skeletal mesh's bounds can be nothing like what you see**: the Vehicle template's car bodies are separate
  components, and its skeletal mesh's box is 2.5 cm. Measure an actor's size or front from every visible primitive
  component's own box.
- **Chaos vehicles ignore inputs without a controller** (`bRequiresControllerForInputs`, on by default): give a test car
  one (`SpawnDefaultController()`) before driving it.

## Drawing and recording

- **Text that never draws**: `FCanvasTextItem` with an `FSlateFontInfo` that has no font asset (`FCoreStyle`'s default
  style) is skipped silently (`HasValidText()` checks the font object). Use the engine's Roboto `UFont` asset.
- **Black shade in scene captures**: see test-screen.md, lighting. Captures without Lumen get no bounce; a real-time sky
  light gave almost nothing; sky light shadows blackened doorways.
- **Choppy editor recordings**: a test at 4x with frames grabbed on game time repeats pictures. Record headless, or at 1x.
- **A browser page of many videos**: most get suspended and show black. Show a still per test (made by ffmpeg) and load
  the video only when a test is opened.
- **Headless videos need `-RenderOffscreen`**: `-nullrhi` draws nothing.

## Building the test level

- **Python spawning in a commandlet** (`UnrealEditor-Cmd -run=pythonscript`): `spawn_actor_from_object` returns None,
  and saving a level there dropped its built nav mesh (the commandlet can't build navigation). Build the test level in a
  headless *editor* instead: `UnrealEditor-Cmd <project> -ExecutePythonScript=<full path> -unattended -nosplash
  -RenderOffscreen`, the script ending in `unreal.SystemLibrary.quit_editor()` (in a `finally`, or the editor hangs on
  an error). The project needs the `PythonScriptPlugin` enabled: it's off by default.
- **From Git Bash**, arguments starting with `/Game/...` are rewritten to `C:/Program Files/Git/Game/...`: set
  `MSYS_NO_PATHCONV=1`.
- **Merging a Fab pack's parts into one mesh** (`StaticMeshEditorSubsystem.merge_static_mesh_actors`): the pivot is
  `mesh_merging_settings.pivot_type = MeshMergePivotType.WORLD_ORIGIN` in 5.8, and the merge puts "SM_" before the name
  given. A pack's Overview map can hold engine meshes too (a sky sphere): keep only the pack's own.
