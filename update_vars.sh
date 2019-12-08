#!/usr/bin/env bash

# the purpose of this script is to:
# 1) set envrionment variables as defined in the encrypted secrets/secrets-prod file
# 2) consistently rebuild the secrets.template file based on the variable names found in the secrets-prod file.
#    This generated template will never/should never have any secrets stored in it since it is commited to version control.
#    The purpose of this script is to ensure that the template for all users remains consistent.
# 3) Example values for the secrets.template file are defined in secrets.example. Ensure you have placed an example key=value for any new vars in secrets.example. 
# If any changes have resulted in a new variable name, then example values helps other understand what they should be using for their own infrastructure.

RED='\033[0;31m' # Red Text
NC='\033[0m' # No Color        
# the directory of the current script
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export TF_VAR_firehawk_path=$SCRIPTDIR

mkdir -p $TF_VAR_firehawk_path/tmp/
mkdir -p $TF_VAR_firehawk_path/../secrets/
# The template will be updated by this script
tmp_template_path=$TF_VAR_firehawk_path/tmp/secrets.template
touch $tmp_template_path
rm $tmp_template_path
temp_output=$TF_VAR_firehawk_path/tmp/secrets.temp
touch $temp_output
rm $temp_output

failed=false
verbose=false
optspec=":hv-:t:"

encrypt_mode="encrypt"

# IFS must allow us to iterate over lines instead of words seperated by ' '
IFS='
'

verbose () {
    local OPTIND
    OPTIND=0
    while getopts "$optspec" optchar; do
        case "${optchar}" in
            -)
                case "${OPTARG}" in
                    tier)
                        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        ;;
                    tier=*)
                        ;;
                    var-file)
                        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        ;;
                    var-file=*)
                        ;;
                    vault)
                        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        ;;
                    vault=*)
                        ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                        ;;
                esac;;
            t)
                ;;
            v)
                echo "Parsing option: '-${optchar}'" >&2
                echo "verbose mode"
                verbose=true
                ;;
        esac
    done
}
verbose "$@"

tier () {
    if [[ "$verbose" == true ]]; then
        echo "Parsing tier option: '--${opt}', value: '${val}'" >&2;
    fi
    export TF_VAR_envtier=$val
}

var_file=

var_file () {
    if [[ "$verbose" == true ]]; then
        echo "Parsing var_file option: '--${opt}', value: '${val}'" >&2;
    fi
    export var_file="${val}"
}

vault () {
    echo "verbose=$verbose"
    if [[ "$verbose" == true ]]; then
        echo "Parsing tier option: '--${opt}', value: '${val}'" >&2;
    fi
    if [[ $val = 'encrypt' || $val = 'decrypt' || $val = 'none' ]]; then
        export encrypt_mode=$val
    else
        printf "\n${RED}ERROR: valid modes for encrypt are:\nencrypt, decrypt or none. Enforcing encrypt mode as default.${NC}\n"
        export encrypt_mode='encrypt'
        failed=true
    fi
}

function to_abs_path {
    local target="$1"
    if [ "$target" == "." ]; then
        echo "$(pwd)"
    elif [ "$target" == ".." ]; then
        echo "$(dirname "$(pwd)")"
    else
        echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
    fi
}

# We allow equivalent args such as:
# -t dev
# --tier dev
# --tier=dev
# which each results in the same function tier() running.

#OPTIND=0
parse_opts () {
    local OPTIND
    OPTIND=0
    while getopts "$optspec" optchar; do
        case "${optchar}" in
            -)
                case "${OPTARG}" in
                    tier)
                        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        tier
                        ;;
                    tier=*)
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        tier
                        ;;
                    var-file)
                        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        var_file
                        ;;
                    var-file=*)
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        var_file
                        ;;
                    vault)
                        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        vault
                        ;;
                    vault=*)
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        vault
                        ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                        ;;
                esac;;
            t)
                val="${OPTARG}"
                opt="${optchar}"
                tier
                ;;
            v) # verbosity is handled prior since its a dependency for this block
                ;;
            h)
                echo "usage: source ./update_vars.sh [-v] [--tier[=]dev/prod] [--var-file[=]vagrant/secrets] [--vault[=]encrypt/decrypt]" >&2
                printf "\nUse this to source either the vagrant or encrypted secrets config in your dev or prod tier.\n" &&
                    failed=true
                ;;
            *)
                if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                    echo "Non-option argument: '-${OPTARG}'" >&2
                fi
                ;;
        esac
    done
}
parse_opts "$@"

# if any parsing failed this is the correct method to parse an exit code of 1 whether executed or sourced

[ "$BASH_SOURCE" == "$0" ] &&
    echo "This file is meant to be sourced, not executed" && 
        exit 30

