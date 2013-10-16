#!/usr/bin/env python
###############################################################################
#
# quotareport.py
# By: Michael Durnhofer
# 11/11/2009
#
# Objective 1 (partially complete):
# a) capture the output of the quota -g command and create a group quota report
# b) when either the file count or quantity quota reaches 90% of the allowed
#    maximum, send a notification email to the respective lab manager.
# c) this script should be run on a daily schedule, but email notifications
#    should not exceed more than once per week
#
# Objective 2 (not completed):
# a) gathers a file count and data usage for each individual user
# b) the collected data should be stored in the groups directory, located in
#    /u/home9/groupname/data/ in a folder named 'stats'
# c) a well formatted file or database should be stored here
###############################################################################

from subprocess import Popen
from subprocess import PIPE
from sys import exit
import re

class QuotaReport:

  def get_report(self):
    report, stderr = Popen('quota -g', shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
    if report == '':
      try:
        raise RuntimeError('Failed to retrieve quota report: ' + stderr)
      except RuntimeError, detail:
        exit(1)
    return report
    
  def get_grouplist(self, report):
    groups = []
    splitreport = report.split()
    for i in splitreport:
      if re.match('titan', i):
        name = (i.split('/'))[-1]
        data = float(splitreport[splitreport.index(i) + 1])
        datalmt = float(splitreport[splitreport.index(i) + 3])
        files = float(splitreport[splitreport.index(i) + 4])
        filelmt = float(splitreport[splitreport.index(i) + 6])
        group = HoffmanGroup(name, data, datalmt, files, filelmt)
        if len(groups) == 0:
          groups.append(group)
        else:
          exists = False
          for j in groups:
            if name == j.get_name():
              exists = True
          if exists == False:
            groups.append(group)
    return groups
    
  def get_90pct_groups(self, groups):
    groups2notify = []
    for group in groups:
      if group.calcdatapercent() >= 90.0 or group.calcfilepercent() >= 90.0:
        groups2notify.append(group)
    return groups2notify
  
    
class HoffmanGroup:
  def __init__(self, name, data, datalmt, files, filelmt):
    self.name = name
    self.data = data
    self.datalmt = datalmt
    self.files = files
    self.filelmt = filelmt
  
  def get_name(self):
    return self.name
  def get_data(self):
    return self.data
  def get_datalmt(self):
    return self.datalmt
  def get_files(self):
    return self.files
  def get_filelmt(self):
    return self.filelmt
    
  def calcdatapercent(self):
    return 100*self.get_data()/self.get_datalmt()
  def calcfilepercent(self):
    return 100*self.get_files()/self.get_filelmt()
  def get_datapercent_str(self):
    return '%' + str(self.calcdatapercent())
  def get_filepercent_str(self):
    return '%' + str(self.calcfilepercent())
    	    
def main():
  quotarep = QuotaReport()
  report = quotarep.get_report()
  groups = quotarep.get_grouplist(report)
  groups2notify = quotarep.get_90pct_groups(groups)
    
if __name__=="__main__":
  main()
