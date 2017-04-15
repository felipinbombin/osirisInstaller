import sys
import os

if len(sys.argv) < 2:
    pass
else:
    postgresVersion = sys.argv[1]
    path = '/etc/postgresql/' + postgresVersion + '/main/pg_hba.conf'
    FILE = open(path)

    newLines = []
    passOne = False

    for line in FILE:
        if passOne:
            passOne = False
            continue
        if line == '''# "local" is for Unix domain socket connections only\n''':
            os.system("echo done")
            newLines.append(line)
            newLines.append("local   all             all                                     md5\n")
            passOne = True
        else:
            newLines.append(line)

    FILE.close()
 
    CONFIGFILE = open(path,'w')
    for line in newLines:
        CONFIGFILE.write(line)
    CONFIGFILE.close()
