#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@studysplunk.club
# https://github.com/SplunkStudyClub/splunk-on-aws
# Example usage
# sudo bash create_base_apps.sh -h /opt -c false -i "sh130-int.bsides.dns.splunkstudy.club:9997" -d "sh130-int.bsides.dns.splunkstudy.club:8089" 

#Apply script arguments
while getopts h:c:i:d: flag
do
    case "${flag}" in
        h) SPLUNK_PARENT_FOLDER=${OPTARG};;
        c) COPY_BASE_APPS=${OPTARG};;
        i) INDEX_SERVERS=${OPTARG};;
        d) DEPLOYMENT_SERVER=${OPTARG};;
   esac
done

# Prepare script variables
SCRIPT_ABSOLUTE_PATH=$(dirname $(readlink -f $0))
echo "SPLUNK_PARENT_FOLDER="$SPLUNK_PARENT_FOLDER
echo "COPY_BASE_APPS="$COPY_APPS
echo "INDEX_SERVERS="$INDEX_SERVERS
echo "DEPLOYMENT_SERVER="$DEPLOYMENT_SERVER

# Check which instance of Splunk is deployed
if [ -d $SPLUNK_PARENT_FOLDER"/splunk" ]; then
    SPLUNK_HOME_FOLDER=$SPLUNK_PARENT_FOLDER"/splunk"
    IS_ENTERPRISE=true
elif [ -d "$SPLUNK_PARENT_FOLDER/splunkforwarder" ];  then
    SPLUNK_HOME_FOLDER=$SPLUNK_PARENT_FOLDER"/splunkforwarder"
    IS_FORWARDER=true
else
    echo "Splunk is not installed yet ...... aborting"
fi

# Remove app files and folders if they exist
BASE_APP_FOLDER=$SCRIPT_ABSOLUTE_PATH"/base_apps"
sudo rm -rf $BASE_APP_FOLDER || fail

#create apps
echo "Creating app files and folders"
sudo mkdir $BASE_APP_FOLDER

# Create a deployment client app
echo "Creating "$BASE_APP_FOLDER"/deployment_client"
sudo mkdir $BASE_APP_FOLDER"/deployment_client"
sudo mkdir $BASE_APP_FOLDER"/deployment_client/local"
sudo mkdir $BASE_APP_FOLDER"/deployment_client/metadata"

echo "[deployment-client]" >> $BASE_APP_FOLDER"/deployment_client/local/deploymentclient.conf"
echo "phoneHomeIntervalInSecs = 15" >> $BASE_APP_FOLDER"/deployment_client/local/deploymentclient.conf"
echo -e "" >> $BASE_APP_FOLDER"/deploymentclient.conf"
echo "[target-broker:deploymentServer]" >> $BASE_APP_FOLDER"/deployment_client/local/deploymentclient.conf"
echo "targetUri = "$DEPLOYMENT_SERVER >> $BASE_APP_FOLDER"/deployment_client/local/deploymentclient.conf"
echo "[install]" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"
echo "state = enabled" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"
echo -e "" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"
echo "[package]" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"
echo "check_for_updates = false" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"   
echo "[ui]" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"
echo "is_visible = false" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"   
echo "is_manageable = false" >> $BASE_APP_FOLDER"/deployment_client/local/app.conf"
echo "[]" >> $BASE_APP_FOLDER"/deployment_client/metadata/local.meta"
echo "access = read : [ * ], write : [ admin ]" >> $BASE_APP_FOLDER"/deployment_client/metadata/local.meta"
echo "export = system" >> $BASE_APP_FOLDER"/deployment_client/metadata/local.meta"

# Create a forwarder output app
echo "Creating "$BASE_APP_FOLDER"/forwarder_outputs"
sudo mkdir $BASE_APP_FOLDER"/forwarder_outputs"
sudo mkdir $BASE_APP_FOLDER"/forwarder_outputs/local"
sudo mkdir $BASE_APP_FOLDER"/forwarder_outputs/metadata"

echo "[tcpout]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "defaultGroup = primary_indexers" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo -e "" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "[tcpout:primary_indexers]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "server = "$INDEX_SERVERS >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"

echo "[install]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "state = enabled" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo -e "" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "[package]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "check_for_updates = false" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "[ui]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"
echo "is_visible = false" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf" 
echo "is_manageable = false" >> $BASE_APP_FOLDER"/forwarder_outputs/local/outputs.conf"

echo "[]" >> $BASE_APP_FOLDER"/forwarder_outputs/metadata/local.meta"
echo "access = read : [ * ], write : [ admin ]" >> $BASE_APP_FOLDER"/forwarder_outputs/metadata/local.meta"
echo "export = system" >> $BASE_APP_FOLDER"/forwarder_outputs/metadata/local.meta"

if [ "$COPY_BASE_APPS" = true ] ; then
    if [ "$IS_ENTERPRISE" = true ] ; then
        echo "Deployment Server: copying apps to " $BASE_APP_FOLDER"/deployment_client "$SPLUNK_HOME_FOLDER"/etc/deployment-apps"
        sudo cp -R $BASE_APP_FOLDER/deployment_client $SPLUNK_HOME_FOLDER/etc/deployment-apps
        sudo cp -R $BASE_APP_FOLDER/forwarder_outputs $SPLUNK_HOME_FOLDER/etc/deployment-apps
    fi

    if [ "$IS_FORWARDER" = true ] ; then
        echo "Univesal Forwarder: copying apps to " $BASE_APP_FOLDER"/deployment_client "$SPLUNK_HOME_FOLDER"/etc/apps"
        sudo cp -R $BASE_APP_FOLDER/deployment_client $SPLUNK_HOME_FOLDER/etc/apps
        sudo cp -R $BASE_APP_FOLDER/forwarder_outputs $SPLUNK_HOME_FOLDER/etc/apps
    fi
    echo "Restart Splunk for app updates to be applied"
    sudo $SPLUNK_HOME/bin/splunk restart
else
    echo "Apps are not being copied"
fi