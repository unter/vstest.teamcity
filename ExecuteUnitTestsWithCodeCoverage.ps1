#rootDirectory is the base directory to search for Test Projects. (Most likely your solution directory)
#configName is a string name that the code coverage output files will be placed in
#filters is a list of dotCover filters to be added to the /Filters argument
#vsConfigName is the configuration folder to find the Test DLLs in
Param([string]$rootDirectory,[string]$configName,[string]$filters,[string]$vsConfigName)

$vstestconsolepath = "C:\Program Files (x86)\Microsoft Visual Studio 11.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
$dotcoverpath = "C:\BuildAgent\tools\dotCover\dotCover.exe"
$dotcovertargetexecutable = "/TargetExecutable=" + $vstestconsolepath
$dotcoveroutput = "/Output=" + $configName + "/coverage.dcvr"
$dotcoverfilters = "/Filters=" + $filters


# Get list of folders with Test DLLs in them matching pattern *Tests\bin
$testFolders = Get-ChildItem -Recurse -Force $rootDirectory | Where-Object { ($_.PSIsContainer -eq $true) -and (($_.FullName -like "*Tests\bin\" + $vsConfigName) -or ($_.FullName -like "*Tests\bin\x64\" + $vsConfigName)) } | Select-Object

foreach ($folder in $testFolders)
{
    #look for Fakes DLLs. If we find one we can't do code coverage on this test assembly
    $fakesDLLs = Get-ChildItem -Recurse -Force $folder.FullName -File | Where-Object { $_.Name -like "*Fakes.dll" } | Select-Object
    
    #grab the testing DLLs from the folder which match pattern *Tests.dll
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
    #build up command for vstest console to pass inside of dotCover command
    $targetarguments = "/TargetArguments=" + $arr + " /inIsolation /logger:TeamCityLogger /Platform:x64"
    
    #execute dotCover command with arguments
    & $dotcoverpath 'c' $dotcovertargetexecutable $targetarguments $dotcoveroutput $dotcoverfilters

    # pass message to teamcity to process code coverage
    "##teamcity[importData type='dotNetCoverage' tool='dotcover' path='" + $rootDirectory + "\" + $configName + "\coverage.dcvr']"
}