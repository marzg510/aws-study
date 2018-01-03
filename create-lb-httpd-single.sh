#!/bin/bash

EC2_SG_IDS="sg-663af003 sg-8e7fb9e9"

echo "creating ec2 instances.."
EC2_INST_ID=$( \
aws ec2 run-instances \
--image-id ami-da9e2cbc \
--key-name demo \
--count 1 \
--instance-type t2.micro \
--security-group-ids ${EC2_SG_IDS} \
--query 'Instances[].InstanceId' \
--output text \
#--dry-run \
) && echo "created instance id --> ${EC2_INST_ID}"
export EC2_INST_ID

echo "adding tags.."
aws ec2 create-tags --resources  ${EC2_INST_ID} --tags '[{"Key": "Name", "Value": "httpd"},{"Key": "Number", "Value": "1"}]'

#echo "waiting for the instance to be running"
#INST_STATE="waiting"
#while [ "${INST_STATE}" != "running" ]; do
#  INST_STATE=$(aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].InstanceState.Name' --output text)
#  echo "instance state ${INST_STATE}"
#  sleep 1
#done

#echo "adding ssh known_hosts.. "
EC2_PUBLIC_NAME=$(aws ec2 describe-instances --instance-ids ${EC2_INST_ID} --query 'Reservations[].Instances[].PublicDnsName' --output text)
#ssh-keygen -R ${EC2_PUBLIC_NAME}
#ssh-keyscan -H ${EC2_PUBLIC_NAME} >>~/.ssh/known_hosts

echo "generating ssh command.."
SSH_CMD="ssh -i ~/.ssh/demo.pem ec2-user@${EC2_PUBLIC_NAME}"
echo ${SSH_CMD}

echo "installing httpd.."
${SSH_CMD} sudo yum update -y
${SSH_CMD} sudo yum install -y httpd
${SSH_CMD} sudo service httpd start
${SSH_CMD} sudo chkconfig httpd on
${SSH_CMD} "echo 'hello,world(#1)' | sudo tee /var/www/html/index.html"


ELB_LB_NAME="test-m510" && echo ${ELB_LB_NAME}
ELB_TG_NAME="${ELB_LB_NAME}-tg"
ELB_SG_IDS="sg-663af003 sg-ff2d9c86"

echo "getting VPC ID.."
VPC_ID=$( \
        aws ec2 describe-vpcs \
          --filters Name=isDefault,Values=true \
          --query 'Vpcs[].VpcId' \
          --output text \
) && echo "VPC ID=${VPC_ID}"

echo "creating target group(${ELB_TG_NAME}).."
ELB_TG_ARN=$(\
aws elbv2 create-target-group --name ${ELB_TG_NAME} --protocol HTTP --port 80 --vpc-id ${VPC_ID} \
--query TargetGroups[].TargetGroupArn --output text \
) && echo "Target Group ARN=${ELB_TG_ARN}"

echo "registering instances.."
aws elbv2 register-targets --target-group-arn ${ELB_TG_ARN} \
 --targets Id=${EC2_INST_ID},Port=80 \
#Id=${INSTANCE2_ID},Port=${INSTANCE2_PORT}

echo "getting subnets.."
VPC_SUBNETS=$( \
aws ec2 describe-subnets \
        --filters Name=vpcId,Values=${VPC_ID} \
        --query 'Subnets[].{SubnetId:SubnetId}' \
        --output text
) && echo "subnets=${VPC_SUBNETS}"

echo "creating load balancer(${ELB_LB_NAME}).."
ELB_LB_ARN=$( \
aws elbv2 create-load-balancer --name ${ELB_LB_NAME} \
 --subnets ${VPC_SUBNETS} \
 --security-groups ${ELB_SG_IDS} \
 --query LoadBalancers[].LoadBalancerArn --output text \
) && echo "ELB ARN=${ELB_LB_ARN}"

echo "creating listener.."
ELB_LS_ARN=$( \
aws elbv2 create-listener --load-balancer-arn ${ELB_LB_ARN} --protocol HTTP --port 80 \
 --default-actions Type=forward,TargetGroupArn=${ELB_TG_ARN} \
 --query Listeners[].ListenerArn --output text \
) && echo "Listener ARN=${ELB_LS_ARN}"

echo "create ELB complete,please access this url"
aws elbv2 describe-load-balancers --names ${ELB_LB_NAME} --query LoadBalancers[].DNSName --output text

exit

