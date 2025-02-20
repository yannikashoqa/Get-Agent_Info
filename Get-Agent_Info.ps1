Clear-Host
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -Assembly System.Windows.Forms

#region Functions

function Get-AgentInfo {
	$Product = @{}
	$DS_key = 'HKLM:\SOFTWARE\TrendMicro\Deep Security Agent'

	If (Test-Path $DS_key){
		$Product.ProductName = "Deep Security Agent"
		$Product.InstallationFolder = (Get-ItemProperty -Path $DS_key -Name InstallationFolder).InstallationFolder
	}Else{
		$Product.ProductName = "None"
	}

	If ($Product.ProductName -ne "None"){
		Push-Location $Product.InstallationFolder
	}Else{
		Write-Host "Trend Micro Product was not found"
		Exit
	}

	$DSAStatus	=  Invoke-Expression -Command ".\dsa_query --cmd GetAgentStatus"
	$i=0
	$DSAStatus | ForEach-Object {
		$AgentState1 = $DSAStatus[$i] | Select-String -Pattern "AgentStatus.agentState"
		If ($null -ne $AgentState1) {
			$AgentStateTemp = $DSAStatus[$i]
			$a0 = $AgentStateTemp.indexof(":")
			$a0 = $a0 + 2
			$b0 = $AgentStateTemp.get_Length()
			$c0 = $b0 - $a0
			#$AgentState = $AgentStateTemp.Substring($a0,$c0)
			$Product.AgentState = $AgentStateTemp.Substring($a0,$c0)
		}
		$i++
	}

	#Agent Service Status
	$DSA_Service = get-service -ComputerName . -Name "Trend Micro Deep Security Agent"
	$Product.ServiceStatus = $DSA_Service.status

	#Agent Configuration
	$DSAConfigRaw		= Invoke-Expression -Command ".\sendCommand.cmd --get GetConfiguration"
	$DSAConfigTemp	= $DSAConfigRaw  | Select-Object -skip 3		#Remove top three lines from output
	$DSAConfig	= [xml]$DSAConfigTemp
	
	write-Host $DSAConfig.SecurityConfiguration

	$Product.ManagerURL = $DSAConfig.SecurityConfiguration.AgentConfiguration.dsmUrl
	$Product.SecurityProfile = $DSAConfig.SecurityConfiguration.SecurityProfile.name
	$Product.DSAFeaturesRaw	= $DSAConfig.SecurityConfiguration.AgentConfiguration.Features.Feature
	$Product.IPSRules = $DSAConfig.SecurityConfiguration.PayloadFilter2s.PayloadFilter2
	$Product.FirewallFilters = $DSAConfig.SecurityConfiguration.PacketFilters.PacketFilter
	$Product.IMRules = $DSAConfig.SecurityConfiguration.IntegrityRules.IntegrityRule
	$Product.LIRules = $DSAConfig.SecurityConfiguration.LogInspectionRules.ChildNodes
	$Product.AntiMalwareSettings = $DSAConfig.SecurityConfiguration.AntiMalwares
	$Product.WebReputationSetting = $DSAConfig.SecurityConfiguration.WebReputationConfiguration
	$Product.Exclusion_Directory = $DSAConfig.SecurityConfiguration.ScanDirectoryLists.ScanDirectoryList[0]
	$Product.Exclusion_File = $DSAConfig.SecurityConfiguration.ScanFileLists.ScanFileList[0]
	$Product.Exclusion_Extension = $DSAConfig.SecurityConfiguration.ScanFileExtLists.ScanFileExtList[0]


	Return $Product
}

function String2Array {
	Param(	[Parameter(Mandatory=$true)][String]$String)
	$stringItems = $String -split ','
	return $stringItems
}


function GetModuleFullName {
	Param(	[Parameter(Mandatory=$true)][String]$Module)
	Switch ($Module) {
		"RELAY"	{Return "Relay"}
		"AM"	{Return "Anti-Malware"}
		"WRS"	{Return "Web Reputation"}
		"FW"	{Return "Firewall"}
		"DPI"	{Return "Intrusion Prevention"}
		"IM"	{Return "Integrity Monitoring"}
		"LI"	{Return "Log Inspection"}
		"AC"	{Return "Application Control"}
		default {Return "None"}
	}
}
#endregion Functions

