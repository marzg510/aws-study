title: aws-enterprise
==========
date: 2018-01-02 20:12
tags: []
categories: []
- - -

## reference
* AWS Cli自分用Tips
 * https://qiita.com/takachan/items/421928dc61c51af97fb1
* AWS-CLI EC2でおなじものをつくるよ
 * https://qiita.com/bohebohechan/items/891120175efc1b3cc7c4
* 【Tips】AWS CLIを使ってAmazon EC2を起動・停止するワンライナーまとめ
 * https://dev.classmethod.jp/cloud/aws/awscli-tips-ec2-start-stop/
* [JAWS-UG CLI] EC2:#3 インスタンスの削除 (Tokyo)
 * https://qiita.com/tcsh/items/f2ac887777d374b1ad61

## EC2 httpd

### 全てのインスタンスの情報を取得
```
aws ec2 describe-instances | jq '.Reservations[].Instances[]'
aws ec2 describe-instances | jq '.Reservations[].Instances[] | {InstanceId, InstanceType, PublicDnsName, PublicIpAddress}'
aws ec2 describe-instances | jq '.Reservations[].Instances[] | {InstanceId, InstanceType, PublicDnsName, PublicIpAddress,State}'
```

### 稼働中のインスタンスIDを取得
```
ARRAY_EC2_INSTANCE_ID=$( \
  aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text \
) \
  && echo ${ARRAY_EC2_INSTANCE_ID}
EC2_INSTANCE_ID=$(echo ${ARRAY_EC2_INSTANCE_ID} | sed 's/ .*$//') && echo ${EC2_INSTANCE_ID}
```

### AMIからインスタンスを作成する
 * あらかじめキーペアdemoの作成が必要
 * あらかじめセキュリティグループの作成が必要
```
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
) && echo ${EC2_INST_ID}
```

### タグをつける
```
aws ec2 create-tags --resources  ${EC2_INST_ID} --tags '[{"Key": "Name", "Value": "Test httpd"}]'
aws ec2 create-tags --resources  i-00781a192961e077c --tags '[{"Key": "Name", "Value": "Test httpd"}]'
```

### 固定ＩＰ付与
```
aws ec2 associate-address --allocation-id eipalloc-d7230aed --instance-id ${EC2_INST_ID}
aws ec2 associate-address --allocation-id eipalloc-d7230aed --network-interface-id eni-XXXXX
```

### インスタンスのステータス確認
```
aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID}
aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].SystemStatus.Status' --output text
aws ec2 describe-instance-status --instance-ids ${EC2_INST_ID} --query 'InstanceStatuses[].InstanceState.Name' --output text
```

### 接続する
```
EC2_PUBLIC_NAME=$(aws ec2 describe-instances --instance-ids ${EC2_INST_ID} --query 'Reservations[].Instances[].PublicDnsName' --output text)
SSH_CMD="ssh -i ~/.ssh/demo.pem ec2-user@${EC2_PUBLIC_NAME}"
echo ${SSH_CMD}
ssh -i ~/.ssh/demo.pem ec2-user@ec2-13-230-196-167.ap-northeast-1.compute.amazonaws.com
```

### httpd起動
```
sudo yum update -y
sudo yum install -y httpd
sudo service httpd start
sudo chkconfig httpd on
sudo sh -c "echo 'hello,world' > /var/www/html/index.html"
```

### アクセス
```
curl http://${EC2_PUBLIC_NAME}
curl -I http://${EC2_PUBLIC_NAME}
```

### インスタンス停止
```
aws ec2 stop-instances --instance-ids i-0edf21cf22de4748d
```

### インスタンス削除
```
aws ec2 terminate-instances --instance-ids ${EC2_INSTANCE_ID}
aws ec2 terminate-instances --instance-ids i-0edf21cf22de4748d
# runningなインスタンスをすべて削除
EC2_INSTANCE_IDS=$( \
  aws ec2 describe-instances \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text \
) && echo ${EC2_INSTANCE_IDS}
aws ec2 terminate-instances --instance-ids ${EC2_INSTANCE_IDS}

```

### AMIを作る
```
aws ec2 create-image --instance-id i-XXXXXX --no-reboot --name test_httpd_01
```


## Elastic IP
### Elastic IPの一覧を取得
```
aws ec2 describe-addresses
# 未割当のＥＩＰを取得
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null]'
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output text
```

### Elastic IPを作成
```
aws ec2 allocate-address \
--dry-run
```

### Elastic IPの解放
```
EC2_EIP_ALLOC_ID=$(
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output text
) && echo ${EC2_EIP_ALLOC_ID}
aws ec2 release-address --allocation-id ${EC2_EIP_ALLOC_ID} \
--dry-run
```



## ELB

### reference
* AWS Application Load Balancer CLIメモ
 * https://qiita.com/zakky/items/fc9c9da174aafd9f87ff
