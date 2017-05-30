function Initialize
{
    [CmdletBinding()]
    Param()

    Write-Verbose "AutomateCloning script has started its setup procedure..."
    Push-Location -StackName "PriorLocation"

    Write-Verbose ("Setting CLI location to "+$Settings.HostLocation)
    Switch-ProjectLocation -Location $Settings.HostLocation

    Write-Verbose "Setting Git author to Alice"
    $Author = $User.Alice

    Write-Verbose ("Cloning "+$Settings.ProjectName+" repository into the subfolder for Alice")
    Switch-ProjectLocation -Location $Settings.ProjectDirectory -Clean
    Invoke-GitCommand -Command $GitCommand.Clone
    Switch-ProjectLocation -Location $Settings.ASubDirectory

    Write-Verbose "Changing config to reflect that this repository is for Alice"
    Invoke-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserName
    Invoke-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserEmail

    Write-Verbose ("Alice checkouts a new branch with the name: "+$GitProperty.BranchName)
    Invoke-GitCommand -Command $GitCommand.Checkout -GitParam $GitProperty.NewBranchFlag -Value $GitProperty.BranchName
    
    Write-Verbose "Alice creates and edits X.txt file"
    Edit-File -FileName $File.X -Content $Content.ForAlexInXFile
    
    Write-Verbose "Alice creates and edits Y.txt file"
    Edit-File -FileName $File.Y -Content $Content.ForAlexInYFile

    Write-Verbose "Alice commits all files and pushes to remote repo"
    Invoke-GitCommand -Command $GitCommand.Add -Value X.txt, Y.txt
    Invoke-GitCommand -Command $GitCommand.Commit -GitParam '-m {0}' -Value 'Alice is committing files X and Y'
    Invoke-GitCommand -Command $GitCommand.Push -GitParam $GitProperty.SetUpstreamOriginBranch -Value $GitProperty.BranchName
    
    Write-Verbose ("Cloning "+$Settings.ProjectDirectory+" repository into the subfolder for Bob")
    $Author = $User.Bob
    Switch-ProjectLocation -Location $Settings.ProjectDirectory
    Invoke-GitCommand -Command $GitCommand.Clone
    Switch-ProjectLocation -Location $Settings.BSubDirectory

    Write-Verbose "Changing config to reflect that this repository is for Bob"
    Invoke-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserName
    Invoke-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserEmail
    Invoke-GitCommand -Command $GitCommand.Checkout -Value $GitProperty.BranchName

    Write-Verbose "Alice now deletes X.txt file"
    $Author = $User.Alice
    Switch-ProjectLocation -Location $Settings.ASubDirectory
    Invoke-GitCommand -Command $GitCommand.Remove -Value $File.X

    Write-Verbose "Alice now edits Y.txt file"
    Edit-File -FileName $File.Y -Content $Content.ForAlexInYEditFile

    Write-Verbose "Alice creates and edits Z.txt file"
    Edit-File -FileName $File.Z -Content $Content.ForAlexInZFile
    
    Write-Verbose "Alice commits her changes and pushes to remote repo"
    Invoke-GitCommand -Command $GitCommand.Add -Value Y.txt, Z.txt
    Invoke-GitCommand -Command $GitCommand.Commit -GitParam '-m {0}' -Value 'Alice is committing deletion of X.txt, edit in Y.txt and creation of Z.txt'
    Invoke-GitCommand -Command $GitCommand.Push -GitParam $GitProperty.SetUpstreamOriginBranch -Value $GitProperty.BranchName
   
    Write-Verbose "Bob makes a correction in X.txt file"
    $Author = $User.Bob
    Switch-ProjectLocation -Location $Settings.BSubDirectory
    Edit-File -FileName $File.X -Content $Content.ForBobCorrectionsInXFile

    Write-Verbose "Bob makes a correction in Y.txt file"
    Edit-File -FileName $File.Y -Content $Content.ForBobCorrectionsInYFile

    Write-Verbose "Bob creates and edits Z.txt file"
    Edit-File -FileName $File.Z -Content $Content.ForBobInZFile

    Write-Verbose "Bob commits all files"
    Invoke-GitCommand -Command $GitCommand.Add -Value X.txt, Y.txt, Z.txt
    Invoke-GitCommand -Command $GitCommand.Commit -GitParam '-m {0}' -Value "Bob has corrected the mistakes in X.txt and Y.txt and creates Z.txt file"

    Write-Verbose "Bob fetches and attempts to merge..."
    Invoke-GitCommand -Command $GitCommand.Fetch 
    Invoke-GitCommand -Command $GitCommand.Merge -Value $GitProperty.BranchName

    Write-Verbose "Bob recieved 3 conflicts that need to be resolved."
}

