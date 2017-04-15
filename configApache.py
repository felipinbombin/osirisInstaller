
def getConfigFileHTTP(pathToProyect, projectName):
    return '''
    # path to virtual env
    WSGIPythonHome '''  + pathToProyect + '''/''' + projectName + '''/myenv

    <VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        #ServerName www.example.com

        #ServerAdmin webmaster@localhost
        #DocumentRoot /var/www/html

        Alias /static ''' + pathToProyect + '''/''' + projectName + '''/static
        <Directory ''' + pathToProyect + '''/''' + projectName + '''/static>
                Require all granted
        </Directory>

        <Directory ''' + pathToProyect + '''/''' + projectName + '''/''' + projectName + '''>
                <Files wsgi.py>
                      Require all granted
                </Files>
        </Directory>

        LoadModule wsgi_module /usr/lib/apache2/modules/mod_wsgi.so

        WSGIDaemonProcess ''' + projectName + ''' python-path=''' + pathToProyect + '''/''' + projectName + ''':''' + pathToProyect + '''/''' + projectName + '''/venv/lib/python2.7/$
        WSGIProcessGroup ''' + projectName + '''
        WSGIScriptAlias / ''' + pathToProyect + '''/''' + projectName + '''/''' + projectName + '''/wsgi.py

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf
    </VirtualHost>'''

import sys
import os

if len(sys.argv) < 4:
    pass
else:
    configFile = getConfigFileHTTP(sys.argv[1], sys.argv[4])

    #Writte the file to destination
    PATH = '/etc/apache2/sites-available/'
    pathFile = "{}{}".format(PATH, sys.argv[3])

    FILE = open(pathFile, 'w')
    for line in configFile:
        FILE.write(line)
    FILE.close()