$Product = Get-AgentInfo

#region GUI
$form = New-Object System.Windows.Forms.Form
$form.text = "Deep Security Agent Information"
$form.StartPosition = "CenterScreen"
$form.Width = 700
$form.Height = 700
$form.BackColor = "WhiteSmoke"
$IconPath = $Product.InstallationFolder + 'dsa.exe'
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($IconPath)

$button_ok = New-Object -TypeName System.Windows.Forms.Button
$button_ok.Size = New-Object -TypeName System.Drawing.Size(75,23)
$button_ok.Location = New-Object -TypeName System.Drawing.Size(600,605)
$button_ok.Text = 'OK'
$button_ok.Add_Click({
	$form.Close() #Button pressed
	})
$form.Controls.Add($button_ok)
$form.AcceptButton = $button_ok

#region TABS
################ Tabs ########################
$tabcontrols = New-Object System.Windows.Forms.TabControl
$tabcontrols.Width	=	650
$tabcontrols.Height	=	600
$tabcontrols.BackColor = "WhiteSmoke"
$form.Controls.Add($tabcontrols)

$tabGeneralInfo = New-Object System.Windows.Forms.TabPage
$tabGeneralInfo.Text = "General Information"
$tabcontrols.Controls.Add($tabGeneralInfo)

$tabAM = New-Object System.Windows.Forms.TabPage
$tabAM.Text = "Anti-Malware"
$tabcontrols.Controls.Add($tabAM)

$tabWR = New-Object System.Windows.Forms.TabPage
$tabWR.Text = "Web Reputation"
$tabcontrols.Controls.Add($tabWR)

$tabIPS = New-Object System.Windows.Forms.TabPage
$tabIPS.Text = "Intrusion Prevention"
$tabcontrols.Controls.Add($tabIPS)

$tabFW = New-Object System.Windows.Forms.TabPage
$tabFW.Text = "Firewall"
$tabcontrols.Controls.Add($tabFW)

$tabIM = New-Object System.Windows.Forms.TabPage
$tabIM.Text = "Integrity Monitoring"
$tabcontrols.Controls.Add($tabIM)

$tabLI = New-Object System.Windows.Forms.TabPage
$tabLI.Text = "Log Inspection"
$tabcontrols.Controls.Add($tabLI)
#endregion TABS

#region General Tab
$lblProductName				= New-Object system.Windows.Forms.Label
$lblProductName.Text		= "Product Name:"
$lblProductName.Top			= 10
$lblProductName.Left		= 5
$lblProductName.Width		= 100
$lblProductName.Height		= 10
$lblProductName.Autosize	= $true

$txtProductName				= New-Object system.Windows.Forms.Label
$txtProductName.multiline	= $false
$txtProductName.top			= 10
$txtProductName.left		= 150
$txtProductName.width		= 100
$txtProductName.Autosize	= $true
$txtProductName.Text		= $Product.ProductName

$lblManagerURL				= New-Object system.Windows.Forms.Label
$lblManagerURL.Text			= "Manager URL:"
$lblManagerURL.Top			= 30
$lblManagerURL.Left			= 5
$lblManagerURL.Width		= 100
$lblManagerURL.Height		= 10
$lblManagerURL.Autosize		= $true

$txtManagerURL				= New-Object system.Windows.Forms.Label
$txtManagerURL.multiline	= $false
$txtManagerURL.top			= 30
$txtManagerURL.left			= 150
$txtManagerURL.width		= 100
$txtManagerURL.Autosize		= $true
$txtManagerURL.Text			= $Product.ManagerURL

$lblAgentState				= New-Object system.Windows.Forms.Label
$lblAgentState.Text			= "Agent State:"
$lblAgentState.Top			= 50
$lblAgentState.Left			= 5
$lblAgentState.Width		= 100
$lblAgentState.Height		= 10
$lblAgentState.Autosize		= $true

