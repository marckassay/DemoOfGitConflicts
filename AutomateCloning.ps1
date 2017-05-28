function Initialize
{
    $BranchName = "branch_"+(New-Guid | Select-String -Pattern '\w{3}').Matches.Value
    $InformationPreference = 'Continue';

    Push-Location
    Set-Location -Path $Env:LOCALAPPDATA

    $Mesg = $GitProperty.ProjectDirectory+" script has started its setup procedure..."
    Write-Information -MessageData $Mesg

    Remove-Item $GitProperty.ProjectDirectory -Force -Recurse -ErrorAction SilentlyContinue
    New-Item $GitProperty.ProjectDirectory -ItemType Directory

    $Mesg = "Cloning "+$GitProperty.ProjectDirectory+" repository into Alice subfolder"
    Write-Information -MessageData $Mesg

    Push-Location
    Set-Location -Path $GitProperty.ProjectDirectory

    Execute-GitCommand -Command $GitCommand.Clone -SubFolder $User.Alice

    Push-Location
    Set-Location -Path $User.Alice

    Execute-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserName -Value $User.Alice
    Execute-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserEmail -Value $User.Alice
    Execute-GitCommand -Command $GitCommand.Checkout -GitParam $GitProperty.NewBranchFlag -Value $BranchName
    
    Write-Information -MessageData "Alice creates and edits X.txt file"
    Edit-File -FileName $File.X -Content $Content.ForAlexInXFile
    
    Write-Information -MessageData "Alice creates and edits Y.txt file"
    Edit-File -FileName $File.Y -Content $Content.ForAlexInYFile

    Write-Information -MessageData "Alice commits all files and pushes to remote repo"
    Execute-GitCommand -Command $GitCommand.Add -Value '.'
    Execute-GitCommand -Command $GitCommand.Commit -GitParam '-m {0}' -Value 'Alice is committing files X and Y'
    Execute-GitCommand -Command $GitCommand.Push -GitParam $GitProperty.SetUpstreamOriginBranch -Value $BranchName

    Pop-Location
    
    $Mesg = "Cloning "+$GitProperty.ProjectDirectory+" repository into Bob subfolder"
    Write-Information -MessageData $Mesg
    Execute-GitCommand -Command $GitCommand.Clone -SubFolder $User.Bob

    Push-Location
    Set-Location -Path $User.Bob

    Execute-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserName -Value $User.Bob
    Execute-GitCommand -Command $GitCommand.Config -GitParam $GitProperty.UserEmail -Value $User.Bob
    Execute-GitCommand -Command $GitCommand.Checkout -Value $BranchName

    Pop-Location
    Push-Location
    Set-Location -Path $User.Alice

    Write-Information -MessageData "Alice deletes X.txt file"
    Execute-GitCommand -Command $GitCommand.Remove -Value $File.X

    Write-Information -MessageData "Alice edits Y.txt file"
    Edit-File -FileName $File.Y -Content $Content.ForAlexInYEditFile

    Write-Information -MessageData "Alice creates and edits Z.txt file"
    Edit-File -FileName $File.Z -Content $Content.ForAlexInZFile
    
    Write-Information -MessageData "Alice commits her changes and pushes to remote repo"
    Execute-GitCommand -Command $GitCommand.Add -Value '.'
    Execute-GitCommand -Command $GitCommand.Commit -GitParam '-m {0}' -Value 'Alice is committing deletion of X.txt, edit in Y.txt and creation of Z.txt'
    Execute-GitCommand -Command $GitCommand.Push -GitParam $GitProperty.SetUpstreamOriginBranch -Value $BranchName

    Pop-Location
    Push-Location
    Set-Location -Path $User.Bob

    Write-Information -MessageData "Bob makes a correction in X.txt file"
    Edit-File -FileName $File.X -Content $Content.ForBobCorrectionsInXFile

    Write-Information -MessageData "Bob makes a correction in Y.txt file"
    Edit-File -FileName $File.Y -Content $Content.ForBobCorrectionsInYFile

    Write-Information -MessageData "Bob creates and edits Z.txt file"
    Edit-File -FileName $File.Z -Content $Content.ForBobInZFile

    Write-Information -MessageData "Bob commits all files"
    Execute-GitCommand -Command $GitCommand.Add -Value '.'
    Execute-GitCommand -Command $GitCommand.Commit -GitParam '-m {0}' -Value "Bob has corrected the mistakes in X.txt and Y.txt and creates Z.txt file"

    Write-Information -MessageData "Bob fetches and attempts to merge..."
    Execute-GitCommand -Command $GitCommand.Fetch 
    Execute-GitCommand -Command $GitCommand.Merge -Value $BranchName

    Write-Information -MessageData "Bob recieved 3 conflicts that need to be resolved."
    
    Pop-Location
    Pop-Location
    Pop-Location
}

