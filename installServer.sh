#! /bin/bash

#####################################################################
# COMMAND LINE INPUT
#####################################################################
if [ -z "$1" ]; then
    echo "It was not specified server ip"
    exit 1 
fi
if [ -z "$2" ]; then
    echo "It was not specified database name"
    exit 1
fi
if [ -z "$3" ]; then
    echo "It was not specified postgres user name"
    exit 1
fi
if [ -z "$4" ]; then
    echo "It was not specified postgres user password"
    exit 1
fi
if [ -z "$5" ]; then
    echo "It was not specified linux user name"
    exit 1
fi
if [ -z "$6" ]; then
    echo "It was not specified django secret key"
    exit 1
fi

IP_SERVER=$1
DATABASE_NAME=$2
POSTGRES_USER=$3
POSTGRES_PASS=$4
LINUX_USER_NAME=$5
DJANGO_SECRET_KEY=$6

# name of github repository
REPOSITORY_NAME="osirisWebPlatform"
GITHUB_URL="https://github.com/felipinbombin/osirisWebPlatform.git"

#####################################################################
# SETUP
#####################################################################

SCRIPT="$(readlink "$0")"
INSTALLER_FOLDER="$(dirname "$SCRIPT")"
if [ ! -d "$INSTALLER_FOLDER" ]; then
    echo "failed to retrieve the installer folder path"
    exit 1
fi
unset SCRIPT

# move to installation folder
cd "$INSTALLER_FOLDER"


#####################################################################
# USER CONFIGURATION
#####################################################################

# stores the current path
if id "$LINUX_USER_NAME" >/dev/null 2>&1; then
    echo "User $LINUX_USER_NAME already exists.. skipping"
else
    echo "User $LINUX_USER_NAME does not exists.. CREATING!"
    adduser "$LINUX_USER_NAME"
fi

PROJECT_PATH=/home/"$LINUX_USER_NAME"
PROJECT_DIR="$PROJECT_PATH"/"$REPOSITORY_NAME"


#####################################################################
# CONFIGURATION
#####################################################################

clone_project=false
install_packages=false
postgresql_configuration=false
project_configuration=false
apache_configuration=false


#####################################################################
# CLONE PROJECT
#####################################################################

if $clone_project; then

    apt-get install --yes git

    cd "$PROJECT_PATH"

    # clone project from git
    echo ""
    echo "----"
    echo "Clone project from gitHub"
    echo "----"
    echo ""
  
    DO_CLONE=true
    if [ -d "$REPOSITORY_NAME" ]; then
        echo ""
        echo "$REPOSITORY_NAME repository already exists."
        read -p "Do you want to remove it and clone it again? [Y/n]: " -n 1 -r
        echo # (optional) move to a new line
        DO_CLONE=false
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            echo "Removing repository '$REPOSITORY_NAME' at: $(pwd)"
            rm -rf "$REPOSITORY_NAME"
            DO_CLONE=true
        fi
    fi

    if "$DO_CLONE" ; then
        git clone "$GITHUB_URL"
        chown -R "$LINUX_USER_NAME":"$LINUX_USER_NAME" "$PROJECT_PATH"
    fi

    # move to installation folder
    cd "$INSTALLER_FOLDER"
fi

#####################################################################
# REQUIREMENTS
#####################################################################

if $install_packages; then

    apt-get update
    aptget upgrade

    # install dependencies

    cd "$PROJECT_DIR"
    pip install virtualenv
    # create virtual env
    virtualenv myenv
    # activate virtualenv
    source myenv/bin/activate

    # install requirements
    pip install -r requirements.txt

    # move to installation folder
    cd "$INSTALLER_FOLDER"
fi

#####################################################################
# POSTGRESQL
#####################################################################
if $postgresql_configuration; then
  echo ----
  echo ----
  echo "Postgresql"
  echo ----
  echo ----

  CREATE_DATABASE=true
  DATABASE_EXISTS=$(sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -w "$DATABASE_NAME")
  if [ "$DATABASE_EXISTS" ]; then
      echo ""
      echo "The database $DATABASE_NAME already exists."
      read -p "Do you want to remove it and create it again? [Y/n]: " -n 1 -r
      echo # (optional) move to a new line
      CREATE_DATABASE=false
      if [[ $REPLY =~ ^[Yy]$ ]]
      then
        echo "Removing database $DATABASE_NAME..."
        sudo -u postgres psql -c "DROP DATABASE $DATABASE_NAME;"
        CREATE_DATABASE=true
      fi
  fi
  
  if "$CREATE_DATABASE" ; then
      # get the version of psql
      psqlVersion=$(psql -V | egrep -o '[0-9]{1,}\.[0-9]{1,}')
      # change config of psql
      cd "$INSTALLER_FOLDER"
      python replaceConfigPSQL.py "$psqlVersion"
      service postgresql restart
  
      # create user and database
      postgres_template_file="$INSTALLER_FOLDER"/template_postgresqlConfig.sql
      postgres_final_file="$INSTALLER_FOLDER"/postgresqlConfig.sql
      # copy the template
      cp "$postgres_template_file" "$postgres_final_file"
      # change parameters
      sed -i -e 's/<DATABASE>/'"$DATABASE_NAME"'/g' "$postgres_final_file"
      sed -i -e 's/<USER>/'"$POSTGRES_USER"'/g' "$postgres_final_file"
      sed -i -e 's/<PASSWORD>/'"$POSTGRES_PASS"'/g' "$postgres_final_file"
  
      # postgres user has to be owner of the file and folder that contain the file
      #current_owner=$(stat -c '%U' .)
      # change owner to let postgres user exec file
      chown postgres "$INSTALLER_FOLDER"/postgresqlConfig.sql
      chown postgres "$INSTALLER_FOLDER"
      sudo -u postgres psql -f "$postgres_final_file"
      rm "$postgres_final_file"
      #sudo chown "${current_owner}" "$postgres_final_file"
      #sudo chown "${current_owner}" "$INSTALLER_FOLDER"
  fi

  echo ----
  echo ----
  echo "Postgresql ready"
  echo ----
  echo ----
