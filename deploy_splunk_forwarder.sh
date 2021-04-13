#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@studysplunk.club
# https://github.com/SplunkStudyClub/splunk-on-aws
# Example usage
# sudo bash deploy_splunk_forwarder.sh -h /opt -p testing123 -s uf01 -d true -z "sh130-int.bsides.dns.splunkstudy.club:8089" -i "sh130-int.bsides.dns.splunkstudy.club:9997"

#Apply script arguments
echo "Number of parameters passed to this script is $#"
while getopts h:p:s:d:z:i: flag
do
    case "${flag}" in
        h) SPLUNK_PARENT_FOLDER=${OPTARG};;
        p) SPLUNK_PASSWORD=${OPTARG};;
        s) SPLUNK_SERVER_NAME=${OPTARG};;
        d) UPDATE_DNS=${OPTARG};;
        z) DEPLOYMENT_SERVER=${OPTARG};;
        i) INDEX_SERVERS=${OPTARG};;
   esac
done

# Prepare script variables
SCRIPT_ABSOLUTE_PATH=$(dirname $(readlink -f $0))
echo "SCRIPT_ABSOLUTE_PATH="$SCRIPT_ABSOLUTE_PATH
SPLUNK_INSTALLER="splunkforwarder-8.1.3-63079c59e632-Linux-x86_64.tgz"
echo "DEPLOYMENT_SERVER="$DEPLOYMENT_SERVER

SPLUNK_HOME_FOLDER=$SPLUNK_PARENT_FOLDER"/splunkforwarder"
SPLUNK_APP_FOLDER=$SPLUNK_HOME_FOLDER"/etc/apps"
SPLUNK_VERSION="8.1.3"
SPLUNK_PLATFORM="linux"
SPLUNK_ARCHITECTURE="x86_64"
SPLUNK_PRODUCT="universalforwarder"
echo "INDEX_SERVERS="$INDEX_SERVERS
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
sudo wget -O $SCRIPT_ABSOLUTE_PATH"/"$SPLUNK_INSTALLER "https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture="$SPLUNK_ARCHITECTURE"&platform="$SPLUNK_PLATFORM"&version="$SPLUNK_VERSION"&product="$SPLUNK_PRODUCT"&filename="$SPLUNK_INSTALLER"&wget=true"

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

#output.conf for indexer

if [ -z "$DEPLOYMENT_SERVER" ]; then
    echo "Not configuring as a deployment client"
else
    echo "Configuring Deployment Client for "$DEPLOYMENT_SERVER
    echo "Creating "$SPLUNK_APP_FOLDER"/deployment_client"
    sudo mkdir $SPLUNK_APP_FOLDER"/deployment_client"

    SPLUNK_APP_FOLDER_LOCAL=$SPLUNK_APP_FOLDER"/deployment_client/local"
    echo "Creating "$SPLUNK_APP_FOLDER_LOCAL
    sudo mkdir $SPLUNK_APP_FOLDER_LOCAL

    SPLUNK_APP_FOLDER_METADATA=$SPLUNK_APP_FOLDER"/deployment_client/metadata"
    echo "Creating "$SPLUNK_APP_FOLDER_METADATA
    sudo mkdir $SPLUNK_APP_FOLDER_METADATA

    # Create a deployment client app
    echo "[deployment-client]" >> $SPLUNK_APP_FOLDER_LOCAL"/deploymentclient.conf"
    echo "phoneHomeIntervalInSecs = 15" >> $SPLUNK_APP_FOLDER_LOCAL"/deploymentclient.conf"
    echo -e "" >> $SPLUNK_APP_FOLDER_LOCAL"/deploymentclient.conf"
    echo "[target-broker:deploymentServer]" >> $SPLUNK_APP_FOLDER_LOCAL"/deploymentclient.conf"
    echo "targetUri = "$DEPLOYMENT_SERVER >> $SPLUNK_APP_FOLDER_LOCAL"/deploymentclient.conf"
    echo "[install]" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"
    echo "state = enabled" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"
    echo -e "" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"
    echo "[package]" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"
    echo "check_for_updates = false" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"   
    echo "[ui]" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"
    echo "is_visible = false" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"   
    echo "is_manageable = false" >> $SPLUNK_APP_FOLDER_LOCAL"/app.conf"   
    echo "[]" >> $SPLUNK_APP_FOLDER_METADATA"/local.meta"
    echo "access = read : [ * ], write : [ admin ]" >> $SPLUNK_APP_FOLDER_METADATA"/local.meta"
    echo "export = system" >> $SPLUNK_APP_FOLDER_METADATA"/local.meta"
fi

if [ -z "$INDEX_SERVERS" ]; then
    echo "Not configuring forwarding to indexers"
else
    echo "Configuring forwarding to indexers "$INDEX_SERVERS
    echo "Creating "$SPLUNK_APP_FOLDER"/forwarder_outputs"
    sudo mkdir $SPLUNK_APP_FOLDER"/forwarder_outputs"

    SPLUNK_APP_FOLDER_IDX_LOCAL=$SPLUNK_APP_FOLDER"/forwarder_outputs/local"
    echo "Creating "$SPLUNK_APP_FOLDER_IDX_LOCAL
    sudo mkdir $SPLUNK_APP_FOLDER_IDX_LOCAL

    SPLUNK_APP_FOLDER_IDX_METADATA=$SPLUNK_APP_FOLDER"/forwarder_outputs/metadata"
    echo "Creating "$SPLUNK_APP_FOLDER_IDX_METADATA
    sudo mkdir $SPLUNK_APP_FOLDER_IDX_METADATA

    echo "[tcpout]" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/outputs.conf"
    echo "defaultGroup = primary_indexers" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/outputs.conf"
    echo -e "" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/outputs.conf"
    echo "[tcpout:primary_indexers]" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/outputs.conf"
    echo "server = "$INDEX_SERVERS >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/outputs.conf"

    echo "[install]" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"
    echo "state = enabled" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"
    echo -e "" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"
    echo "[package]" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"
    echo "check_for_updates = false" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"   
    echo "[ui]" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"
    echo "is_visible = false" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"   
    echo "is_manageable = false" >> $SPLUNK_APP_FOLDER_IDX_LOCAL"/app.conf"  
    
    echo "[]" >> $SPLUNK_APP_FOLDER_IDX_METADATA"/local.meta"
    echo "access = read : [ * ], write : [ admin ]" >> $SPLUNK_APP_FOLDER_IDX_METADATA"/local.meta"
    echo "export = system" >> $SPLUNK_APP_FOLDER_IDX_METADATA"/local.meta"
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