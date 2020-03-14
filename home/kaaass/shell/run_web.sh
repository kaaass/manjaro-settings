#!/bin/sh

systemctl start httpd.service
systemctl start php-fpm.service
systemctl start mariadb.service
systemctl start redis.service
