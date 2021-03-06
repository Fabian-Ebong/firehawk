#!/bin/bash
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

# This stage configures softnas, but optionally doesn't not setup any mounts reliant on a vpn. it wont commence installing render nodes until the next stage.

# vagrant reload
# vagrant ssh

# test the vpn buy logging into softnas and ping another system on your local network.

# when sooftnas storage is set to true, it will create and mount devices, and add the exports if volume paths are available.  otherwise you will need to continue to setup the volumes manually before proceeding to the next step
# loging into the softnas instance and setting up your volumes is necesary if this is your first time creating the volumes.
# export TF_VAR_softnas_storage=true
# when site mounts are true, then cloud nodes will start and use NFS site mounts.
# export TF_VAR_aws_nodes_enabled=false
# export TF_VAR_remote_mounts_on_local=false

# ensure vpn is up and test
terraform apply --auto-approve; exit_test

# test if vpn private ip can be reached/
$TF_VAR_firehawk_path/scripts/tests/test-openvpn.sh; exit_test

config_override=$(to_abs_path $TF_VAR_firehawk_path/../secrets/config-override-$TF_VAR_envtier)
echo "...Config Override path $config_override"
echo '...Configure softnas remote storage.'
sudo sed -i 's/^TF_VAR_softnas_storage=.*$/TF_VAR_softnas_storage=true/' $config_override
echo '...Site mounts will not be mounted in cloud'
sudo sed -i 's/^TF_VAR_aws_nodes_enabled=.*$/TF_VAR_aws_nodes_enabled=false/' $config_override
echo '...Softnas nfs exports will not be mounted on local site'
sudo sed -i 's/^TF_VAR_remote_mounts_on_local=.*$/TF_VAR_remote_mounts_on_local=false/' $config_override

echo "...Sourcing config overrides"
source $TF_VAR_firehawk_path/update_vars.sh --$TF_VAR_envtier --var-file config-override; exit_test

terraform apply --auto-approve; exit_test

$TF_VAR_firehawk_path/scripts/tests/test-softnas.sh; exit_test

# kill the current session to ensure any new groups can be used in next script
# sleep 1; pkill -u deployuser sshd
printf "\n...Finished $SCRIPTNAME\n\n"