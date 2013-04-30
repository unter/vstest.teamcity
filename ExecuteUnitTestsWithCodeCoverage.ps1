Param([string]$rootDirectory,[string]$configName,[string]$filters,[string]$vsConfigName)

$vstestconsolepath = "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
$dotcoverpath = "C:\BuildAgent\tools\dotCover\dotCover.exe"
$dotcovertargetexecutable = "/TargetExecutable=" + $vstestconsolepath
$dotcoveroutput = "/Output=" + $configName + "/coverage.dcvr"
$dotcoverfilters = "/Filters=" + $filters

$testFolders = Get-ChildItem -Recurse -Force $rootDirectory | Where-Object { ($_.PSIsContainer -eq $true) -and (($_.FullName -like "*Tests\bin\" + $vsConfigName) -or ($_.FullName -like "*Tests\bin\x64\" + $vsConfigName)) } | Select-Object
foreach ($folder in $testFolders)
{
    #look for Fakes DLLs. If we find one we can't do code coverage on this test assembly
    $fakesDLLs = Get-ChildItem -Recurse -Force $folder.FullName -File | Where-Object { $_.Name -like "*Fakes.dll" } | Select-Object
    
    #grab the testing DLLs
    $testDlls = Get-ChildItem -Force $folder.FullName -File | Where-Object { $_.Name -like "*Tests.dll" } | Select-Object

    foreach ($dll in $testDlls)
    {
        if ($fakesDLLs.length -eq 0)
        {
            $arr += @($dll.FullName)
        }
        else
        {
            $fakesArr += @($dll.FullName)
        }
    }
}

#execute test DLLs with fakes
if ($fakesArr.length -gt 0)
{
    & $vstestconsolepath $fakesArr '/inIsolation' '/logger:TeamCityLogger' '/Platform:x64'
}

# execute test DLLs without fakes with dotCover
if ($arr.length -gt 0)
{
    $targetarguments = "/TargetArguments=" + $arr + " /inIsolation /logger:TeamCityLogger /Platform:x64"
    
    & $dotcoverpath 'c' $dotcovertargetexecutable $targetarguments $dotcoveroutput $dotcoverfilters
    "##teamcity[importData type='dotNetCoverage' tool='dotcover' path='" + $rootDirectory + "\" + $configName + "\coverage.dcvr']"
}