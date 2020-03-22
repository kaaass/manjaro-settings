#!/bin/sh

CONF_PATH=/home/kaaass/.config/aria2/aria2.conf

list=`wget -qO- https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt|awk NF|sed ":a;N;s/\n/,/g;ta"`
if [ -z "$list" ]; then
    echo "error: Cannot get trackers list!" > /dev/stderr
else
    if [ -z "`grep "bt-tracker" $CONF_PATH`" ]; then
        sed -i '$a # Trackers list -Auto generate-' $CONF_PATH
        sed -i '$a bt-tracker='${list} $CONF_PATH
        echo Successful added to aria config
    else
        sed -i "s@bt-tracker.*@bt-tracker=$list@g" $CONF_PATH
        echo Successful updated
    fi
fi
