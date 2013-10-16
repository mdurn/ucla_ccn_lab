#!/u/home9/FMRI/apps/usr/bin/python
import os, re, shutil

# ANSI Colors class
class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[31;1m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''

def prompt_and_return(msg):
    message = msg + " [yes, no]: "
    response = None

    while response != 'yes' or response != 'no':
        response = raw_input(message)
        if response == "yes":
            return True
        elif response == "no":
            return False
        else:
            print "You", bcolors.OKBLUE, "must", bcolors.ENDC,
            print "specify either", bcolors.OKGREEN, " 'yes'",
            print bcolors.ENDC, " or", bcolors.OKGREEN, " 'no'",
            print bcolors.ENDC, " to continue"

def get_tsplot_list(path):
    match = re.compile('^tsplot$').match
    dir_list = []
    for path, dirs, files in os.walk(path):
        for d in dirs:
            if match(d): dir_list.append(os.path.join(path, d))
    return dir_list

def get_ds_store_list(path):
    match = re.compile('^\.DS_Store$').match
    store_list = []
    for path, dirs, files in os.walk(path):
        for f in files:
            if match(f): store_list.append(os.path.join(path, f))
    return store_list

def get_ext_attr_list(path):
    """Get list of extended attributes"""
    match = re.compile('^\._.*').match
    ex_list = []
    for path, dirs, files in os.walk(path):
        for f in files:
            if match(f): ex_list.append(os.path.join(path, f))
    return ex_list

def get_empty_dirs(path):
    dir_list = []
    for p, dirs, files in os.walk(path):
        if len(files) == 0 and len(dirs) == 0: dir_list.append(p)

    return dir_list

def get_empty_files(path):
    """Return list of all files that contain no data, e.g. 0 bytes"""
    empty_files = []
    for p, dirs, files in os.walk(path):
        for f in files:
            if os.path.getsize(os.path.join(p, f)) == 0:
                empty_files.append(os.path.join(p, f))
    return empty_files

def confirm_and_remove(file_type, root, list_func, delete):
    """
    confirm_and_remove(file_type, root, list_func, delete)

    file_type:  type of file being search for, only used for displaying
                messages
     root:      root path to search
     list_func: function used to retrieve list of files
     delete:    function to use for file removal

     The list_func must take one argument that specifies the root path to
     gather list from
    """
    file_list = None
    msg = "Would you like to remove all %s's" % file_type
    if prompt_and_return(msg):
        msg = "Building list of %s's. . ." % file_type
        print(bcolors.OKGREEN + msg + bcolors.ENDC)
        file_list = list_func(root)

        print("\n".join(file_list))
        if len(file_list) > 0:
            msg = "%d matches found" % len(file_list)
            print bcolors.OKGREEN + msg + bcolors.ENDC

            msg = "Would you like to permanently delete these?"
            if prompt_and_return(msg):
                for f in file_list:
                    delete(f)

        else:
            print bcolors.OKGREEN + "Nothing found!" + bcolors.ENDC
    else:
        msg = "Skipping deletion of %s's" % file_type
        print bcolors.OKGREEN + msg + bcolors.ENDC

def main():
    """Main method for the clean_up.py script"""
    warning = """
WARNING: The following script permanantly and irrevocably removes files and
directories from the current working directory. Prior to each file type
removal, a list of the files to be removed are printed and confirmation of
deletion is requested.
    """
    empty_dir_warning = """
The remove empty directories task will remove all empty directories. It will
also remove the parent directory if it becomes empty after the removal of a
child.
For example, for a series of directories foo/bar/bah the only thing in each
directory is another empty directory. This will remove bah, then bar, than
foo.

This method is "safe" in the sense that it will NOT remove a directory that is
not completely empty.
        """

    root = os.getcwd()
    # This dispatch dict is for standard file removals
    dispatch_dict = {
        'tsplot': [get_tsplot_list, shutil.rmtree],
        '.DS_store': [get_ds_store_list, os.remove],
        'Extended Attributes': [get_ext_attr_list, os.remove],
        'Empty Directories': [get_empty_dirs, os.removedirs],
        'Empty Files': [get_empty_files, os.remove]
    }


    print bcolors.WARNING, warning, bcolors.ENDC

    msg = "I understand the risks and wish to proceed."
    if not prompt_and_return(msg):
        print(bcolors.OKGREEN + " Exiting Now. . ." + bcolors.ENDC)
        exit()

    print bcolors.WARNING + empty_dir_warning + bcolors.ENDC
    msg = """I understand that empty directory removal will clean out ALL
empty directories and their parents if they are empty as a result (you can
skip this removal later, we are merely confirming the user understands the
implications)"""

    if not prompt_and_return(msg):
        print(bcolors.OKGREEN + "Exiting Now. . . " + bcolors.ENDC)
        exit()

    for key, value in dispatch_dict.iteritems():
        confirm_and_remove(key, root, value[0], value[1])


    msg = "All Done!"
    print(bcolors.OKBLUE + msg + bcolors.ENDC)

if __name__ == "__main__":
    main()
