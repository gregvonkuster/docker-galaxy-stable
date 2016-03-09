#!/bin/bash

# start Galaxy
service postgresql start
install_log='galaxy_install.log'

# wait for database to finish starting up
STATUS=$(psql 2>&1)
while [[ ${STATUS} =~ "starting up" ]]
do
  echo "waiting for database: $STATUS"
  STATUS=$(psql 2>&1)
  sleep 1
done

echo "starting Galaxy"
sudo -E -u galaxy ./run.sh --daemon --log-file=$install_log --pid-file=galaxy_install.pid

galaxy_install_pid=`cat galaxy_install.pid`

while : ; do
    tail -n 2 $install_log | grep -E -q "Removing PID file galaxy_install.pid|Daemon is already running"
    if [ $? -eq 0 ] ; then
        echo "Galaxy could not be started."
        echo "More information about this failure may be found in the following log snippet from galaxy_install.log:"
        echo "========================================"
        tail -n 60 $install_log
        echo "========================================"
        echo $1
        exit 1
    fi
    tail -n 2 $install_log | grep -q "Starting server in PID $galaxy_install_pid"
    if [ $? -eq 0 ] ; then
        echo "Galaxy is running."
        break
    fi
done

#for arg do shift
#    set -- "$@" \',\' "$arg"
#done; shift
#tl="\"['"`printf %s "$@"`"']\""
su galaxy -c "cd $GALAXY_HOME/ansible/galaxy-tools-playbook; unset PYTHONPATH; \
    ansible-playbook tools.yml -i "localhost," --extra-vars galaxy_tools_api_key=admin \
    --extra-vars galaxy_config_file=/etc/galaxy/galaxy.ini \
    --extra-vars galaxy_venv_dir=$GALAXY_VIRTUAL_ENV \
    --extra-vars galaxy_server_dir=/galaxy-central \
    --extra-vars galaxy_tools_tool_list=$1"

exit_code=$?

if [ $exit_code != 0 ] ; then
    exit $exit_code
fi

# stop everything
sudo -E -u galaxy ./run.sh --stop-daemon --log-file=$install_log --pid-file=galaxy_install.pid
rm $install_log
service postgresql stop


# Enable Test Tool Shed
if [ "x$ENABLE_TTS_INSTALL" != "x" ]
    then
        echo "Enable installation from the Test Tool Shed."
        export GALAXY_CONFIG_TOOL_SHEDS_CONFIG_FILE=$GALAXY_HOME/tool_sheds_conf.xml
fi


