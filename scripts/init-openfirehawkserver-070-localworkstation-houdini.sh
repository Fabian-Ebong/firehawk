#!/bin/bash
eval $(ssh-agent)

argument="$1"

SCRIPTNAME=`basename "$0"`
echo "Argument $1"
echo ""
ARGS=''

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
        printf "\n** CTRL-C ** EXITING...\n"
        exit
}
to_abs_path() {
  python -c "import os; print os.path.abspath('$1')"
}
# This is the directory of the current script
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPTDIR=$(to_abs_path $SCRIPTDIR)
printf "\n...checking scripts directory at $SCRIPTDIR\n\n"
# source an exit test to bail if non zero exit code is produced.
. $SCRIPTDIR/exit_test.sh

cd /deployuser

if [[ -z $argument ]] ; then
  echo "Error! you must specify an environment --dev or --prod" 1>&2
  exit 64
else
  case $argument in
    -d|--dev)
      ARGS='--dev'
      echo "using dev environment"
      source ./update_vars.sh --dev; exit_test
      ;;
    -p|--prod)
      ARGS='--prod'
      echo "using prod environment"
      source ./update_vars.sh --prod; exit_test
      ;;
    *)
      raise_error "Unknown argument: ${argument}"
      return
      ;;
  esac
fi

echo "openfirehawkserver ip: $TF_VAR_openfirehawkserver"

ansible-playbook -i "$TF_VAR_inventory" ansible/deadline-db-check.yaml -v; exit_test

# install houdini on a local workstation with deadline submitters and environment vars.

ansible-playbook -i "$TF_VAR_inventory" ansible/ansible_collections/firehawkvfx/houdini/houdini_module.yaml -v --extra-vars "variable_host=workstation1 variable_user=deadlineuser variable_connect_as_user=deployuser" --tags "install_houdini set_hserver install_deadline_db" --skip-tags "sync_scripts"; exit_test

ansible-playbook -i "$TF_VAR_inventory" ansible/deadline-db-check.yaml -v; exit_test

ansible-playbook -i "$TF_VAR_inventory" ansible/node-centos-ffmpeg.yaml -v --extra-vars "variable_host=workstation1 variable_user=deadlineuser variable_connect_as_user=deployuser"; exit_test

printf "\n...Finished $SCRIPTNAME\n\n"