fi


#####################################################################
# SETUP DJANGO APP
#####################################################################
if $project_configuration; then
  echo ----
  echo ----
  echo "Project configuration"
  echo ----
  echo ----
 
  # configure wsgi
  cd "$INSTALLER_FOLDER"
  python wsgiConfig.py "$PROJECT_PATH" "$REPOSITORY_NAME"

  # create secret_key.txt file
  mkdir -p "$PROJECT_DIR"/"$REPOSITORY_NAME"/keys
  SECRET_KEY_FILE="$PROJECT_DIR"/"$REPOSITORY_NAME"/keys/secret_key.txt
  touch "$SECRET_KEY_FILE"
  echo "$DJANGO_SECRET_KEY" > "$SECRET_KEY_FILE"
 
  database_template_file="$INSTALLER_FOLDER"/template_database.py
  database_final_file="$PROJECT_PATH"/visualization/visualization/keys/database.py

  # copy the template

  cp "$database_template_file" "$database_final_file"
  sed -i -e 's/<DATABASE>/'"$DATABASE_NAME"'/g' "$database_final_file"
  sed -i -e 's/<USER>/'"$POSTGRES_USER"'/g' "$database_final_file"
  sed -i -e 's/<PASSWORD>/'"$POSTGRES_PASS"'/g' "$database_final_file"

  # create folder used by loggers if not exist
  LOG_DIR="$PROJECT_DIR"/"$REPOSITORY_NAME"/logs
  mkdir -p "$LOG_DIR"
  touch "$LOG_DIR"/file.log
  chmod 777 "$LOG_DIR"/file.log


  # install all dependencies of python to the project
  echo "--------------------------------------------------------------------------------"
  
  # uptade the model of the database
  python "$PROJECT_DIR"/manage.py migrate
  python "$PROJECT_DIR"/manage.py collectstatic

  # add the cron task data
  #python manage.py crontab add

  echo ----
  echo ----
  echo "Project configuration ready"
  echo ----
  echo ----
fi


#####################################################################
# APACHE CONFIGURATION
#####################################################################

if $apache_configuration; then
  echo ----
  echo ----
  echo "Apache configuration"
  echo ----
  echo ----
  # configure apache 2.4

  cd "$INSTALLER_FOLDER"
  configApache="transapp_visualization.conf"

  python configApache.py "$PROJECT_PATH" "$IP_SERVER" "$configApache" visualization
  a2dissite 000-default.conf
  a2ensite "$configApache"

  # create the certificfate
  # this part must be by hand

  sudo service apache2 reload

  # change the MPM of apache.
  # MPM is the way apache handles the request
  # using proceses, threads or a bit of both.

  # this is the default 
  # is though to work whith php
  # becuase php isn't thread safe.
  # django works better whith
  # MPM worker, but set up
  # the number of precess and
  # threads whith care.

  sudo a2dismod mpm_event 
  sudo a2enmod mpm_worker 

  # configuration for the worker
  # mpm.
  # apacheSetup arg1 arg2 arg3 ... arg7
  # arg1 StartServers: initial number of server processes to start
  # arg2 MinSpareThreads: minimum number of 
  #      worker threads which are kept spare
  # arg3 MaxSpareThreads: maximum number of
  #      worker threads which are kept spare
  # arg4 ThreadLimit: ThreadsPerChild can be 
  #      changed to this maximum value during a
  #      graceful restart. ThreadLimit can only 
  #      be changed by stopping and starting Apache.
  # arg5 ThreadsPerChild: constant number of worker 
  #      threads in each server process
  # arg6 MaxRequestWorkers: maximum number of threads
  # arg7 MaxConnectionsPerChild: maximum number of 
  #      requests a server process serves
  cd "$INSTALLER_FOLDER"
  sudo python apacheSetup.py 1 10 50 30 25 75

  sudo service apache2 restart

  # this lets apache add new things to the media folder
  # to store the pictures of the free report
  sudo adduser www-data "$LINUX_USER_NAME"

  echo ----
  echo ----
  echo "Apache configuration ready"
  echo ----
  echo ----
fi

cd "$INSTALLER_FOLDER"

echo "Installation ready."
echo "To check that its all ok, enter to 0.0.0.0"