$txtAgentState				= New-Object system.Windows.Forms.Label
$txtAgentState.multiline	= $false
$txtAgentState.top			= 50
$txtAgentState.left			= 150
$txtAgentState.width		= 100
$txtAgentState.Autosize		= $true
$txtAgentState.Text			= $Product.AgentState

$lblAgentStatus				= New-Object system.Windows.Forms.Label
$lblAgentStatus.text		= "Agent Service Status:"
$lblAgentStatus.Top			= 70
$lblAgentStatus.Left		= 5
$lblAgentStatus.width		= 100
$lblAgentStatus.AutoSize	= $true

$txtAgentStatus				= New-Object system.Windows.Forms.Label
$txtAgentStatus.multiline	= $false
$txtAgentStatus.Top			= 70
$txtAgentStatus.Left		= 150
$txtAgentStatus.width		= 100
$txtAgentStatus.AutoSize	= $true
$txtAgentStatus.Text		= $Product.ServiceStatus

$lblPolicyName				= New-Object system.Windows.Forms.Label
$lblPolicyName.text			= "Policy Name:"
$lblPolicyName.top			= 90
$lblPolicyName.left			= 5
$lblPolicyName.width		= 100
$lblPolicyName.Autosize		= $true

$txtPolicyName				= New-Object system.Windows.Forms.Label
$txtPolicyName.multiline	= $false
$txtPolicyName.top			= 90
$txtPolicyName.left			= 150
$txtPolicyName.width		= 100
$txtPolicyName.AutoSize		= $true
$txtPolicyName.Text			= $Product.SecurityProfile

$lblModuleStatus			= New-Object system.Windows.Forms.Label
$lblModuleStatus.text		= "Enabled Modules:"
$lblModuleStatus.Top		= 110
$lblModuleStatus.Left		= 5
$lblModuleStatus.width		= 25
$lblModuleStatus.AutoSize	= $true

$DSAFeaturesRaw	= $Product.DSAFeaturesRaw
$i=0
$DSAFeaturesRaw | ForEach-Object {
	If (($_.state) -eq "1") {
		$txtModuleStatus			= New-Object system.Windows.Forms.Label
		$txtModuleStatus.Top		= 110 + $i
		$txtModuleStatus.Left		= 150
		$txtModuleStatus.width		= 200
		$txtModuleStatus.AutoSize	= $true

		$EnabledModule = GetModuleFullName -Module $_.Name
		If ($EnabledModule -ne "None") {
			$txtModuleStatus.Text		= "- " + $EnabledModule
			$tabGeneralInfo.Controls.Add($txtModuleStatus)
		}
		$i = $i + 20
	}
}

$tabGeneralInfo.Controls.AddRange(@($lblAgentState,$txtAgentState,$lblManagerURL,$txtManagerURL,$lblProductName,$txtProductName,$lblPolicyName,$txtPolicyName,$lblAgentStatus,$txtAgentStatus,$lblModuleStatus))
#endregion General Tab

#region AM Tab
$AntiMalwareSettings = $Product.AntiMalwareSettings
$WebReputationSetting = $Product.WebReputationSetting
$Exclusion_Directory = $Product.Exclusion_Directory
$Exclusion_File = $Product.Exclusion_File
$Exclusion_Extension = $Product.Exclusion_Extension

$RealTimeInfo = $AntiMalwareSettings.AntiMalware[0]
$RealTimeScanConfigurationName = $RealTimeInfo.Name

$Exclusion_Directory_Items = $Exclusion_Directory.Items
$Exclusion_File_Items = $Exclusion_File.Items
$Exclusion_Extension_Items = $Exclusion_Extension.Items

$Exclusion_Directory_List	= String2Array -String $Exclusion_Directory_Items
$Exclusion_File_List		= String2Array -String $Exclusion_File_Items
$Exclusion_Extension_List	= String2Array -String $Exclusion_Extension_Items

