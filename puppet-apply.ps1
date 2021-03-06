param(
    $role,
    $buildNumber =0 ,
    [switch]$pack,
	[switch]$build,
	[switch]$debug
)

try {

    if ($build) {
        write-host "Fetching all environments with R10K...."
        & r10k deploy environment -pv
    }
    elseif ($pack) {
        $source = $PSScriptRoot
        $destination = "$source\Puppet.1.0.$buildNumber.zip"
        $dirExclusions=@(".vagrant", ".r10k")
        $filesToExclude=@("*.zip", "*.ps1")

        if (Test-Path $destination) {
          Remove-Item $destination
        }

        # Add folders
        Get-ChildItem $source -Directory  | where { $_.Name -notin $dirExclusions} | Compress-Archive -DestinationPath $destination -Update

        # Add files on the root
        Get-ChildItem "*.*" | where { $_.Name -notlike "*.zip"}  | Compress-Archive -DestinationPath $destination -CompressionLevel Optimal -Update
    }
    else {
        Get-Content "c:\ProgramData\PuppetLabs\puppet\etc\puppet.conf" | ForEach-Object -Begin {$settings=@{}} -Process {$store = [regex]::split($_,'='); if(($store[0].CompareTo("") -ne 0) -and ($store[0].StartsWith("[") -ne $True) -and ($store[0].StartsWith("#") -ne $True)) {$settings.Add($store[0], $store[1])}}
        $environment = $settings.Get_Item("Environment")

        # Create empty folder with environment name - otherwise puppet apply fails
        New-Item "C:\ProgramData\PuppetLabs\code\environments\$environment" -type directory -force | Out-Null

        # Set the role on the agent
        New-Item "c:\ProgramData\PuppetLabs\facter\facts.d\role.txt" -type file -force -value "role=$role" | Out-Null

        # Required for puppet-apply to work locally on Vagrant
        New-Item "c:\ProgramData\PuppetLabs\facter\facts.d\dsc.txt" -type file -force -value "powershell_version=$($psversiontable.psversion.tostring())" | Out-Null
        New-Item "c:\ProgramData\PuppetLabs\facter\facts.d\filebeat.txt" -type file -force -value "filebeat_version=5" | Out-Null

        $debugMode = ""
        if ($debug) {
            $debugMode = "--debug"
        }

        Write-Host "Running Puppet Apply for environment $environment...."
        & puppet config set strict_variables true
        & puppet config set hiera_config hiera.yaml
        & puppet config set environmentpath environments
        & puppet config set basemodulepath environments/$environment/site

        & puppet apply environments/$environment/manifests/default.pp $debugMode
    }
}
Catch
{
    throw $_
}