* [JAWS-UG CLI] ACM入門 #9 ALBの削除
 * https://qiita.com/zakky/items/c10fb1fcb66b97982959
### 504 Gateway Timeout
* 最終的にはセキュリティグループで解決
 * ELB側：インバウンドは解放。アウトバウンドはEC2インスタンスと通信できるように。(VPC defaultなど）
 * EC2側：インバウンド/アウトバウンドは、ELBと通信できるように（VPC default)。
* ロードバランサーのセキュリティグループの推奨ルール
 * https://docs.aws.amazon.com/ja_jp/elasticloadbalancing/latest/classic/elb-security-groups.html#elb-vpc-security-groups


### 作成
* デフォルトVPCのVPC_ID取得
```
VPC_ID=$( \
        aws ec2 describe-vpcs \
          --filters Name=isDefault,Values=true \
          --query 'Vpcs[].VpcId' \
          --output text \
) \
        && echo ${VPC_ID}
```
* LB名の決定
```
ELB_LB_NAME="lb-$( date +%Y%m%d )" && echo ${ELB_LB_NAME}
```

* サブネットの指定
```
aws ec2 describe-subnets \
        --filters Name=vpcId,Values=${VPC_ID} \
        --query 'Subnets[].{SubnetId:SubnetId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone}' \
        --output text
VPC_SUBNETS=$( \
aws ec2 describe-subnets \
        --filters Name=vpcId,Values=${VPC_ID} \
        --query 'Subnets[].{SubnetId:SubnetId}' \
        --output text
) && echo ${VPC_SUBNETS}
```

* 作成
```
ELB_LB_ARN=$( \
aws elbv2 create-load-balancer --name ${ELB_LB_NAME} \
 --subnets ${VPC_SUBNETS} \
 --security-groups sg-663af003 sg-ff2d9c86 \
 --query LoadBalancers[].LoadBalancerArn --output text \
) && echo ${ELB_LB_ARN}
ELB_LB_ARN=$( \
aws elbv2 describe-load-balancers --query LoadBalancers[].LoadBalancerArn --output text \
) && echo ${ELB_LB_ARN}
```
* ターゲットグループの作成
```
ELB_TG_NAME="${ELB_LB_NAME}-tg"
ELB_TG_ARN=$(\
aws elbv2 create-target-group --name ${ELB_LB_NAME}-tg --protocol HTTP --port 80 --vpc-id ${VPC_ID} \
--query TargetGroups[].TargetGroupArn --output text \
) && echo ${ELB_TG_ARN}
```

* ターゲットグループへインスタンスを登録
```
aws elbv2 register-targets --target-group-arn ${ELB_TG_ARN} \
 --targets Id=${EC2_INST_ID},Port=80 \
#Id=${INSTANCE2_ID},Port=${INSTANCE2_PORT}
```

* リスナの作成
```
ELB_LS_ARN=$( \
aws elbv2 create-listener --load-balancer-arn ${ELB_LB_ARN} --protocol HTTP --port 80 \
 --default-actions Type=forward,TargetGroupArn=${ELB_TG_ARN} \
 --query Listeners[].ListenerArn --output text \
) && echo ${ELB_LS_ARN}
```
### 確認
```
aws elbv2 describe-load-balancers
aws elbv2 describe-load-balancers --names ${ELB_LB_NAME}
aws elbv2 describe-load-balancers --names ${ELB_LB_NAME} --query LoadBalancers[].DNSName --output text
aws elbv2 describe-listeners --load-balancer-arn ${ELB_LB_ARN}
aws elbv2 describe-target-groups
```
### 状態監視
```
aws elbv2 describe-load-balancers --load-balancer-arn ${ELB_LB_ARN} --query LoadBalancers[].State.Code --output text
aws elbv2 describe-load-balancers --query LoadBalancers[].State.Code --output text
```

### 削除
```
aws elbv2 delete-load-balancer --load-balancer-arn ${ELB_LB_ARN}
aws elbv2 delete-target-group --target-group-arn ${ELB_TG_ARN}
```

## 

## EC2 httpd ansible
* https://qiita.com/isobecky74/items/163b23d5a0e566aaa159

### install
```
pip install ansible boto
pip install boto3
```

### EC2 simple
```
cd ansible/ec2-simple
ansible-playbook main.yml
ansible-playbook -i hosts main.yml
```

### prepare
```
mkdir -p hosts
mkdir -p host_vars
mkdir -p roles/ec2/tasks
```

### inventory
```
cat >hosts/aws <<EOF
[aws]
localhost ansible_connection=local ansible_python_interpreter=/home/masaru/.pyenv/shims/python
EOF
```

### vars
host_vars/localhost.yml

### role
roles/ec2/tasks/main.yml

### site.yml

### 実行
ansible-playbook -i hosts/aws -l localhost site.yml

