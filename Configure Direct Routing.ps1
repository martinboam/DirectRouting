####################################################################################################

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
Set-CsUser -Identity "AllanD@consoso.com" -EnterpriseVoiceEnabled $true -HostedVoiceMail $true

##########If managing the user's phone number online, issue the command###
Set-CsUser -Identity "AllanD@consoso.com" -EnterpriseVoiceEnabled $true -HostedVoiceMail $true -OnPremLineURI tel:+15102177792

######## add Ext (Optional) #####
Set-CsUser -Identity "martin@consoso.com" -OnPremLineURI "tel:+14255388701;ext=1001" -EnterpriseVoiceEnabled $true -HostedVoiceMail $true
Set-CsUser -Identity "bob@consoso.com" -OnPremLineURI "tel:+14255388701;ext=1002" -EnterpriseVoiceEnabled $true -HostedVoiceMail $true




#### 5. Stale Script Check https://msunified.net/category/lync-server-2013/troubleshooting-lync-server-2013/
Get-CsOnlineUser martin@consoso.com | Format-List UserPrincipalName, DisplayName, SipAddress, Enabled, TeamsUpgradeEffectiveMode, EnterpriseVoiceEnabled, HostedVoiceMail, City, UsageLocation, DialPlan, TenantDialPlan, OnlineVoiceRoutingPolicy, LineURI, OnPremLineURI, OnlineDialinConferencingPolicy, TeamsVideoInteropServicePolicy, TeamsCallingPolicy, HostingProvider, InterpretedUserType, VoicePolicy, CountryOrRegionDisplayName


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

Get-CsOnlineUser "AllanD@consoso.com" | select OnlineVoiceRoutingPolicy





#####Dial Plans
Get-CsEffectiveTenantDialPlan -Identity AllanD@consoso.com |fl

Test-CsEffectiveTenantDialPlan -DialedNumber 001447590032994 -Identity AllanD@consoso.com
Test-CsEffectiveTenantDialPlan -DialedNumber 7571 -Identity AllanD@consoso.com







##CALL QUEUES ############################
#Resource Account Number assignment
Set-CsOnlineApplicationInstance -Identity cq-marketing@consoso.com -OnpremPhoneNumber +15102177793

Set-CsOnlineApplicationInstance -Identity aa-support-attendant@consoso.com 

Get-CsOnlineApplicationInstance -Identity cq-support-queue@consoso.com

#grant voice routing to call queue for dial out.
Grant-CsOnlineVoiceRoutingPolicy -Identity "cq-marketing@consoso.com" -PolicyName "No restrictions"










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
