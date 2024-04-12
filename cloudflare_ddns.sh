#!/bin/bash
# Cloudflare API configuration
ZONE_ID="YOUR_ZONE_ID"
RECORD_ID="YOUR_RECORD_ID"
API_KEY="YOUR_API_TOKEN"
EMAIL="YOUR_EMAIL"
DOMAIN="example.com"
IP=$(curl -s http://ipv4.icanhazip.com)

# DNS record configuration set by the user
TTL=1                # TTL value, set by user, default to 1 (auto)
PROXIED=true         # Set true to proxy through Cloudflare, false to disable

# Webhooks and Email configuration
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
EMAIL_RECIPIENT="YOUR_EMAIL_RECIPIENT"
EMAIL_SUBJECT="DDNS Update Notification"

# User notification preferences
NOTIFICATION_ENABLE_DISCORD=false    # Set to false to disable Discord notifications
NOTIFICATION_ENABLE_TELEGRAM=false  # Set to false to disable Telegram notifications
NOTIFICATION_ENABLE_EMAIL=false     # Set to false to disable Email notifications
NOTIFICATION_SECURE_PUBLIC_IP=true  # value true limits display of public ip in notifications, value false displays old and new public ip address

# Check for empty IP
if [[ -z "$IP" ]]; then
    echo "Failed to retrieve public IP for $DOMAIN."
    exit 1
fi

# Check current DNS record in Cloudflare
RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $API_KEY" \
    -H "X-Auth-Email: $EMAIL" \
    -H "Content-Type: application/json")

CURRENT_IP=$(echo "$RECORD_INFO" | jq -r '.result.content')
CURRENT_TTL=$(echo "$RECORD_INFO" | jq -r '.result.ttl')
CURRENT_PROXIED=$(echo "$RECORD_INFO" | jq -r '.result.proxied')

# Initialize a message to log changes
CHANGE_LOG="Detected changes for $DOMAIN:"

# Compare current record settings with new settings and log changes
if [[ "$CURRENT_IP" != "$IP" ]]; then
    if [[ "$NOTIFICATION_SECURE_PUBLIC_IP" == "false" ]]; then
        CHANGE_LOG+=" IP updated from $CURRENT_IP to $IP."
    else
        CHANGE_LOG+=" IP updated."
    fi
fi

if [[ "$CURRENT_TTL" != "$TTL" ]]; then
    CHANGE_LOG+=" TTL updated from $CURRENT_TTL to $TTL."
fi

if [[ "$CURRENT_PROXIED" != "$PROXIED" ]]; then
    CHANGE_LOG+=" Proxied status changed from $CURRENT_PROXIED to $PROXIED."
fi

# Check if any changes were detected
if [[ "$CURRENT_IP" == "$IP" ]] && [[ "$CURRENT_TTL" == "$TTL" ]] && [[ "$CURRENT_PROXIED" == "$PROXIED" ]]; then
    echo "No changes detected for $DOMAIN. No update required."
    exit 0
fi

# DNS record update on Cloudflare
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
     -H "X-Auth-Email: $EMAIL" \
     -H "Authorization: Bearer $API_KEY" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$IP\",\"ttl\":$TTL,\"proxied\":$PROXIED}")

if [[ $(echo $RESPONSE | jq '.success') == "true" ]]; then
    MESSAGE="DDNS update successful: $CHANGE_LOG"
    EMBED_COLOR=65280  # Green
else
    ERROR=$(echo $RESPONSE | jq -r '.errors[] | .message')
    MESSAGE="DDNS update failed for $DOMAIN. Error: $ERROR $CHANGE_LOG"
    EMBED_COLOR=16711680  # Red
fi

# Sending notifications
if $NOTIFICATION_ENABLE_DISCORD; then
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"embeds\": [{\"title\": \"DDNS Update Notification\", \"description\": \"$MESSAGE\", \"color\": $EMBED_COLOR}]}" \
         $DISCORD_WEBHOOK_URL
fi

if $NOTIFICATION_ENABLE_TELEGRAM; then
    curl -X POST \
         https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage \
         -d chat_id=$TELEGRAM_CHAT_ID \
         -d parse_mode="Markdown" \
         -d text="*DDNS Update Notification*\n$MESSAGE"
fi

if $NOTIFICATION_ENABLE_EMAIL; then
    echo "<html><body><h1>DDNS Update Notification</h1><p>$MESSAGE</p></body></html>" | mail -s "$EMAIL_SUBJECT" -a "Content-type: text/html;" $EMAIL_RECIPIENT
fi

printf "\nNotifications have been sent.\n"
