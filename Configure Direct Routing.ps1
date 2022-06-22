####################################################################################################
#### THis script is a personal collection for configuring Direct routing for Microsoft TEams with voice routing, dial plan configuration ###
##v1.1###
##Please always check the scripts before running this and these is provided as examples only so use at your own risk###
### Thank you ! and hope these are useful for you !! #####


###Check PowerShell Version to check for PowerShell 5.1 or Higher
$PSVersionTable.PSVersion 

##Installing PowerShellGet
Install-Module -Name PowerShellGet -Force -AllowClobber

### Install the Teams PowerShell Module
Install-Module -Name MicrosoftTeams -Force -AllowClobber

##### Update Teams PowerShell Module
Update-Module MicrosoftTeams

##############################################################################################

### check WinRM settings.
winrm get winrm/config/client/auth
#### 
winrm quickconfig -q
winrm set winrm/config/client/auth '@{Basic="true"}'


#### Sign in#####################
Connect-MicrosoftTeams


######## DIRECT ROUTING CONFIG ##############################################################################

### 1. SBC - ADD NEW SBC1.CONSOSO.COM ########################################################################
New-CsOnlinePSTNGateway -Fqdn sbc1.consoso.com -SipSignalingPort 5061 -MaxConcurrentSessions 24 -Enabled $true

### 2.  verify Pairing
Get-CsOnlinePSTNGateway -Identity sbc1.consoso.com 


####remove sbc
Remove-CsOnlinePSTNGateway -Identity sbc1.consoso.com 

#################################################################################


#### User enablement ############################################################

###### 3. Ensure that the user is homed online#############
Get-CsOnlineUser -Identity "AllanD@consoso.com" | fl RegistrarPool,OnPremLineUriManuallySet,OnPremLineUri,LineUri

####In case OnPremLineUriManuallySet is set to False and LineUri is populated with a <E.164 phone number>, 
#the phone number was assigned on-premises and synchronized to O365. If you want manage the phone number online, clean the parameter
Set-CsUser -Identity "<User name>" -LineUri $null

####### 4. Configure the phone number and enable enterprise voice and voicemail online###

######## If managing the user's phone number on-premises, issue the command

Set-CsPhoneNumberAssignment -Identity "AllanD@consoso.com" -EnterpriseVoiceEnabled $false


##########If managing the user's phone number online, issue the command###
Set-CsPhoneNumberAssignment -Identity "AllanD@consoso.com" -PhoneNumber "+12315381011" -PhoneNumberType DirectRouting

######## add Ext (Optional) #####
Set-CsPhoneNumberAssignment -Identity "martin@consoso.com" -PhoneNumber "+14255388701;ext=1001" -PhoneNumberType DirectRouting
Set-CsPhoneNumberAssignment -Identity "bob@consoso.com" -PhoneNumber "+14255388701;ext=1002" -PhoneNumberType DirectRouting



#### 5. Stale Script Check https://msunified.net/category/lync-server-2013/troubleshooting-lync-server-2013/
Get-CsOnlineUser AllanD@consoso.com | Format-List UserPrincipalName, DisplayName, SipAddress, Enabled, TeamsUpgradeEffectiveMode, EnterpriseVoiceEnabled, HostedVoiceMail, City, UsageLocation, DialPlan, TenantDialPlan, OnlineVoiceRoutingPolicy, LineURI, OnPremLineURI, OnlineDialinConferencingPolicy, TeamsVideoInteropServicePolicy, TeamsCallingPolicy, HostingProvider, InterpretedUserType, VoicePolicy, CountryOrRegionDisplayName


######## 6. VOICE ROUTING##########################

######## Create the "US and Canada" PSTN usage
Set-CsOnlinePstnUsage -Identity Global -Usage @{Add="PSTN Usage - US and Canada"}

##### verify 
Get-CSOnlinePSTNUsage
### remove pstn usages
set-csonlinePSTNusage -Identity Global -Usage $null
Set-CsOnlinePstnUsage -Usage @{remove="PSTN Usage - US and Canada"}

#### add voice routes to PSTN Usage - US and Canada 
New-CsOnlineVoiceRoute -Identity "Redmond 1" -NumberPattern "^\+1(425|206)(\d{7})$" -OnlinePstnGatewayList sbc1.consoso.com -Priority 1 -OnlinePstnUsages "PSTN Usage - US and Canada"
New-CsOnlineVoiceRoute -Identity "Other +1" -NumberPattern "^\+1(\d{10})$" -OnlinePstnGatewayList sbc1.consoso.com -OnlinePstnUsages "PSTN Usage - US and Canada"

#Add PSTN Usage Internal
Set-CsOnlinePstnUsage -Identity Global -Usage @{Add="PSTN Usage - International"}
### create voice route for international and assigned to PSTN Usage - International
New-CsOnlineVoiceRoute -Identity "International" -NumberPattern ".*" -OnlinePstnGatewayList sbc1.consoso.com -OnlinePstnUsages "PSTN Usage - International"

