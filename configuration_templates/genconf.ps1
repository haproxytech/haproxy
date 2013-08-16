# genconf.ps1

# HAProxy configurator script for Windows Powershell
# Copyright Exceliance
# v 1.1 - August 6th, 2013

# Check if there is only one argument, otherwise exit and print usage
if($args.Count -ne 1) {
    Write-Host -ForegroundColor Yellow ("Usage: "+$MyInvocation.InvocationName+" <template name>")
    Exit
}

# Get file content into string array or exit if error (for example file does not exists)
$fileContent = Get-Content $args.GetValue(0)
if($fileContent -eq $null)
{
    Exit
}

# Prepare list of variables and show user basic info
$variables = @()
Write-Host "Please prepare the following information before carying on"

# Search for variables inside fileContent and show them, converts fileContent array to string
ForEach ($fileLine in $fileContent)
{
    If ($insideRequiredLines -eq 1)
    {
        If ($fileLine.ToLower().IndexOf("end of required information") -ne -1)
        {
            # Found end of required variables
            $insideRequiredLines = 0
            Continue
        }
        Else
        {
            # Remove junk from string and add it to array and show it
            $variables += ($fileLine.Substring(1,$fileLine.Length-3)).TrimStart().TrimEnd()
            Write-Host -ForegroundColor Yellow $variables[$variables.Length-1]
        }
    }
    Else
    {
        # Add currentLine to output string
        If($fileLine.ToLower().IndexOf("required information") -eq -1)
        {
            $outputString += $fileLine+"`r`n"
        }
    }
    
    # Found start of required variables
    if($fileLine.ToLower().IndexOf("required information") -ne -1)
    {
        $insideRequiredLines = 1
    }
}

# If user is ready we can continue
If((Read-Host "Confirm you are ready by typing 'y'").ToLower() -ne "y")
{
    Write-Host "See you later..."
    Exit
}

# Ask user for all variable values and put it into outputString
ForEach ($currentVariable in $variables)
{
    $outputString = $outputString.Replace($currentVariable, (Read-Host ("Value for "+$currentVariable)))
}

# Write outputString to file with .conf extension
$outputFileName=$args.GetValue(0).ToString().Replace(".tpl", "")+".conf"
$outputString | Out-File ($outputFileName)
Write-Host -ForegroundColor Green ("Configuration file is ready: "+$outputFileName)