if [[ $failed = true ]]; then    
    return 88
fi


template_path="$TF_VAR_firehawk_path/secrets.template"

source_vars () {
    local var_file=$1
    local encrypt_mode=$2

    printf "\n...Sourcing var_file $var_file\n"
    # If initialising vagrant vars, no encryption is required
    if [[ -z "$var_file" ]] || [[ "$var_file" = "secrets" ]]; then
        var_file="secrets-$TF_VAR_envtier"
        printf "\nUsing vault file $var_file\n"
        template_path="$TF_VAR_firehawk_path/secrets.template"
    elif [[ "$var_file" = "vagrant" ]]; then
        printf '\nUsing variable file vagrant. No encryption/decryption will be used.\n'
        encrypt_mode="none"
        template_path="$TF_VAR_firehawk_path/vagrant.template"
    elif [[ "$var_file" = "config" ]]; then
        printf '\nUsing variable file config. No encryption/decryption will be used.\n'
        encrypt_mode="none"
        template_path="$TF_VAR_firehawk_path/config.template"
    else
        printf "\nUnrecognised vault/variable file. \n$var_file\nExiting...\n"
        failed=true
    fi

    if [[ $failed = true ]]; then
        return 88
    fi

    var_file="$(to_abs_path $TF_VAR_firehawk_path/../secrets/$var_file)"

    # set vault key location based on envtier dev/prod
    if [[ "$TF_VAR_envtier" = 'dev' ]]; then
        vault_key="$(to_abs_path $TF_VAR_firehawk_path/../secrets/keys/$TF_VAR_vault_key_name_dev)"
    elif [[ "$TF_VAR_envtier" = 'prod' ]]; then
        vault_key="$(to_abs_path $TF_VAR_firehawk_path/../secrets/keys/$TF_VAR_vault_key_name_prod)"
    else 
        printf "\n...${RED}WARNING: envtier evaluated to no match for dev or prod.  Inspect update_vars.sh to handle this case correctly.${NC}\n"
        return 88
    fi

    # We use a local key and a password to encrypt and decrypt data.  no operation can occur without both.  in this case we decrypt first without password and then with the password.
    vault_command="ansible-vault view --vault-id $vault_key --vault-id $vault_key@prompt $var_file"

    if [[ $encrypt_mode != "none" ]]; then
        #check if a vault key exists.  if it does, then install can continue automatically.
        if [ -e $vault_key ]; then
            if [[ $verbose ]]; then
                path=$(to_abs_path $vault_key)
                printf "\n$vault_key exists. vagrant up will automatically provision.\n\n"
            fi
        else
            printf "\n$vault_key doesn't exist.\n\n"
            printf "\nNo vault key has been initialised at this location.\n\n"
            PS3='Do you wish to initialise a new vault key?'
            options=("Initialise A New Key" "Quit")
            select opt in "${options[@]}"
            do
                case $opt in
                    "Initialise A New Key")
                        printf "\n${RED}WARNING: DO NOT COMMIT THESE KEYS TO VERSION CONTROL.${NC}\n"
                        openssl rand -base64 64 > $vault_key || failed=true
                        break
                        ;;
                    "Quit")
                        echo "You selected $REPLY to $opt"
                        quit=true
                        break
                        ;;
                    *) echo "invalid option $REPLY";;
                esac
            done
            
        fi
    fi

    if [[ $failed = true ]]; then    
        echo "${RED}WARNING: Failed to create key.${NC}"
        return 88
    fi

    if [[ $quit = true ]]; then    
        return 88
    fi

    # vault arg will set encryption mode
    if [[ $encrypt_mode = "encrypt" ]]; then
        echo "Encrypting Vault..."
        line=$(head -n 1 $var_file)
        if [[ "$line" == "\$ANSIBLE_VAULT"* ]]; then 
            echo "Vault is already encrypted"
        else
            echo "Encrypting secrets with a key on disk and with a password. Vars will be set from an encrypted vault."
            ansible-vault encrypt --vault-id $vault_key@prompt $var_file
        fi
    elif [[ $encrypt_mode = "decrypt" ]]; then
        echo "Decrypting Vault... $var_file"
        line=$(head -n 1 $var_file)
        if [[ "$line" == "\$ANSIBLE_VAULT"* ]]; then 
            echo "Found encrypted vault"
            echo "Decrypting secrets."
            ansible-vault decrypt --vault-id $vault_key --vault-id $vault_key@prompt $var_file
        else
            echo "Vault already unencrypted.  No need to decrypt. Vars will be set from unencrypted vault."
        fi
        printf "\n${RED}WARNING: Never commit unencrypted secrets to a repository/version control. run this command again without --decrypt before commiting any secrets to version control.${NC}"
        printf "\nIf you accidentally do commit unencrypted secrets, ensure there is no trace of the data in the repo, and invalidate the secrets / replace them.\n"
            
        export vault_command="cat $var_file"
    elif [[ $encrypt_mode = "none" ]]; then
        echo "Assuming variables are not encrypted to set environment vars"
        export vault_command="cat $var_file"
    fi

    if [[ $verbose = true ]]; then
        printf "\n"
        echo "TF_VAR_envtier=$TF_VAR_envtier"
        echo "var_file=$var_file"
        echo "vault_key=$vault_key"
        echo "encrypt_mode=$encrypt_mode"
        echo "vault_command=$vault_command"
    fi

    export vault_examples_command="cat $TF_VAR_firehawk_path/secrets.example"

    ### Use the vault command to iterate over variables and export them without values to the template

    if [[ $encrypt_mode = "none" ]]; then
        printf "\n...Parsing unencrypted file to template.  No Decryption necesary.\n"
    else
        printf "\n...Parsing vault file to template.  Decrypting.\n"
    fi

    local MULTILINE=$(eval $vault_command)
    for i in $(echo "$MULTILINE" | sed 's/^$/###/')
    do
        if [[ "$i" =~ ^#.*$ ]]
        then
            # replace ### blank line placeholder for user readable temp_output and respect newlines
            if [[ $verbose = true ]]; then
                echo "line= $i"
            fi
            echo "${i#"###"}" >> $temp_output
        else
            # temp_output original line to file without value
            if [[ $verbose = true ]]; then
                echo "var= ${i%%=*}"
            fi
            echo "${i%%=*}=insertvalue" >> $temp_output
        fi
    done

    # substitute example var values into the template.
    envsubst < "$temp_output" > "$tmp_template_path"
    rm $temp_output

    printf "\n...Exporting variables to environment\n"
    # # Now set environment variables to the actual values defined in the user's secrets-prod file
    for i in $(echo "$MULTILINE")
    do
        [[ "$i" =~ ^#.*$ ]] && continue
        export $i
    done


    # # Determine your current public ip for security groups.

    export TF_VAR_remote_ip_cidr="$(dig +short myip.opendns.com @resolver1.opendns.com)/32"

    # # this python script generates mappings based on the current environment.
    # # any var ending in _prod or _dev will be stripped and mapped based on the envtier
    python $TF_VAR_firehawk_path/scripts/envtier_vars.py
    envsubst < "$TF_VAR_firehawk_path/tmp/envtier_mapping.txt" > "$TF_VAR_firehawk_path/tmp/envtier_exports.txt"

    # Next- using the current envtier environment, evaluate the variables for the that envrionment.  
    # variables ending in _dev or _prod will take precedence based on the envtier, and be set to keys stripped of the appended _dev or _prod namespace
    for i in `cat $TF_VAR_firehawk_path/tmp/envtier_exports.txt`
    do
        [[ "$i" =~ ^#.*$ ]] && continue
        export $i
    done

    rm $TF_VAR_firehawk_path/tmp/envtier_exports.txt

    if [[ "$TF_VAR_envtier" = 'dev' ]]; then
        # The template will now be written to the public repository without any private values
        printf "\n...Saving template to $template_path\n"
        mv -fv $tmp_template_path $template_path
    elif [[ "$TF_VAR_envtier" = 'prod' ]]; then
        printf "\n...Bypassing saving of template to public repository since we are in a prod environment.  Writes to the Firehawk repository path are only done in the dev environment.\n"
        rm -fv $tmp_template_path
    else 
        printf "\n...${RED}WARNING: envtier evaluated to no match for dev or prod.  Inspect update_vars.sh to handle this case correctly.${NC}\n"
        return 88
    fi
}

if [[ "$TF_VAR_envtier" = 'dev' ]] || [[ "$TF_VAR_envtier" = 'prod' ]]; then
    # check for valid environment
    printf "\n...Using environment $TF_VAR_envtier"
else 
    printf "\n...${RED}WARNING: envtier evaluated to no match for dev or prod.  Inspect update_vars.sh to handle this case correctly.${NC}\n"
    return 88
fi

# if sourcing secrets, we also source the vagrant file and unencrypted config file
if [[ "$var_file" = "secrets" ]] || [[ -z "$var_file" ]]; then
    # assume secrets is the var file for default behaviour
    source_vars 'vagrant' 'none'
    source_vars 'config' 'none'
    var_file = "secrets"
    source_vars "secrets" "$encrypt_mode"
else
    source_vars "$var_file" "$encrypt_mode"
fi

printf "\nDone.\n\n"