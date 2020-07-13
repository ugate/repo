#!/bin/bash
# Builds a virtual host for an app based upon a properties file (see README.md).
# ------------ For httpd.type=apache ---------------------------------------------
# The VH uses https://httpd.apache.org/docs/current/mod/mod_proxy_balancer.html
# So, it will attempt to load "mod_proxy". The VH will only be written to when
# changes are discovered or the VH for the app name is not yet created.
##################################################################################
# $1 The proprties file that contains the configuration (required: can also use export APP_PROPS_PATH)
# $2 The app name (required: must contain only alpha characters, can also use export $APP_NAME)
# $3 The app directory path (required: can also use export $APP_DIR)
# $4 Space delimited port numbers that will be load balanced (required, can also contain systemd
# service names with a numeric port- "myapp@8080.service", can also use export $SERVICES)
HTTPD_PROPS_PATH=$([[ -n "$1" ]] && echo "$1" || echo "$APP_PROPS_PATH")
HTTPD_APP_NAME=$([[ -n "$2" ]] && echo "$2" || echo "$APP_NAME")
HTTPD_APP_DIR=$([[ -n "$3" ]] && echo "$3" || echo "$APP_DIR")
HTTPD_SERVICES=$([[ -n "$4" ]] && echo "$4" || echo "$SERVICES")
HTTPD_HOSTNAME_FQDN=$(hostname)
HTTPD_HOSTNAME=$(hostname -s)
HTTPD_HOST_NUM=$(echo "$HTTPD_HOSTNAME" | sed -rn "s/^[^0-9]*?([0-9]+).*$/\1/p")
HTTPD_MSGI=$([[ -z "$MSGI" ]] && echo "HTTPD ($HTTPD_HOSTNAME):" || echo "HTTPD $MSGI")
HTTPD_ARGS="HTTPD_PROPS_PATH=\"$HTTPD_PROPS_PATH\" HTTPD_APP_NAME=\"$HTTPD_APP_NAME\" HTTPD_APP_DIR=\"$HTTPD_APP_DIR\" HTTPD_SERVICES=\"$HTTPD_SERVICES\""

if [[ ! -r "$HTTPD_PROPS_PATH" ]]; then
  echo "$HTTPD_MSGI a read-accessible properties file is required at argument \$1 [ARGS: $HTTPD_ARGS]" >&2
  exit 1
elif [[ "$HTTPD_APP_NAME" =~ [^a-zA-Z] ]]; then
  echo "$HTTPD_MSGI missing or invalid app name at argument \$2 (must contain only alpha characters) [ARGS: $HTTPD_ARGS]" >&2
  exit 1
elif [[ -z "$HTTPD_SERVICES" ]]; then
  echo "$HTTPD_MSGI missing space delimited app port numbers that will be load balanced at argument \$4 [ARGS: $HTTPD_ARGS]" >&2
  exit 1
fi

httpdConfProp() {
  sed -rn "s/^${1}=([^\n]+)$/\1/p" "${HTTPD_PROPS_PATH}"
}

HTTPD_APP_CONF_DIR=$(confProp "httpd.app.conf.dir")
HTTPD_APP_CONF_DIR=$([[ -n "$HTTPD_APP_CONF_DIR" ]] && echo "$HTTPD_APP_CONF_DIR" || echo "/etc/httpd/conf.d")
HTTPD_APP_DOMAIN=$(httpdConfProp "httpd.app.domain")
HTTPD_APP_SID=$(httpdConfProp "httpd.app.stickysession")
HTTPD_APP_STICKY=$([[ -n "$HTTPD_APP_SID" ]] && echo "stickysession=$HTTPD_APP_SID" || echo "")
HTTPD_APP_STICKY_LOG=$([[ -n "$HTTPD_APP_SID" ]] && echo " \\\"%{$HTTPD_APP_SID}C\\\"" || echo "")
HTTPD_LBMETHOD=$(httpdConfProp "httpd.app.lbmethod")
HTTPD_LBMETHOD=$([[ -n "$HTTPD_LBMETHOD" ]] && echo "$HTTPD_LBMETHOD" || echo "byrequests")
HTTPD_APP_PATH=$(httpdConfProp "httpd.app.path")
HTTPD_APP_PATH=$([[ -n "$HTTPD_APP_PATH" ]] && echo "$HTTPD_APP_PATH" || echo "/")
HTTPD_APP_FQDN_DOMAIN=$([[ -n "$HTTPD_APP_DOMAIN" ]] && echo "${HTTPD_APP_NAME}.${HTTPD_APP_DOMAIN}" || echo "$HTTPD_HOSTNAME_FQDN")
HTTPD_PROXY_PATH=$(httpdConfProp "httpd.proxy.path")
HTTPD_PROXY_PATH=$([[ -n "$HTTPD_PROXY_PATH" ]] && echo "$HTTPD_PROXY_PATH" || echo "/")
HTTPD_SVR_ALIAS=$([[ -n "$HTTPD_APP_DOMAIN" ]] && echo "${HTTPD_APP_NAME}${HTTPD_HOST_NUM}.${HTTPD_APP_DOMAIN}" || echo "")
HTTPD_SVR_ADMIN=$([[ -n "$HTTPD_APP_DOMAIN" ]] && echo "$USER@$HTTPD_APP_DOMAIN" || echo "$USER@$HTTPD_HOSTNAME_FQDN")

