#!/bin/bash
# Performs either a Node.js app BUILD or DEPLOY depending on the passed execution type.
# BUILD/DEPLOY: Ensures that the proper Node.js version is used via nvm. So, ensure the desired
# Noode.js version/name is in the .nvmrc file and it is present under root of the app's dir. For
# example, .nvmrc could contain lts/iron or v20.0.0 and will be installed (if needed)/used.
# $NVM_DIR should be already set before running (usually auto loaded from profile).
# BUILD: Builds, tests and bundles (optional) a Node.js app into a compressed archive file.
# DEPLOY: Backs up the existing Node.js app (if present), extracts the archive created from
# the build, generates the systemctl node app services with "npm start" that will vertically
# scale to match the number of physical CPU cores (if needed or DEPLOY_CLEAN), debundles the app
# (optional) and tests the app (optional).
##################################################################################
# $1 Execution type (either BUILD, DEPLOY or DEPLOY_CLEAN)
# $2 Node.js app name (required)
# $3 Node.js app dir (defaults to "")
# $4 nvmrc.sh directory (defaults to "/opt")
# $5 npm/node ci/install command (defaults to "npm ci")
# $6 npm/node test command (defaults to "npm test", optional)
# $7 npm/node bundle/debundle command (defaults to "", optional)
# $8 node app starting port for service (increments int to number of physical cores, DEPLOY only)
# $9 node environment that will be used to set NODE_ENV (defaults to "test", DEPLOY only)
# $10 Temporary directory for deployment backup and other temp files (defaults to "/tmp", DEPLOY only)
# NOTE: during BUILD the generated artifact resides at $3/artifacts/$2.gz.tar
# NOTE: during DEPLOY the generated BUILD artifact is expected to reside at $10/$2/$2.gz.tar

EXEC_TYPE=`[[ ("$1" == "BUILD" || "$1" == "DEPLOY" || "$1" == "DEPLOY_CLEAN") ]] && echo $1 || echo ""`
APP_NAME=`[[ (-n "$2") ]] && echo $2`
APP_DIR=`[[ (-n "$3") ]] && echo $3 || echo ""`
NVMRC_DIR=`[[ (-n "$4") ]] && echo $4 || echo "/opt"`
CMD_INSTALL=`[[ (-n "$5") ]] && echo $5 || echo "npm ci"`
CMD_TEST=`[[ (-n "$6") ]] && echo $6 || echo "npm test"`
CMD_BUNDLE=`[[ (-n "$7") ]] && echo $7 || echo ""`
APP_PORT=`[[ "$8" =~ ^[0-9]+$ ]] && echo $8 || echo ""`
NODE_ENV=`[[ (-n "$9") ]] && echo $9 || echo "test"`
APP_TMP=`[[ (-n "${10}") ]] && echo ${10} || echo /tmp`

DEPLOY=`[[ "$EXEC_TYPE" =~ ^DEPLOY ]] && echo "DEPLOY" || echo ""`
CLEAN=`[[ "$EXEC_TYPE" =~ CLEAN$ ]] && echo "CLEAN" || echo ""`
SERVICE_BASE="/etc/systemd/system"
SERVICE_PATH="$SERVICE_BASE/$APP_NAME@.service"
TARGET_PATH="$SERVICE_BASE/$APP_NAME.target"

execCmdCICD () {
  if [[ (-n "$1") ]]; then
    echo "$EXEC_TYPE: \"$1\""
    $1
    local CMD_STATUS=$?
    if [[ ("$CMD_STATUS" != 0) ]]; then
      echo "$EXEC_TYPE: $2 \"$1\" returned: $CMD_STATUS" >&2
      return $CMD_STATUS
    fi
  else
    echo "$EXEC_TYPE: No $2 being performed"
  fi
}

setServices() {
  if [[ -z "$SERVICES" ]]; then
    # lookup services in target Wants=
    local WANTS_PROP=$(sed -n "/^[ tab]*Wants[ tab]*/p" $TARGET_PATH)
    if [[ $WANTS_PROP =~ ^([ tab]*"Wants"[ tab]*=)(.*) ]]; then
      SERVICES=${BASH_REMATCH[2]}
    fi
  fi
}

