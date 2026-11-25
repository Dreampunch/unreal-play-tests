# Builds the project, runs its play tests headless, prints each result and opens the run's report.
#   .\Scripts\run_tests.ps1                  every case, each recorded to video (rendered offscreen)
#   .\Scripts\run_tests.ps1 -Filter door     the cases whose name contains "door"
#   .\Scripts\run_tests.ps1 -Fast            nothing drawn, no videos (much quicker)
# The editor must be closed (it holds the game's DLLs). Needs ffmpeg on the PATH for the videos.
param(
    [string]$Filter = "",
    [switch]$Fast,
    [string]$Engine = "C:\Program Files\Epic Games\UE_5.8\Engine",   # the engine's Engine folder
    [string]$Target = "MyGameEditor",                                 # the editor target: <Module>Editor
    [string]$Level = "L_PlayTests"                                    # the test level's name
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$Project = (Get-ChildItem *.uproject | Select-Object -First 1).FullName
$Render = if ($Fast) { "-nullrhi" } else { "-RenderOffscreen -ResX=640 -ResY=360" }
$Tests = if ($Filter) { "$Level.$Filter" } else { $Level }
$Log = "PlayTests.log"

Write-Host "building..."
& "$Engine\Build\BatchFiles\Build.bat" $Target Win64 Development "-Project=$Project" -WaitMutex *> Saved\Logs\PlayTestsBuild.log
if ($LASTEXITCODE -ne 0) { Get-Content Saved\Logs\PlayTestsBuild.log -Tail 20; Write-Host "build failed (is the editor open?)"; exit 1 }

Write-Host "running $Tests..."
$Start = Get-Date
$UeArgs = @("`"$Project`"", "-unattended") + $Render.Split(" ") + @("-nosplash", "-nosound", "-NoP4", "-UseFixedTimeStep", "-FPS=30",
    "-ExecCmds=`"Automation RunTests $Tests`"", "-TestExit=`"Automation Test Queue Empty`"", "-log=$Log")
Start-Process -FilePath "$Engine\Binaries\Win64\UnrealEditor-Cmd.exe" -ArgumentList $UeArgs -Wait -NoNewWindow -RedirectStandardOutput Saved\Logs\PlayTestsOut.txt

$Lines = Get-Content "Saved\Logs\$Log"
$Lines | Select-String "Test Completed|FinishTest TestResult=Failed" | ForEach-Object { ($_ -replace '^\[[^]]*\]\[[^]]*\]', '') -replace ' Path=\{[^}]*\}', '' }
$Passed = ($Lines | Select-String 'Result=\{Success\}').Count
$Failed = ($Lines | Select-String 'Result=\{Fail\}').Count
Write-Host "passed: $Passed, failed: $Failed, $([int]((Get-Date) - $Start).TotalSeconds) s"

$Report = ($Lines | Select-String "test report (.*report\.html)" | Select-Object -Last 1).Matches.Groups[1].Value
if ($Report) { Write-Host "report: $Report"; Start-Process $Report }
