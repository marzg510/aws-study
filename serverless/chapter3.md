## Amazon Kinesis DataStreams

```
aws kinesis create-stream --stream-name sample-stream --shard-count 1
```

データストリームができた

```
aws kinesis list-streams
```

put-records.pyを作成 => OK

## Amazon SNS

アラームの通知先となるSNSトピックを作成する

```
aws sns create-topic --name sample-sns-topic
```
SNSにトピックが作成された


## Amazon CloudWatch

アラームの作成
```
aws cloudwatch put-metric-alarm \
--alarm-name sample-kinesis-mon \
--metric-name IncomingRecords \
--namespace AWS/Kinesis \
--statistic Sum \
--period 60 \
--threshold 10 \
--comparison-operator GreaterThanThreshold \
--dimensions Name=StreamName,Value=sample-stream \
--evaluation-periods 1 \
--alarm-actions arn:aws:sns:ap-northeast-1:246262167857:sample-sns-topic
```

アラームのテスト
```
aws cloudwatch set-alarm-state --alarm-name sample-kinesis-mon \
--state-reason 'initializing' --state-value ALARM
```
履歴を見るとALARMになっているがすぐにデータ不足に戻る

## Amazon Lambda
### 関数の作成
resharding-function.py

### IAMロールの作成
trustpolicy.jsonを作成して
```
aws iam create-role --role-name sample_resharding_function_role \
--assume-role-policy-document file://trustpolicy.json
```

### IAMロールにポリシーを適用
```
aws iam put-role-policy --role-name sample_resharding_function_role \
--policy-name basic-permission \
--policy-document file://permission.json
```

### デプロイパッケージの作成
```
cd ./resharding-function
zip -r9 ../resharding-function.zip *
```

### lambdaファンクションの作成
```
aws lambda create-function --function-name resharding-function \
--zip-file fileb://resharding-function.zip \
--role arn:aws:iam::246262167857:role/sample_resharding_function_role \
--handler resharding-function.lambda_handler \
--runtime python3.6
```

### lambda関数をアラーム通知のトピックに紐付け
まずはアクセス権を追加
```
aws lambda add-permission --function-name resharding-function \
--statement-id 1 \
--action "lambda:InvokeFunction" \
--principal sns.amazonaws.com \
--source-arn arn:aws:sns:ap-northeast-1:246262167857:sample-sns-topic
```

その上でSNSトピックのサブスクライバをlambdaにする
```
aws sns subscribe \
--topic-arn arn:aws:sns:ap-northeast-1:246262167857:sample-sns-topic \
--protocol lambda \
--notification-endpoint arn:aws:lambda:ap-northeast-1:246262167857:function:resharding-function
```

## アラームのテスト

```
python put-records.py
aws kinesis describe-stream-summary --stream-name sample-stream
```

