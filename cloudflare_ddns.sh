#!/bin/bash
VERSION="v2024.4.7"      # Script version

# Cloudflare API configuration
CF_ZONE_ID="YOUR_ZONE_ID"
CF_RECORD_ID="YOUR_RECORD_ID"
CF_API_KEY="YOUR_API_TOKEN"
CF_EMAIL="YOUR_EMAIL"
CF_DOMAIN="example.com"
PUBLIC_IP=$(curl -s http://ipv4.icanhazip.com)

# DNS record configuration set by the user
CF_DNS_TTL=1                 # TTL value, set by user, default to 1 (auto)
CF_DNS_PROXIED=true        # Set true to proxy through Cloudflare, false to disable

# Webhooks and Email configuration
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
SLACK_WEBHOOK_URL="YOUR_SLACK_WEBHOOK_URL"
EMAIL_RECIPIENT="YOUR_EMAIL_RECIPIENT"
EMAIL_SUBJECT="DDNS Update Notification"

# User notification preferences
NOTIFICATION_ENABLE_DISCORD=false    # Set to false to disable Discord notifications
NOTIFICATION_ENABLE_TELEGRAM=false  # Set to false to disable Telegram notifications
NOTIFICATION_ENABLE_SLACK=false     # Set to false to disable Slack notifications
NOTIFICATION_ENABLE_EMAIL=false     # Set to false to disable Email notifications
NOTIFICATION_SECURE_PUBLIC_IP=true  # value true limits display of public ip in notifications, value false displays old and new public ip address

# Log file configuration
LOG_FILE="/path/to/cloudflare_ddns_bifrost.log"  # Full path to logfile.
MAX_LOG_ENTRIES=288

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
    echo "$1"
    # Keep only the last 10 lines in the log file
    tail -n $MAX_LOG_ENTRIES $LOG_FILE > temp_log_file
    mv temp_log_file $LOG_FILE
}

# Check for empty IP
if [[ -z "$PUBLIC_IP" ]]; then
    log_message "Failed to retrieve public IP for $CF_DOMAIN."
    exit 1
fi

# Check current DNS record in Cloudflare
RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
    -H "Authorization: Bearer $CF_API_KEY" \
    -H "Content-Type: application/json")

CURRENT_CF_PUBLIC_IP=$(echo "$RECORD_INFO" | jq -r '.result.content')
CURRENT_CF_DNS_TTL=$(echo "$RECORD_INFO" | jq -r '.result.ttl')
CURRENT_CF_DNS_PROXIED=$(echo "$RECORD_INFO" | jq -r '.result.proxied')

# Initialize a message to log changes
CHANGE_LOG="Detected changes for $CF_DOMAIN:"

# Compare current record settings with new settings and log changes
if [[ "$CURRENT_CF_PUBLIC_IP" != "$PUBLIC_IP" ]]; then
    if [[ "$NOTIFICATION_SECURE_PUBLIC_IP" == "false" ]]; then
        CHANGE_LOG+=" IP updated from $CURRENT_CF_PUBLIC_IP to $PUBLIC_IP."
        CHANGE_NOTIFICATION+="- IP updated from $CURRENT_CF_PUBLIC_IP to $PUBLIC_IP.\n"
    else
        CHANGE_LOG+=" IP updated."
        CHANGE_NOTIFICATION+="- IP updated.\n"
    fi
fi

if [[ "$CURRENT_CF_DNS_TTL" != "$CF_DNS_TTL" ]]; then
    CHANGE_LOG+=" CF_DNS_TTL updated from $CURRENT_CF_DNS_TTL to $CF_DNS_TTL."
    CHANGE_NOTIFICATION+="- CF_DNS_TTL updated from $CURRENT_CF_DNS_TTL to $CF_DNS_TTL.\n"
fi