### Voice Routing Policies US only
New-CsOnlineVoiceRoutingPolicy "US Only" -OnlinePstnUsages "PSTN Usage - US and Canada"
# Voice Routing Unrestricted with US and Canada and International PSTN Usages
New-CsOnlineVoiceRoutingPolicy "No Restrictions" -OnlinePstnUsages "PSTN Usage - US and Canada","PSTN Usage - International"

#### Grant voice routing policy to user #######
Grant-CsOnlineVoiceRoutingPolicy -Identity "AllanD@consoso.com" -PolicyName "US Only"

Grant-CsOnlineVoiceRoutingPolicy -Identity "AllanD@consoso.com" -PolicyName "No restrictions"

Get-CsOnlineUser "martin@consoso.com" | select OnlineVoiceRoutingPolicy


######### 7. Dial Plan Customization

### Create Custom Dial Plan ###################

#create normalizations rules
$nr1 = New-CsVoiceNormalizationRule -Identity Redmond/4DigitEx -Description "Redmond/4DigitEx" -Pattern '^(\d{4})$' -Translation '+1425555$1' -InMemory
$nr2 = New-CsVoiceNormalizationRule -Identity Redmond/5DigitEx -Description "Redmond/5DigitEx" -Pattern '^5(\d{4})$' -Translation '+1425555$1' -InMemory
$nr3 = New-CsVoiceNormalizationRule -Identity Redmond/7digitcalling -Description "Redmond/7digitcalling" -Pattern '^(\d{7})$' -Translation '+1425$1' -InMemory
$nr4 = New-CsVoiceNormalizationRule -Identity Redmond/RedmondOperator -Description "Redmond/RedmondOperator" -Pattern '^0$' -Translation '+14255550100' -InMemory
$nr5 = New-CsVoiceNormalizationRule -Identity Redmond/RRedmondSitePrefix -Description "Redmond/RedmondSitePrefix" -Pattern '^6222(\d{4})$' -Translation '+1425555$1' -InMemory
$nr6 = New-CsVoiceNormalizationRule -Identity Redmond/5digitRange -Description "Redmond/5digitRange" -Pattern '^([3-7]\d{4})$' -Translation '+142555$1' -InMemory
$nr7 = New-CsVoiceNormalizationRule -Identity Redmond/PrefixAdded -Description "Redmond/PrefixAdded" -Pattern '^([2-9]\d\d[2-9]\d{6})$' -Translation '1$1' -InMemory

#Add tenant dial plan with normalizations rules created above
New-CsTenantDialPlan -Identity RedmondDialPlan -Description "Dial Plan for Redmond" -NormalizationRules @{Add=$nr1,$nr2,$nr3,$nr4,$nr5,$nr6,$nr7} -SimpleName "Dial-Plan-for-Redmond"

#grant dialplan to user####
Grant-CsTenantDialPlan -PolicyName RedmondDialPlan -Identity AllanD@consoso.com

#####Get users Dial Plans
Get-CsEffectiveTenantDialPlan -Identity AllanD@consoso.com |fl

#Test effective dialplans
Test-CsEffectiveTenantDialPlan -DialedNumber 001447598732994 -Identity AllanD@consoso.com
Test-CsEffectiveTenantDialPlan -DialedNumber 7571 -Identity AllanD@consoso.com

#remove dialplan (if required)
Remove-CsTenantDialPlan -Identity RedmondDialPlan

### View Service Country dial plan (optional)
Get-CsDialPlan -Identity US
Get-CsDialPlan -Identity GB

#### Get Tenant dialplans
Get-CsTenantDialPlan



##CALL QUEUES ############################
#Resource Account Number assignment

#Make sure you dissociate the telephone number from the resource account before deleting it, to avoid getting your service number stuck in pending mode.
Remove-CsPhoneNumberAssignment -Identity "AA-Support-Attendant@consoso.com" -PhoneNumber +12319386241 -PhoneNumberType DirectRouting

#assign phone number to resoruce account
Set-CsPhoneNumberAssignment -Identity aa-contoso_main@contoso64.net -PhoneNumber +19295550150 -PhoneNumberType DirectRouting

Set-CsPhoneNumberAssignment -Identity aa-support-attendant@consoso.com -PhoneNumber +441785558198 -PhoneNumberType DirectRouting

#grant voice routing to call queue for dial out.
Grant-CsOnlineVoiceRoutingPolicy -Identity "AA-Support-Attendant@consoso.com" -PolicyName "No restrictions"





##### Music on Hold Preview #######

#The configuration of custom Music On Hold starts with uploading the audio file.
$content = Get-Content "C:\temp\customMoH1.mp3" -Encoding byte -ReadCount 0
$AudioFile = Import-CsOnlineAudioFile -FileName "customMoH1.mp3" -Content $content
$AudioFile

#reference the file in a Teams Call Hold Policy by using the Id of the file when you create or set a Teams Call Hold Policy
New-CsTeamsCallHoldPolicy -Identity "CustomMoH1" -Description "Custom MoH using CustomMoH1.mp3" -AudioFileId $AudioFile.Id

