#!/bin/bash

# HAProxy configurator script for Linux
#
# Copyright Exceliance
# v 1.1 - August 16th, 2013


help () {
  echo "Usage: ${0##*/} <template name>"
  exit 1
}

if [[ $# -eq 0 ]]; then
  help
fi

list_required_information () {
TMP=$(sed  -n '
/^# required information:/,/^# end of required information/{
 p
}
' $1 | fgrep -v 'required information'
)

LIST=""
for f in $TMP
do
  if [[ $f != *\<*\>* ]]; then
    continue
  fi
  LIST="$LIST $f"
done

echo $LIST
}

LIST=$(list_required_information $1)

## updating the user with required information
echo "Please prepare the following information before carying on"
for f in $LIST
do
  echo $f
done
echo
read -p "Confirm you're ready by typing 'y': " -n 1 -r 
if [[ $REPLY =~ ^[^Yy]$ ]]; then
  echo
  echo "see you later..."
  exit 1
fi

clear
FILENAME="${1%%.*}.conf"
echo "Preparing configuration file \"$FILENAME\""
cp $1 $FILENAME
sed  -i '
/^# required information:/,/^# end of required information/{
 d
}
' $FILENAME

## prompt user for required information
for f in $LIST
do
  read -p "Value for $f: " -r 
  sed -i "s~$f~$REPLY~g" $FILENAME
done

echo "Configuration file is ready: $FILENAME"

