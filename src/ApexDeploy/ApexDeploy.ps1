﻿param (
    [string] [Parameter(Mandatory = $true)]$ConnectedServiceName,
    [string]$antBuildFile,
    [string]$options,
    [string]$targets,
    [string]$publishJUnitResults,   
    [string]$testResultsFiles, 
    [string]$javaHomeSelection,
    [string]$jdkVersion,
    [string]$jdkArchitecture,
    [string]$jdkUserInputPath
)

Write-Verbose 'Entering Ant.ps1'
Write-Verbose "antBuildFile = $antBuildFile"
Write-Verbose "options = $options"
Write-Verbose "targets = $targets"
Write-Verbose "publishJUnitResults = $publishJUnitResults"
Write-Verbose "testResultsFiles = $testResultsFiles"
Write-Verbose "javaHomeSelection = $javaHomeSelection"
Write-Verbose "jdkVersion = $jdkVersion"
Write-Verbose "jdkArchitecture = $jdkArchitecture"
Write-Verbose "jdkUserInputPath = $jdkUserInputPath"

#Verify Ant build file is specified
if(!$antBuildFile)
{
    throw "Ant build file is not specified"
}

# Import the Task.Common, Task.TestResults and Task.Internal dll that has all the cmdlets we need for Build
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"
import-module "Microsoft.TeamFoundation.DistributedTask.Task.TestResults"

# If JAVA_HOME is being set by choosing a JDK version find the path to that specified version else use the path given by the user
$jdkPath = $null
if($javaHomeSelection -eq 'JDKVersion')
{
    Write-Verbose "Using JDK version to find and set JAVA_HOME"
    # If the JDK version is not the default set the jdkPath to the new JDK version selected
    if($jdkVersion -and ($jdkVersion -ne "default"))
     {
        $jdkPath = Get-JavaDevelopmentKitPath -Version $jdkVersion -Arch $jdkArchitecture
        if (!$jdkPath) 
        {
            throw (Get-LocalizedString -Key 'Could not find JDK {0} {1}. Please make sure the selected JDK is installed properly.' -ArgumentList $jdkVersion, $jdkArchitecture)
        }
     }
}
else
{
    Write-Verbose "Using path from user input to set JAVA_HOME"
    if($jdkUserInputPath -and (Test-Path -LiteralPath $jdkUserInputPath))
    {
        $jdkPath = $jdkUserInputPath
    }
    else
    {
         throw (Get-LocalizedString -Key "The specified JDK path does not exist. Please provide a valid path.")
    }
}
 
# If jdkPath is set to something other than the default then update JAVA_HOME
if ($jdkPath)
{
    Write-Host "Setting JAVA_HOME to $jdkPath"
    $env:JAVA_HOME = $jdkPath
    Write-Verbose "JAVA_HOME set to $env:JAVA_HOME"
}

#Write-Verbose "Downloading ant-salesforce.jar ..."
# location on the Internet
# $source = "https://valtlbstorcusprod01.blob.core.windows.net/public/ant-salesforce.jar"
#$destination = "$PSScriptRoot\\ant-salesforce.jar"
 
#Invoke-WebRequest $source -OutFile $destination

#Write-Verbose "Download of ant-salesforce.jar complete."
#Write-Verbose $destination

$connectedServiceDetails = Get-ServiceEndpoint -Name "$ConnectedServiceName" -Context $distributedTaskContext 
$salesforceUrl = $connectedServiceDetails.Url
$username = $connectedServiceDetails.Authorization.Parameters.Username
$password = $connectedServiceDetails.Authorization.Parameters.Password

$optstring = "-Dsf.username=" + $username + " -Dsf.password=" + $password
$options = $options + $optstring

Write-Verbose "Running Ant..."
Invoke-Ant -AntBuildFile $antBuildFile -Options $options -Targets $targets

# Publish test results files
$publishJUnitResultsFromAntBuild = Convert-String $publishJUnitResults Boolean
if($publishJUnitResultsFromAntBuild)
{
   # check for JUnit test result files
    $matchingTestResultsFiles = Find-Files -SearchPattern $testResultsFiles
    if (!$matchingTestResultsFiles)
    {
        Write-Host "No JUnit test results files were found matching pattern '$testResultsFiles', so publishing JUnit test results is being skipped."
    }
    else
    {
        Write-Verbose "Calling Publish-TestResults"
        Publish-TestResults -TestRunner "JUnit" -TestResultsFiles $matchingTestResultsFiles -Context $distributedTaskContext
    }    
}
else
{
    Write-Verbose "Option to publish JUnit Test results produced by Ant build was not selected and is being skipped."
}

Write-Verbose "Leaving script Ant.ps1"




