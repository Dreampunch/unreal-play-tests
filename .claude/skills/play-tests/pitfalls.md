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
  and saving a level there dropped its built nav mesh (the commandlet can't build navigation). Build the test level in
  the editor.
- **From Git Bash**, arguments starting with `/Game/...` are rewritten to `C:/Program Files/Git/Game/...`: set
  `MSYS_NO_PATHCONV=1`.
- **Merging a Fab pack's parts into one mesh** (`StaticMeshEditorSubsystem.merge_static_mesh_actors`): the pivot is
  `mesh_merging_settings.pivot_type = MeshMergePivotType.WORLD_ORIGIN` in 5.8, and the merge puts "SM_" before the name
  given. A pack's Overview map can hold engine meshes too (a sky sphere): keep only the pack's own.
