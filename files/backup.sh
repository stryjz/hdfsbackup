#!/bin/bash
date_today=$(date +%F)
date_yesterday=$(date +%F -d "-1 day")
date_14=$(date +%F -d "-14 days")

krb=/etc/security/keytabs/hdfs.headless.keytab
principal=hdfs-cluset1@stryjz.biz

#update fiters file
cat > /opt/tools/filters <<EOF
.*/path_to_exclude_from_backup
EOF

kinit -kt $krb  $principal

#finding active NN
active_node=''
if hadoop fs -test -e hdfs://master1.stryjz.biz/ ; then
active_node='dopinthdpmaa01.node.pmiint.ocean'
elif hadoop fs -test -e hdfs://master2.stryjz.biz/ ; then
active_node='dopinthdpmac01.node.pmiint.ocean'
fi

echo "Active Dev Name node : $active_node"

#declare paths for backup
declare -a StringArray=("apps" "data" "hdp" "staging" "system" "landing" "ranger")

#delete old snapshots
for val in "${StringArray[@]}"; do
  kinit -kt $krb  $principal
  hdfs dfs -deleteSnapshot  /$val/ $date_14
done

kinit -kt $krb  $principal
yarn application --list | grep "backup-user" >/dev/null

if [ $? -eq 0 ]; then
echo "
###############################################################
##############   There is running backup   ####################
##############           exiting           ####################
###############################################################"
        exit 0
else
echo "
##########################################
#############  Doing backup  #############
#############                #############
##########################################"

#allow snapshots
for val in "${StringArray[@]}"; do
  kinit -kt $krb  $principal
  hdfs dfsadmin -allowSnapshot /$val
done

#create snapshots
for val in "${StringArray[@]}"; do
  kinit -kt $krb  $principal
  hdfs dfs  -createSnapshot /$val $date_today
done

export HADOOP_CLIENT_OPTS="-Xmx20048M"
export HADOOP_OPTS="-Xmx20096m"

#copy data to backup to folder
for val in "${StringArray[@]}"; do
  kinit -kt /etc/security/keytabs/backup-user.keytab backup-user@stryjz.biz
  hadoop distcp  -update -i -skipcrccheck -filters /opt/tools/filters hdfs://$active_node:8020/$val/.snapshot/$date_yesterday s3a://hadoopbackup/$val &
done
fi