if [[ ! -d "$HTTPD_APP_CONF_DIR" ]]; then
  echo "$HTTPD_MSGI missing or invalid app directory \"$HTTPD_APP_DIR\" at argument \$3 (must be a valid directory path) [ARGS: $HTTPD_ARGS]" >&2
  exit 1
fi

# build listening ports for virtual host
# ${HTTPD_HOSTNAME_FQDN}:${HTTPD_APP_PORT}${HTTPD_APP_PATH}
# sed -rn "s/^Listen ([^\n]+)$/\1/p" ${HTTPD_CONF_PATH}
HTTPD_SS_PORTS=$(sudo ss -tulwnHp | grep httpd | sed -rn "s/.*:([0-9]+).*/\1/p")
for httpd_ss_port in $HTTPD_SS_PORTS; do
  if [[ "$httpd_ss_port" =~ ^[0-9]+$ ]]; then
    echo "$HTTPD_MSGI adding port $httpd_ss_port to virtual host"
    HTTPD_VH_LISTEN=$([[ -n "$HTTPD_VH_LISTEN" ]] && echo "$HTTPD_VH_LISTEN " || echo "")
    HTTPD_VH_LISTEN=$(printf "$HTTPD_VH_LISTEN%s" "*:$httpd_ss_port")
  else
    echo "$HTTPD_MSGI unable to extract httpd port number from: $httpd_ss_port" >&2
    exit 1;
  fi
done
if [[ -z "$HTTPD_VH_LISTEN" ]]; then
  echo "$HTTPD_MSGI unable to find the httpd process listening on any ports, is the the httpd process is up and running?" >&2
  exit 1;
fi

# build the various load balancer workers based upon the defined app port numbers
for httpd_svc in $HTTPD_SERVICES; do
  HTTPD_PORT=$(echo "$httpd_svc" | sed 's/[^0-9]*//g')
  if [[ -z "$HTTPD_PORT" ]]; then
    echo "$HTTPD_MSGI failed to extract port number from: $httpd_svc" >&2
    exit 1;
  fi
  HTTPD_BAL_URL="http://${HTTPD_APP_FQDN_DOMAIN}:${HTTPD_PORT}${HTTPD_APP_PATH}"
  echo "$HTTPD_MSGI load balance member being added for $HTTPD_BAL_URL"
  HTTPD_BAL_MEMBS=$([[ -n "$HTTPD_BAL_MEMBS" ]] && echo "$HTTPD_BAL_MEMBS " || echo "")
  # apache specific balancer member content
  HTTPD_BAL_MEMBER="BalancerMember $HTTPD_BAL_URL route=server${HTTPD_PORT}"
  HTTPD_BAL_MEMBS=$( printf "$HTTPD_BAL_MEMBS\n%s\n" "$HTTPD_BAL_MEMBER")
done