$lblScanConfigurationName			= New-Object system.Windows.Forms.Label
$lblScanConfigurationName.Text		= "Scan Configuration Name:"
$lblScanConfigurationName.Top		= 10
$lblScanConfigurationName.Left		= 5
$lblScanConfigurationName.Width		= 100
$lblScanConfigurationName.Height	= 10
$lblScanConfigurationName.Autosize	= $true

$txtScanConfigurationName			= New-Object system.Windows.Forms.Label
$txtScanConfigurationName.multiline	= $false
$txtScanConfigurationName.top		= 10
$txtScanConfigurationName.left		= 150
$txtScanConfigurationName.width		= 100
$txtScanConfigurationName.Autosize	= $true
$txtScanConfigurationName.Text		= $RealTimeScanConfigurationName

$lblDirExclusion				= New-Object system.Windows.Forms.Label
$lblDirExclusion.text			= "Directory Exclusions:"
$lblDirExclusion.Top			= 30
$lblDirExclusion.Left			= 150
$lblDirExclusion.width			= 25
$lblDirExclusion.AutoSize		= $true
$txtDirExclusion				= New-Object system.Windows.Forms.ListBox
$txtDirExclusion.Text			= "Realtime Directory Exclusions"
$txtDirExclusion.Top			= 50
$txtDirExclusion.Left			= 150
$txtDirExclusion.width			= 350
$txtDirExclusion.height			= 100
$txtDirExclusion.Scrollable		= 1
$Exclusion_Directory_List | ForEach-Object {
	$Exclusion_Item = New-Object System.Windows.Forms.ListViewItem([System.String[]]$_)
	[Void]$txtDirExclusion.Items.AddRange($Exclusion_Item.Text)
}

$lblFileExclusion				= New-Object system.Windows.Forms.Label
$lblFileExclusion.text			= "File Exclusions:"
$lblFileExclusion.Top			= 160
$lblFileExclusion.Left			= 150
$lblFileExclusion.width			= 25
$lblFileExclusion.AutoSize		= $true
$txtFileExclusion				= New-Object system.Windows.Forms.ListBox
$txtFileExclusion.text			= "Realtime File Exclusions"
$txtFileExclusion.Top			= 180
$txtFileExclusion.Left			= 150
$txtFileExclusion.width			= 250
$txtFileExclusion.height		= 100
$Exclusion_File_List | ForEach-Object {
	$Exclusion_Item = New-Object System.Windows.Forms.ListViewItem([System.String[]]$_)
	[Void]$txtFileExclusion.Items.Add($Exclusion_Item.Text)
}

$lblExtExclusion				= New-Object system.Windows.Forms.Label
$lblExtExclusion.text			= "Extension Exclusions:"
$lblExtExclusion.Top			= 290
$lblExtExclusion.Left			= 150
$lblExtExclusion.width			= 25
$lblExtExclusion.AutoSize		= $true
$txtExtExclusion				= New-Object system.Windows.Forms.ListBox
$txtExtExclusion.text			= "Realtime Extension Exclusions"
$txtExtExclusion.Top			= 310
$txtExtExclusion.Left			= 150
$txtExtExclusion.width			= 250
$txtExtExclusion.height			= 100
$Exclusion_Extension_List | ForEach-Object {
	$Exclusion_Item = New-Object System.Windows.Forms.ListViewItem([System.String[]]$_)
	[Void]$txtExtExclusion.Items.Add($Exclusion_Item.Text)
}

$tabAM.Controls.AddRange(@($lblScanConfigurationName,$txtScanConfigurationName,$lblDirExclusion,$txtDirExclusion,$lblFileExclusion,$txtFileExclusion,$lblExtExclusion,$txtExtExclusion))
#endregion AM Tab

#region WR Tab
# securityLevel='80' ==> High
# securityLevel='65' ==> Medium
# securityLevel='50' ==> Low

Switch ($Product.WebReputationSetting.securityLevel)
{
    80 {$SecurityLevel =  "High"}
    65 {$SecurityLevel =  "Medium"}
	50 {$SecurityLevel =  "Low"}
}