if [[ "$CURRENT_CF_DNS_PROXIED" != "$CF_DNS_PROXIED" ]]; then
    CHANGE_LOG+=" PROXIED status changed from $CURRENT_CF_DNS_PROXIED to $CF_DNS_PROXIED."
    CHANGE_NOTIFICATION+="- PROXIED status changed from $CURRENT_CF_DNS_PROXIED to $CF_DNS_PROXIED.\n"
fi


# Check if any changes were detected
if [[ "$CURRENT_CF_PUBLIC_IP" == "$PUBLIC_IP" ]] && [[ "$CURRENT_CF_DNS_TTL" == "$CF_DNS_TTL" ]] && [[ "$CURRENT_CF_DNS_PROXIED" == "$CF_DNS_PROXIED" ]]; then
    log_message "No changes detected for $CF_DOMAIN. No update required."
    exit 0
fi

# DNS record update on Cloudflare
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" \
        -H "Authorization: Bearer $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$CF_DOMAIN\",\"content\":\"$PUBLIC_IP\",\"TTL\":$CF_DNS_TTL,\"CF_DNS_PROXIED\":$CF_DNS_PROXIED}")

if [[ $(echo $RESPONSE | jq '.success') == "true" ]]; then
    MESSAGE="DDNS update successful: $CHANGE_LOG"
    NOTIFICATION_MESSAGE="DDNS update **successful**: \n$CHANGE_NOTIFICATION"
    log_message "$MESSAGE"
    EMBED_COLOR=65280  # Green
else
    ERROR=$(echo $RESPONSE | jq -r '.errors[] | .message')
    MESSAGE="DDNS update failed for $CF_DOMAIN. Error: $ERROR $CHANGE_LOG"
    NOTIFICATION_MESSAGE="DDNS update **failed** for $CF_DOMAIN. Error: $ERROR $CHANGE_LOG"
    log_message "$MESSAGE"
    EMBED_COLOR=16711680  # Red
fi

# Sending notifications
if $NOTIFICATION_ENABLE_DISCORD; then
    curl -H "Content-Type: application/json" \
        -X POST \
        -d "{\"embeds\": [
            {
                \"title\": \"DDNS Update Notification\", 
                \"description\": \"$NOTIFICATION_MESSAGE\", 
                \"footer\": {\"text\": \"Version: $VERSION\"},
                \"color\": $EMBED_COLOR, 
                \"fields\": [
                    {
                    \"name\": \"Domain:\",
                    \"value\": \"$CF_DOMAIN\",
                    \"inline\": true
                    },
                    {
                    \"name\": \"Timestamp:\",
                    \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
                    \"inline\": true
                    }]
            }]}" \
        $DISCORD_WEBHOOK_URL
fi

if $NOTIFICATION_ENABLE_TELEGRAM; then
    TELEGRAM_MESSAGE=$(echo -e "$NOTIFICATION_MESSAGE" | sed 's/\n/%0A/g')
    curl -X POST \
        https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage \
        -d chat_id=$TELEGRAM_CHAT_ID \
        -d parse_mode="Markdown" \
        -d text="*DDNS Update Notification*%0A%0A$TELEGRAM_MESSAGE%0A%0A*Domain:* $CF_DOMAIN%0A*Timestamp:* $(date '+%Y-%m-%d %H:%M:%S')%0A*Version:* $VERSION"
fi
    
if $NOTIFICATION_ENABLE_SLACK; then
    curl -s -X POST -H 'Content-type: application/json' \
        --data '{"text":"*DDNS Update Notification* '"$MESSAGE"'"}' \
        $SLACK_WEBHOOK_URL
fi

if $NOTIFICATION_ENABLE_EMAIL; then
    echo "<html><body><h1>DDNS Update Notification</h1><p>$MESSAGE</p></body></html>" | mail -s "$EMAIL_SUBJECT" -a "Content-type: text/html;" $EMAIL_RECIPIENT
fi

log_message "Notifications have been sent."
