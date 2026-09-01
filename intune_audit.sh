#!/usr/bin/env bash


#Load tenant ID, client ID, and client secret from the config file
source ~/.config/intune-auditor/config.env

#Requesting an Oauth2.0 Access Token from Entra ID
OAuth_response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
	-d "client_id=$CLIENT_ID"\
	-d "client_secret=$CLIENT_SECRET"\
        -d "scope=https://graph.microsoft.com/.default"\
	-d "grant_type=client_credentials")

#Extracting only the access token from the OAuth Response
ACCESS_TOKEN=$(echo "$OAuth_response" | jq -r .access_token) #Gives raw string by removing the quotes


#Requesting Intune device details from Microsoft Graph and extracting the managed DEVICE ID
device_response=$(curl -s -X GET "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices" \
	-H "Authorization: Bearer $ACCESS_TOKEN")
DEVICE_ID="$(echo "$device_response" | jq -r '.value[].id')"
DEVICE_NAME=$(echo "$device_response" | jq -r '.value[0].deviceName') 
SYNC_TIME="$(echo "$device_response" | jq -r '.value[].lastSyncDateTime')"

#Requesting summaries for all Intune compliance settings and extracting each compliance-setting summary ID.
summary_response=$(curl -s "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicySettingStateSummaries" \
  -H "Authorization: Bearer $ACCESS_TOKEN")
SUMMARY_IDS="$(echo "$summary_response" | jq -r '.value[].id')"

#Read one compliance-setting summary ID at a time
#LOOPING THROUGH COMPLIANCE SUMMARY_IDS with DEVICE_ID as the filter
counter=0
ncounter=0

printf "\nINTUNE COMPLIANCE AUDITOR\n"
printf "==========================\n\n"

printf "Device: %s\n\n" "$DEVICE_NAME"

printf "%-45s %-15s\n" "SETTING" "STATE"
printf "%-45s %-15s\n" "---------------------------------------------" "---------------"


while read -r summary_id;do	
	setting_response=$(curl -s "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicySettingStateSummaries/$summary_id/deviceComplianceSettingStates" \
	-H "Authorization: Bearer $ACCESS_TOKEN") 
 	result=$(echo "$setting_response" | jq -r --arg DEVICE_ID "$DEVICE_ID" '.value[]| select(.deviceId == $DEVICE_ID)| [(.settingName | split(".") | last),.state]| @tsv')
if [[ -n "$result" ]];then
	IFS=$'\t' read -r setting state <<< "$result"
    	printf "%-45s %-15s\n" "$setting" "$state"
fi


#Increasing counter after Compliance Check
if [[ "$state" == "compliant" ]]; then
            ((counter++))

        elif [[ "$state" == "nonCompliant" ]]; then
            ((ncounter++))
fi
done <<< "$SUMMARY_IDS"

total=$((counter+ncounter))
if ((total > 0)); then
	comp_percentage=$(awk -v c="$counter" -v t="$total" \
	 'BEGIN { printf "%.1f", (c / t) * 100 }')
else
	comp_percentage="0.0%"
fi


epoch=$(date -d "$SYNC_TIME" +%s)
current_epoch_time=$(date +%s)


seconds_since_sync=$((current_epoch_time - epoch))
hours_since_sync=$((seconds_since_sync / 3600))
days_since_sync=$((seconds_since_sync / 86400))

if (( days_since_sync >= 30 )); then
    device_status="INACTIVE/STALE"
else
    device_status="ACTIVE"
fi



printf "\nSUMMARY\n"
printf "=======\n"

printf "Compliant settings:      %d\n" "$counter"
printf "Non-compliant settings:  %d\n" "$ncounter"
printf "Compliance percentage:   %s%%\n" "$comp_percentage"

printf "Last sync: %d hours ago (%d days)\n" \
    "$hours_since_sync" "$days_since_sync"
printf "Device status:           %s\n" "$device_status"

