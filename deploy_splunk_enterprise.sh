#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@studysplunk.club
# https://github.com/SplunkStudyClub/splunk-on-aws
# Example usage
# sudo bash deploy_splunk_enterprise.sh -h /opt -p testing123 -s sh30 -d true -z true

#Apply script arguments
echo "Number of parameters passed to this script is $#"
while getopts h:p:s:d:z: flag
do
    case "${flag}" in
        h) SPLUNK_PARENT_FOLDER=${OPTARG};;
        p) SPLUNK_PASSWORD=${OPTARG};;
        s) SPLUNK_SERVER_NAME=${OPTARG};;
        d) UPDATE_DNS=${OPTARG};;
        z) SLIM_DOWN=${OPTARG};;
   esac
done

# Prepare script variables
SCRIPT_ABSOLUTE_PATH=$(dirname $(readlink -f $0))
echo "SCRIPT_ABSOLUTE_PATH="$SCRIPT_ABSOLUTE_PATH
SPLUNK_INSTALLER="splunk-8.1.3-63079c59e632-Linux-x86_64.tgz"

SPLUNK_HOME_FOLDER=$SPLUNK_PARENT_FOLDER"/splunk"
REMOTE_SERVER_APP_FOLDER=$SPLUNK_HOME_FOLDER"/etc/apps"
INDEXES_CONF=$SPLUNK_PARENT_FOLDER"/splunk/etc/system/local/indexes.conf"

SPLUNK_VERSION="8.1.3"
SPLUNK_PLATFORM="linux"
SPLUNK_ARCHITECTURE="x86_64"
# Retrieve the user that executed this script even if sudo command was used
AWS_USERNAME="${SUDO_USER:-$USER}"
echo "Splunk will be configured to run under the user "$AWS_USERNAME

#Create Splunk Home Folder
sudo mkdir $SPLUNK_HOME_FOLDER

echo "Creating Splunk global variables"
export SPLUNK_HOME=$SPLUNK_HOME_FOLDER
echo "New system variable SPLUNK_HOME created and set to "$SPLUNK_HOME_FOLDER
export SPLUNK_DB=$SPLUNK_HOME/var/lib/splunk
echo "New system variable SPLUNK_DB created and set to "$SPLUNK_DB
echo "Downloading Splunk installer ("$SPLUNK_INSTALLER")"
sudo wget -O $SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER "https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture="$SPLUNK_ARCHITECTURE"&platform="$SPLUNK_PLATFORM"&version="$SPLUNK_VERSION"&product=splunk&filename="$SPLUNK_INSTALLER"&wget=true"

echo "Extracting Splunk installation file to " $SPLUNK_HOME_FOLDER
sudo tar -xvf $SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER -C $SPLUNK_PARENT_FOLDER

#echo "Deleting Splunk installer ("$SPLUNK_INSTALLER")"
sudo rm -r $SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER || fail

echo "Start Install Splunk as Root user"
sudo $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd $SPLUNK_PASSWORD

echo "Changing ownership of "$SPLUNK_HOME" to "$AWS_USERNAME
sudo $SPLUNK_HOME/bin/splunk stop
sudo chown -R $AWS_USERNAME $SPLUNK_HOME

echo "Starting Splunk as a Non-Root OS User ("$AWS_USERNAME")"
sudo -H -u $AWS_USERNAME $SPLUNK_HOME/bin/splunk start

#set serverName and default hostname
sudo $SPLUNK_HOME/bin/splunk set servername $SPLUNK_SERVER_NAME -auth admin:$SPLUNK_PASSWORD
sudo $SPLUNK_HOME/bin/splunk set default-hostname $SPLUNK_SERVER_NAME -auth admin:$SPLUNK_PASSWORD

if [ "$UPDATE_DNS" = true ] ; then
    echo "Slimming down Splunk instance"
    #on a free tier AWS reduce limit for free disk space before stop indexing to 500MB as default size of imstance in 8GiB
    sudo $SPLUNK_HOME/bin/splunk set minfreemb 500 -auth admin:$SPLUNK_PASSWORD

    # Reduce the index sizes for the default indexes from 500GB to 500MB  as default size of imstance in 8GiB
    echo "[main]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_audit]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_internal]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_introspection]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_metrics]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_metrics_rollup]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_telemetry]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[_thefishbucket]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[history]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[splunklogger]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
    echo "[summary]" >> $INDEXES_CONF ; echo "maxTotalDataSizeMB = 500" >> $INDEXES_CONF ; echo -e "" >> $INDEXES_CONF
else
    echo "Not slimming down Splunk instance"
fi

echo "Enable Splunk on Boot as OS user " $AWS_USERNAME
sudo $SPLUNK_HOME/bin/splunk enable boot-start -user $AWS_USERNAME

echo "Restart Splunk sizing updates to be applied"
sudo $SPLUNK_HOME/bin/splunk restart

echo "---------------------------------------------"
echo "Splunk Enterprise "$SPLUNK_VERSION" has been successfully installed at "$SPLUNK_HOME_FOLDER" and is running as OS user "$AWS_USERNAME
SERVER_CONF=$SPLUNK_HOME_FOLDER"/etc/system/local/server.conf"
SPLUNK_SERVERNAME=`grep serverName $SERVER_CONF | sed 's/[ ][ ]*//g' | cut -c 12- | sed -e 's/\(.*\)/\L\1/'` 
echo "Splunk Server Name has been set to " $SPLUNK_SERVERNAME" in "$SERVER_CONF
echo "---------------------------------------------"

if [ "$UPDATE_DNS" = true ] ; then
    DNS_UPDATE_SCRIPT=$SCRIPT_ABSOLUTE_PATH"/update_dns.sh"
    echo "Executing DNS Update Script " $DNS_UPDATE_SCRIPT
    source $DNS_UPDATE_SCRIPT "-l true"
    echo "Finished executing DNS Update Script " $DNS_UPDATE_SCRIPT
else    
    echo "DNS updating was not requested"
fi