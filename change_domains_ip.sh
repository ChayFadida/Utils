#!/bin/bash
## change to "bin/sh" when necessary

auth_email=""       # The email used to log in to 'https://dash.cloudflare.com'
auth_method="global"                        # Set to "global" for Global API Key or "token" for Scoped API Token
auth_key=""                                 # Your API Token or Global API Key
zone_identifier=""                          # Can be found in the "Overview" tab of your domain
ttl="3600"                                  # Set the DNS TTL (seconds)
proxy="true"                                # Set the proxy to true or false
sitename=""                                 # Title of the site "Example Site"
slackchannel=""                             # Slack Channel #example
slackuri=""                                 # URI for Slack WebHook "https://hooks.slack.com/services/xxxxx"
discorduri=""                               # URI for Discord WebHook "https://discordapp.com/api/webhooks/xxxxx"

# Check if there are at least two command-line arguments (email and API key)
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <email> <api_key> <zone_identifier> '<domain_list>'"
    exit 1
fi

# Set the email, API key, and zone identifier from command-line arguments
auth_email="$1"
auth_key="$2"
zone_identifier="$3"
domain_list="$4"

echo "$domain_list"

# Use a while loop to split the string
domain_array=($domain_list)

# Remove the first three arguments from the list of arguments
shift 3

###########################################
## Check if we have a public IP
###########################################
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
if [[ ! $ret == 0 ]]; then # In the case that Cloudflare failed to return an IP.
    # Attempt to get the IP from other websites.
    ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
else
    # Extract just the IP from the IP line from Cloudflare.
    ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
fi

# Use regex to check for proper IPv4 format.
if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
    logger -s "DDNS Updater: Failed to find a valid IP."
    exit 2
fi

###########################################
## Check and set the proper auth header
###########################################
if [[ "${auth_method}" == "global" ]]; then
    auth_header="X-Auth-Key:"
else
    auth_header="Authorization: Bearer"
fi

###########################################
## Loop through the domain names
###########################################
for record_name in "${domain_array[@]}"; do

    ###########################################
    ## Seek for the A record
    ###########################################

    logger "DDNS Updater: Check Initiated for $record_name"
    record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
        -H "X-Auth-Email: $auth_email" \
        -H "$auth_header $auth_key" \
        -H "Content-Type: application/json")

    ###########################################
    ## Check if the domain has an A record
    ###########################################
    if [[ $record == *"\"count\":0"* ]]; then
        echo -s "DDNS Updater: Record does not exist, perhaps create one first? (for ${record_name})"
        exit 1
    fi

    ###########################################
    ## Get existing IP
    ###########################################
    old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
    # Compare if they're the same
    if [[ $ip == $old_ip ]]; then
        echo "DDNS Updater: IP for ${record_name} has not changed."
        continue  # Continue to the next domain name
    fi

    ###########################################
    ## Set the record identifier from result
    ###########################################
    record_identifier=$(echo "$record" | sed -E 's/.*"id":"([A-Za-z0-9_]+)".*/\1/')

    ###########################################
    ## Change the IP@Cloudflare using the API
    ###########################################
    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
        -H "X-Auth-Email: $auth_email" \
        -H "$auth_header $auth_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":\"$ttl\",\"proxied\":${proxy}}")
    
    ###########################################
    ## Report the status
    ###########################################
    case "$update" in
    *"\"success\":false"*)
        echo -e "DDNS Updater: $ip $record_name DDNS failed for $record_identifier. DUMPING RESULTS:\n$update" | logger -s
        if [[ $slackuri != "" ]]; then
            curl -L -X POST $slackuri \
                --data-raw '{
                  "channel": "'$slackchannel'",
                  "text" : "'"$sitename"' DDNS Update Failed: '$record_name': '$record_identifier' ('$ip')."
                }'
        fi
        if [[ $discorduri != "" ]]; then
            curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST \
                --data-raw '{
                  "content" : "'"$sitename"' DDNS Update Failed: '$record_name': '$record_identifier' ('$ip')."
                }' $discorduri
        fi
        exit 1;;
    *)
        echo "DDNS Updater: $record_name DDNS updated."
        if [[ $slackuri != "" ]]; then
            curl -L -X POST $slackuri \
                --data-raw '{
                  "channel": "'$slackchannel'",
                  "text" : "'"$sitename"' Updated: '$record_name''"'"'s'""' new IP Address is '$ip'"
                }'
        fi
        if [[ $discorduri != "" ]]; then
            curl -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST \
                --data-raw '{
                  "content" : "'"$sitename"' Updated: '$record_name''"'"'s'""' new IP Address is '$ip'"
                }' $discorduri
        fi
        ;;
    esac

done