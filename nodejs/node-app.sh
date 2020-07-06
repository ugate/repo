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
# $1 Execution type (required: either BUILD, DEPLOY or DEPLOY_CLEAN)
# $2 The app name (required: must contain only alpha characters)
# $3 The NODE_ENV value that will be set when the app is ran (optional: set when app is ran)
# $4 Dir path for artifacts (the archive and conf properties will be placed/extracted to/from)
EXEC_TYPE=`[[ "$1" == "BUILD" || "$1" == "DEPLOY" || "$1" == "DEPLOY_CLEAN" ]] && echo "$1" || echo ""`
APP_NAME=`[[ -n "$2" ]] && echo "$2" || echo ""`
NODE_ENV=`[[ -n "$3" ]] && echo "$3" || echo ""`
ARTIFACTS_PATH=`[[ -n "$4" ]] && echo "$4" || echo ""`

# SCRIPT_FILE=$(readlink -f "$0") or SCRIPT_FILE=$(readlink "$BASH_SOURCE" || echo "$BASH_SOURCE")
SCRIPT_DIR=`dirname $0`
HOSTNAME=$(hostname -s)
MSGI="$EXEC_TYPE ($HOSTNAME):"
DEPLOY=`[[ "$EXEC_TYPE" =~ ^DEPLOY ]] && echo "DEPLOY" || echo ""`
CLEAN=`[[ "$EXEC_TYPE" =~ CLEAN$ ]] && echo "CLEAN" || echo ""`
CONF_PATH=`[[ -z "$DEPLOY" ]] && echo "./node-app.properties" || echo "$ARTIFACTS_PATH/$APP_NAME.properties"`

ARGS="\$1=\"$1\" \$2=\"$2\" \$3=\"$3\" \$4=\"$4\""
if [[ -z "$EXEC_TYPE" ]]; then
  echo "Missing or invalid execution type at argument \$1 (either \"BUILD\", \"DEPLOY\" or \"DEPLOY_CLEAN\") [ARGS: $ARGS]" >&2
  exit 1
elif [[ "$APP_NAME" =~ [^a-zA-Z] ]]; then
  echo "$MSGI missing or invalid app name \"$APP_NAME\" at argument \$2 (must contain only alpha characters) [ARGS: $ARGS]" >&2
  exit 1
elif [[ -z "$ARTIFACTS_PATH" || ((-n "$DEPLOY") && ( ! -d "$ARTIFACTS_PATH")) ]]; then
  echo "$MSGI missing or invalid artifacts directory path at argument \$4 [ARGS: $ARGS]" >&2
  exit 1
elif [[ ! -r "$CONF_PATH" ]]; then
  echo "$MSGI missing configuration properties file at $CONF_PATH [ARGS: $ARGS]" >&2
  exit 1
fi

confProp() {
  sed -rn "s/^${1}=([^\n]+)$/\1/p" ${CONF_PATH}
}
getAbsPath() {
  local filename=$1
  local parentdir=$(dirname "${filename}")
  if [[ -d "${filename}" ]]; then
    echo "$(cd "${filename}" && pwd)"
  elif [[ -d "${parentdir}" ]]; then
    echo "$(cd "${parentdir}" && pwd)/$(basename "${filename}")"
  fi
}

APP_DESC=$(confProp 'app.description')
APP_DIR=$(confProp "app.$EXEC_TYPE.directory")
APP_DIR=`[[ (-z "$APP_DIR") && (-z "$DEPLOY") ]] && echo "$PWD" || echo "$APP_DIR"`
if [[ -n "$APP_DIR" ]]; then
  echo "$MSGI converting app.$EXEC_TYPE.directory=\"$APP_DIR\" into an absolute path"
  APP_DIR=$(getAbsPath "$APP_DIR")
  echo "$MSGI absolute path set to app.$EXEC_TYPE.directory=\"$APP_DIR\""
