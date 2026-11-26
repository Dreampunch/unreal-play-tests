# Builds the project, runs its play tests headless, prints each result and opens the run's report.
#   .\Scripts\run_tests.ps1                  every case, each recorded to video (rendered offscreen)
#   .\Scripts\run_tests.ps1 -Filter driving_brakes            the cases whose name starts with "driving_brakes"
#   .\Scripts\run_tests.ps1 -Filter driving_brakes,collisions several, comma-separated, in one run
#   .\Scripts\run_tests.ps1 -Fast            nothing drawn, no videos (much quicker)
#   .\Scripts\run_tests.ps1 -BuildLevel      rebuild the test level first (after adding or renaming a case)
#   .\Scripts\run_tests.ps1 -Repeat 3        the whole run three times on the same code, each its own run: the last
#                                            report marks any test that passed and failed on that version as flaky
# The project's own editor must be closed (it holds the game's DLLs). Needs ffmpeg on the PATH for the videos.
param(
    [string]$Filter = "",
    [switch]$Fast,
    [switch]$BuildLevel,
    [int]$Repeat = 1,
    [string]$Engine = "C:\Program Files\Epic Games\UE_5.8\Engine",   # the engine's Engine folder
    [string]$Target = "MyGameEditor",                                 # the editor target: <Module>Editor
    [string]$Level = "L_PlayTests"                                    # the test level's name
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force Saved\Logs | Out-Null   # (a fresh project has no Saved\Logs yet)
$Project = (Get-ChildItem *.uproject | Select-Object -First 1).FullName
$Editor = "$Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
$Render = if ($Fast) { "-nullrhi" } else { "-RenderOffscreen -ResX=640 -ResY=360" }
# Automation matches "<Level>.<filter>" as the start of a test's name; "+" joins several into one run
$Tests = if ($Filter) { ($Filter -split "," | ForEach-Object { "$Level.$($_.Trim())" }) -join "+" } else { $Level }
$Log = "PlayTests.log"

Write-Host "building..."
# -NoHotReloadFromIDE: without it the build refuses while ANY editor of this engine install has Live Coding on, even one
# open on another project. -Log: the build tool's own log here, not the per-user one every build shares (another build
# holding it fails this one: "IOException: The process cannot access the file").
& "$Engine\Build\BatchFiles\Build.bat" $Target Win64 Development "-Project=$Project" -WaitMutex -NoHotReloadFromIDE "-Log=$PWD\Saved\Logs\UnrealBuildTool.log" *> Saved\Logs\PlayTestsBuild.log
if ($LASTEXITCODE -ne 0) { Get-Content Saved\Logs\PlayTestsBuild.log -Tail 20; Write-Host "build failed (is this project's editor open?)"; exit 1 }

if ($BuildLevel) {
    Write-Host "building the test level..."
    Start-Process -FilePath $Editor -Wait -NoNewWindow -RedirectStandardOutput Saved\Logs\BuildLevelOut.txt -ArgumentList @("`"$Project`"",
        "-ExecutePythonScript=`"$PWD\Scripts\build_test_level.py`"", "-unattended", "-nosplash", "-nosound", "-NoP4", "-RenderOffscreen", "-log=BuildLevel.log")
    Select-String "PlayTests: (built|building)" Saved\Logs\BuildLevel.log | ForEach-Object { $_.Line -replace '^\[[^]]*\]\[[^]]*\]', '' }
}

for ($I = 1; $I -le $Repeat; $I++) {   # each pass a new editor, so a run folder of its own
    if ($Repeat -gt 1) { Write-Host "--- run $I of $Repeat" }
    Write-Host "running $Tests..."
    $Start = Get-Date
    $UeArgs = @("`"$Project`"", "-unattended") + $Render.Split(" ") + @("-nosplash", "-nosound", "-NoP4", "-UseFixedTimeStep", "-FPS=30",
        "-ExecCmds=`"Automation RunTests $Tests`"", "-TestExit=`"Automation Test Queue Empty`"", "-log=$Log")
    Start-Process -FilePath $Editor -ArgumentList $UeArgs -Wait -NoNewWindow -RedirectStandardOutput Saved\Logs\PlayTestsOut.txt

    $Lines = Get-Content "Saved\Logs\$Log"
    $Lines | Select-String "Test Completed|FinishTest TestResult=Failed" | ForEach-Object { ($_ -replace '^\[[^]]*\]\[[^]]*\]', '') -replace ' Path=\{[^}]*\}', '' }
    $Passed = ($Lines | Select-String 'Result=\{Success\}').Count
    $Failed = ($Lines | Select-String 'Result=\{Fail\}').Count
    Write-Host "passed: $Passed, failed: $Failed, $([int]((Get-Date) - $Start).TotalSeconds) s"
    if ($Passed + $Failed -eq 0) { Write-Host "nothing ran: no test matched `"$Tests`", or the level or editor failed (see Saved\Logs\$Log)" }
}

$Match = $Lines | Select-String "test report (.*report\.html)" | Select-Object -Last 1   # none when nothing ran
$Report = if ($Match) { $Match.Matches[0].Groups[1].Value } else { "" }
if ($Report) { Write-Host "report: $Report"; if (-not $env:NO_OPEN) { Start-Process $Report } }
# exit 1 when anything failed or nothing ran (the last pass), so a hook or CI can stop on it
if ($Failed -gt 0 -or $Passed -eq 0) { exit 1 }
exit 0
