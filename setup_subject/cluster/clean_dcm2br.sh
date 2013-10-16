#!/bin/bash
# 12/6/2010
# Michael Durnhofer
# mdurn@ucla.edu
#
# Clean up Files older than 1 week from Dicom2BR

dicom2br_dirs=$(ls -dl --time-style=+%m/%d/%Y ./Dicom2BR/*/*/*/ | awk -F" " '{ print $6"-"$7 }')
for i in $dicom2br_dirs; do
  current_dir=$(echo $dicom2br_dirs | awk -F"-" '{ print $2 }')
  dir_date=$(echo $dicom2br_dirs | awk -F"-" '{ print $1 }')
  current_date=$(date +%m/%d/%Y)
  difference=$(sh days-between.sh $current_date $dir_date)
  if (( $difference > 7 )); then
    rm -r $current_dir
  fi
done
