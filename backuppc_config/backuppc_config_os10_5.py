#!/usr/bin/env python

# backuppc.py
# By: Michael Durnhofer (mdurn@ucla.edu)
# 10/5/2009
#
# Primary Objectives:
# 1) Backup the pc user home directory
# 2) Copy over the ssh public key and preconfigged authorized keys file
# 3) Add a rsync entry in the sudoers file
#
# Secondary Objectives:
# 1) Create and send an email that notifies admins that the client has been set
# up and provides the necessary info to configure the backup server for the
# client.
#   Requirements:
#   a) MAC address of the network connection
#   b) Shared resource username via prompt (e.g. mdurn)
#   c) Client computer name (e.g. 17369-monster)

import re
import platform
import exceptions
import os
import shutil
from subprocess import Popen
from subprocess import PIPE
import email.iterators
from email.mime.text import MIMEText
from sys import exit
import hashlib
import smtplib
import socket

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

class OSVersionError(exceptions.Exception):
  """Prints error message indicating use of OS before Mac OS 10.5."""
  def __init__(self):
    return
  def __str__(self):
    print "","Operating System not supported. Please run on Mac OS 10.5 or\n\
    above."

def checkOS():
  """Checks to see if the operating system is at least Mac OS 10.5 and raises
  OSVersionError if not.

  """
  try:
    mac_release = platform.mac_ver()[0]
  except AttributeError, detail:
    display_exception(" ".join('platform.mac_ver()'), detail)
    exit(1)
  try:
    # split string 'x.y.z' representing version number into tuple ('x', 'y', z')
    # and use it to create the floating point number 'x.y'.
    mac_release_float = float('.'.join(re.split('\.', mac_release)[0:2]))
  except Exception, detail:
    display_exception(" ".join("float('.'.join(re.split('\.', \
      mac_release)[0:2]))'"), detail)
    exit(1)

  if mac_release_float < 10.5:
    try:
      raise OSVersionError
    except OSVersionError, detail:
      display_exception(" ".join('mac_release_float < 10.5'), detail)
      exit(1)

