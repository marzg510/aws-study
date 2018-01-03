#!/bin/bash

./terminate-all-running-ec2.sh
./release-eip.sh
./delete-elb.sh

