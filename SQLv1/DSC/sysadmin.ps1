# Dot-sourced PowerShell function that can add users to Administrators group
param (
        [Parameter(Mandatory=$false)]
        [string]
        $InputFile,

        [Parameter(Mandatory=$false)]
        [string]
        $Computer= $env:COMPUTERNAME,

        [Parameter(Mandatory=$false)]
        [string]
        $Trustee= 'ADI Supporters',

        [Parameter(Mandatory=$false)]
        [string]
        $group= 'DREFOQA\ADI Supporters'
)

function Resolve-SamAccount {
param(
    [string]
        $SamAccount,
    [boolean]
        $Exit
)
    process {
        try
        {
            $ADResolve = ([adsisearcher]"(samaccountname=$Trustee)").findone().properties['samaccountname']
        }
        catch
        {
            $ADResolve = $null
        }

        if (!$ADResolve) {
            Write-Warning "User `'$SamAccount`' not found in AD, please input correct SAM Account"
            if ($Exit) {
                exit
            }
        }
        $ADResolve
    }
}

if (!$Trustee) {
    $Trustee = Read-Host "Please input trustee"
}
if ($Trustee -notmatch '\\') {
    $ADResolved = (Resolve-SamAccount -SamAccount $Trustee -Exit:$true)
    $Trustee = 'WinNT://',"$env:userdomain",'/',$ADResolved -join ''
} else {
    $ADResolved = ($Trustee -split '\\')[1]
    $DomainResolved = ($Trustee -split '\\')[0]
    $Trustee = 'WinNT://',$DomainResolved,'/',$ADResolved -join ''
}
if (!$InputFile) {
	if (!$Computer) {
		$Computer = Read-Host "Please input computer name"
	}
	[string[]]$Computer = $Computer.Split(',')
	$Computer | ForEach-Object {
		$_
		Write-Host "Adding `'$ADResolved`' to Administrators group on `'$_`'"
		try {
			([ADSI]"WinNT://$_/Administrators,group").add($Trustee)
			Write-Host -ForegroundColor Green "Successfully completed command for `'$ADResolved`' on `'$_`'"
		} catch {
			Write-Warning "$_"
		}	
	}
}
else {
	if (!(Test-Path -Path $InputFile)) {
		Write-Warning "Input file not found, please enter correct path"
		exit
	}
	Get-Content -Path $InputFile | ForEach-Object {
		Write-Host "Adding `'$ADResolved`' to Administrators group on `'$_`'"
		try {
			([ADSI]"WinNT://$_/Administrators,group").add($Trustee)
			Write-Host -ForegroundColor Green "Successfully completed command"
		} catch {
			Write-Warning "$_"
		}        
	}
}
###########################################################################
$ServiceName = "MSSQLSERVER" #Enter the service name for your SQL Server Instance (MSSQLSERVER by default)
$Server = $env:COMPUTERNAME #Enter the name of SQL Server Instance

NET STOP $ServiceName 
NET START $ServiceName /mSQLCMD 

SQLCMD -S $Server -Q "if not exists(select * from sys.server_principals where name='BUILTIN\administrators') CREATE LOGIN [BUILTIN\administrators] FROM WINDOWS;EXEC master..sp_addsrvrolemember @loginame = N'BUILTIN\administrators', @rolename = N'sysadmin'" 

NET STOP $ServiceName 
NET START $ServiceName

SQLCMD -S $Server -Q "if exists( select * from fn_my_permissions(NULL, 'SERVER') where permission_name = 'CONTROL SERVER') print 'You are a sysadmin.'" 
###########################################################################
$servers = $env:COMPUTERNAME
foreach($server in $servers) {
$srv = New-Object 'Microsoft.SQLServer.Management.SMO.Server' $Server
Write-Host "Sysadmin Role Members on $server" -ForegroundColor Green
$srv.Roles['sysadmin'].EnumServerRoleMembers()
}
