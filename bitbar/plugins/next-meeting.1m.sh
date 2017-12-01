#! /bin/bash

######### CONFIGURATION #########
CALENDAR="dev.ascariandrea@gmail.com" # name of the Google Calendar, e.g. gabriele@buildo.io
#################################

PATH=$PATH:/usr/local/bin

NOW=$(date +%Y-%m-%dT%H:%M:%S)
MIDNIGHT=$(date +%Y-%m-%dT23:59:59)

AGENDA=$(gcalcli --calendar $CALENDAR agenda --nocolor $NOW $MIDNIGHT)
MEETING=$(echo "$AGENDA" | cut -d " " -f 4- | head -2 | tail -1 | sed "s/^ *//g" | sed "s/    / /g")

echo " $MEETING"
echo "---"
echo "$AGENDA" | tail -n +3 # print all the events after the first
