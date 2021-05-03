#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@cummins.me
# https://github.com/SplunkStudyClub/splunk-on-aws
# Example usage
# sudo bash create_splunk_base_apps.sh -p /opt -c false -i "sh130-int.bsides.dns.splunkstudy.club:9997" -d "sh130-int.bsides.dns.splunkstudy.club:8089" -u splunk -g splunk
# for AWS instances using Ubuntu, a user name and a group name called ubuntu will already exist
# read up on "adduser" command as a good learning opportunity

# any amount of additional checking and validation can be added as necessary
# this script uses a number of concepts and techniques that may prove valuable elsewhere
# for example tokens and valiarbles could be passed as script arguments

#Apply script arguments
while getopts p:c:i:d:u:g: flag
do
    case "${flag}" in
        p) SPLUNK_PARENT_FOLDER=${OPTARG};;
        c) COPY_BASE_APPS=${OPTARG};;
        i) INDEX_SERVERS=${OPTARG};;
        d) DEPLOYMENT_SERVER=${OPTARG};;
        u) SPLUNK_OS_USERNAME=${OPTARG};;
        g) SPLUNK_OS_USERGROUP=${OPTARG};;
   esac
done

# Displaying the last modified time of scripts can be useful to avoid confusion when updating and testing
echo "======================================================================================================================================="
echo $(clear)
LAST_MODIFIED_DATE_EPOCH=$(stat -c %Y $SCRIPT_ABSOLUTE_PATH"/"$SCRIPT_NAME)
LAST_MODIFIED_DATE=$(date -d @$LAST_MODIFIED_DATE_EPOCH)
echo "Script Last Modified:" $LAST_MODIFIED_DATE "("$SCRIPT_ABSOLUTE_PATH"/"$SCRIPT_NAME")"
echo "======================================================================================================================================="

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
    exit
fi

# Check is OS user already exists
egrep -i "^$SPLUNK_OS_USERNAME:" /etc/passwd;
if [ $? -eq 0 ]; then
    #echo "User ["$SPLUNK_OS_USERNAME"] Exists"
else
    echo "User ["$SPLUNK_OS_USERNAME"] does not exist"
    echo "Please create user first ...... aborting"
    exit
fi

# Check is OS group already exists
egrep -i "^$SPLUNK_OS_USERGROUP:" /etc/group;
if [ $? -eq 0 ]; then
    #echo "User Group [" $SPLUNK_OS_USERGROUP"] Exists"
else
    echo "User Group [" $SPLUNK_OS_USERGROUP"]  does not exist"
    echo "Please create group first ...... aborting"
    exit
fi

# Remove app files and folders if they exist
BASE_APP_FOLDER=$SCRIPT_ABSOLUTE_PATH"/splunk_base_apps"
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
echo -e "" >> $BASE_APP_FOLDER"/deployment_client/local/deploymentclient.conf"
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

if [ "$IS_ENTERPRISE" = true ] ; then
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

    echo "[install]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"
    echo "state = enabled" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"
    echo -e "" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"
    echo "[package]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"
    echo "check_for_updates = false" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"
    echo "[ui]" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"
    echo "is_visible = false" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf" 
    echo "is_manageable = false" >> $BASE_APP_FOLDER"/forwarder_outputs/local/app.conf"

    echo "[]" >> $BASE_APP_FOLDER"/forwarder_outputs/metadata/local.meta"
    echo "access = read : [ * ], write : [ admin ]" >> $BASE_APP_FOLDER"/forwarder_outputs/metadata/local.meta"
    echo "export = system" >> $BASE_APP_FOLDER"/forwarder_outputs/metadata/local.meta"
fi

if [ "$COPY_BASE_APPS" = true ] ; then
    if [ "$IS_ENTERPRISE" = true ] ; then
        echo "Deployment Server: copying apps to " $BASE_APP_FOLDER"/deployment_client "$SPLUNK_HOME_FOLDER"/etc/deployment-apps"
        sudo cp -R $BASE_APP_FOLDER/deployment_client $SPLUNK_HOME_FOLDER/etc/deployment-apps
        sudo cp -R $BASE_APP_FOLDER/forwarder_outputs $SPLUNK_HOME_FOLDER/etc/deployment-apps
        #update permission recursively for copied folders and file of apps
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $BASE_APP_FOLDER/deployment_client
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $BASE_APP_FOLDER/forwarder_outputs
    fi

    if [ "$IS_FORWARDER" = true ] ; then
        echo "Univesal Forwarder: copying apps to " $BASE_APP_FOLDER"/deployment_client "$SPLUNK_HOME_FOLDER"/etc/apps"
        #update permission recursively for copied folders and file of apps
        sudo cp -R $BASE_APP_FOLDER/deployment_client $SPLUNK_HOME_FOLDER/etc/apps
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $BASE_APP_FOLDER/deployment_client
    fi

    echo "Restart Splunk for app updates to be applied"
    sudo $SPLUNK_HOME_FOLDER/bin/splunk restart

    # Remove app files and folders
    sudo rm -rf $BASE_APP_FOLDER || fail
else
    if [ "$IS_ENTERPRISE" = true ] ; then
        #update permission recursively for copied folders and file of apps
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $BASE_APP_FOLDER/deployment_client
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $BASE_APP_FOLDER/forwarder_outputs
    fi

    if [ "$IS_FORWARDER" = true ] ; then
        #update permission recursively for copied folders and file of apps
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $BASE_APP_FOLDER/deployment_client
    fi
   echo "Apps have been created in "$BASE_APP_FOLDER" with permissions set to "$SPLUNK_OS_USERNAME":"$SPLUNK_OS_USERGROUP
fi