#!/bin/bash

echo "deleting elb.."
ELB_LB_ARN=$( \
aws elbv2 describe-load-balancers --query LoadBalancers[].LoadBalancerArn --output text \
) && echo "target ELB ARN=${ELB_LB_ARN}"
#
#ELB_TG_ARN=$( \
#aws elbv2 describe-listeners --load-balancer-arn ${ELB_LB_ARN} \
#--query "Listeners[].[ListenerArn,DefaultActions[].TargetGroupArn]" --output text
#) && echo "target TG ARN=${ELB_TG_ARN}"

ELB_ARNS=($( \
aws elbv2 describe-listeners --load-balancer-arn ${ELB_LB_ARN} \
--query "Listeners[].[ListenerArn,DefaultActions[].TargetGroupArn]" --output text
))

ELB_LS_ARN=${ELB_ARNS[0]} && echo "ELB LS ARN=${ELB_LS_ARN}"
ELB_TG_ARN=${ELB_ARNS[1]} && echo "ELB TG ARN=${ELB_TG_ARN}"

echo "deleting listener.."
aws elbv2 delete-listener --listener-arn ${ELB_LS_ARN}
echo "deleting load balancer.."
aws elbv2 delete-load-balancer --load-balancer-arn ${ELB_LB_ARN}
echo "deleting target group.."
aws elbv2 delete-target-group --target-group-arn ${ELB_TG_ARN}

echo "finish"