fi
CMD_INSTALL=$(confProp "app.command.$EXEC_TYPE.install")
CMD_INSTALL=`[[ (-n "$CMD_INSTALL") ]] && echo "$CMD_INSTALL" || echo "npm ci"`
CMD_TEST=$(confProp "app.command.$EXEC_TYPE.test")
CMD_TEST=`[[ (-n "$CMD_TEST") ]] && echo "$CMD_TEST" || echo "npm test"`
CMD_BUNDLE=$(confProp "app.command.$EXEC_TYPE.bundle")
CMD_BUNDLE=`[[ (-n "$CMD_BUNDLE") ]] && echo "$CMD_BUNDLE" || echo ""`
CMD_DEBUNDLE=$(confProp "app.command.$EXEC_TYPE.debundle")
CMD_DEBUNDLE=`[[ (-n "$CMD_DEBUNDLE") ]] && echo "$CMD_DEBUNDLE" || echo ""`
APP_PORT=$(confProp 'app.port.number')
APP_PORT=`[[ "$APP_PORT" =~ ^[0-9]+$ ]] && echo "$APP_PORT" || echo ""`
APP_PORT_COUNT=$(confProp 'app.port.count')
APP_PORT_COUNT=`[[ "$APP_PORT_COUNT" =~ ^[0-9]+$ ]] && echo "$APP_PORT_COUNT" || echo ""`
NVMRC_SH_DIR=$(confProp 'nvmrc.script.directory')
NVMRC_SH_DIR=`[[ (-n "$NVMRC_SH_DIR") ]] && echo "$NVMRC_SH_DIR" || echo "$SCRIPT_DIR"`
APP_TMP=$(confProp 'nvmrc.script.directory')
APP_TMP=`[[ (-n "$APP_TMP") ]] && echo "$APP_TMP" || echo /tmp`
SYSD_BASE=$(confProp 'app.systemd.directory')
SYSD_BASE=`[[ (-n "$SYSD_BASE") ]] && echo "$SYSD_BASE" || echo "/etc/systemd/system"`

SERVICE_PATH="$SYSD_BASE/$APP_NAME@.service"
TARGET_PATH="$SYSD_BASE/$APP_NAME.target"