# virtual host content
HTTPD_SVR_NAME=$([[ -n "$HTTPD_APP_DOMAIN" ]] && printf "\nServerName %s\n" "${HTTPD_APP_NAME}.${HTTPD_APP_DOMAIN}" || echo "")
HTTPD_SVR_ALIAS=$([[ -n "$HTTPD_SVR_ALIAS" ]] && printf "\nServerAlias %s\n" "$HTTPD_SVR_ALIAS" || echo "")
HTTPD_PROXY_COOKIE_PATH=$([[ "$HTTPD_APP_PATH" == "$HTTPD_PROXY_PATH"  ]] && echo "" || echo "ProxyPassReverseCookiePath $HTTPD_PROXY_PATH $HTTPD_APP_PATH")
HTTPD_PROXY_COOKIE_DOMAIN=$([[ "$HTTPD_APP_FQDN_DOMAIN" == "$HTTPD_HOSTNAME_FQDN"  ]] && echo "" || echo "ProxyPassReverseCookieDomain $HTTPD_APP_FQDN_DOMAIN $HTTPD_HOSTNAME_FQDN")
HTTPD_VH_CONF=$([[ -z "$HTTPD_BAL_MEMBS" ]] && echo "" || echo "
<VirtualHost $HTTPD_VH_LISTEN>
  LoadModule proxy_ajp_module modules/mod_proxy_ajp.so
  LoadModule proxy_module modules/mod_proxy.so
  LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
  LoadModule proxy_connect_module modules/mod_proxy_connect.so
  LoadModule proxy_ftp_module modules/mod_proxy_ftp.so
  LoadModule proxy_http_module modules/mod_proxy_http.so
  LoadModule reqtimeout_module modules/mod_reqtimeout.so
  ${HTTPD_SVR_NAME}${HTTPD_SVR_ALIAS}
  ServerAdmin $HTTPD_SVR_ADMIN
  ErrorLog logs/${HTTPD_APP_NAME}.error_log
  LogFormat \"%{X-Forwarded-For}i (%h) %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-agent}i\\\"${HTTPD_APP_STICKY_LOG}\" xfwd
  CustomLog \"logs/${HTTPD_APP_NAME}.access_log\" xfwd

  <IfModule mod_proxy_ajp.c>
    ProxyRequests Off
    ProxyTimeout 300
    ProxyPreserveHost On
    ProxyVia On

    <Proxy balancer://${HTTPD_APP_NAME}Cluster>
      $HTTPD_BAL_MEMBS

      # accessibility
      Order Allow,Deny
      Allow from all

      # round-robin style load balancer
      ProxySet lbmethod=$HTTPD_LBMETHOD
    </Proxy>

    # allow changes via apache web gui (mod_proxy_balancer)
    <Location /${HTTPD_APP_NAME}-balancer-manager>
      SetHandler balancer-manager

      # private net access only
      Order Deny,Allow
      Deny from all
      Allow from 127.0.0.1 ::1
      Allow from localhost
      Allow from 192.168
      Allow from 10
      Satisfy Any

      # alternative host access
      # Require host example.com
    </Location>

    ProxyPass /${HTTPD_APP_NAME}-balancer-manager !
    ProxyPass $HTTPD_PROXY_PATH balancer://${HTTPD_APP_NAME}Cluster $HTTPD_APP_STICKY
    ProxyPassReverse $HTTPD_PROXY_PATH balancer://${HTTPD_APP_NAME}Cluster $HTTPD_APP_STICKY
    $HTTPD_PROXY_COOKIE_PATH
    $HTTPD_PROXY_COOKIE_DOMAIN
  </IfModule>
</VirtualHost>
")

# write app httpd conf content (if changed)
HTTPD_APP_CONF_PATH="${HTTPD_APP_CONF_DIR}/${HTTPD_APP_NAME}.conf"
HTTPD_APP_CONF_TYPE=$([[ -f "$HTTPD_APP_CONF_PATH" ]] && echo "EXISTING" || echo "NEW")
if [[ "$HTTPD_APP_CONF_TYPE" == "NEW" || "$HTTPD_VH_CONF" != $(cat "$HTTPD_APP_CONF_PATH") ]]; then
  if [[ "$HTTPD_APP_CONF_TYPE" != "NEW" ]]; then
    echo "$HTTPD_MSGI stopping the httpd service"
    sudo systemctl stop httpd
  fi
  echo "$HTTPD_MSGI writting $HTTPD_APP_CONF_TYPE virtual host to $HTTPD_APP_CONF_PATH"
  echo "$HTTPD_VH_CONF" | sudo tee "$HTTPD_APP_CONF_PATH"
  echo "$HTTPD_MSGI validating $HTTPD_APP_CONF_PATH and restarting the httpd service"
  # validate conf and restart if configtest passes
  sudo systemctl restart httpd
  HTTPD_SVC_FAILED=$?
  HTTPD_SVC_JOURNAL=$(sudo journalctl -u httpd.service -x -n 10 --no-pager)
  if [[ "$HTTPD_SVC_FAILED" != 0 ]]; then
    printf "$MSGI failed to restart httpd service:\n\n%s\n\n" "$HTTPD_SVC_JOURNAL" >&2
    sudo rm -f "$HTTPD_APP_CONF_PATH"
    sudo systemctl start httpd
    exit 1
  else
    printf "$MSGI successfully restarted httpd service:\n\n%s\n\n" "$HTTPD_SVC_JOURNAL" >&2
  fi
else
  echo "$HTTPD_MSGI skipping virtual host write to $HTTPD_APP_CONF_PATH since there are not any pending changes"
fi