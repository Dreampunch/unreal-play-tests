# The test screen and its recording

While a test plays, the window shows its own screen, not the game's UI: five cameras of the test's own and a panel with
its name, state, steps and time. The same screen is recorded to video.

## Layout

A 1920 x 1080 render target, a 3 x 3 grid of 640 x 360 cells, each view inset 2 px (dark lines between):

```
+---------------------------+-----------+
|                           |  PANEL    |
|          WIDE             +-----------+
|                           |   TOP     |
+--------+---------+--------+-----------+
| FRONT  |  BACK   |       SIDE         |
+--------+---------+--------------------+
```

(the side view takes the bottom-right cell; the wide view the top-left four). Nothing is drawn over the pictures but a
small camera name in each corner, on a dark box.

## The cameras

Five `USceneCaptureComponent2D` on the test actor (made in its constructor, `bCaptureEveryFrame` and
`bCaptureOnMovement` off, `CaptureSource = SCS_FinalColorLDR`, `bAlwaysPersistRenderingState = true` so exposure carries
from frame to frame). Each frame: place them, `CaptureScene()` each, compose.

- **Wide**: over the arena, fixed (for a moving subject on a long track: riding alongside it).
- **Top, front, back, side**: on the test's subject (the first character, else the first vehicle), in the arena's fixed
  directions (so a turn shows against them), pulled in towards it when a wall is in the way (a trace from the subject
  to where the camera wants to be). Hide anything overhead (a roof: bottom above ~2.2 m) from the wide and top views.

**No Lumen in the cameras**: five Lumen views a frame are most of the frame time. On each capture's post process set
`DynamicGlobalIlluminationMethod = None` and `ReflectionMethod = None` (with their `bOverride_` flags). Light the test
level for that (below).

## The panel

Dark background; a bar across its top in the state's colour; the case name as large as fits (shrink the font until it
does); a solid block with RUNNING (amber) / PASS (green) / FAIL (red); beside it two boxed facts with drawn icons ("step 2
of 5", "3.4 s"); then the steps, one per line: number, label (the current one bright and marked with a bar), seconds on
the right. At the end the panel turns dark green or dark red; a failure shows the failed step and its message, wrapped.

**Text**: Roboto, the engine's font asset, at its real size: `FSlateFontInfo(LoadObject<UFont>(nullptr,
TEXT("/Engine/EngineFonts/Roboto.Roboto")), Size, TEXT("Bold"))`, drawn with `FCanvasTextItem`. Measure text with
`FSlateApplication::Get().GetRenderer()->GetFontMeasureService()->Measure(Text, Font)`. Not `FCoreStyle`'s default font
(pitfalls.md: it draws nothing), not `GEngine`'s bitmap fonts scaled up (blurred).

**Composing**: `UKismetRenderingLibrary::BeginDrawCanvasToRenderTarget` on the screen target, `K2_DrawTexture` each
camera's target into its cell, boxes as `FCanvasTileItem` (translucent), text, `EndDrawCanvasToRenderTarget`. Colours
written as sRGB `FColor` and converted to `FLinearColor`.

**Showing it**: a test game mode (the test level's override) with a HUD that, while a test runs, sets the viewport's
`bDisableWorldRendering` (the game view isn't needed) and draws the screen texture as large as fits on black. Its default
pawn a `ASpectatorPawn`, hidden. No game UI in the test level.

## Recording

- **Frames**: `ReadPixels` on the screen target, then JPEG-encode (`IImageWrapper`) and write on a thread pool
  (`Async(EAsyncExecution::ThreadPool, ...)`), into `<run>/<case>_frames/00000.jpg...`. Wait for all writes before
  encoding the video.
- **Frame rate and pace**: frames are taken on game time, so a video plays at the game's own pace. Headless with a fixed
  time step (`-UseFixedTimeStep -FPS=30`): every frame, 30 fps, smooth. In the editor, recording is off by default
  (`game.TestRecord 0`): `ReadPixels` stalls the GPU, and at 4x speed each editor frame covers four game frames, so a
  recording repeats each picture and plays choppy. With `game.TestRecord 1` the test plays at 1x and records at 30 fps.
  A long frame repeats the last picture so time stays right.
- **Video**: when the test ends, run ffmpeg in the background (`FPlatformProcess::CreateProc`, e.g. `cmd /c` on Windows):
  `ffmpeg -y -framerate 30 -i <dir>/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart <run>/<case>.mp4`,
  then a still for the report's card (`ffmpeg -sseof -2 -i <case>.mp4 -frames:v 1 -vf crop=1276:716:2:2,scale=640:-2
  <case>.jpg`: the wide view near the end), then delete the frames. ffmpeg must be on the PATH.
- **Headless with pictures**: run with `-RenderOffscreen` (not `-nullrhi`) so the captures render without a window.

## Lighting the test level for the cameras

With no Lumen in the captures nothing bounces, and a sky light captured from the sky in real time gave almost nothing
(the game view behind the test screen isn't drawn): shadowed faces came out black. What works:

- a movable directional light (the sun, ~10 lux);
- a sky light from a fixed cubemap (`SLS_SPECIFIED_CUBEMAP`, `/Engine/EngineResources/GrayLightTextureCube`, real-time
  capture off, intensity ~2.5, **cast shadows off**: with shadows, walls round a doorway hid the sky and faces went black);
- a soft fill: a second directional light opposite the sun, no shadows, ~2.5 lux, `atmosphere_sun_light` off;
- a sky atmosphere for the background, and an unbound post process volume with a fixed exposure bias (a big pale floor
  in sun burns out otherwise).
