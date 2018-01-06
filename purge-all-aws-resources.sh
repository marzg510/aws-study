#!/bin/bash

cd $(dirname $0)

./terminate-all-running-ec2.sh
./release-eip.sh
./delete-elb.sh


