#!/bin/bash
# Cloudflare API configuration
ZONE_ID="YOUR_ZONE_ID"
RECORD_ID="YOUR_RECORD_ID"
API_KEY="YOUR_API_TOKEN"
EMAIL="YOUR_EMAIL"
DOMAIN="example.com"
IP=$(curl -s http://ipv4.icanhazip.com)

# Webhooks and Email configuration
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
EMAIL_RECIPIENT="YOUR_EMAIL_RECIPIENT"
EMAIL_SUBJECT="DDNS Update Notification"

# DNS record update on Cloudflare
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
     -H "X-Auth-Email: $EMAIL" \
     -H "Authorization: Bearer $API_KEY" \
     -H "Content-Type: application/json" \
     --data '{"type":"A","name":"'"$DOMAIN"'","content":"'"$IP"'","ttl":1,"proxied":false}')

if [[ $(echo $RESPONSE | jq '.success') == "true" ]]; then
    MESSAGE="DDNS update successful for $DOMAIN to $IP"
else
    MESSAGE="DDNS update failed for $DOMAIN. Response: $RESPONSE"
fi

# Sending notifications
# Discord
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\":\"$MESSAGE\"}" \
     $DISCORD_WEBHOOK_URL

# Telegram
curl -X POST \
     https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage \
     -d chat_id=$TELEGRAM_CHAT_ID \
     -d text="$MESSAGE"

# Email
echo "$MESSAGE" | mail -s "$EMAIL_SUBJECT" $EMAIL_RECIPIENT

echo "Notifications have been sent."
