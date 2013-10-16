#!/bin/bash
# 12/2/2010
# Michael Durnhofer
# mdurn@ucla.edu
#
# Initiation of file transfer from Staglin Server to Dicom dir.
# Automation of file transfers from Dicom dir of files received from Staglin Server to Blu Ray.
#
# Make sure to set the right path for brdir!!!
#
# dcm2br_out_log is a comprehensive history of all file manipulations
# dcm2br_out_cache is the history from the last session
# dcm2br_err_log is a comprehensive history of all errors that have occurred dring file manipulation
# dcm2br_err_cache is the error history from the last session
# dcm2br_links_cache keeps track of the links that should be established from Dicom dir to BR dir for the current session

ssh dicom "cd scripts; cd sbxfer; sh sbxfer.sh"

# cleaning
rm dcm2br_out_cache
rm dcm2br_err_cache
rm dcm2br_links_cache

# store the date in the lgs
date | tee -a dcm2br_out_log dcm2br_err_log

# receiver location of dicoms from server
dcmdir="Dicom"
# location of formatted directories to be moved to BR, kept for one week
dcm2br="Dicom2BR"
# blu ray dir (CHANGE THIS TO THE CORRECT PATH!)
brdir="/path/to/bluray/dir"

# create dcmdir and dcm2br dir if not already created
if [ ! -d "${dcmdir}" ]; then
  mkdir ${dcmdir}
fi
if [ ! -d "${dcm2br}" ]; then
  mkdir ${dcm2br}
fi

# moves files from dcmdir to dcm2br in the correct dir format and creates initial links_cache.
# the list of files to move to dcmbr is taken from the cache file sent from the dicom server from rsync.
# the list is parsed for the top level dir for i.
for i in `cat sbxfer_out_cache | grep ^.*_[0-9][0-9][0-9][0-9][0-9]_[0-1][0-9]_[0-3][0-9]_[0-9][0-9]/$`; do
  # awk1 = study abbreviation
  awk1=`echo $i | awk -F"_" '{ print $1 }'`
  # creat the study abbreviation folder and dicom dir in dcm2br if DOE
  if [ ! -d "${dcm2br}/${awk1}" ]; then
    mkdir ${dcm2br}/${awk1}
    mkdir ${dcm2br}/${awk1}/dicom
  fi
  # awk12 = [study abbreviation]_[study id]
  awk12=`echo $i | awk -F"_" '{ print $1"_" $2 }'`
  # make the study folder in the study's dicom folder
  mkdir ${dcm2br}/${awk1}/dicom/${awk12}
  # use the study date from the original dicom path
  scandate=`find ${dcmdir}/${i}*/ -maxdepth 1 | tail -n 1 | awk -F"/" '{ print $4 }'`
  # move the parent dir from the actual scans (eg PI_NAME^STUDY_1) to the study's scandate folder
  # start the links_links cache
  dcm_to_move=${dcmdir}/${i}*/*/*
  if [ ! -L $dcm_to_move ]; then
    mv -v $dcm_to_move ${dcm2br}/${awk1}/dicom/${awk12}/${scandate} 2>> dcm2br_err_cache | tee -a dcm2br_out_log dcm2br_links_cache dcm2br_out_cache
  fi
done

# email and stop if errors
sh check_dcm2br_err.sh
if [[ $? == 1 ]]; then
  exit 1
fi

# edit links cache to reflect link to brdir instead of dcm2br
for i in $(cat dcm2br_links_cache | awk -F"\`" '{ print $3 }' | awk -F"'" '{ print $1 }'); do
  awk2345=$(echo $i | awk -F"/" '{ print $2"/" $3"/" $4"/" $5 }')
  # below commented code was used before to make incremental folders if the location aready existed on BR (instead of date)
  # awk234=$(echo $awk234 | sed '$s:.$::')
  #j=1;
  #while [ -d "${brdir}/${awk234}${j}" ]; do
  #  j=$(($j+1))
  #done
   
  sed -i "s:${dcm2br}/${awk2345}:${brdir}/${awk2345}:" dcm2br_links_cache 2>> dcm2br_err_cache
  #mv ${dcm2br}/${awk234}1 ${dcm2br}/${awk234}${j} 2>> dcm2br_err_cache | tee -a dcm2br_out_log dcm2br_out_cache
done

echo "changing dcm2br_links_cache..." | tee -a dcm2br_out_log dcm2br_out_cache dcm2br_err_log
cat dcm2br_links_cache | tee -a dcm2br_out_log dcm2br_out_cache

# email and stop if errors
sh check_dcm2br_err.sh
if [[ $? == 1 ]]; then
  exit 1
fi

echo "rsyncing with BluRay..." | tee -a dcm2br_out_log dcm2br_out_cache dcm2br_err_log
# sync dcm2br dir to brdir
rsync -rlptDv --ignore-existing ${dcm2br}/ ${brdir} 2>> dcm2br_err_cache | tee -a dcm2br_out_cache dcm2br_out_log

# email and stop if errors
sh check_dcm2br_err.sh
if [[ $? == 1 ]]; then
  exit 1
fi

echo "creating links from Dicom dir to BluRay..." | tee -a dcm2br_out_log dcm2br_out_cache dcm2br_err_log
# i is one line of the links without spaces
for i in $(cat dcm2br_links_cache | awk -F" " '{ print $1 $2 $3 }'); do
  dcmlink=$(echo $i | awk -F"\`" '{ print $2 }' | awk -F"'" '{ print $1 }')
  brpath=$(echo $i | awk -F"\`" '{ print $3 }' | awk -F"'" '{ print $1 }')
  ln -vs $brpath $dcmlink 2>> dcm2br_err_cache | tee -a dcm2br_out_cache dcm2br_out_log
done

# email and stop if errors
sh check_dcm2br_err.sh
if [[ $? == 1 ]]; then
  exit 1
fi

# convert dicoms on BR to nii within the setup subjects framework
# this will store logs and dicom header in "notes", nii.gz
# files in "nii", and create link ("dicom") to original dicoms.
sh dcm2br_nii.sh

# Clean Dicom2BR scans older than one week
sh clean_dcm2br.sh

cat dcm2br_err_cache >> dcm2br_err_log
