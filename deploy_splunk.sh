#!/bin/sh

# Run script: sudo bash ./deploy_splunk.sh -d false -t false -x false

# clear down splunk     
# sudo $SPLUNK_HOME/bin/splunk stop 
# sudo rm -rf /opt/splunk 
# sudo userdel "splunk"
# sudo groupdel "splunk"
# sudo rm -r /home/splunk


#ap3-cclabs516921-idx1	3.236.112.227	ap3-cclabs516921-idx1.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.142
#ap3-cclabs516921-idx2	3.226.244.31	ap3-cclabs516921-idx2.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.94 
#ap3-cclabs516921-if1	3.235.41.54	    ap3-cclabs516921-if1.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.148 
#ap3-cclabs516921-if2	35.173.47.211	ap3-cclabs516921-if2.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.46 
#ap3-cclabs516921-mc1	3.239.1.122	    ap3-cclabs516921-mc1.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.192
#ap3-cclabs516921-sh1	3.235.77.227	ap3-cclabs516921-sh1.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.177
#ap3-cclabs516921-uf1	44.192.24.110	ap3-cclabs516921-uf1.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.189 
#ap3-cclabs516921-uf2	3.235.175.186	ap3-cclabs516921-uf2.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.43
#ap3-cclabs516921-uf3	3.234.209.82	ap3-cclabs516921-uf3.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.183 
#ap3-cclabs516921-uf4	18.205.67.135	ap3-cclabs516921-uf4.class.splunk.com	admin	sccStudent	-	mBG15utw    10.0.0.103 



#Apply script arguments
while getopts d:t:x: flag
do
    case "${flag}" in
        d) IS_DEPLOYMENT_SERVER=${OPTARG};;
        t) IS_AWS_TEST=${OPTARG};;
        x) IS_DEBUG_MODE=${OPTARG};;
    esac
done

#IS_DEPLOYMENT_SERVER=$IS_DEPLOYMENT_SERVER
#IS_AWS_TEST=$IS_AWS_TEST
#IS_DEBUG_MODE=$IS_DEBUG_MODE

echo "IS_DEPLOYMENT_SERVER: $IS_DEPLOYMENT_SERVER";
echo "IS_DEBUG_MODE: $IS_DEBUG_MODE";
echo "IS_AWS_TEST: $IS_AWS_TEST";
echo "-----------------------------------------------------"

#Prepare script variables
SPLUNK_OS_GROUP="splunk"
SPLUNK_OS_USER="splunk"
SPLUNK_OS_USER_PASSWORD="testing123"
REMOTE_SERVER="ec2-35-163-113-53.us-west-2.compute.amazonaws.com"
SPLUNK_INSTALLER="splunk-8.1.3-63079c59e632-Linux-x86_64.tgz"
SPLUNK_HOME_FOLDER="/opt/splunk"
LAB_USER_HOME_FOLDER="/home/sccStudent"
REMOTE_SERVER_APP_FOLDER=$SPLUNK_HOME_FOLDER"/etc/apps"
IDX1_INT_IP=""
IDX2_INT_IP=""
SH1_INT_IP=""
MC1_INT_IP=""
UF1_INT_IP=""

#Create Splunk Home Folder
sudo mkdir $SPLUNK_HOME_FOLDER

if [ "$IS_AWS_TEST" = true ]
then
    echo "Installing AWS WGET command"  
    sudo yum -y install wget || true 
    
    echo "Creating AWS user "$SPLUNK_OS_USER
    sudo useradd -m $SPLUNK_OS_USER -p $SPLUNK_OS_USER_PASSWORD

    #echo "Creating group "$SPLUNK_OS_GROUP
    #sudo groupadd $SPLUNK_OS_GROUP
else
    echo "Creating Lab user "$SPLUNK_OS_USER
    sudo adduser $SPLUNK_OS_USER
    echo "Installing WGET command"  
    sudo yum -y install wget || true 
fi

echo "Creating Splunk global variables"
export SPLUNK_HOME=/opt/splunk
export SPLUNK_HOME=$SPLUNK_HOME_FOLDER
echo "SPLUNK_HOME has been set to "$SPLUNK_HOME
export SPLUNK_DB=$SPLUNK_HOME/var/lib/splunk
echo "SPLUNK_DB has been set to "$SPLUNK_DB

