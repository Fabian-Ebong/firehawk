#!/bin/bash

### GENERAL FUNCTIONS FOR ALL INSTALLS

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

argument="$1"

echo "Argument $1"
echo ""
ARGS=''

cd /deployuser

### Get s3 access keys from terraform ###

tf_action="apply"

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
    -p|--plan)
      tf_action="plan"
      echo "using prod environment"
      source ./update_vars.sh --prod; exit_test
      ;;
    *)
      raise_error "Unknown argument: ${argument}"
      return
      ;;
  esac
fi

if [[ "$keybase_disabled" != "true" ]]; then
  if [[ "$TF_VAR_pgp_public_key" == "keybase:"* ]]; then
    echo "Installing keybase since pgp_public key starts with keybase:"
    # install keybase, used for aquiring keys for deadline spot plugin.
    echo "...Downloading/installing keybase for PGP encryption"
    (
    cd /deployuser/tmp
    file='/deployuser/tmp/keybase_amd64.deb'
    uri='https://prerelease.keybase.io/keybase_amd64.deb'
    if test -e "$file"
    then zflag=(-z "$file")
    else zflag=()
    fi
    curl -o "$file" "${zflag[@]}" "$uri"
    )
    sudo apt install -y /deployuser/tmp/keybase_amd64.deb
    run_keybase
    echo $(keybase --version)
  else
    echo "Installing pgp and expect"
    # Currently this imports existing keys.  need to handle generation of keys if nothing exists with ansible instead of bash.
    sudo apt-get install expect -y
    echo "...Import key"
    gpg --import $TF_VAR_pgp_private_key
    echo "...Trust key"
    expect -c "spawn gpg --edit-key $TF_VAR_pgp_email trust quit; send \"5\ry\r\"; expect eof"
    echo "...Finished GPG import"
  fi
  # install keybase and test decryption
  $TF_VAR_firehawk_path/scripts/keybase-pgp-test.sh; exit_test
  # if you encounter issues you should login with 'keybase login'.  if you haven't created a user account you can do so at keybase.io
fi