execCmdCICD() {
  if [[ (-n "$1") ]]; then
    echo "$MSGI \"$1\""
    $1
    local CMD_STATUS=$?
    if [[ ("$CMD_STATUS" != 0) ]]; then
      echo "$MSGI $2 \"$1\" returned: $CMD_STATUS" >&2
      return $CMD_STATUS
    fi
  else
    echo "$MSGI No $2 being performed"
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

echo "$MSGI starting using parameters \$EXEC_TYPE=\"$EXEC_TYPE\" \$NODE_ENV=\"$NODE_ENV\" \$CONF_PATH=\"$CONF_PATH\" \
\$APP_NAME=\"$APP_NAME\" \$APP_DIR=\"$APP_DIR\" \$NVMRC_SH_DIR=\"$NVMRC_SH_DIR\" \$CMD_INSTALL=\"$CMD_INSTALL\" \
\$CMD_TEST=\"$CMD_TEST\" \$CMD_BUNDLE=\"$CMD_BUNDLE\" \$CMD_DEBUNDLE=\"$CMD_DEBUNDLE\" \$APP_PORT=\"$APP_PORT\" \
\$APP_PORT_COUNT=\"$APP_PORT_COUNT\" \$APP_TMP=\"$APP_TMP\""
if [[ (-n "$APP_DIR") && (-d "$APP_DIR") ]]; then
  if [[ -n "$DEPLOY" ]]; then
    echo "$MSGI backing up $APP_DIR"
    tar -czf $APP_TMP/$APP_NAME-backup-`date +%Y%m%d_%H%M%S`.tar.gz $APP_DIR
    [[ $? != 0 ]] && { echo "$MSGI failed to backup $APP_DIR to $APP_TMP" >&2; exit 1; }
  fi
elif [[ ("$EXEC_TYPE" == "BUILD") ]]; then
  echo "$MSGI unable to find dir $APP_DIR" >&2
  exit 1
elif [[ (-z "$APP_DIR") ]]; then
  echo "$MSGI app.$EXEC_TYPE.directory is required" >&2
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
      echo "$MSGI stopping $APP_NAME.target"
      sudo systemctl stop $APP_NAME.target
      [[ $? != 0 ]] && { echo "$MSGI failed to stop $APP_NAME.target" >&2; exit 1; }
      if [[ -n "$CLEAN" ]]; then
        setServices
        for svc in $SERVICES; do
          echo "$MSGI stopping/disabling $svc"
          sudo systemctl stop $svc
          [[ $? != 0 ]] && echo "$MSGI failed to stop $svc" >&2
          sudo systemctl disable $svc
          [[ $? != 0 ]] && { echo "$MSGI failed to disabled $svc" >&2; exit 1; }
        done
        for svc in $SYSD_BASE/$APP_NAME*; do
          echo "$MSGI removing $svc"
          sudo rm -f $SYSD_BASE/$svc
          [[ $? != 0 ]] && { echo "$MSGI failed to remove $SYSD_BASE/$svc" >&2; exit 1; }
        done
        sudo systemctl daemon-reload
        [[ $? != 0 ]] && { echo "$MSGI failed to systemctl daemon-reload" >&2; exit 1; }
        sudo systemctl reset-failed
        [[ $? != 0 ]] && { echo "$MSGI failed to systemctl reset-failed" >&2; exit 1; }
      fi
      SERVICES="" # reset services to prevent duplication during setup
    fi
    if [[ -z "$TARGETED" || -n "$CLEAN" ]]; then
      echo "$MSGI performing setup for systemctl on $APP_NAME.target"
      if [[ -n "$APP_PORT_COUNT" ]]; then
        echo "$MSGI app services count explicitly set to \$APP_PORT_COUNT=$APP_PORT_COUNT starting at port $APP_PORT"
      else
        # match the number of processes/services with the number of physical cores
        CORE_CNT=`getconf _NPROCESSORS_ONLN`
        [[ $? != 0 ]] && { echo "$MSGI failed deterine the number of physical CPU cores" >&2; exit 1; }
        APP_PORT_COUNT=$CORE_CNT
        echo "$MSGI matching app services to $APP_PORT_COUNT physical CPU cores starting at port $APP_PORT"
      fi
      for (( c=$APP_PORT; c<$APP_PORT_COUNT + $APP_PORT; c++ )); do
        PORT_USED=`sudo ss -tulwnH "( sport = :$c )"`
        if [[ -n "$PORT_USED" ]]; then
          echo "$MSGI app port $c is already in use (core count: $APP_PORT_COUNT, start port: $APP_PORT)" >&2
          exit 1
        fi
        echo "$MSGI building systemctl node app service on port $c"
        SERVICES=`[[ -n "$SERVICES" ]] && echo "$SERVICES " || echo ""`
        SERVICES="$SERVICES$APP_NAME@$c.service"
      done
    fi
  else
    echo "$MSGI no app port specified, skipping systemctl setup for $APP_NAME.target"
  fi
  sudo chown -hR $USER $APP_DIR
  # replace app contents with extracted content
  ARTIFACT_ARCHIVE="$ARTIFACTS_PATH/$APP_NAME.tar.gz"
  if [[ (-f "$ARTIFACT_ARCHIVE") ]]; then
    echo "$MSGI cleaning app at $APP_DIR"
    sudo rm -rfd $APP_DIR/*
    [[ $? != 0 ]] && { echo "$MSGI failed to clean $APP_DIR" >&2; exit 1; }
    echo "$MSGI extracting app contents from $ARTIFACT_ARCHIVE to $APP_DIR"
    tar --warning=no-timestamp --strip-components=1 -xzvf $ARTIFACT_ARCHIVE -C $APP_DIR
    [[ $? != 0 ]] && { echo "$MSGI failed to extract $ARTIFACT_ARCHIVE to $APP_DIR" >&2; exit 1; }
    # remove extracted app archive/conf
    sudo rm -f $ARTIFACT_ARCHIVE
    sudo rm -f $CONF_PATH
  else
    echo "$MSGI missing archive at $ARTIFACT_ARCHIVE" >&2
    exit 1
  fi
fi
# change to app dir to execute node/npm commands
cd $APP_DIR

# ensure desired node version is installed using .nvmrc in base dir of app
if [[ (-x "$NVMRC_SH_DIR/nvmrc.sh") ]]; then
  echo "$MSGI using nvmrc.sh located at \"$NVMRC_SH_DIR/nvmrc.sh\""
else
  echo "$MSGI unable to find/execute: \"$NVMRC_SH_DIR/nvmrc.sh\"" >&2
  exit 1
fi
# source nvmrc.sh so we have access to $NVMRC_VER that is exported by nvmrc.sh
. $NVMRC_SH_DIR/nvmrc.sh $PWD
CMD_STATUS=$?
if [[ ("$CMD_STATUS" != 0) ]]; then
  echo "$MSGI $NVMRC_SH_DIR/nvmrc.sh returned: $CMD_STATUS" >&2
  exit $CMD_STATUS
elif [[ (-z "$NVMRC_VER") ]]; then
  echo "$MSGI $NVMRC_SH_DIR/nvmrc.sh failed to set \$NVMRC_VER" >&2
  exit 1
fi

# DEPLOY: service/target templates
# ExecStart=/bin/bash -c '~/.nvm/nvm-exec node .'
# ExecStart=/bin/bash -c '$NVM_DIR/nvm-exec node .'
SERVICE=`[[ -z "$SERVICES" ]] && echo "" || echo "
# $SERVICE_PATH
[Unit]
Description=\"$APP_DESC (%H:%i)\"
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
  echo "$MSGI creating $SERVICE_PATH and $TARGET_PATH"
  echo "$SERVICE" | sudo tee "$SERVICE_PATH"
  [[ $? != 0 ]] && { echo "$MSGI failed to write $SERVICE_PATH" >&2; exit 1; }
  echo "$MSGI creating $TARGET_PATH"
  echo "$TARGET" | sudo tee "$TARGET_PATH"
  [[ $? != 0 ]] && { echo "$MSGI failed to write $TARGET_PATH" >&2; exit 1; }
  sudo systemctl daemon-reload
  [[ $? != 0 ]] && { echo "$MSGI failed to systemctl daemon-reload (for new services)" >&2; exit 1; }
  sudo systemctl enable $APP_NAME.target
  [[ $? != 0 ]] && { echo "$MSGI failed to enable $TARGET_PATH" >&2; exit 1; }
  echo "$MSGI enabled \"$SERVICE_PATH\" and \"$TARGET_PATH\""
fi

# enable nvm (alt "$NVM_DIR/nvm-exec node" or "$NVM_DIR/nvm-exec npm")
#NVM_EDIR=`[[ (-n "$NVM_DIR") ]] && echo $NVM_DIR || echo "$HOME/.nvm"`
#if [[ (-x "$NVM_EDIR/nvm-exec") ]]; then
source ~/.bashrc
if [[ ("$(command -v nvm)" == "nvm") ]]; then
  echo "$MSGI executing nvm commands"
else
  echo "$MSGI nvm command is not accessible for execution" >&2
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
  [[ $? != 0 ]] && { echo "$MSGI failed to create $PWD/artifacts directory" >&2; exit 1; }
  echo "$MSGI building compressed artifact $PWD/artifacts/$APP_NAME.tar.gz"
  ARTIFACT_ARCHIVE="$ARTIFACTS_PATH/$APP_NAME.tar.gz"
  tar --exclude='./*git*' --exclude='./node_modules' --exclude='*.gz' --exclude="$ARTIFACTS_PATH" -czvf $ARTIFACT_ARCHIVE .
  [[ $? != 0 ]] && { echo "$MSGI failed to create app archive $ARTIFACT_ARCHIVE (PWD=$PWD)" >&2; exit 1; }
  ARTIFACT_CONF="$ARTIFACTS_PATH/$APP_NAME.properties"
  echo "$MSGI copying $CONF_PATH to $ARTIFACT_CONF"
  cp -f $CONF_PATH $ARTIFACT_CONF
  [[ $? != 0 ]] && { echo "$MSGI failed to copy configuration properties file from $CONF_PATH to $ARTIFACT_CONF (PWD=$PWD)" >&2; exit 1; }
else
  # execute debundle
  execCmdCICD "$CMD_DEBUNDLE" "debundling"
  [[ $? != 0 ]] && exit 1
  # execute install
  execCmdCICD "$CMD_INSTALL" "ci/install"
  [[ $? != 0 ]] && exit 1
  # start the services
  sudo systemctl start $APP_NAME.target
  [[ $? != 0 ]] && { echo "$MSGI failed to start $APP_NAME.target" >&2; exit 1; }
  echo "$MSGI validating services"
  setServices
  SERVICES="$APP_NAME.target $SERVICES" # include target
  for svc in $SERVICES; do
    SERVICE_STARTED=`sudo systemctl is-active "$svc" >/dev/null 2>&1 && echo ACTIVE || echo ""`
    if [[ -z "$SERVICE_STARTED" ]]; then
      SERVICE_JOURNAL=$(sudo journalctl -u $svc  -x -n 10 --no-pager)
      printf "$MSGI %s\n\n%s\n%s\n%s\n\n" "systemctl \"$svc\" is not active (see output below)" "============> $svc" "$SERVICE_JOURNAL" "<============ $svc" >&2;
      exit 1;
    fi
    echo "$MSGI validated $svc is-active"
  done
  # execute tests
  execCmdCICD "$CMD_TEST" "tests"
  [[ $? != 0 ]] && exit 1
fi

echo "$MSGI ============> SUCCESS <============"