$lblWRStatus			= New-Object system.Windows.Forms.Label
$lblWRStatus.Text		= "Enabled:"
$lblWRStatus.Top		= 10
$lblWRStatus.Left		= 5
$lblWRStatus.Width		= 100
$lblWRStatus.Height		= 10
$lblWRStatus.Autosize	= $true

$txtWRStatus			= New-Object system.Windows.Forms.Label
$txtWRStatus.multiline	= $false
$txtWRStatus.top			= 10
$txtWRStatus.left		= 150
$txtWRStatus.width		= 100
$txtWRStatus.Autosize	= $true
$txtWRStatus.Text		= $Product.WebReputationSetting.enabled

$lblWRSecurityLevel				= New-Object system.Windows.Forms.Label
$lblWRSecurityLevel.Text		= "Security Level:"
$lblWRSecurityLevel.Top			= 30
$lblWRSecurityLevel.Left		= 5
$lblWRSecurityLevel.Width		= 100
$lblWRSecurityLevel.Height		= 10
$lblWRSecurityLevel.Autosize	= $true

$txtWRSecurityLevel				= New-Object system.Windows.Forms.Label
$txtWRSecurityLevel.multiline	= $false
$txtWRSecurityLevel.top			= 30
$txtWRSecurityLevel.left		= 150
$txtWRSecurityLevel.width		= 100
$txtWRSecurityLevel.Autosize	= $true
$txtWRSecurityLevel.Text		= $SecurityLevel

[Void]$tabWR.Controls.AddRange(@($lblWRStatus,$txtWRStatus,$lblWRSecurityLevel,$txtWRSecurityLevel))
#endregion WR Tab

#region IPS Tab
$lblIPS_Rules				= New-Object system.Windows.Forms.Label
$lblIPS_Rules.text			= "IPS Rules:"
$lblIPS_Rules.Top			= 10
$lblIPS_Rules.left			= 5
$lblIPS_Rules.width			= 100
$lblIPS_Rules.AutoSize		= $true
$txtIPS_Rules				= New-Object system.Windows.Forms.ListView
$txtIPS_Rules.view			= "Detail"
$txtIPS_Rules.Top			= 10
$txtIPS_Rules.Left			= 80
$txtIPS_Rules.width			= 500
$txtIPS_Rules.height		= 550
$txtIPS_Rules.GridLines		= 1
$txtIPS_Rules.Scrollable	= 1


[Void]$txtIPS_Rules.Columns.Add('Rule ID', 50)
[Void]$txtIPS_Rules.Columns.Add('Rule Name', 800)

$IPSRules = $Product.IPSRules
$IPSRules = $IPSRules | Sort-Object identifier
$IPSRules | ForEach-Object {
	$Rule_Item = New-Object System.Windows.Forms.ListViewItem($_.identifier)
	[Void]$Rule_Item.SubItems.Add($_.name)
	[Void]$txtIPS_Rules.Items.Add($Rule_Item)
}

[Void]$tabIPS.Controls.AddRange(@($lblIPS_Rules,$txtIPS_Rules))
#endregion IPS Tab

#region FW Tab
$lblFW_Rules				= New-Object system.Windows.Forms.Label
$lblFW_Rules.text			= "FW Rules:"
$lblFW_Rules.Top			= 10
$lblFW_Rules.Left			= 5
$lblFW_Rules.width			= 25
$lblFW_Rules.AutoSize		= $true
$txtFW_Rules				= New-Object system.Windows.Forms.ListView
$txtFW_Rules.view			= "Detail"
$txtFW_Rules.Top			= 10
$txtFW_Rules.Left			= 80
$txtFW_Rules.width			= 500
$txtFW_Rules.height			= 550
$txtFW_Rules.GridLines		= 1
$txtFW_Rules.Scrollable		= 1

[Void]$txtFW_Rules.Columns.Add('Name', 250)
[Void]$txtFW_Rules.Columns.Add('Action', 100)
[Void]$txtFW_Rules.Columns.Add('Direction', 100)

