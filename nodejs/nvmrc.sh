#!/bin/bash
# Ensure node version in .nvmrc is installed (e.g. lts/iron or v20.0.0)
# $NVM_DIR should be already set before running (usually auto loaded from profile)
# $1 Node.js app base directory (defaults to $PWD)
source ~/.bashrc
NVMRC_APP_DIR=`[[ (-n "$1") ]] && echo $1 || echo $PWD`
echo "Using \$NVM_DIR=$NVM_DIR for $NVMRC_APP_DIR/.nvmrc"
NVMRC_RC=`cat $NVMRC_APP_DIR/.nvmrc 2>/dev/null | sed 's/lts\///'`
if [[ (-z "$NVMRC_RC") ]]; then
  echo "No Node.js version or LTS codename in base app directory: $NVMRC_APP_DIR/.nvmrc" >&2
  exit 1
fi
echo "Found $NVMRC_APP_DIR/.nvmrc version: $NVMRC_RC (excluding any \"lts/\" prefix)"
NVMRC_VER=`echo $NVMRC_RC | sed -nre 's/^[^0-9]*(([0-9]+\.)*[0-9]+).*/v\1/p'`
NVMRC_LTS_NAME=`[[ (-z "$NVMRC_VER") ]] && echo $NVMRC_RC || echo ''`
NVMRC_LTS_VER=`[[ (-n "$NVMRC_LTS_NAME") ]] && cat $NVM_DIR/alias/lts/$NVMRC_LTS_NAME 2>/dev/null || echo ''`
echo "Extracted $NVMRC_APP_DIR/.nvmrc version: `[[ (-n "$NVMRC_LTS_VER") ]] && echo $NVMRC_LTS_VER || echo $NVMRC_LTS_NAME $NVMRC_VER`"
if [[ (-z "$NVMRC_VER") ]]; then
  echo "Checking for latest remote Node.js lts/$NVMRC_LTS_NAME (from: nvm ls-remote --lts)"
  NVMRC_LTS_LATEST=`nvm ls-remote --lts | sed -nre "s/^.*(v[0-9]+\.[0-9]+\.[0-9]).*Latest LTS.*$NVMRC_LTS_NAME.*/\1/pi"`
  if [[ (-n "$NVMRC_LTS_LATEST") && ("$NVMRC_LTS_VER" == "$NVMRC_LTS_LATEST") ]]; then
    NVMRC_LTS_INSTALL=1
    NVMRC_VER=$NVMRC_LTS_LATEST
  elif [[ (-n "$NVMRC_LTS_LATEST") && (-n "$NVMRC_LTS_VER") && ("$NVMRC_LTS_VER" != "$NVMRC_LTS_LATEST") ]]; then
    echo "Upgrading Node.js to the latest lts/$NVMRC_LTS_NAME: $NVMRC_LTS_VER -> $NVMRC_LTS_LATEST"
    nvm install $NVMRC_LTS_LATEST
  elif [[ (-z "$NVMRC_LTS_VER") ]]; then
    echo "Installing Node.js lts/$NVMRC_LTS_NAME"
    nvm install lts/$NVMRC_LTS_NAME
  else
    echo "Found installed Node.js lts/$NVMRC_LTS_NAME version: $NVMRC_LTS_VER"
  fi
fi
if [[ (-n "$NVMRC_VER") ]]; then
  NVMRC_VER_FOUND=`find $NVM_DIR/versions/node -type d -name "$NVMRC_VER" 2>/dev/null | wc -l`
  if [[ ("$NVMRC_VER_FOUND" -ge 1) ]]; then
    if [[ "$NVMRC_LTS_INSTALL" == 1 ]]; then
      echo "Currently installed Node.js lts/$NVMRC_LTS_NAME is already at the latest version: $NVMRC_VER"
    else
      echo "Found installed Node.js version: $NVMRC_VER"
    fi
  else
    echo "Installing Node.js version: $NVMRC_VER"
    nvm install $NVMRC_VER
  fi
fi
export NVMRC_VER=$NVMRC_VER
