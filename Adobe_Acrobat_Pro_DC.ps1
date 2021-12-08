# Firstly, open and close the app. Then you may run the script, otherwise some registry key won'be created

#region Privacy & Telemetry
# Turn off services
$services = @(
	# Adobe Genuine Monitor Service
	"AGMService",

	# Adobe Genuine Software Integrity Service
	"AGSService"
)
Get-Service -Name $services -ErrorAction Ignore | Stop-Service -Force
Get-Service -Name $services -ErrorAction Ignore | Set-Service -StartupType Disabled

# Disable task
Get-ScheduledTask -TaskName AdobeGCInvoker-1.0 | Disable-ScheduledTask
#endregion Privacy & Telemetry

#region Task
# Create a task in the Task Scheduler to configure Adobe Acrobat Pro DC. The task runs every 31 days
$Argument = @"
Get-Service -Name AGMService, AGSService | Set-Service -StartupType Disabled
Get-Service -Name AGMService, AGSService | Stop-Service -Force
Stop-Process -Name acrotray -Force -ErrorAction Ignore
Get-ScheduledTask -TaskName AdobeGCInvoker-1.0 | Disable-ScheduledTask
if (Test-Path -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\AcroRd32.exe")
{
	Remove-Item -Path  """$env:ProgramFiles\Adobe\Acrobat DC\Acrobat\Browser""" -Recurse -Force
}
else
{
	Remove-Item -Path """${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Reader\Browser""" -Recurse -Force
}
"@

$Action     = New-ScheduledTaskAction -Execute powershell.exe -Argument $Argument
$Trigger    = New-ScheduledTaskTrigger -Daily -DaysInterval 31 -At 9am
$Settings   = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
$Principal  = New-ScheduledTaskPrincipal -UserID $env:USERNAME -RunLevel Highest
$Parameters = @{
	TaskName    = "Acrobat Pro DC Cleanup"
	TaskPath    = "Sophia Script"
	Principal   = $Principal
	Action      = $Action
	Description = "Cleaning Acrobat Pro DC up after every app's update"
	Settings    = $Settings
	Trigger     = $Trigger
}
Register-ScheduledTask @Parameters -Force
#endregion Task

#region UI
# Do not show messages from Adobe when the product launches
# https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/index.html
if (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\IPM"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\IPM" -Force
}
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\IPM" -Name bShowMsgAtLaunch -PropertyType DWord -Value 0 -Force

# Collapse all tips on the main page
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\HomeWelcomeFirstMile" -Name bFirstMileMinimized -PropertyType DWord -Value 1 -Force

# Always use page Layout Style: "Single Pages Continuous"
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\Originals" -Name iPageViewLayoutMode -PropertyType DWord -Value 2 -Force

# Turn on dark theme
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name aActiveUITheme -PropertyType String -Value DarkTheme -Force
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name bHonorOSTheme -PropertyType DWord -Value 0 -Force

# Hide "Share" button lable from Toolbar
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name bHideShareButtonLabel -PropertyType DWord -Value 1 -Force

# Remember Task Pane state after document closed
if (Test-Path -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\AcroRd32.exe")
{
	# If it's Acrobat Pro DC
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name aDefaultRHPViewModeL -PropertyType String -Value AppSwitcherOnly -Force
}
else
{
	# If it's Acrobat Reader DC
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name bRHPSticky -PropertyType DWord -Value 1 -Force
}

# Left "Edit PDF" and "Organize Pages" only tools in the Task Pane
if (Test-Path -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\AcroRd32.exe")
{
	Remove-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AcroApp\cFavorites" -Name * -Force
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AcroApp\cFavorites" -Name a0 -PropertyType String -Value EditPDFApp -Force
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AcroApp\cFavorites" -Name a1 -PropertyType String -Value PagesApp -Force
}

# Restore last view settings when reopening documents
if (Test-Path -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\AcroRd32.exe")
{
	if (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\RememberedViews"))
	{
		New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\RememberedViews" -Force
	}
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\RememberedViews" -Name iRememberView -PropertyType DWord -Value 2 -Force
}
#endregion UI

#region Quick Tools
# Clear favorite Quick Tools (сommented out)
# Remove-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name * -Force -ErrorAction Ignore

# Clear Quick Tools (сommented out)
# Remove-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name * -Force -ErrorAction Ignore

# Show Quick Tools in Toolbar
if (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Force
}
$match = '^' + 'a' + '\d+'

# "Save file"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
if ($names)
{
	if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Save")
	{
		New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Save -Force
	}
}
else
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a0" -PropertyType String -Value Save -Force
}

# "Print file"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Print")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Print -Force
}

# "Undo last change"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Undo")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Undo -Force
}

# "Redo last change"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Redo")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Redo -Force
}

# "Page number"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "GoToPage")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value GoToPage -Force
}

# "Rotate counterclockwise. Change is saved"
if (Test-Path -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\AcroRd32.exe")
{
	if (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop"))
	{
		New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Force
	}
	[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
	$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property
	if ($names)
	{
		if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name $names) -notcontains "RotatePagesCCW")
		{
			New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name "a$int" -PropertyType String -Value RotatePagesCCW -Force
		}
	}
	else
	{
		New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name "a0" -PropertyType String -Value RotatePagesCCW -Force
	}
}

# "Rotate clockwise. Change is saved"
if (Test-Path -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\AcroRd32.exe")
{
	[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
	$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property
	if ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name $names) -notcontains "RotatePagesCW")
	{
		New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name "a$int" -PropertyType String -Value RotatePagesCW -Force
	}
}
#endregion Quick Tools