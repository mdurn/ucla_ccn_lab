#!/bin/bash
# 12/2/2010
# Michael Durnhofer
# mdurn@ucla.edu
#
# Send error email if automate.sh encounters error and store errors in log.
# Make sure to set a valid email address!

if [[ -s $dcm2br_err_cache ]] ; then
  cat dcm2br_err_cache >> dcm2br_err_log
  echo "move to Dicom2BR had errors. sending notification..."
  errlog=dcm2br_err_cache
  outlog=dcm2br_out_cache
  # CHANGE username@mail TO A VALID EMAIL ADDRESS!!!
  /usr/lib/sendmail -t username@mail <<EOF
Subject: sbxfer Dicom2BR error
Error Log:

$errlog

Output Log:

$outlog

EOF

  exit 1
fi