$FirewallFilters = $Product.FirewallFilters

If ($FirewallFilters.count -gt 0){
	$FirewallFilters = $FirewallFilters | Sort-Object filterAction
	$FirewallFilters | ForEach-Object {
		$Rule_Item = New-Object System.Windows.Forms.ListViewItem($_.name)
	    If (($_.packetDirection) -eq 1){
	        $FWDirection = "Incoming"
	    }else{
	        $FWDirection = "Outgoing"
	    }
	    switch ($_.filterAction)
	    {
	        0 {$FWAction = "Log Only"}
	        1 {$FWAction = "Allow"}
	        2 {$FWAction = "Deny"}
	        3 {$FWAction = "Force Allow"}
	        4 {$FWAction = "Bypass"}
	        Default {$FWAction = "Unkbown Action"}
	    }
		[Void]$Rule_Item.SubItems.Add($FWAction)
		[Void]$Rule_Item.SubItems.Add($FWDirection)
	    [Void]$txtFW_Rules.Items.Add($Rule_Item)
	}
}

[Void]$tabFW.Controls.AddRange(@($lblFW_Rules,$txtFW_Rules))

#endregion FW Tab

#region IM Tab
$lblIM_Rules				= New-Object system.Windows.Forms.Label
$lblIM_Rules.text			= "IM Rules:"
$lblIM_Rules.Top			= 10
$lblIM_Rules.Left			= 5
$lblIM_Rules.width			= 25
$lblIM_Rules.AutoSize		= $true
$txtIM_Rules				= New-Object system.Windows.Forms.ListView
$txtIM_Rules.View			= "Detail"
$txtIM_Rules.Top			= 10
$txtIM_Rules.Left			= 80
$txtIM_Rules.width			= 500
$txtIM_Rules.height			= 550
$txtIM_Rules.GridLines		= 1
$txtIM_Rules.Scrollable		= 1

[Void]$txtIM_Rules.Columns.Add('Rule ID', 50)
[Void]$txtIM_Rules.Columns.Add('Rule Name', 800)

$IMRules = $Product.IMRules
if ($IMRules.count -ne 0){
	$IMRules = $IMRules | Sort-Object identifier
	$IMRules | ForEach-Object {
		$Rule_Item = New-Object System.Windows.Forms.ListViewItem($_.identifier)
		[Void]$Rule_Item.SubItems.Add($_.name)
		[Void]$txtIM_Rules.Items.Add($Rule_Item)
	}
}

[Void]$tabIM.Controls.AddRange(@($lblIM_Rules,$txtIM_Rules))
#endregion IM Tab

#region LI Tab
$lblLI_Rules				= New-Object system.Windows.Forms.Label
$lblLI_Rules.text			= "LI Rules:"
$lblLI_Rules.Top			= 10
$lblLI_Rules.Left			= 5
$lblLI_Rules.width			= 25
$lblLI_Rules.AutoSize		= $true
$txtLI_Rules				= New-Object system.Windows.Forms.ListView
$txtLI_Rules.View			= "Detail"
$txtLI_Rules.Top			= 10
$txtLI_Rules.Left			= 80
$txtLI_Rules.width			= 500
$txtLI_Rules.height			= 550
$txtLI_Rules.GridLines		= 1
$txtLI_Rules.Scrollable		= 1

[Void]$txtLI_Rules.Columns.Add('Rule ID', 50)
[Void]$txtLI_Rules.Columns.Add('Rule Name', 600)

$LIRules = $Product.LIRules
if ($LIRules.count -ne 0){
	$LIRules = $LIRules | Sort-Object identifier
	$LIRules | ForEach-Object {
		$Rule_Item = New-Object System.Windows.Forms.ListViewItem($_.identifier)
		[Void]$Rule_Item.SubItems.Add($_.name)
		[Void]$txtLI_Rules.Items.Add($Rule_Item)
	}
}

[Void]$tabLI.Controls.AddRange(@($lblLI_Rules,$txtLI_Rules))
#endregion LI Tab


[void]$Form.ShowDialog()

#endregion GUI
