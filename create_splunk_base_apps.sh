#!/bin/sh

# Written by Aleem Cummins - Splunk Study Club
# aleem@cummins.me
# https://github.com/SplunkStudyClub/splunk-on-aws
# Example usage
# sudo bash create_splunk_base_apps.sh -p /opt -c false -i "sh130-int.bsides.dns.splunkstudy.club:9997" -d "sh130-int.bsides.dns.splunkstudy.club:8089" -u splunk -g splunk -z "deployment_client,forwarder_outputs" -r deploymentclient
# for AWS instances using Ubuntu, a user name and a group name called ubuntu will already exist
# read up on "adduser" command as a good learning opportunity
# The deployment_client app is used for instigating the communication back to a deployment server. 
# The forwarder_outputs_app is used to get started without needing to configure a deployment server.
# Maintaining these app on a file system and copying over would be a normal best practice. This is being done via scripting
# as it is anticipated that the AWS instances would be spun up, tweaked, broken and smashed often, so scripting has a place
# any amount of additional checking and validation can be added as necessary
# this script uses a number of concepts and techniques that may prove valuable elsewhere
# for example tokens and valiarbles could be passed as script arguments

#Apply script arguments
while getopts p:c:i:d:u:g:z:r: flag
do
    case "${flag}" in
        p) SPLUNK_PARENT_FOLDER=${OPTARG};;
        c) COPY_BASE_APPS=${OPTARG};;
        i) INDEXER_SERVER_LIST=${OPTARG};;
        d) DEPLOYMENT_SERVER=${OPTARG};;
        u) SPLUNK_OS_USERNAME=${OPTARG};;
        g) SPLUNK_OS_USERGROUP=${OPTARG};;
        z) BASE_APPS_LIST=${OPTARG};;
        r) SPLUNK_DEPLOYMENT_ROLE=${OPTARG};;
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
SCRIPT_NAME=${0##*/}
BASE_APP_FOLDER=$SCRIPT_ABSOLUTE_PATH"/splunk_base_apps"

# Check if an instance of Splunk is already deployed
if [ -d $SPLUNK_PARENT_FOLDER"/splunk" ]; then
    SPLUNK_HOME=$SPLUNK_PARENT_FOLDER"/splunk"
    IS_ENTERPRISE=true
elif [ -d "$SPLUNK_PARENT_FOLDER/splunkforwarder" ];  then
    SPLUNK_HOME=$SPLUNK_PARENT_FOLDER"/splunkforwarder"
    IS_FORWARDER=true
else
    echo "Splunk is not installed yet ...... aborting"
    exit
fi

# Check if OS user already exists
egrep -i "^$SPLUNK_OS_USERNAME:" /etc/passwd;
if [ $? -eq 0 ]; then
    echo "User ["$SPLUNK_OS_USERNAME"] Exists"
else
    echo "User ["$SPLUNK_OS_USERNAME"] does not exist"
    echo "Please create user first ...... aborting"
    exit
fi

# Check if OS group already exists
egrep -i "^$SPLUNK_OS_USERGROUP:" /etc/group;
if [ $? -eq 0 ]; then
    echo "User Group [" $SPLUNK_OS_USERGROUP"] Exists"
else
    echo "User Group [" $SPLUNK_OS_USERGROUP"]  does not exist"
    echo "Please create group first ...... aborting"
    exit
fi

# Remove base app files and folders if they exist
sudo rm -rf $BASE_APP_FOLDER || fail

echo "BASE_APPS_LIST="$BASE_APPS_LIST
if grep -q "deployment_client" <<<$BASE_APPS_LIST; then
    #create apps
    echo "Creating deployment_client app files and folders"
    sudo mkdir -p $BASE_APP_FOLDER

    # Create a deployment client app
    echo "Creating "$BASE_APP_FOLDER"/deployment_client_app"
    sudo mkdir -p $BASE_APP_FOLDER"/deployment_client_app"
    sudo mkdir -p $BASE_APP_FOLDER"/deployment_client_app/local"
    sudo mkdir -p $BASE_APP_FOLDER"/deployment_client_app/metadata"

    echo "[deployment-client]" >> $BASE_APP_FOLDER"/deployment_client_app/local/deploymentclient.conf"
    echo "phoneHomeIntervalInSecs = 15" >> $BASE_APP_FOLDER"/deployment_client_app/local/deploymentclient.conf"
    echo -e "" >> $BASE_APP_FOLDER"/deployment_client_app/local/deploymentclient.conf"
    echo "[target-broker:deploymentServer]" >> $BASE_APP_FOLDER"/deployment_client_app/local/deploymentclient.conf"
    echo "targetUri = "$DEPLOYMENT_SERVER >> $BASE_APP_FOLDER"/deployment_client_app/local/deploymentclient.conf"

    echo "[install]" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"
    echo "state = enabled" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"
    echo -e "" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"
    echo "[package]" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"
    echo "check_for_updates = false" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"   
    echo "[ui]" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"
    echo "is_visible = false" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"   
    echo "is_manageable = false" >> $BASE_APP_FOLDER"/deployment_client_app/local/app.conf"

    echo "[]" >> $BASE_APP_FOLDER"/deployment_client_app/metadata/local.meta"
    echo "access = read : [ * ], write : [ admin ]" >> $BASE_APP_FOLDER"/deployment_client_app/metadata/local.meta"
    echo "export = system" >> $BASE_APP_FOLDER"/deployment_client_app/metadata/local.meta"
else
    echo "Base app not required: deployment_client_app"
fi

if grep -q "forwarder_outputs" <<<$BASE_APPS_LIST; then
    # Create a forwarder output app
    echo "Creating forwarder_outputs_app files and folders"
    sudo mkdir -p $BASE_APP_FOLDER
    
    echo "Creating "$BASE_APP_FOLDER"/forwarder_outputs_app"
    sudo mkdir -p $BASE_APP_FOLDER"/forwarder_outputs_app"
    sudo mkdir -p $BASE_APP_FOLDER"/forwarder_outputs_app/local"
    sudo mkdir -p $BASE_APP_FOLDER"/forwarder_outputs_app/metadata"

    echo "[tcpout]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/outputs.conf"
    echo "defaultGroup = primary_indexers" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/outputs.conf"
    echo -e "" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/outputs.conf"
    echo "[tcpout:primary_indexers]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/outputs.conf"
    echo "server = "$INDEXER_SERVER_LIST >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/outputs.conf"

    echo "[install]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"
    echo "state = enabled" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"
    echo -e "" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"
    echo "[package]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"
    echo "check_for_updates = false" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"
    echo "[ui]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"
    echo "is_visible = false" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf" 
    echo "is_manageable = false" >> $BASE_APP_FOLDER"/forwarder_outputs_app/local/app.conf"

    echo "[]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/metadata/local.meta"
    echo "access = read : [ * ], write : [ admin ]" >> $BASE_APP_FOLDER"/forwarder_outputs_app/metadata/local.meta"
    echo "export = system" >> $BASE_APP_FOLDER"/forwarder_outputs_app/metadata/local.meta"
else
    echo "Base app not required: forwarder_outputs_app"
fi

if [ "$COPY_BASE_APPS" = true ]; then
    echo "Copying apps"

    if grep -q "deploymentserver" <<<$SPLUNK_DEPLOYMENT_ROLE; then
        echo "This Splunk instance is acting as a deployment server"
        TARGET_APP_FOLDER=$SPLUNK_HOME"/etc/deployment-apps"
    elif grep -q "deploymentclient" <<<$SPLUNK_DEPLOYMENT_ROLE; then
        echo "This Splunk instance is acting as a deployment client"
        TARGET_APP_FOLDER=$SPLUNK_HOME"/etc/apps"
    else
        echo "Instance role is undefined"
        echo "..... Aborting"
        exit
    fi

    if grep -q "deployment_client_app" <<<$BASE_APPS_LIST; then
        echo "Copying from "$BASE_APP_FOLDER/deployment_client_app" to "$TARGET_APP_FOLDER
        sudo cp -R $BASE_APP_FOLDER/deployment_client_app $TARGET_APP_FOLDER
        echo "Making "$SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP" owner of "$TARGET_APP_FOLDER"/deployment_client_app"
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $TARGET_APP_FOLDER/deployment_client_app
    fi

    if grep -q "forwarder_outputs_app" <<<$BASE_APPS_LIST; then
        echo "Copying from "$BASE_APP_FOLDER/forwarder_outputs_app" to "$TARGET_APP_FOLDER
        sudo cp -R $BASE_APP_FOLDER/forwarder_outputs_app $TARGET_APP_FOLDER
        echo "Making "$SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP" owner of "$TARGET_APP_FOLDER"/forwarder_outputs_app"
        sudo chown -R $SPLUNK_OS_USERNAME:$SPLUNK_OS_USERGROUP $TARGET_APP_FOLDER/forwarder_outputs_app
    fi

    echo "Restarting Splunk for app updates to be applied"
    sudo $SPLUNK_HOME/bin/splunk restart

    # Remove app files and folders
    sudo rm -rf $BASE_APP_FOLDER || fail
else
   echo "Apps have been created in "$BASE_APP_FOLDER" with permissions set to "$SPLUNK_OS_USERNAME":"$SPLUNK_OS_USERGROUP
fi