function Execute-GitCommand
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Command,

        [Parameter(Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [string]
        $GitParam,

        [Parameter(Mandatory = $False)]
        [String]
        $SubFolder,

        [Parameter(Mandatory = $False)]
        [string]
        $Value
    )
    
    $StringBuilder = New-Object System.Text.StringBuilder
    [void]$StringBuilder.Append('& git ')
    [void]$StringBuilder.Append($Command+" ")

    switch($Command)
    {
        $GitCommand.Clone { 
                            [void]$StringBuilder.Append($GitProperty.Url+" ")
                            [void]$StringBuilder.Append($SubFolder+" ")
        } 
        $GitCommand.Add { 
                            [void]$StringBuilder.Append("."); 
        } 
        $GitCommand.Checkout {
                            if($GitParam) {
                                [void]$StringBuilder.Append($GitParam+" ")
                            }
                            [void]$StringBuilder.Append($Value)
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
                            [void]$StringBuilder.Append($Value)
        } 
        $GitCommand.Config { 
                            if($GitParam -eq $GitProperty.UserName) {
                                [void]$StringBuilder.Append($GitProperty.UserName+" '$Value'")
                            } else {
                                [void]$StringBuilder.Append($GitProperty.UserEmail+" '$Value@info.com'")
                            }
        }
        $GitCommand.Push {
                            if($GitParam -eq $GitProperty.SetUpstreamOriginBranch) {
                                [void]$StringBuilder.Append(" "+$GitParam+$Value)
                            } 
        }
        $GitCommand.Remove {
                            [void]$StringBuilder.Append($Value)
        }
    }

    $Expression =  $StringBuilder.ToString()
    $Expression
    Invoke-Expression $Expression
}

function Edit-File
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $False)]
        [string]
        $SubFolder,
        
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

    $StringBuilder = New-Object System.Text.StringBuilder

    if($SubFolder) {
        [void]$StringBuilder.Append($SubFolder)
        [void]$StringBuilder.Append("/")
    }

    $FilePath = $StringBuilder.Append($FileName)

    if($_ -eq $False){ New-Item $FilePath -ItemType File }

    if($ReplaceValue) {
        $FileContents = Get-Content -Path $FilePath
        $FileContents = $FileContents -replace $Content, $ReplaceValue
    } else {
        $FileContents = $Content
    }

    Set-Content -Path $FilePath -Value $FileContents
}

function Remove-File
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $False)]
        [string[]]
        $SubFolder,

        [Parameter(Mandatory = $False)]
        [string]$FileName
    )

    if($SubFolder) {
        [void]$StringBuilder.Append($SubFolder)
        [void]$StringBuilder.Append("/")
    }

    $FilePath = $StringBuilder.Append($FileName)

    Remove-Item -Path $FilePath -Force 
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
    SetUpstreamOriginBranch = '--set-upstream origin '; 
    ProjectDirectory = 'DemoOfGitConflicts';
}

$User = @{
    Alice = 'Alice';
    Bob = 'Bob';
}

$File = @{
    X = 'X.txt';
    Y = 'Y.txt';
    Z = 'Z.txt';
}

$Content = @{
    ForAlexInXFile = "i think I could that if I only know how to begin.... For, you see, so many out-of-the-way things had happened lately that Alice had begun to think that very few things indeed were like-really imposible. - Lewis Carrol";
    ForAlexInYFile = "life would-like be infinitely bigger, if we could only be born like at the age of ninety and gradually approach 8. - Mark Twain";
    ForAlexInYEditFile = "life would be infinitely bigger, if I could only be born at the age of 90 and gradually approach 9. - Mark Twain";
    ForAlexInZFile = "The basis of umpire is art+music. Remove them and that the empire is no more. Empire follows art and not vice versa as you suppose. - William Blake";


    ForBobCorrectionsInXFile = "I think I could, if I only knew how to begin. For, you see, so many out-of-the-way things had happened lately that Alice had begun to think that very few things indeed were really impossible. - Lewis Carrol";
    ForBobCorrectionsInYFile = "Life would be infinitely happier if we could only be born at the age of eighty and gradually approach eighteen. - Mark Twain";
    ForBobInZFile = "The foundation of empire is art and science. Remove them or degrade them, and the empire is no more. Empire follows art and not vice versa as Englishmen suppose. - William Blake"; 
}

Initialize