function Invoke-GitCommand
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Command,

        [Parameter(Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GitParam,

        [Parameter(Mandatory = $False)]
        [String[]]
        $Value
    )
    
    $StringBuilder = New-Object System.Text.StringBuilder
    [void]$StringBuilder.Append('git ')
    [void]$StringBuilder.Append($Command+" ")

    switch($Command)
    {
        $GitCommand.Clone { 
                            [void]$StringBuilder.Append($GitProperty.Url+" ")
                            [void]$StringBuilder.Append($Author)
        } 
        $GitCommand.Add { 
                            [void]$StringBuilder.Append("$Value")
        } 
        $GitCommand.Checkout {
                            if($GitParam) {
                                [void]$StringBuilder.Append($GitParam)
                            }
                            [void]$StringBuilder.Append("$Value")
        }
        $GitCommand.Commit {

                            $Message = $GitParam -f "'$Value'"
                            [void]$StringBuilder.Append($Message)
        } 
        $GitCommand.Fetch { 
                            [void]$StringBuilder.Append("origin")
        } 
        $GitCommand.Merge { 
                            [void]$StringBuilder.Append("origin/")
                            [void]$StringBuilder.Append("$Value")
        } 
        $GitCommand.Config { 
                            if($GitParam -eq $GitProperty.UserName) {
                                [void]$StringBuilder.Append($GitProperty.UserName+" '$Author'")
                            } else {
                                [void]$StringBuilder.Append($GitProperty.UserEmail+" '$Author@info.com'")
                            }
        }
        $GitCommand.Push {
                            if($GitParam -eq $GitProperty.SetUpstreamOriginBranch) {
                                [void]$StringBuilder.Append($GitParam+"$Value")
                            } 
        }
        $GitCommand.Remove {
                            [void]$StringBuilder.Append("$Value")
        }
    }
    
    $Expression =  $StringBuilder.ToString()
    
    Write-Host
    Write-Host "$Author> " -ForegroundColor Yellow -NoNewline
    Write-Host $Expression -ForegroundColor Red

    Invoke-Expression $Expression
}

function Edit-File
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $False)]
        [string]
        $FileName,
        
        [Parameter(Mandatory = $False)]
        [string]
        $Content,
        
        [Parameter(Mandatory = $False)]
        [string]
        $ReplaceValue
    )
    $FilePath = $FileName

    if($_ -eq $False){ New-Item $FilePath -ItemType 'File' }

    if($ReplaceValue) {
        $FileContents = Get-Content -Path $FilePath
        $FileContents = $FileContents -replace $Content, $ReplaceValue
    } else {
        $FileContents = $Content
    }

    Set-Content -Path $FilePath -Value $FileContents
}

function Switch-ProjectLocation
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $False)]
        [string]$Location,

        [switch]$Clean
    )

    if ($Clean) {
        Remove-Item $Location -Force -Recurse -ErrorAction 'SilentlyContinue'
    }

    $PathExists = Test-Path -Path $Location
    if($PathExists -eq $False)
    {
        Write-Host $Location
        New-Item -Path $Location -ItemType 'Directory'
    }

    Set-Location $Location
}

$GitCommand = @{
    Clone = 'clone';
    Add = 'add';
    Checkout = 'checkout';
    Commit = 'commit';
    Push = 'push';
    Fetch = 'fetch';
    Merge = 'merge';
    Pull = 'pull';
    Config = 'config';
    Remove = 'rm';
}

$GitProperty = @{
    UserName = 'user.name';
    UserEmail = 'user.email';
    Message = '-m ';
    Url = 'https://github.com/marckassay/DemoOfGitConflicts.git';
    NewBranchFlag = '-b ';
    BranchName = "branch_"+(New-Guid | Select-String -Pattern '\w{3}').Matches.Value;
    SetUpstreamOriginBranch = '--set-upstream origin '; 
}

$User = @{
    Alice = 'Alice';
    Bob = 'Bob';
}

$Settings = @{
    ProjectName = 'DemoOfGitConflicts';

    PriorLocation = 'PriorLocation';
    HostLocation = $Env:LOCALAPPDATA;
    ProjectDirectory = ($Settings.HostLocation+"\"+$Settings.ProjectName);
    ASubDirectory = ($Settings.ProjectDirectory+"\"+$User.Alice);
    BSubDirectory = ($Settings.ProjectDirectory+"\"+$User.Bob);
}

$File = @{
    X = 'X.txt';
    Y = 'Y.txt';
    Z = 'Z.txt';
}

$Content = @{
    ForAlexInXFile = "i think I could that if I only know how to begin.... For, you see, so many out-of-the-way things had happened lately that Alice had begun to think that very few things indeed were like-really imposible. - Lewis ?";
    ForAlexInYFile = "life would-like be infinitely bigger, if we could only be born like at the age of ninety and gradually approach 8. - ???";
    ForAlexInYEditFile = "life would be infinitely bigger, if I could only be born at the age of 90 and gradually approach 9. - Mark ?";
    ForAlexInZFile = "The basis of umpire is art+music. Remove them and that the empire is no more. Empire follows art and not vice versa as you suppose. - ??";


    ForBobCorrectionsInXFile = "I think I could, if I only knew how to begin. For, you see, so many out-of-the-way things had happened lately that Alice had begun to think that very few things indeed were really impossible. - Lewis Carrol";
    ForBobCorrectionsInYFile = "Life would be infinitely happier if we could only be born at the age of eighty and gradually approach eighteen. - Mark Twain";
    ForBobInZFile = "The foundation of empire is art and science. Remove them or degrade them, and the empire is no more. Empire follows art and not vice versa as Englishmen suppose. - William Blake"; 
}

# Initialize -Verbose
Initialize 