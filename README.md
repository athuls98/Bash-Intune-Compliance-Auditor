###### Intune Compliance Auditor ######

## Overview
A Bash-based Intune Compliance Auditor that uses Microsoft Graph API to retrieve Intune-managed devices and perform a device compliance check.
The bash script: 
* Authenticates to Microsoft Entra ID using OAuth2.0 client credentials.
* Uses Microsoft Graph API for retrieving managed-devices and compliance information from Microsoft Intune using curl.
* Processes the JSON responses with 'jq'.
* Terminal and CSV report.

The project is a hands-on lab using Bash Scripting, Microsoft Intune, Entra ID, Microsoft Graph, API Authentication, JSON parsing and Automation.

## Features

* Authenticates to Microsoft Graph using OAuth2.0 client credentials.
* Retrieves all Intune managed devices using curl.
* Multi-device support and compliance setting states.
* Lists compliant and non-compliant settings along with compliance percentage for each device.
* Detects synchronization of devices in hours and days.
* Device Status: ACTIVE or INACTIVE/STALE.
* A simple CSV report.
* Implemented curl,network connection, API error handling

## Architecture

Project's Flowchart:
```
Bash Script
  |
  v
Microsoft Entra ID
OAuth2.0 Client Credentials.
  |
  v
Retrieve Access Token
  |
  v
Microsoft Graph API
  |
  v
Microsoft Intune
  |
  v
Managed Devices and Compliance settings
  |
  v
jq for JSON Processing
  |
  +---> Terminal Display
  |
  +---> CSV Report
```

## Requirements

Bash,
Virtual Machines (QEMU/KVM),
curl,
jq,
Access to Microsoft Entra tenant,
Intune Licensing (30 day free trial),
App registration with Microsoft Graph permissions.

## Microsoft Graph Permissions

* DeviceManagementManagedDevices.Read.All
* DeviceManagementConfiguration.Read.All
Admin consent must be granted for these permissions. 
Application permission type to be used as bash script uses no interactive login.

https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0
https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-devicecompliancesettingstate-list?view=graph-rest-1.0

## Configuration

The config file is created outside project repository. Protected with chmod 600.
~/.config/intune-auditor/config.env

Contents:
TENANT_ID="Tenant_id"
CLIENT_ID="Client_id"
CLIENT_SECRET="Client_secret"
 
Loaded into bash using source command.

## Usage

Script Name: intune_audit.sh

chmod +x intune_audit.sh
./intune.audit.

## Example Output
```
INTUNE COMPLIANCE AUDITOR
~~~~~~~~~~~~~~~~~~~~~~~~~~

Device: DESKTOP-UMEJ8M1

SETTINGS                                      STATE          
--------------------------------------------- ---------      
RequireDeviceCompliancePolicyAssigned         compliant      
RequireRemainContact                          compliant      
RequireUserExistence                          compliant      
ActiveFirewallRequired                        compliant      
AntivirusRequired                             compliant      
BitLockerEnabled                              nonCompliant   

SUMMARY
=======
Compliant settings:     5
Non-compliant settings: 1
Compliance percentage:  83.3%
Last sync: 29 hours ago (1 days)
Device status:          ACTIVE

============================================================

Device: DESKTOP-JFEK1N5

SETTINGS                                      STATE          
--------------------------------------------- ---------      
RequireDeviceCompliancePolicyAssigned         compliant      
RequireRemainContact                          compliant      
RequireUserExistence                          compliant      
ActiveFirewallRequired                        compliant      
AntivirusRequired                             compliant      
BitLockerEnabled                              nonCompliant   

SUMMARY
=======
Compliant settings:     5
Non-compliant settings: 1
Compliance percentage:  83.3%
Last sync: 23 hours ago (0 days)
Device status:          ACTIVE

============================================================


The script also generates a simple csv report containing the summary.
Contents: 
"Device","CompliancePercentage","CompliantSettings","NonCompliantSettings","LastSyncHours","DeviceStatus"
"DESKTOP-UMEJ8M1","83.3","5","1","29","ACTIVE"
"DESKTOP-JFEK1N5","83.3","5","1","23","ACTIVE"
```

## Security Considerations

* Client secret is stored outside GIT repository in a config.env file.
* Credentials are loaded from the config file.
* Limited file permissions for the config file.
* Dynamic Access Token generation.
* Permissions for Microsoft Graph are set to read-only Intune access.
* Error handling for cases like network issues, HTTP, API issues. 


## Planned Improvements

Future improvements include:
* Pagination
* Automated Report Scheduling 
* Additional device and compliance properties.

## Version History

Current: v1.0

Focuses on Bash, multi-device compliance audit, inactive-device detection, Microsoft Graph Error Handling and CSV report.
