#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@cummins.me
# https://github.com/SplunkStudyClub/splunk-on-aws
# Example usage
# sudo bash deploy_splunk_enterprise.sh -p /opt -h sh01 -v 8.1.2 -b 545206cc9f70 -c true -d true -s true
# Script is coded for x86_64 on Linux. This can be updated as necessary

#Apply script arguments
echo "Number of parameters passed to this script is $#"
while getopts p:h:v:b:c:d:s: flag
do
    case "${flag}" in
        p) SPLUNK_PARENT_FOLDER=${OPTARG};;
        h) SPLUNK_SERVER_NAME=${OPTARG};;
        v) SPLUNK_SERVER_VERSION=${OPTARG};;
        b) SPLUNK_SERVER_BUILD=${OPTARG};;
        c) CREATE_DNS_CRON_JOB=${OPTARG};;
        d) UPDATE_DNS=${OPTARG};;
        s) SLIM_DOWN=${OPTARG};;
   esac
done

# Prepare script variables
SCRIPT_ABSOLUTE_PATH=$(dirname $(readlink -f $0))
SCRIPT_NAME=${0##*/}
echo "SCRIPT_ABSOLUTE_PATH="$SCRIPT_ABSOLUTE_PATH
SPLUNK_INSTALLER="splunk-"$SPLUNK_SERVER_VERSION"-"$SPLUNK_SERVER_BUILD"-Linux-x86_64.tgz"
SPLUNK_HOME=$SPLUNK_PARENT_FOLDER"/splunk"
SERVER_CONF=$SPLUNK_HOME"/etc/system/local/server.conf"
REMOTE_SERVER_APP_FOLDER=$SPLUNK_HOME"/etc/apps"
INDEXES_CONF=$SPLUNK_PARENT_FOLDER"/splunk/etc/system/local/indexes.conf"
DNS_UPDATE_SCRIPT=$SCRIPT_ABSOLUTE_PATH"/update_splunk_dns.sh"
DNS_LOG_FILE=$SCRIPT_ABSOLUTE_PATH"/update_splunk_dns.log"
SPLUNK_PLATFORM="linux"
SPLUNK_ARCHITECTURE="x86_64"
SPLUNK_PRODUCT="splunk"

# Displaying the last modified time of scripts can be useful to avoid confusion when updating and testing
echo "======================================================================================================================================="
echo $(clear)
LAST_MODIFIED_DATE_EPOCH=$(stat -c %Y $SCRIPT_ABSOLUTE_PATH"/"$SCRIPT_NAME)
LAST_MODIFIED_DATE=$(date -d @$LAST_MODIFIED_DATE_EPOCH)
echo "Script Last Modified:" $LAST_MODIFIED_DATE "("$SCRIPT_ABSOLUTE_PATH"/"$SCRIPT_NAME")"
echo "======================================================================================================================================="

# Check if Splunk is already deployed
# This is to prevent an existing Splunk instance being overwritten by mistake
# To remove and existing instance the following commands are useful
# sudo $SPLUNK_HOME/bin/splunk stop;# sudo rm -rf $SPLUNK_HOME
# This code could be updated to also check if a universal forwarder may be already installed as a learning opportunity

if [ -f $SERVER_CONF ]; then
    SPLUNK_INSTANCE_VERSION=`sudo $SPLUNK_HOME/bin/splunk version`
    SPLUNK_SERVERNAME=`grep serverName $SERVER_CONF | sed 's/[ ][ ]*//g' | cut -c 12- | sed -e 's/\(.*\)/\L\1/'` || fail
    echo "Splunk Enterprise "$SPLUNK_INSTANCE_VERSION" is already installed on this instance with serverName of "$SPLUNK_SERVERNAME" specified in "$SERVER_CONF
    echo "Aborting Install"
    echo "The existing instance can be removed with the following commands"
    echo $SPLUNK_HOME"/bin/splunk stop;rm -rf "$SPLUNK_HOME
    echo "sudo may be required dpending on the ownship of "$SPLUNK_HOME
    echo "Run ls -l "$SPLUNK_HOME" to check permissions"
    echo "Executing these command will permanently destroy all settings and all data from the existing instance"
    echo "CRON jobs created for previous testing can be examined as removed as necessary by running following command"
    echo "crontab -e"
    echo "Do not run these commands unless you are fully authorised and fully approved to do so and undertand to the consequences"
    exit
else
    echo "Splunk Enterprise "$SPLUNK_SERVER_VERSION" ("$SPLUNK_SERVER_BUILD") will now be deployed to " $SPLUNK_PARENT_FOLDER"/splunk"
fi

# Retrieve the user that executed this script even if sudo command was used
AWS_USERNAME="${SUDO_USER:-$USER}"

# It is best practice to create user account to use to run Splunk with non root privileges
# For this script the username from the SSH login is being used for deployment
# Other scripts from the Splunk Study Club GitHub respositiry cover best practice in full
# Updating this script for cater for best practice is a good learing opportunity and is why we have done it this way
# The user account name and user account group could be passed as arguments
# See create_splunk_base_apps.sh in the GitHub repository for an example of this

echo "Splunk will be configured to run under the user "$AWS_USERNAME

echo "Creating Splunk Home Folder "$SPLUNK_HOME
sudo mkdir -p $SPLUNK_HOME

echo "Downloading Splunk installer ("$SPLUNK_INSTALLER") to " $SPLUNK_INSTALLER_PATH
SPLUNK_INSTALLER_PATH=$SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER
sudo wget -O $SPLUNK_INSTALLER_PATH "https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture="$SPLUNK_ARCHITECTURE"&platform="$SPLUNK_PLATFORM"&version="$SPLUNK_SERVER_VERSION"&product="$SPLUNK_PRODUCT"&filename="$SPLUNK_INSTALLER"&wget=true"

#check if file has been downloaded
if [ -f $SPLUNK_INSTALLER_PATH ]; then
    echo "Installer downloaded successfully to " $SPLUNK_INSTALLER_PATH
else
    echo "Download has failed for: " $SPLUNK_INSTALLER_PATH
    echo "Aborting Install"
    exit
fi

echo "Extracting Splunk installation file to " $SPLUNK_HOME
sudo tar -xvf $SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER -C $SPLUNK_PARENT_FOLDER

echo "Deleting Splunk installer ("$SPLUNK_INSTALLER")"
sudo rm -r $SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER || fail

echo "Start Install Splunk as root user"
echo "Splunk will prompt for a new admin password"
sudo $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes

echo "Changing ownership of "$SPLUNK_HOME" to "$AWS_USERNAME
sudo $SPLUNK_HOME/bin/splunk stop
sudo chown -R $AWS_USERNAME $SPLUNK_HOME

echo "Starting Splunk as a Non-Root OS User ("$AWS_USERNAME")"
sudo -H -u $AWS_USERNAME $SPLUNK_HOME/bin/splunk start

echo "Enable Splunk on Boot as OS user "$AWS_USERNAME
sudo $SPLUNK_HOME/bin/splunk enable boot-start -user $AWS_USERNAME

if [ "$SLIM_DOWN" = true ] ; then
    echo "Slimming down Splunk instance to fit t2.micro default storage of 8GiB"
    #on a free tier AWS reduce limit for free disk space before stop indexing to 500MB as default size of t2.micro instance is 8GiB
    sudo $SPLUNK_HOME/bin/splunk set minfreemb 500

    # Reduce the index sizes for the default indexes from 500GB to 500MB  as default size of imstance in 8GiB
    # /etc/system/local/indexes.conf
    INDEX_SIZE=500
    echo "[main]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_audit]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_internal]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_introspection]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_metrics]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_metrics_rollup]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_telemetry]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_thefishbucket]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[history]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[splunklogger]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[summary]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = "$INDEX_SIZE >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
else
    echo "Not slimming down Splunk instance"
fi

echo "Enabling SSL on DEFAULT port 8000 to connect to "$SPLUNK_SERVER_NAME
echo "Port 443 is not set as any port below 1000 requires root access to it and splunk is running as non-root user "$AWS_USERNAME
sudo $SPLUNK_HOME/bin/splunk enable web-ssl

echo "Setting serverName and default-hostname to "$SPLUNK_SERVER_NAME
sudo $SPLUNK_HOME/bin/splunk set servername $SPLUNK_SERVER_NAME 
sudo $SPLUNK_HOME/bin/splunk set default-hostname $SPLUNK_SERVER_NAME

echo "Restart Splunk sizing updates to be applied"
sudo $SPLUNK_HOME/bin/splunk restart

if [ "$UPDATE_DNS" = true ] ; then
    echo "Executing DNS Update Script " $DNS_UPDATE_SCRIPT
    source $DNS_UPDATE_SCRIPT -l $DNS_LOG_FILE
    echo "Finished executing DNS Update Script " $DNS_UPDATE_SCRIPT
else    
    echo "DNS updating was not requested"
fi

if [ "$CREATE_DNS_CRON_JOB" = true ] ; then
    echo "A CRON job is being created for the DNS updates at 5 minute intervals"
    # Create a CRON job for updating DNS every 5 minutes
    # The script places the script in the home folder of the SSH user 
    # Updating this script for cater for best practice in the location of update_splunk_dns.sh is a good learning opportunity
    CRON_CMD=$SCRIPT_ABSOLUTE_PATH"/cron_cmd.txt"
    crontab -l > $CRON_CMD
    # echo new cron into cron file
    echo "*/5 * * * * sudo bash "$DNS_UPDATE_SCRIPT -l $DNS_LOG_FILE >> $CRON_CMD
    # install new cron file
    crontab $CRON_CMD
    rm $CRON_CMD
else
    echo "CRON job creation was not requested"
fi

echo "";echo ""
echo "---------------------------------------------"
echo "Splunk Enterprise "$SPLUNK_VERSION" has been successfully installed at "$SPLUNK_HOME" and is running as OS user "$AWS_USERNAME
SERVER_CONF=$SPLUNK_HOME"/etc/system/local/server.conf"
SPLUNK_SERVERNAME=`grep serverName $SERVER_CONF | sed 's/[ ][ ]*//g' | cut -c 12- | sed -e 's/\(.*\)/\L\1/'` 
echo "Splunk Server Name has been set to " $SPLUNK_SERVERNAME" in "$SERVER_CONF
echo ""
echo "Splunk web can be reached at "$SPLUNK_WEB_URL
echo "Best wishes from Splunk Study Club";echo ""
echo "---------------------------------------------"