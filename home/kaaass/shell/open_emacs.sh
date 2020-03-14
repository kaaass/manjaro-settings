#!/bin/sh

WID=$(xdotool search "emacs@kaaass-pc" | head -1)
ACT=$(xdotool getactivewindow)

if [ "$WID" == "$ACT" ]; then
    xdotool windowminimize --sync $WID
else
    if [[ "$WID" ]]; then
        xdotool windowactivate --sync $WID
    else
        emacs
        xdotool windowactivate --sync $WID
    fi
fi
