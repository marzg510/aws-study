#!/bin/bash

EC2_EIP_ALLOC_ID=$(
#aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output text
aws ec2 describe-addresses --query 'Addresses[].AllocationId' --output text
) && echo "target EIP allocate id --> ${EC2_EIP_ALLOC_ID}"
[ "${EC2_EIP_ALLOC_ID}" != "" ] && aws ec2 release-address --allocation-id ${EC2_EIP_ALLOC_ID}
#--dry-run

