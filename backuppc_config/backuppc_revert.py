#!/usr/bin/env python

# backuppc_revert.py
# By: Michael Durnhofer (mdurn@ucla.edu)
# 10/19/2009
#
# Reverts all changes made to the system by backuppc.py.

import os
import shutil
from subprocess import Popen, PIPE
from sys import exit

def display_exception(cmd, inst):
  """Displays a cocoa dialog of the exception to the user"""
  osa_cmd = """
  tell application "System Events"
      activate
      display dialog "Command:\n %s \nResulted in an error:\n %s"
  end tell
  """ % (cmd, inst)
  osa = ['/usr/bin/osascript', '-e', osa_cmd]
  output = Popen(osa, stdout=PIPE, stderr=PIPE).communicate()[0]

def revert():
  """Reverts all of the changes made by backuppc.py"""
  print 'Reverting all system changes made...'
  username = os.getlogin()
  bkp_username = 'backuppc'

  # remove the backuppc user account
  check_username_cmd = 'dscacheutil -q user -a name ' + bkp_username
  stdout, stderr = Popen(check_username_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
    try:
      raise RuntimeError('Failed to look up the backuppc user info: ' + stderr)
    except RuntimeError, detail:
      display_exception(" ".join(check_username_cmd), detail)
      exit(1)
  if not stdout == '':
    delete_user_cmd = 'dscl /Local/Default -delete /Users/' + bkp_username
    stdout, stderr = Popen(delete_user_cmd, shell=True, stdout=PIPE, \
        stderr=PIPE).communicate()
    if not stderr == '':
      try:
        raise RuntimeError('Failed to delete the backuppc user account: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(delete_user_cmd), detail)
        exit(1)
  # remove the backuppc user home directory
  if os.path.isdir('/var/' + bkp_username):
    try:
      shutil.rmtree('/var/' + bkp_username)
    except (IOError, OSError), detail:
      display_exception(" ".join("shutil.rmtree('/var/' + bkp_username)"), detail)
      exit(1)

  ## remove the rsa private key from the user's .ssh folder
  # if os.path.exists('/Users/' + username + '/.ssh/backup_rsa'):
  #   try:
  #     os.remove('/Users/' + username + '/.ssh/backup_rsa')
  #   except (IOError, OSError), detail:
  #     display_exception(" ".join('os.remove(\'/Users/\' + username + ' + \
  #         '\'/.ssh/backup_rsa\')'), detail)
  #     exit(1)

  # remove the added line from the sudoers file
  sudoer_line = 'backuppc ALL = NOPASSWD: /usr/bin/rsync --server '\
      + '--sender *\n'
  try:
    file = open('/etc/sudoers', 'r')
  except (IOError, OSError), detail:
    display_exception(" ".join("open('/etc/sudoers', 'r')"), detail)
    exit(1)
  lines = file.readlines()
  file.close()
  for line in lines:
    if line == sudoer_line or line == sudoer_line + '\n':
      lines.remove(line)
      break
  try:
    file = open('/etc/sudoers', 'w')
  except (IOError, OSError), detail:
    display_exception(" ".join("open('/etc/sudoers', 'w')"), detail)
    exit(1)
  file.writelines(lines)
  file.close()
  print 'Reversion complete'

def main():
  """Main function."""
  revert()

if __name__=="__main__":
  main()
