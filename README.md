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
* 自分で作成したAMIのName,ImageIdの一覧を取得
```
aws ec2 describe-images --owners self | jq '.Images[] | {Name, ImageId}'
```

* 全てのインスタンスの情報を取得
```
aws ec2 describe-instances | jq '.Reservations[].Instances[]'
aws ec2 describe-instances | jq '.Reservations[].Instances[] | {InstanceId, InstanceType, PublicDnsName, PublicIpAddress}'
aws ec2 describe-instances | jq '.Reservations[].Instances[] | {InstanceId, InstanceType, PublicDnsName, PublicIpAddress,State}'
```

* 稼働中のインスタンスIDを取得
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

* AMIからインスタンスを作成する
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

* タグをつける
```
aws ec2 create-tags --resources  ${EC2_INST_ID} --tags '[{"Key": "Name", "Value": "Test httpd"}]'
aws ec2 create-tags --resources  i-00781a192961e077c --tags '[{"Key": "Name", "Value": "Test httpd"}]'
```

* 固定ＩＰ付与
```
aws ec2 associate-address --allocation-id eipalloc-d7230aed --instance-id ${EC2_INST_ID}
aws ec2 associate-address --allocation-id eipalloc-d7230aed --network-interface-id eni-XXXXX
```

* 接続する
```
ssh -i ~/.ssh/demo.pem ec2-user@ec2-13-230-196-167.ap-northeast-1.compute.amazonaws.com
```

* httpd
```
sudo yum update -y
sudo yum install -y httpd
sudo service httpd start
sudo chkconfig httpd on
sudo sh -c "echo 'hello,world' > /var/www/html/index.html"
```

* インスタンス停止
```
aws ec2 stop-instances --instance-ids i-0edf21cf22de4748d
```

* インスタンス削除
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

* AMIを作る
```
aws ec2 create-image --instance-id i-XXXXXX --no-reboot --name test_httpd_01
```


## Elastic IP
* Elastic IPの一覧を取得
```
aws ec2 describe-addresses
# 未割当のＥＩＰを取得
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null]'
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output text
```

* Elastic IPを作成
```
aws ec2 allocate-address \
--dry-run
```


* Elastic IPの解放
```
EC2_EIP_ALLOC_ID=$(
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null].AllocationId' --output text
) && echo ${EC2_EIP_ALLOC_ID}
aws ec2 release-address --allocation-id ${EC2_EIP_ALLOC_ID} \
--dry-run
```

## ELB
## 
