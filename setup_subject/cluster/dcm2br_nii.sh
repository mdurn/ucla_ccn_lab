#!/bin/bash
# Michael Durnhofer
# mdurn@ucla.edu
# 4/6/11
#
# Create a list of subjects existing in each study on Bluray and use dcm_convert.py to
# convert to nii.gz in the setup subject framework.
#
# Make sure to set brdir and datadir to the correct paths!

# CHANGE brdir AND datadir TO VALID PATHS!!!
brdir="/path/to/bluray/dir"
datadir="/path/to/data/dir"

# perform these actions for each study found in Dicom2BR
for study in `ls Dicom2BR`; do
  if [ ! -d "${datadir}/${study}" ]; then
    mkdir ${datadir}/${study}
  fi
  if [ ! -d "${datadir}/${study}/subjects" ]; then
    mkdir ${datadir}/${study}/subjects
  fi

  # create a list of all dicom subject folders on BR for each study listed in the Dicom2BR folder
  # Only happens if the br dir is found or else we exit because something is wrong! (eg br not mounted)
  if [ -d "${brdir}/${study}" ]; then
    subject_list=$(ls -l ${brdir}/${study}/dicom | tail -n +2 | awk '{ for (i=9; i<NF; i++) printf("%s ", $i); printf($NF); printf("\n") }')
  else
    exit 1
  fi
  
  #DEBUG
  echo "study: ${study}"

  # for each subject in the study do dcm_convert to the correct data dir
  for subject in $subject_list; do
    if [ ! -d "${datadir}/${study}/subjects/${subject}" ]; then
      mkdir ${datadir}/${study}/subjects/${subject}
    fi

    outdir=${datadir}/${study}/subjects/${subject}/nii
    logdir=${datadir}/${study}/subjects/${subject}/notes
    rootdir=${brdir}/${study}/dicom/${subject}
    
    #DEBUG
    #echo "subject: ${subject}"
    #echo "outdir: $outdir"
    #echo "logdir: $logdir"
    #echo "rootdir: $rootdir"

    # see dcm_convert.py for options or do "python dcm_convert -h"
    # -s is very important so we are not overwriting the same things every time
    python dcm_convert.py -t mri_convert -f nii.gz -d $outdir -r $rootdir -b -l $logdir -m -s

    # create link to the subjects dicom dir on BR
    if [ ! -L "${datadir}/${study}/subjects/${subject}/dicom" ]; then
      ln -s ${brdir}/${study}/dicom/${subject} ${datadir}/${study}/subjects/${subject}/dicom
    fi
  done
done
