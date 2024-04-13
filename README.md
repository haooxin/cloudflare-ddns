# Cloudflare DDNS

## About
This script is used to update Dynamic DNS (DDNS) service based on Cloudflare! Access your home network remotely via a custom domain name without a static IP!
- DDNS Cloudflare Bash Script for most **Linux** distributions.
- Cloudflare's options configurable.
- Discord, Telegram and Email Notifications


## Requirements:
- A Cloudflare account and a domain for which you want to set up DDNS.
- An API key from Cloudflare.
- `curl` and `jq` installed on your Linux system (for making API requests and parsing JSON responses).

## Important Notes:
1. **Security**: Never share your API keys, tokens, or other sensitive data. Be careful not to place them in publicly accessible locations.
2. **Dependencies**: Ensure you have `curl` and `jq` installed, as well as a configured and working mail system (sendmail, postfix, etc.) on your server.
3. **Testing**: Before deploying and automating, thoroughly test the script to ensure that all components are working correctly.

## Here are two ways to authenticate requests to the Cloudflare API:
### Using the Global API Key:
If you use the Global API Key, you need to include two headers in the request: `X-Auth-Email` and `X-Auth-Key`. Ensure you provide the correct email address associated with your Cloudflare account and your Global API Key.

`curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" -H "X-Auth-Email: YOUR_EMAIL" -H "X-Auth-Key: YOUR_GLOBAL_API_KEY" -H "Content-Type: application/json"`

### Using an API Token:
If you decide to use an API token, you will need only one header: Authorization, to which you will attach the API token preceded by the word `Bearer`.

`curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" -H "Authorization: Bearer YOUR_API_TOKEN" -H "Content-Type: application/json"`

In both cases, replace `YOUR_ZONE_ID`, `YOUR_EMAIL`, `YOUR_GLOBAL_API_KEY`, or `YOUR_API_TOKEN` with the appropriate values for your account and domain.

### Diagnostics and Troubleshooting: 
- **Ensure you are using correct data**: Check if the email address and API key are correct and belong to the account holder of Cloudflare you are trying to use. 
- **Check the validity of the API token**: If using an API token, ensure it has the necessary permissions to perform operations on DNS records. 
- **Use the correct headers**: According to the error message, ensure that your request uses either `X-Auth-Email` and `X-Auth-Key` headers, or the Authorization header with a correct API token. 
- **Check for typos**: Ensure there are no typos or extra spaces in the headers that could disrupt the authorization process.

# Usage
## Step 1: Obtain a Cloudflare API Key
1. Log in to your Cloudflare account.
2. Go to the “My Profile” section.
3. Find the “API Tokens” section and generate a new token with the appropriate permissions, or use your Global API Key.

## Step 2: Find Zone ID and Record ID
To update a DNS record, you need the Zone ID of your domain and the Record ID of the record you want to update.
1. **Finding Zone ID:**
    - You can find the Zone ID in the Cloudflare dashboard for your domain, in the “Overview” section.
2. **Finding Record ID:**    
    - Use the following command, replacing YOUR_ZONE_ID, YOUR_EMAIL, and YOUR_API_KEY with your values.
    
    `curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" -H "X-Auth-Email: YOUR_EMAIL" -H "Authorization: Bearer YOUR_API_KEY" -H "Content-Type: application/json"`
   
    - Review the response to find the ID of the record you want to update.

## Step 3: DDNS Update Script 
Before running, configure the `cloudflare_ddns.sh` script according to your personal requirements.
### Configuration
#### Cloudflare API
```sh
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
```
#### Notifications
```sh
# Webhooks and Email configuration
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"
TELEGRAM_BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
EMAIL_RECIPIENT="YOUR_EMAIL_RECIPIENT"
EMAIL_SUBJECT="DDNS Update Notification"

# User notification preferences
NOTIFICATION_ENABLE_DISCORD=false    	# Set to false to disable Discord notifications
NOTIFICATION_ENABLE_TELEGRAM=false  	# Set to false to disable Telegram notifications
NOTIFICATION_ENABLE_EMAIL=false     	# Set to false to disable Email notifications
NOTIFICATION_SECURE_PUBLIC_IP=true  	# value true limits display of public ip in notifications,
					# value false displays old and new public ip address
```
## Step 4: Grant Execution Permissions and Run the Script 
1. Grant execution permissions to the script: `chmod +x cloudflare_ddns.sh`
2. Run the script to update the DNS record: `./cloudflare_ddns.sh`
## Step 5: Automation with Cron
To have the script run automatically, you can add it to crontab:
1. Open crontab: `crontab -e`
2. Add a line to crontab to have the script run hourly (you can adjust the frequency):
    `0 * * * * /path/to/cloudflare_ddns.sh`
Example with adding messages with date to *.log file using cron, the script executes every 15min:
```sh
*/15 * * * * /path/to/cloudflare_ddns.sh | while IFS= read -r line; do echo "$(date) - $line"; done >> /path/to/cloudflare_ddns.log
```
 
```bash
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday 7 is also Sunday on some systems)
# │ │ │ │ │ ┌───────────── command to issue                               
# │ │ │ │ │ │
# │ │ │ │ │ │
# * * * * * /bin/bash {Location of the script}
```

# Notifications
## 1. Discord Webhook
Create a Webhook on Discord:
- Go to your Discord server settings, select “Integrations”, and then “Webhooks”.
- Create a new webhook and copy its URL.
- Send a message using the webhook:
    - Use the following command, replacing `WEBHOOK_URL` with the webhook URL and `YOUR_MESSAGE` with your message.
    
    `curl -H "Content-Type: application/json" -X POST -d '{"content":"YOUR_MESSAGE"}' WEBHOOK_URL`
    
## 2. Telegram Bot
1. Create a Bot on Telegram:
	- Use BotFather on Telegram to create a new bot. You will receive an API token.
2. Send a message using the bot:
    - Find the chat_id by sending a message to the bot and visiting `https://api.telegram.org/bot<TOKEN>/getUpdates`.
    - Use the following command, replacing `<TOKEN>` with the bot’s token, `<CHAT_ID>` with the chat identifier, and `YOUR_MESSAGE` with your message.
    
    `curl -X POST https://api.telegram.org/bot<TOKEN>/sendMessage -d chat_id=<CHAT_ID> -d text="YOUR_MESSAGE"`
## 3. Email
To send emails, you can use the `email` program available on most Unix/Linux systems. However, you must have a mail client configured on your server (e.g. `sendmail` or `postfix`).
1. Send an email:
	- Use the following command, replacing `RECIPIENT_EMAIL` with the recipient's email address, `SUBJECT` with the subject of the message, and `YOUR_MESSAGE` with the content of the message.
	    `echo "YOUR_MESSAGE" | mail -s "SUBJECT" RECIPIENT_EMAIL`
