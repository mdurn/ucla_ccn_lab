#!/bin/bash
# 10/11/2010
# Michael Durnhofer
# mdurn@ucla.edu
#
# Transfer data from dicom server data dir to cluster data dir, 
# then submit script to perform checks and write to bluray.
#
# Make sure to set the correct path to the dicom data directory
# and change the email address for error notifications.

# cleaning of caches
# logs are comprehensive in history, caches are only for last session
rm sbxfer_out_cache sbxfer_err_cache

# store date in logs
date | tee -a sbxfer_out_log sbxfer_err_log

# run first time as (to preserve folder times for preexisting scans)
# rsync -rlptDKv --ignore-existing \
# thereafter run as 
# rsync -rptOKv --ignore-existing \
rsync -rptOKv --ignore-existing \
--include "[[:alpha:]][[:alpha:]]_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/" \
--include "[[:alpha:]][[:alpha:]]_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/**" \
--include "[[:alpha:]][[:alpha:]][[:alpha:]]_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/" \
--include "[[:alpha:]][[:alpha:]][[:alpha:]]_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/**" \
--include "[[:alpha:]][[:alpha:]][[:alpha:]][[:alpha:]]_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/" \
--include "[[:alpha:]][[:alpha:]][[:alpha:]][[:alpha:]]_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/**" \
--exclude '*/' \
# CHANGE /dicom/server/data/dir/ TO THE VALID DATA DIRECTORY!!!
/dicom/server/data/dir/ sbxfer:Dicom 2>> sbxfer_err_cache | tee -a sbxfer_out_log sbxfer_out_cache

cat sbxfer_err_cache >> sbxfer_err_log

# send error notification if any important file manipulation errors
if [[ -s $sbxfer_err_cache ]] ; then
  echo "rsync had errors. sending notification..."
  errlog=sbxfer_err_cache
  outlog=sbxfer_out_cache
  # CHANGE "From\ Sender" AND toaddress@foo.com!!! 
  /usr/lib/sendmail -F From\ Sender -t toaddress@foo.com <<EOF
Subject: sbxfer rsync error
Error Log:

$errlog

Output Log:

$outlog

EOF

  exit 1
fi

# send the output cache since this will information the file transfers to bluray
scp sbxfer_out_cache sbxfer:
