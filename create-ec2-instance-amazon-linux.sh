#!/bin/bash

echo "creating ec2 instance.."
EC2_INST_ID=$( \
aws ec2 run-instances \
--image-id ami-da9e2cbc \
--key-name demo \
--count 1 \
--instance-type t2.micro \
--security-group-ids sg-8e7fb9e9 \
--query 'Instances[].InstanceId' \
--output text \
#--dry-run \
) && echo "created instance id --> ${EC2_INST_ID}"

echo "adding tags.."
aws ec2 create-tags --resources  ${EC2_INST_ID} --tags '[{"Key": "Name", "Value": "Test httpd"}]'

echo "getting Elastic IP.."
EC2_EIP_ALLOC_IDS=$(
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output text
) && echo "free EIPs -->${EC2_EIP_ALLOC_IDS}"

EIP_ALLOC_ID=${EC2_EIP_ALLOC_IDS[0]} && echo "free EIP --> ${EIP_ALLOC_ID}"

echo "waiting for the instance to be running"
#echo "aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID}"
#aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID}
#echo "aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].SystemStatus.Status' --output text"
#aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].SystemStatus.Status' --output text
#echo "instancestate name"
#aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].InstanceState.Name' --output text
INST_STATE="waiting"
while [ "${INST_STATE}" != "running" ]; do
  INST_STATE=$(aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].InstanceState.Name' --output text)
  echo "instance state ${INST_STATE}"
  sleep 1
done

echo "associating EIP.."
#aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID}
echo "aws ec2 associate-address --allocation-id ${EIP_ALLOC_ID} --instance-id ${EC2_INST_ID}"
aws ec2 associate-address --allocation-id ${EIP_ALLOC_ID} --instance-id ${EC2_INST_ID}

aws ec2 describe-instances --instance-ids ${EC2_INST_ID} | jq '.Reservations[].Instances[] | {InstanceId, InstanceType, PublicDnsName, PublicIpAddress,State}'

exit