def createUser():
  """Creates a new user account. Sets the username, shell properties, full user
  name, user ID, group ID, home directory, and arbitrary password."""
  try:
    # get the current login name
    username = os.getlogin()
  except AttributeError, detail:
    display_exception(" ".join('os.getlogin()'), detail)
    exit(1)
  # the new user name will be 'backuppc'
  username_bkp = 'backuppc'
  bkpname_check_cmd = 'dscacheutil -q user -a name ' + username_bkp + \
      ' | grep name | awk -v ORS=\'\' {\'print $2\'}'
  bkpname_check_process = Popen(bkpname_check_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE)
  stdout, stderr = bkpname_check_process.communicate()
  if not stderr == '':
    try:
      raise RuntimeError('Checking if backuppc username already exists failed: ' \
          + stderr)
    except RuntimeError, detail:
      display_exception(" ".join(bkpname_check_cmd), detail)
      exit(1)
  # if the backuppc username already exists, terminate the program
  # TODO: maybe give option to select different backup username
  if not stdout == '':
    try:
      raise RuntimeError('The backup username, \'' + username_bkp + '\', \
          already exists.')
    except RuntimeError, detail:
      display_exception(" ".join(bkpname_check_cmd), detail)
      exit(1)

  # backup user IDs start at 501
  new_uid = 501
  uid_exists = True
  # check to see if the new user id already exists. If it does, increment by 1.
  while uid_exists == True:
    uid_check_cmd = 'dscacheutil -q user -a uid ' + str(new_uid)
    uid_check_process = Popen(uid_check_cmd, shell=True, stdout=PIPE, stderr=PIPE)
    stdout, stderr = uid_check_process.communicate()
    if not stderr == '':
      try:
        raise RuntimeError('Checking if uid already exists failed: ' +  stderr)
      except RuntimeError, detail:
        display_exception(" ".join(uid_check_cmd), detail)
        exit(1)
    elif stdout == '':
      uid_exists = False
    else:
      new_uid += 1

  # shell command to create new user
  dscl_create_cmd = 'dscl /Local/Default -create /Users/' + username_bkp
  # shell command to get the current user's full name
  get_fullname_cmd = 'dscacheutil -q user -a name ' +  username + \
      ' | grep gecos | awk -v ORS=\'\' {\'print $2,$3\'}'
  get_fullname_process = Popen(get_fullname_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE)
  stdout, stderr = get_fullname_process.communicate()
  if not stderr == '':
    try:
      raise RuntimeError('Failed to get full name of user: ' + stderr)
    except RuntimeError, detail:
      display_exception(" ".join(get_fullname_cmd), detail)
      exit(1)
  else:
    # shell command to set full name
    set_fullname_cmd = dscl_create_cmd + ' RealName \"' + \
        stdout + ' Backup\"'
  # shell command to set shell properties (set as bash)
  set_shell_cmd = dscl_create_cmd + ' UserShell /bin/bash'
  # shell command to set user ID
  set_uid_cmd = dscl_create_cmd + ' UniqueID ' + str(new_uid)
  # shell command to set group ID
  set_gid_cmd = dscl_create_cmd + ' PrimaryGroupID 20'
  # shell command to set home directory
  set_homedir_cmd = dscl_create_cmd + ' NFSHomeDirectory /var/backuppc' \
      + username_bkp

  # Get contents of system.log and use it as the input to hashlib.md5
  # in order to get a unique password in hexidecimal form. Create the shell
  # command to set the new password.
  try:
    file_reference = open('/var/log/system.log', 'rb')
    syslog = file_reference.read()
    file_reference.close()
  except Exception, detail:
    display_exception(" ".join("open('/var/log/system.log', 'rb')"), detail)
    exit(1)
  try:
    set_pass_cmd = 'dscl /Local/Default -passwd /Users/' + username_bkp + \
        ' ' + hashlib.md5(syslog).hexdigest()
  except AttributeError, detail:
    display_exception(" ".join(set_pass_cmd), detail)
    exit(1)

  # perform the shell commands to set up the new user information
  stdout, stderr = Popen(dscl_create_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
    if stderr.split().count('eDSPermissionError') >= 1:
      try:
        raise RuntimeError('Please run this program as an administrator.')
      except RuntimeError, detail:
        display_exception(" ".join(dscl_create_cmd), detail)
        exit(1)
    else:
      try:
        raise RuntimeError('Failed to set backup username: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(dscl_create_cmd), detail)
        exit(1)
  stdout, stderr = Popen(set_shell_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
      try:
        raise RuntimeError('Failed to set shell properties: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(set_shell_cmd), detail)
        revert()
        exit(1)
  stdout, stderr = Popen(set_fullname_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
      try:
        raise RuntimeError('Failed to set full name: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(set_fullname_cmd), detail)
        revert()
        exit(1)
  stdout, stderr = Popen(set_uid_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
      try:
        raise RuntimeError('Failed to set uid: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(set_uid_cmd), detail)
        revert()
        exit(1)
  stdout, stderr = Popen(set_gid_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
      try:
        raise RuntimeError('Failed to set gid: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(set_gid_cmd), detail)
        revert()
        exit(1)
  stdout, stderr = Popen(set_homedir_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
      try:
        raise RuntimeError('Failed to set home directory: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(set_homedir_cmd), detail)
        revert()
        exit(1)
  stdout, stderr = Popen(set_pass_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
      try:
        raise RuntimeError('Failed to set password: ' + stderr)
      except RuntimeError, detail:
        display_exception(" ".join(set_pass_cmd), detail)
        revert()
        exit(1)

  # make the home directory with .ssh folder and change ownership
  # to the backuppc user
  # mode 700 = 400 (read) + 200 (write) + 100 (execute) for the owner
  homedir = '/var/' + username_bkp
  try:
    os.mkdir(homedir, 0700)
  except (IOError, OSError), detail:
    display_exception(" ".join("os.mkdir(homedir, 0700)"), detail)
    revert()
    exit(1)
  try:
    os.mkdir(homedir + '/.ssh', 0700)
  except (IOError, OSError), detail:
    display_exception(" ".join("os.mkdir(homedir + '/.ssh', 0700)"), detail)
    revert()
    exit(1)
  os.chown(homedir, new_uid, 20)
  os.chown(homedir + '/.ssh', new_uid, 20)

def create_keys2():
  """Adds a hardcoded public rsa key to backuppc's .ssh/authorized_keys file"""
  ## get the username
  # username = os.getlogin()
  ## get user's ssh path
  # user_ssh_path = '/Users/' + username + '/.ssh'
  ## shell command to get user uid
  # uid_cmd = 'dscacheutil -q user -a name ' +  username + \
  #     ' | grep uid | awk -v ORS=\'\' {\'print $2\'}'
  # uid, stderr = Popen(uid_cmd, shell=True, stdout=PIPE, \
  #     stderr=PIPE).communicate()
  # if not stderr == '':
  #   try:
  #     raise RuntimeError('Failed to obtain uid of current user: ' + stderr)
  #   except RuntimeError, detail:
  #     display_exception(" ".join(uid_cmd), detail)
  #     revert()
  #     exit(1)

  ## shell command to get user gid
  # gid_cmd = 'dscacheutil -q user -a name ' +  username + \
  #     ' | grep gid | awk -v ORS=\'\' {\'print $2\'}'
  # gid, stderr = Popen(gid_cmd, shell=True, stdout=PIPE, \
  #     stderr=PIPE).communicate()
  # if not stderr == '':
  #   try:
  #     raise RuntimeError('Failed to obtain gid of current user: ' + stderr)
  #   except RuntimeError, detail:
  #     display_exception(" ".join(gid_cmd), detail)
  #     revert()
  #     exit(1)

  # set backuppc username
  bkp_username = 'backuppc'
  # get the backuppc user ssh path - /var/<username>/.ssh
  bkp_user_ssh_path = '/var/' + bkp_username + '/.ssh'
  # shell command to get the backuppc user uid
  bkp_uid_cmd = 'dscacheutil -q user -a name ' +  bkp_username + \
      ' | grep uid | awk -v ORS=\'\' {\'print $2\'}'
  bkp_uid, stderr = Popen(bkp_uid_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE).communicate()
  if not stderr == '':
    try:
      raise RuntimeError('Failed to obtain uid of the backup user: ' + stderr)
    except RuntimeError, detail:
      display_exception(" ".join(bkp_uid_cmd), detail)
      revert()
      exit(1)

  ## create ssh path if it does not exist and give user ownership mode 700
  # if not os.path.isdir(user_ssh_path):
  #   try:
  #     os.mkdir(user_ssh_path, 0700)
  #   except (IOError, OSError), detail:
  #     display_exception(" ".join("os.mkdir(user_ssh_path, 0700)"), detail)
  #     revert()
  #     exit(1)
  # os.chown(user_ssh_path, int(uid), int(gid))

  # create ssh path for backup user with ownership mode 700
  if not os.path.isdir(bkp_user_ssh_path):
    try:
      os.mkdir(bkp_user_ssh_path, 0700)
    except (IOError, OSError), detail:
      display_exception(" ".join("os.mkdir(bkp_user_ssh_path, 0700)"), detail)
      revert()
      exit(1)
  os.chown(bkp_user_ssh_path, int(bkp_uid), 20)

  ## read the contents of a private rsa key in the current working directory
  # try:
  #   orig_priv_key_file = open(os.path.join(os.getcwd(), 'backup_rsa'), 'rb')
  #   priv_key = orig_priv_key_file.read()
  #   orig_priv_key_file.close()
  # except Exception, detail:
  #   display_exception(" ".join("open(os.path.join(os.getcwd(), 'backup_rsa'), \
  #       'rb')"), detail)
  #   revert()
  #   exit(1)
  ## read the contents of a public rsa key in the current working directory
  # try:
  #   orig_pub_key_file = open(os.path.join(os.getcwd(), 'backup_rsa.pub'), 'rb')
  #   pub_key = orig_pub_key_file.read()
  #   orig_pub_key_file.close()
  # except Exception, detail:
  #   display_exception(" ".join("open(os.path.join(os.getcwd(), \
  #       'backup_rsa.pub'), 'rb')"), detail)
  #   revert()
  #   exit(1)

  ## write contents of private rsa key to 'id_rsa' in user's ssh directory
  # try:
  #   ssh_priv_key_file = open(os.path.join(user_ssh_path, 'backup_rsa'), 'w')
  #   ssh_priv_key_file.write(priv_key)
  #   ssh_priv_key_file.close()
  # except Exception, detail:
  #   display_exception(" ".join("open(os.path.join(user_ssh_path, \
  #       'backup_rsa'), 'w')"), detail)
  #   revert()
  #   exit(1)

  # write contents of public rsa key to .ssh/authorized_keys file
  try:
    pub_key = 'ssh-rsa key_goes_here'
    ssh_pub_key_file = open(os.path.join(bkp_user_ssh_path, \
        'authorized_keys'), 'a')
    ssh_pub_key_file.write(pub_key)
    ssh_pub_key_file.close()
  except Exception, detail:
    display_exception(" ".join('open(os.path.join(bkp_user_ssh_path, ' + \
        '\'authorized_keys\'), \'a\')'), detail)
    revert()
    exit(1)
  os.chown(os.path.join(bkp_user_ssh_path, 'authorized_keys'), int(bkp_uid), 20)
  os.chmod(os.path.join(bkp_user_ssh_path, 'authorized_keys'), 0600)

def edit_sudoers():
  try:
    file = open('/etc/sudoers', 'a')
  except (IOError, OSError), detail:
    display_exception(" ".join("open('/etc/sudoers', 'a')"), detail)
    revert()
    exit(1)
  try:
    file.write('backuppc ALL = NOPASSWD: /usr/bin/rsync --server '\
        + '--sender *\n')
  except (IOError, OSError), detail:
    display_exception(" ".join('file.write(backuppc ALL = NOPASSWD: ' + \
        '/usr/bin/rsync --server --sender *\\n)'), detail)
    revert()
    exit(1)

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

def email_admin():
  # get username
  username = os.getlogin()
  # shell command to get the current user's full name
  get_fullname_cmd = 'dscacheutil -q user -a name ' + username + \
      ' | grep gecos | awk -v ORS=\'\' {\'print $2,$3\'}'
  get_fullname_process = Popen(get_fullname_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE)
  fullname, stderr = get_fullname_process.communicate()
  if not stderr == '':
    try:
      raise RuntimeError('Failed to get full name of user: ' + stderr)
    except RuntimeError, detail:
      display_exception(" ".join(get_fullname_cmd), detail)
      revert()
      exit(1)
  # get network ip
  ip = socket.gethostbyname(socket.gethostname())

  # get the ethernet MAC address
  ethernetMAC_cmd = "ifconfig en0 | grep ether | awk -v ORS='' \
      {'print $2'}"
  get_ethernetMAC_process = Popen(ethernetMAC_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE)
  ethernetMAC, stderr = get_ethernetMAC_process.communicate()
  if not stderr == '':
    ethernetMAC = 'not found'
  #  try:
  #    raise RuntimeError('Failed to get ethernet MAC address: ' + stderr)
  #  except RuntimeError, detail:
  #    display_exception(" ".join(ethernetMAC_cmd), detail)
  #    exit(1)

  # get the Airport MAC address
  airportMAC_cmd = "ifconfig en1 | grep ether | awk -v ORS='' \
      {'print $2'}"
  get_airportMAC_process = Popen(airportMAC_cmd, shell=True, stdout=PIPE, \
      stderr=PIPE)
  airportMAC, stderr = get_airportMAC_process.communicate()
  if not stderr == '':
    airportMAC = 'not found'
  #  try:
  #    raise RuntimeError('Failed to get airport MAC address: ' + stderr)
  #  except RuntimeError, detail:
  #    display_exception(" ".join(airportMAC_cmd), detail)
  #    exit(1)

  FROM         = (username, username + "ccn.ucla.edu")
  SUBJECT      = fullname + "'s \'backuppc\' account has been created"
  TO           = ("support", "support@ccn.ucla.edu")
  SMTPSERVER   = "ccn.ucla.edu"

  # email body
  str = fullname + '\n' + 'Ethernet MAC Address: ' + ethernetMAC + '\n' + \
      'Airport MAC Address: ' + airportMAC + '\nNetwork IP: ' + ip + \
      '\nShared Resource Username: ' + username + '\nComputer Name: ' + \
      socket.gethostname()
  msg = MIMEText(str)

  # Set the headers
  msg['Subject'] = SUBJECT
  msg['From']    = FROM[0]
  msg['To']      = TO[0]

  # Open smtp connection to roadrunner
  s = smtplib.SMTP()
  try:
      s.connect(SMTPSERVER)
      # send email: s.sendmail(:realfrom:, :realto:, :content:)
      s.sendmail(FROM[1], TO[1], msg.as_string())
  except:
      errmsg = 'There was an smtp error. Please check your internet \
          connection and try again.'
      print(errmsg)
      revert()
  finally:
      s.close()


def main():
  """Main function."""
  print 'Running backuppc_config_os10_5.py. Please wait...'
  checkOS()
  createUser()
  create_keys2()
  edit_sudoers()
  email_admin()

if __name__=="__main__":
  main()