##grant it to your users using Grant-CsTeamsCallHoldPolicy as follows:
Grant-CsTeamsCallHoldPolicy -PolicyName "CustomMoH1" -Identity alexw@consoso.com





#### Block inbound calls
New-CsInboundBlockedNumberPattern -Name "BlockNumber1" -Enabled $True -Description "Block Fabrikam" -Pattern "^\+?14125551234$"

### remove blocked
Remove-CsInboundBlockedNumberPattern -Identity "BlockNumber1"

##view inbound calls
Get-CsInboundBlockedNumberPattern

##number expections
New-CsInboundExemptNumberPattern  -Identity "AllowContoso1" -Pattern "^\+?1312555888[2|3]$" -Description "Allow Contoso helpdesk" -Enabled $True





#### Teams Public Preview ####
New-CsTeamsUpdateManagementPolicy -Identity EnablePreview -AllowPublicPreview Enabled

Get-CsTeamsUpdateManagementPolicy

Grant-CsTeamsUpdateManagementPolicy -PolicyName EnablePreview -Identity AlexW@M365x881502.OnMicrosoft.com




#### Enable E2EE Policy

New-CsTeamsEnhancedEncryptionPolicy -Identity ContosoPartnerTeamsEnhancedEncryptionPolicy -CallingEndtoEndEncryptionEnabledType DisabledUserOverride
Set-CsTeamsEnhancedEncryptionPolicy -Identity "ContosoPartnerTeamsEnhancedEncryptionPolicy" -Description "allow useroverride"

Get-CsTeamsEnhancedEncryptionPolicy

Remove-CsTeamsEnhancedEncryptionPolicy -Identity ContosoPartnerTeamsEnhancedEncryptionPolicy

Grant-CsTeamsEnhancedEncryptionPolicy -PolicyName ContosoPartnerTeamsEnhancedEncryptionPolicy -Identity Admin@M365x881502.OnMicrosoft.com
Grant-CsTeamsEnhancedEncryptionPolicy -PolicyName ContosoPartnerTeamsEnhancedEncryptionPolicy -Identity AlexW@M365x881502.OnMicrosoft.com
Grant-CsTeamsEnhancedEncryptionPolicy -PolicyName ContosoPartnerTeamsEnhancedEncryptionPolicy -Identity AdeleV@M365x881502.OnMicrosoft.com

get-csonlineuser -Identity Alexw@M365x881502.OnMicrosoft.com



## Unassigned Number

$RAObjectId = (Get-CsOnlineApplicationInstance -Identity aa-hotline@consoso.com).ObjectId
New-CsTeamsUnassignedNumberTreatment -Identity MainAA -Pattern "^\+15102177790$" -TargetType ResourceAccount -Target $RAObjectId -TreatmentPriority 1

Set-CsTeamsUnassignedNumberTreatment -Identity MainAA -Description "Route Alex Number to AA"

Get-CsTeamsUnassignedNumberTreatment


$RAObjectId = (Get-CsOnlineApplicationInstance -Identity CQ-Support-Queue@consoso.com).ObjectId
New-CsTeamsUnassignedNumberTreatment -Identity CallingPlanCQ2 -Pattern "^\+16165000094$" -TargetType ResourceAccount -Target $RAObjectId -TreatmentPriority 4


###range
$Content = Get-Content "C:\temp\customMOH1.mp3" -Encoding byte -ReadCount 0

$AudioFile = Import-CsOnlineAudioFile -FileName "customMOH1.mp3" -Content $Content

$fid = [System.Guid]::Parse($AudioFile.Id)

New-CsTeamsUnassignedNumberTreatment -Identity AA -Pattern "^\+16165000094$" -TargetType Announcement -Target $fid.Guid -TreatmentPriority 1


##### Surface Hub Account creation
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -UserPrincipalName admin@m365x881502.onmicrosoft.com

New-Mailbox -Name "Conf Room Sweepers" -Alias Conf Room Sweepers -Room -EnableRoomMailboxAccount $true -MicrosoftOnlineServicesID sweepers@m365x881502.onmicrosoft.com -RoomMailboxPassword (ConvertTo-SecureString -String 'Pa55word' -AsPlainText -Force)

Set-CalendarProcessing -Identity "Conf Room Sweepers" -AutomateProcessing AutoAccept -AddOrganizerToSubject $false -DeleteComments $false -DeleteSubject $false -RemovePrivateProperty $false -AddAdditionalResponse $true -AdditionalResponse "This is a Teams room with Surface Hub!"

Connect-MsolService -Credential $cred
Set-MsolUser -UserPrincipalName Conf-Room-Sweepers@m365x881502.onmicrosoft.com -PasswordNeverExpires $true

Get-MsolAccountSku

Get-CalendarProcessing "Conf Room Sweepers" | fl AutomateProcessing
Get-CalendarProcessing "Conf Room Sweepers" | fl ProcessExternalMeetingMessages

Set-CalendarProcessing -Identity "Conf Room Sweepers" -ProcessExternalMeetingMessages $true
