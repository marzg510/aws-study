#!/bin/bash

# runningなEC2インスタンスをすべて削除
EC2_INSTANCE_IDS=$( \
  aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text \
) \
&& echo "target instances ${EC2_INSTANCE_IDS}" \
&& aws ec2 terminate-instances --instance-ids ${EC2_INSTANCE_IDS}

