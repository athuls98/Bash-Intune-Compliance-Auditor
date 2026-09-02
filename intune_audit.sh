#!/usr/bin/env bash


#Load tenant ID, client ID, and client secret from the config file
source ~/.config/intune-auditor/config.env

csv_file="Intune_Compliance_Report.csv"
printf '"Device","CompliancePercentage","CompliantSettings","NonCompliantSettings","LastSyncHours","DeviceStatus"\n' > "$csv_file"

#Requesting an Oauth2.0 Access Token from Entra ID
OAuth_response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
	-d "client_id=$CLIENT_ID"\
	-d "client_secret=$CLIENT_SECRET"\
        -d "scope=https://graph.microsoft.com/.default"\
	-d "grant_type=client_credentials")


#Extracting only the access token from the OAuth Response
ACCESS_TOKEN=$(echo "$OAuth_response" | jq -r .access_token) #Gives raw string by removing the quotes
if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
    echo "Error: Failed to obtain access token from Microsoft Graph."
    exit 1
fi



#API/ERROR HANDLING
graph_get() 
{
	local url="$1"
	local file_name="$2"
	local http_code

	http_code=$(curl -s -w "%{http_code}" -o "$file_name" \
    			-H "Authorization: Bearer $ACCESS_TOKEN" \
			"$url")

	local curl_status=$?

	#Check for Network Error
	if [[ $curl_status != 0 ]];then
		echo "Error: Unable to reach Microsoft Graph"
		return 1
	fi

	#Check for API/Authorization error
	if [[ "$http_code" != "200" ]]; then
    	echo "Error: Microsoft Graph request failed with HTTP $http_code"
    	cat "$file_name"
    	return 1
	fi
}


graph_get "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices" "device_response.json" || exit 1 
device_response=$(cat device_response.json)

#Requesting Intune all device details from Microsoft Graph.
all_devices=$(echo "$device_response" | jq -r '.value[] | [.id,.deviceName,.lastSyncDateTime] | @tsv')


printf "\nINTUNE COMPLIANCE AUDITOR\n"
printf "~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n"


#Requesting summaries for all Intune compliance settings and extracting each compliance-setting summary ID.
while IFS=$'\t' read -r device_id device_name last_sync;
do
	graph_get "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicySettingStateSummaries" "summary_response.json"
	summary_response=$(cat summary_response.json)
	SUMMARY_IDS="$(echo "$summary_response" | jq -r '.value[].id')"
	counter=0
	ncounter=0
printf "Device: %s\n\n" "$device_name"
printf "%-45s %-15s\n" "SETTINGS" "STATE"
printf "%-45s %-15s\n" "---------------------------------------------" "---------"


	while read -r summary_id;
	do	
		graph_get "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicySettingStateSummaries/$summary_id/deviceComplianceSettingStates" "setting_response.json"
		setting_response=$(cat setting_response.json)
 		result=$(echo "$setting_response" | jq -r --arg jq_device_id "$device_id" '.value[]| select(.deviceId == $jq_device_id)| [(.settingName | split(".") | last),.state]| @tsv')
		if [[ -n "$result" ]];then
			IFS=$'\t' read -r settings state <<< "$result"
    			printf "%-45s %-15s\n" "$settings" "$state"
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


epoch=$(date -d "$last_sync" +%s)
current_epoch_time=$(date +%s)


seconds_since_sync=$((current_epoch_time - epoch))
hours_since_sync=$((seconds_since_sync / 3600))
days_since_sync=$((seconds_since_sync / 86400))

if (( days_since_sync >= 30 )); then
    device_status="INACTIVE/STALE"
else
    device_status="ACTIVE"
fi

printf '"%s","%s","%s","%s","%s","%s"\n' \
"$device_name" "$comp_percentage" "$counter" "$ncounter" "$hours_since_sync" "$device_status" >> "$csv_file"

printf "\nSUMMARY\n"
printf "=======\n"

printf "Compliant settings:     %d\n" "$counter"
printf "Non-compliant settings: %d\n" "$ncounter"
printf "Compliance percentage:  %s%%\n" "$comp_percentage"

printf "Last sync: %d hours ago (%d days)\n" \
    "$hours_since_sync" "$days_since_sync"
printf "Device status:          %s\n" "$device_status"
printf "\n============================================================\n\n"
done <<< "$all_devices"
