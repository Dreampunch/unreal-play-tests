"""Builds the play-test level: light for the test cameras, then for each case of the test class a floor, a nav volume
over it and a test actor at its start (its label is the case name: its name in the automation list).

Rerun it whenever a case is added or renamed. It runs in a headless editor (not a commandlet: spawning returns None
there), and quits it when done:

    UnrealEditor-Cmd <project>.uproject -ExecutePythonScript="<full path>/Scripts/build_test_level.py"
        -unattended -nosplash -nosound -NoP4 -RenderOffscreen

(`run_tests.sh --build-level` / `run_tests.ps1 -BuildLevel` do it.) The project needs the Python Editor Script Plugin
(`PythonScriptPlugin`) enabled in its .uproject: it's off by default.
"""
import unreal

# --- set these for the project ---
LEVEL = "/Game/PlayTests/L_PlayTests"
TEST_CLASS = "MyGamePlayTest"          # the test actor's class as Python sees it (C++ AMyGamePlayTest)
GAME_MODE = "MyGamePlayTestGameMode"   # the test game mode (test-screen.md), or None
FLOOR = (3000.0, 3000.0)               # cm: a test's floor, 5 m behind the test actor and the rest ahead (characters)
LONG_FLOOR = (40000.0, 6000.0)         # cm: for vehicles and other long runs: 100 m behind the start, 300 m ahead
LONG_PREFIXES = ("driving_", "train_", "vehicle_")   # cases that get a long floor, by name
LONG_BEHIND = 10000.0                  # cm of a long floor behind its test actor (room to reverse, room for cars behind)
SPACING = 4000.0                       # cm between floors (long floors: their width plus this)
GRID = "/Engine/EngineMaterials/WorldGridMaterial"   # a grid floor, so speed and turns show on camera
# ---

actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def spawn(cls, loc=(0, 0, 0), rot=(0, 0, 0), label=None):
    """rot: (pitch, yaw, roll)."""
    a = actors.spawn_actor_from_class(cls, unreal.Vector(*loc), unreal.Rotator(roll=rot[2], pitch=rot[0], yaw=rot[1]))
    if a is None:
        raise RuntimeError(f"couldn't spawn {cls}")
    if label:
        a.set_actor_label(label)
    return a


def light():
    """For scene captures without Lumen (test-screen.md): a sun, a shadowless fill, an even sky light, a sky."""
    sun = spawn(unreal.DirectionalLight, (0, 0, 2000), (-50, 30, 0), "Sun")
    c = sun.light_component
    c.set_mobility(unreal.ComponentMobility.MOVABLE)
    c.set_intensity(10.0)
    c.set_editor_property("atmosphere_sun_light", True)
    fill = spawn(unreal.DirectionalLight, (0, 0, 2000), (-35, 210, 0), "Fill")
    c = fill.light_component
    c.set_mobility(unreal.ComponentMobility.MOVABLE)
    c.set_intensity(2.5)
    c.set_cast_shadows(False)
    c.set_editor_property("atmosphere_sun_light", False)
    sky = spawn(unreal.SkyLight, (0, 0, 1000), label="Sky")
    c = sky.light_component
    c.set_mobility(unreal.ComponentMobility.MOVABLE)
    c.set_editor_property("source_type", unreal.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
    c.set_editor_property("cubemap", unreal.load_asset("/Engine/EngineResources/GrayLightTextureCube"))
    c.set_editor_property("real_time_capture", False)
    c.set_intensity(2.5)
    c.set_cast_shadows(False)
    spawn(unreal.SkyAtmosphere, label="Atmosphere")
    pp = spawn(unreal.PostProcessVolume, label="Exposure")
    pp.set_editor_property("unbound", True)
    s = pp.get_editor_property("settings")
    s.set_editor_property("override_auto_exposure_bias", True)
    s.set_editor_property("auto_exposure_bias", -1.0)
    pp.set_editor_property("settings", s)


def build():
    if unreal.EditorAssetLibrary.does_asset_exist(LEVEL):
        levels.load_level(LEVEL)
        for a in actors.get_all_level_actors():
            if not isinstance(a, unreal.WorldSettings):
                actors.destroy_actor(a)
    elif not levels.new_level(LEVEL, False):
        raise RuntimeError("couldn't make " + LEVEL)
    light()

    cube = unreal.load_asset("/Engine/BasicShapes/Cube")
    grid = unreal.load_asset(GRID)
    test_class = getattr(unreal, TEST_CLASS)
    cases = [str(c) for c in test_class.cases()]
    short = [c for c in cases if not c.startswith(LONG_PREFIXES)]
    long_ = [c for c in cases if c.startswith(LONG_PREFIXES)]
    places = [(c, ((i % 6) * SPACING, (i // 6) * SPACING), FLOOR, 500.0) for i, c in enumerate(short)]
    top = ((len(short) + 5) // 6) * SPACING + LONG_FLOOR[1]   # the long floors in a column of their own, past the grid
    places += [(c, (0.0, top + i * (LONG_FLOOR[1] + SPACING)), LONG_FLOOR, LONG_BEHIND) for i, c in enumerate(long_)]
    for case, (x, y), size, behind in places:
        mid = (x + size[0] / 2 - behind, y)
        floor = spawn(unreal.StaticMeshActor, (mid[0], mid[1], -50.0), label=f"Floor_{case}")
        floor.static_mesh_component.set_static_mesh(cube)
        floor.static_mesh_component.set_material(0, grid)
        floor.set_actor_scale3d(unreal.Vector(size[0] / 100.0, size[1] / 100.0, 1.0))
        nav = spawn(unreal.NavMeshBoundsVolume, (mid[0], mid[1], 200.0), label=f"Nav_{case}")
        nav.set_actor_scale3d(unreal.Vector(size[0] / 200.0, size[1] / 200.0, 3.0))
        test = spawn(test_class, (x, y, 0), label=case)
        test.set_editor_property("case", case)

    if GAME_MODE:
        ws = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world().get_world_settings()
        ws.set_editor_property("default_game_mode", getattr(unreal, GAME_MODE))
    if not levels.save_current_level():
        raise RuntimeError("couldn't save " + LEVEL)
    unreal.log(f"PlayTests: built {LEVEL} with {len(cases)} cases: {', '.join(cases)}")


try:
    build()
except Exception as e:
    unreal.log_error(f"PlayTests: building the level failed: {e}")
finally:
    unreal.SystemLibrary.quit_editor()