if [[ (-n "$EXEC_TYPE") ]]; then
  echo "$EXEC_TYPE: starting using parameters \$EXEC_TYPE=\"$EXEC_TYPE\" \$APP_NAME=\"$APP_NAME\" \$APP_DIR=\"$APP_DIR\" \$NVMRC_DIR=\"$NVMRC_DIR\" \
  \$CMD_INSTALL=\"$CMD_INSTALL\" \$CMD_TEST=\"$CMD_TEST\" \$CMD_BUNDLE=\"$CMD_BUNDLE\" \$APP_PORT=\"$APP_PORT\" \$NODE_ENV=\"$NODE_ENV\" \$APP_TMP=\"$APP_TMP\""
else
  echo "Missing or invalid execution type (first argument, either \"BUILD\", \"DEPLOY\" or \"DEPLOY_CLEAN\"" >&2
  exit 1
fi
if [[ "$APP_NAME" =~ [^a-zA-Z] ]]; then
  echo "$EXEC_TYPE: missing or invalid app name \"$APP_NAME\" (must contain only alpha characters)" >&2
  exit 1
else
  echo "$EXEC_TYPE: using app name $APP_NAME"
fi
if [[ (-d "$APP_DIR") ]]; then
  echo "$EXEC_TYPE: using app dir $APP_DIR"
  if [[ -n "$DEPLOY" ]]; then
    echo "$EXEC_TYPE: backing up $APP_DIR"
    tar -czf $APP_TMP/$APP_NAME-backup-`date +%Y%m%d_%H%M%S`.tar.gz $APP_DIR
    [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to backup $APP_DIR to $APP_TMP" >&2; exit 1; }
  fi
elif [[ ("$EXEC_TYPE" == "BUILD") ]]; then
  echo "$EXEC_TYPE: unable to find dir $APP_DIR" >&2
  exit 1
elif [[ (-z "$APP_DIR") ]]; then
  echo "$EXEC_TYPE: app dir is required" >&2
  exit 1
else
  # DEPLOY: create new app dir
  sudo mkdir -p $APP_DIR
fi
if [[ -n "$DEPLOY" ]]; then
  # check if the service is installed
  if [[ -n "$APP_PORT" ]]; then
    # check if the service is already installed (may result in exit code != 0)
    TARGETED=`sudo systemctl list-units --all -t target --full --no-legend | grep "$APP_NAME.target"`
    if [[ -n "$TARGETED" ]]; then
      echo "$EXEC_TYPE: stopping $APP_NAME.target"
      sudo systemctl stop $APP_NAME.target
      [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to stop $APP_NAME.target" >&2; exit 1; }
      if [[ -n "$CLEAN" ]]; then
        setServices
        for svc in $SERVICES; do
          echo "$EXEC_TYPE: stopping/disabling $svc"
          sudo systemctl stop $svc
          [[ $? != 0 ]] && echo "$EXEC_TYPE: failed to stop $svc" >&2
          sudo systemctl disable $svc
          [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to disabled $svc" >&2; exit 1; }
        done
        for svc in $SERVICE_BASE/$APP_NAME*; do
          echo "$EXEC_TYPE: removing $svc"
          sudo rm -f $SERVICE_BASE/$svc
          [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to remove $SERVICE_BASE/$svc" >&2; exit 1; }
        done
        sudo systemctl daemon-reload
        [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to systemctl daemon-reload" >&2; exit 1; }
        sudo systemctl reset-failed
        [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to systemctl reset-failed" >&2; exit 1; }
      fi
      SERVICES="" # reset services to prevent duplication during setup
    fi
    if [[ -z "$TARGETED" || -n "$CLEAN" ]]; then
      echo "$EXEC_TYPE: performing setup for systemctl on $APP_NAME.target"
      # match the number of processes/services with the number of physical cores
      CORE_CNT=`getconf _NPROCESSORS_ONLN`
      [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed deterine the number of physical CPU cores" >&2; exit 1; }
      echo "$EXEC_TYPE: matching app services to $CORE_CNT physical CPU cores starting at port $APP_PORT"
      for (( c=$APP_PORT; c<$CORE_CNT + $APP_PORT; c++ )); do
        PORT_USED=`sudo ss -tulwnH "( sport = :$c )"`
        if [[ -n "$PORT_USED" ]]; then
          echo "$EXEC_TYPE: app port $c is already in use (core count: $CORE_CNT, start port: $APP_PORT)" >&2
          exit 1
        fi
        echo "$EXEC_TYPE: building systemctl node app service on port $c"
        SERVICES=`[[ -n "$SERVICES" ]] && echo "$SERVICES " || echo ""`
        SERVICES="$SERVICES$APP_NAME@$c.service"
      done
    fi
  else
    echo "$EXEC_TYPE: no app port specified, skipping systemctl setup for $APP_NAME.target"
  fi
  sudo chown -hR $USER $APP_DIR
  # replace app contents with extracted content
  if [[ (-f "$APP_TMP/$APP_NAME.tar.gz") ]]; then
    echo "$EXEC_TYPE: cleaning app at $APP_DIR"
    sudo rm -rfd $APP_DIR/*
    [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to clean $APP_DIR" >&2; exit 1; }
    echo "$EXEC_TYPE: extracting app contents from $APP_TMP/$APP_NAME.tar.gz to $APP_DIR"
    tar --warning=no-timestamp --strip-components=1 -xzvf $APP_TMP/$APP_NAME.tar.gz -C $APP_DIR
    [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to extract $APP_TMP/$APP_NAME.tar.gz to $APP_DIR" >&2; exit 1; }
    # remove extracted app archive
    sudo rm -f $APP_TMP/$APP_NAME.tar.gz
  else
    echo "$EXEC_TYPE: missing archive at $APP_TMP/$APP_NAME.tar.gz" >&2
    exit 1
  fi
fi
# change to app dir to execute node/npm commands
cd $APP_DIR

# ensure desired node version is installed using .nvmrc in base dir of app
if [[ (-x "$NVMRC_DIR/nvmrc.sh") ]]; then
  echo "$EXEC_TYPE: using nvmrc.sh located at \"$NVMRC_DIR/nvmrc.sh\""
else
  echo "$EXEC_TYPE: unable to find: \"$NVMRC_DIR/nvmrc.sh\"" >&2
  exit 1
fi
# source nvmrc.sh so we have access to $NVMRC_VER that is exported by nvmrc.sh
. $NVMRC_DIR/nvmrc.sh $PWD
CMD_STATUS=$?
if [[ ("$CMD_STATUS" != 0) ]]; then
  echo "$EXEC_TYPE: $NVMRC_DIR/nvmrc.sh returned: $CMD_STATUS" >&2
  exit $CMD_STATUS
elif [[ (-z "$NVMRC_VER") ]]; then
  echo "$EXEC_TYPE: $NVMRC_DIR/nvmrc.sh failed to set \$NVMRC_VER" >&2
  exit 1
fi

# DEPLOY: service/target templates
# ExecStart=/bin/bash -c '~/.nvm/nvm-exec node .'
# ExecStart=/bin/bash -c '$NVM_DIR/nvm-exec node .'
SERVICE=`[[ -z "$SERVICES" ]] && echo "" || echo "
# $SERVICE_PATH
[Unit]
Description=\"$APP_NAME (%H:%i)\"
After=network.target
# Wants=redis.service
PartOf=$APP_NAME.target

[Service]
Environment=NODE_ENV=$NODE_ENV
Environment=NODE_HOST=%H
Environment=NODE_PORT=%i
Type=simple
# user should match the user where nvm was installed
User=$USER
WorkingDirectory=$APP_DIR
# run node using the node version defined in working dir .nvmrc
ExecStart=/bin/bash -c '$NVM_DIR/nvm-exec npm start'
Restart=on-failure
RestartSec=5
StandardError=syslog

[Install]
WantedBy=multi-user.target
"`
TARGET=`[[ -z "$SERVICES" ]] && echo "" || echo "
# $TARGET_PATH
[Unit]
Description=\"$APP_NAME\"
Wants=$SERVICES

[Install]
WantedBy=multi-user.target
"`

if [[ -n "$SERVICE" && -n "$TARGET" ]]; then
  echo "$EXEC_TYPE: creating $SERVICE_PATH and $TARGET_PATH"
  echo "$SERVICE" | sudo tee "$SERVICE_PATH"
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to write $SERVICE_PATH" >&2; exit 1; }
  echo "$EXEC_TYPE: creating $TARGET_PATH"
  echo "$TARGET" | sudo tee "$TARGET_PATH"
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to write $TARGET_PATH" >&2; exit 1; }
  sudo systemctl daemon-reload
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to systemctl daemon-reload (for new services)" >&2; exit 1; }
  sudo systemctl enable $APP_NAME.target
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to enable $TARGET_PATH" >&2; exit 1; }
  echo "$EXEC_TYPE: enabled \"$SERVICE_PATH\" and \"$TARGET_PATH\""
fi

# enable nvm (alt "$NVM_DIR/nvm-exec node" or "$NVM_DIR/nvm-exec npm")
#NVM_EDIR=`[[ (-n "$NVM_DIR") ]] && echo $NVM_DIR || echo "$HOME/.nvm"`
#if [[ (-x "$NVM_EDIR/nvm-exec") ]]; then
source ~/.bashrc
if [[ ("$(command -v nvm)" == "nvm") ]]; then
  echo "$EXEC_TYPE: executing nvm commands"
else
  echo "$EXEC_TYPE: nvm command is not accessible for execution" >&2
  exit 1
fi

# run node commands using app version in .nvmrc
nvm use "$NVMRC_VER"

if [[ ("$EXEC_TYPE" == "BUILD") ]]; then
  # execute install
  execCmdCICD "$CMD_INSTALL" "ci/install"
  [[ $? != 0 ]] && exit 1
  # execute tests
  execCmdCICD "$CMD_TEST" "tests"
  [[ $? != 0 ]] && exit 1
  # execute bundle
  execCmdCICD "$CMD_BUNDLE" "bundling"
  [[ $? != 0 ]] && exit 1
  # create app archive
  mkdir -p artifacts
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to create $PWD/artifacts directory" >&2; exit 1; }
  echo "$EXEC_TYPE: building compressed artifact $PWD/artifacts/$APP_NAME.tar.gz"
  tar --exclude='./*git*' --exclude='./node_modules' --exclude='*.gz' --exclude='./artifacts' -czvf ./artifacts/$APP_NAME.tar.gz .
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to create app archive $PWD/artifacts/$APP_NAME.tar.gz" >&2; exit 1; }
else
  # execute debundle
  execCmdCICD "$CMD_BUNDLE" "debundling"
  [[ $? != 0 ]] && exit 1
  # execute install
  execCmdCICD "$CMD_INSTALL" "ci/install"
  [[ $? != 0 ]] && exit 1
  # start the services
  sudo systemctl start $APP_NAME.target
  [[ $? != 0 ]] && { echo "$EXEC_TYPE: failed to start $APP_NAME.target" >&2; exit 1; }
  echo "$EXEC_TYPE: validating services"
  setServices
  SERVICES="$APP_NAME.target $SERVICES" # include target
  for svc in $SERVICES; do
    SERVICE_STARTED=`sudo systemctl is-active "$svc" >/dev/null 2>&1 && echo ACTIVE || echo ""`
    if [[ -z "$SERVICE_STARTED" ]]; then
      printf "$EXEC_TYPE: %s\n" "systemctl \"$svc\" is not active (see output below)" >&2;
      exit 1;
    fi
    echo "$EXEC_TYPE: validated $svc is-active"
  done
  # execute tests
  execCmdCICD "$CMD_TEST" "tests"
  [[ $? != 0 ]] && exit 1
fi

echo "$EXEC_TYPE: success"