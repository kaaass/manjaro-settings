#!/bin/sh

systemctl start rabbitmq.service
rabbitmq-plugins enable rabbitmq_management 