echo "Downloading Splunk installer ("$SPLUNK_INSTALLER")"
cd /opt
sudo wget -O $SPLUNK_INSTALLER "https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.3&product=splunk&filename="$SPLUNK_INSTALLER"&wget=true"

echo "Extracting Splunk installation file to " $SPLUNK_HOME
sudo tar -xzvf $SPLUNK_INSTALLER

echo "Deleting Splunk installer ("$SPLUNK_INSTALLER")"
sudo rm -r /opt/$SPLUNK_INSTALLER 

echo "Start Install Splunk as Root user"
sudo $SPLUNK_HOME/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd $SPLUNK_OS_USER_PASSWORD

if [ "$IS_DEBUG_MODE" = true ]
then
    echo "Confirm which user is running splunkd process"
    sudo ps aux | grep -i splunkd
    
    echo "Run sample search"
    sudo $SPLUNK_HOME/bin/splunk search "index=_internal"
    sleep 30
fi

sudo $SPLUNK_HOME/bin/splunk stop
if [ "$IS_AWS_TEST" = true ]
then
    echo "Changing ownership of "$SPLUNK_HOME" to "$SPLUNK_OS_USER
    sudo chown -R $SPLUNK_OS_USER $SPLUNK_HOME
 else
     echo "Changing ownership of "$SPLUNK_HOME" to "$SPLUNK_OS_USER" from group "$SPLUNK_OS_GROUP
     sudo chown -R $SPLUNK_OS_USER:$SPLUNK_OS_GROUP $SPLUNK_HOME
fi
echo "Starting Splunk as a Non-Root OS User ("$SPLUNK_OS_USER")"
sudo -H -u $SPLUNK_OS_USER $SPLUNK_HOME/bin/splunk start
 
if [ "$IS_DEBUG_MODE" = true ]
then
    echo "Confirm which user is running splunkd process after ownership change"
    sudo ps aux | grep -i splunkd
fi

#check folder permissions

echo "Enable Splunk on Boot as OS user " $SPLUNK_OS_USER
sudo $SPLUNK_HOME/bin/splunk enable boot-start -user $SPLUNK_OS_USER

if [ "$IS_DEPLOYMENT_SERVER" = true ]
then
    #copy apps from jump server
    echo "Installing local apps on Deployment Server"
    sudo cp -R $LAB_USER_HOME_FOLDER/apps/ap3_internal_forwarder_outputs $SPLUNK_HOME/etc/apps
    #sudo cp -R $LAB_USER_HOME_FOLDER/apps/ap2_all_indexes $SPLUNK_HOME/etc/apps
    #sudo cp -R $LAB_USER_HOME_FOLDER/apps/Splunk_TA_nix $SPLUNK_HOME/etc/apps
    
    echo "Installing apps on Deployment Server for later forwarder management configuration"
    #sudo cp -R $LAB_USER_HOME_FOLDER/apps/ap2_all_forwarder_outputs $SPLUNK_HOME/etc/deployment-apps
    #sudo cp -R $LAB_USER_HOME_FOLDER/apps/ap2_all_indexes $SPLUNK_HOME/etc/deployment-apps
    #sudo cp -R $LAB_USER_HOME_FOLDER/apps/ap2_all_indexer_base $SPLUNK_HOME/etc/deployment-apps
    #sudo cp -R $LAB_USER_HOME_FOLDER/apps/Splunk_TA_nix $SPLUNK_HOME/etc/deployment-apps
else
    #configure as a deployment client
    echo "Installing deployment client base app"
    sudo cp -R $LAB_USER_HOME_FOLDER/apps/ap3_deploymentclient $SPLUNK_HOME/etc/apps
fi
echo "Restarting Splunk to enable newly added apps"
sudo $SPLUNK_HOME/bin/splunk restart

if [ "$IS_AWS_TEST" = true ]
then
    #on a free tier AWS reduce limit for free disk space before stop indexing to 500MB
    sudo $SPLUNK_HOME/bin/splunk set minfreemb 500
    echo "Restarting Splunk to apply free disk space reduction to 500MB"
    sudo $SPLUNK_HOME/bin/splunk restart
    sleep 10
    echo "Run sample search"
    sudo $SPLUNK_HOME/bin/splunk search "index=_internal"
fi