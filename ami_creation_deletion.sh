#!/bin/bash

#Script to create AMI of server on daily basis and deleting AMI older than 3 days.

instance_list=$1

DATE=`date +%Y%m%d-%H`
From="autoami@tejdrive.com "
To="Cloud.Consumer.DevOps@ril.com"
mail_body=/tmp/ami_report
echo -e "----------------------------------\n   `date`   \n----------------------------------" > $mail_body

for instance_id in ${instance_list//,/ }; do

#Get the instance name from the instance id.
instance_name=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value[]]' --output text)

if [[ $instance_name == "" ]] ; then
echo -e "Instance-ID ($instance_id) scheduled for auto AMI creation from $HOSTNAME doesn't exist. Please check." | /bin/mail -A ses -s "$instance_id scheduled for AMI doesn't exist" -r $From $To
exit
else
#Create the AMI name.
ami_name=$(echo "$instance_name-$DATE")
#To create AMI from the instance
ami_id=$(aws ec2 create-image --instance-id "$instance_id" --name "$ami_name" --description "Auto AMI from $instance_name ($instance_id)" --no-reboot --output text)
#Tag the AMI.
aws ec2 create-tags --resources $ami_id --tags Key=Instance_id,Value=$instance_id Key=Date,Value=$DATE

if [[ $ami_id != "" ]];then
echo -e "$ami_id ($ami_name) created successfully from $instance_name ($instance_id).\n" >> $mail_body
else
echo -e "AMI creation failed from $instance_name ($instance_id). Please check.\n" >> $mail_body
fi

#############Auto Delete 2 days old AMI.#############
DATE_d=`date +%Y%m%d-%H --date '2 days ago'`
ami_name_d=$(echo "$instance_name-$DATE_d")

#Find the AMI need to be Deregister.
ami_id_d=$(aws ec2 describe-images --filters Name=name,Values=$ami_name_d Name=tag-key,Values=Instance_id Name=tag-value,Values=$instance_id --query 'Images[*].{ID:ImageId}' --output text)

if [[ $ami_id_d != "" ]]; then
#Find the snapshots attached to the AMI need to be Deregister.
aws ec2 describe-images --image-ids $ami_id_d --query 'Images[].BlockDeviceMappings[].Ebs.SnapshotId' --output text > /tmp/snap.txt
#Deregistering the AMI
aws ec2 deregister-image --image-id $ami_id_d
#Deleting snapshots attached to AMI
for i in `cat /tmp/snap.txt`;do aws ec2 delete-snapshot --snapshot-id $i ; done
echo -e "$ami_id_d deleted with attached snapshot `cat /tmp/snap.txt`\n" >> $mail_body
fi
fi
done
cat $mail_body | /bin/mail -A ses -s "Auto backup report `date +%d%b%y`" -r $From $To
