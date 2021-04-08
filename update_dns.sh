#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@studysplunk.club

# This script is desiged for the free tier of AWS 
# Problems being addressed: 
# 1. IP of instances changes on every restart
# 2. Instances need to be shut down to minimise costs
# 3. Splunk instances communcation breaks on restarts
# Solution: 
# Update DNS every 5 mins with current IPs of instance via a cron job
# This will allow Splunk servers to persist communications using DNS
# Add this script to each of your free tier aws instances

# Example Execution: sudo bash /home/ubuntu/update_dns.sh -s ssh
# Reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html

# Usage: sudo bash /home/ubuntu/update_dns.sh
# To run as CRON job every five minutes as root user see https://crontab-generator.org/
# Make script executable using chmod +x /home/ubuntu/update_dns.sh
# Add entry in cron file for root user using sudo crontab -e
# */5 * * * * sudo bash [scriptfolder]/update_dns.sh > [scriptfolder]/update_dns_last_cron_run.log
# example */5 * * * * sudo bash /home/ubuntu/update_dns.sh -s ssh> /home/ubuntu/update_dns_last_cron_run.log

#Apply script arguments
while getopts s: flag
do
    case "${flag}" in
        s) SSH_HOSTNAME=${OPTARG};;
    esac
done

# Prepare script variables
HOME_PATH=$(dirname $0)
DNS_ZONE="bsides.dns.splunkstudy.club"
UPDATE_TOKEN="4ztzt3fDWr2Yv1A26P5YWnQV4dGQUO7tN/fVM7QqBd0="
UPDATE_TOKEN_NAME="tsig-227759.dynv6.com"
UPDATE_TOKEN_TYPE="hmac-md5" 
DNS_SERVER="ns1.dynv6.com"
SERVER_INT_ADDR=`curl http://169.254.169.254/latest/meta-data/local-ipv4` || fail
SERVER_EXT_ADDR=`curl http://169.254.169.254/latest/meta-data/public-ipv4` || fail
AWS_INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id` || fail
DNS_CMD_FILE=$HOME_PATH"/update_dns_last_cmd.log"
DNS_LOG_FILE=$HOME_PATH"/update_dns.log"

# look up splunk hostname in Splunk config files
SERVER_FILE="/opt/splunk/etc/system/local/server.conf"
FORWARDER_FILE="/opt/splunkforwarder/etc/system/local/server.conf"

# Delete old command file if it exists
sudo rm -f $DNS_CMD_FILE || fail

# Append new command file with nsupdate commands
echo "Writing dnspdate commands to " $DNS_CMD_FILE
echo "server $DNS_SERVER" >> $DNS_CMD_FILE
echo "zone $DNS_ZONE" >> $DNS_CMD_FILE

if [ -f "$SERVER_FILE" ]; then
    echo "Splunk Server "$FILE" exists."
    # Read in the value for serverName from server.conf and convert to lower case for DNS update
    SPLUNK_SERVERNAME=`grep serverName /opt/splunk/etc/system/local/server.conf | sed 's/[ ][ ]*//g' | cut -c 12- | sed -e 's/\(.*\)/\L\1/'`    
    echo "update delete "$SPLUNK_SERVERNAME"-int."$DNS_ZONE" A" >> $DNS_CMD_FILE
    echo "update add "$SPLUNK_SERVERNAME"-int."$DNS_ZONE" 86400 A "$SERVER_INT_ADDR >> $DNS_CMD_FILE
    echo "update delete "$SPLUNK_SERVERNAME"-ext."$DNS_ZONE" A" >> $DNS_CMD_FILE
    echo "update add "$SPLUNK_SERVERNAME"-ext."$DNS_ZONE" 86400 A "$SERVER_EXT_ADDR >> $DNS_CMD_FILE

elif [ -f "$FORWARDER_FILE" ]; then
    echo "Splunk Forwarder "$FILE" exists."
    # Read in the value for serverName from server.conf and convert to lower case for DNS update
    SPLUNK_SERVERNAME=`sudo grep serverName /opt/splunkforwarder/etc/system/local/server.conf | sed 's/[ ][ ]*//g' | cut -c 12- | sed -e 's/\(.*\)/\L\1/'`
    echo "update delete "$SPLUNK_SERVERNAME"-int."$DNS_ZONE" A" >> $DNS_CMD_FILE
    echo "update add "$SPLUNK_SERVERNAME"-int."$DNS_ZONE" 86400 A "$SERVER_INT_ADDR >> $DNS_CMD_FILE
    echo "update delete "$SPLUNK_SERVERNAME"-ext."$DNS_ZONE" A" >> $DNS_CMD_FILE
    echo "update add "$SPLUNK_SERVERNAME"-ext."$DNS_ZONE" 86400 A "$SERVER_EXT_ADDR >> $DNS_CMD_FILE
else
    echo "Splunk Enterprise of Splunk Universal Forwarder is not installed under /opt/splunk or /opt/splunkforwarder"
fi
echo "update delete "$AWS_INSTANCE_ID"."$DNS_ZONE" A" >> $DNS_CMD_FILE
echo "update add "$AWS_INSTANCE_ID"."$DNS_ZONE" 86400 A "$SERVER_EXT_ADDR >> $DNS_CMD_FILE

if [ -z "$SSH_HOSTNAME" ]; then
    echo "No hostname specified for ssh"
else
    echo "update delete "$SSH_HOSTNAME"."$DNS_ZONE" A" >> $DNS_CMD_FILE
    echo "update add "$SSH_HOSTNAME"."$DNS_ZONE" 86400 A "$SERVER_EXT_ADDR >> $DNS_CMD_FILE
fi
echo "key "$UPDATE_TOKEN_TYPE":"$UPDATE_TOKEN_NAME" "$UPDATE_TOKEN >> $DNS_CMD_FILE
echo "send" >> $DNS_CMD_FILE

NOW=$(date +"%Y-%m-%d %T")
echo "Updating DNS Records for "$DNS_ZONE" on "$DNS_SERVER

# Execute nsupdates
nsupdate $DNS_CMD_FILE

# Display the nsupdate commands used for this update
echo "nsupdate commands have been logged to "$DNS_CMD_FILE" and will be overwritten next time script is executed"
echo "-------------------"
n=1
while read line; do
# reading each line
echo $line
n=$((n+1))
done < $DNS_CMD_FILE
echo "-------------------"

# Log nsupdates
EPOCH=`date +%s`
echo "Logging DNS Update to " $DNS_LOG_FILE
echo "UpdateTime="$EPOCH",AWS_INSTANCE_ID="$AWS_INSTANCE_ID",DNS_SERVER="$DNS_SERVER",DNS_EXT_NAME="$DNS_A_RECORD_EXT",DNS_EXT_IP="$SERVER_EXT_ADDR",DNS_INT_NAME="$DNS_A_RECORD_INT",DNS_INT_IP="$SERVER_INT_ADDR >> $DNS_LOG_FILE