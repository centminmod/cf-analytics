#!/bin/bash
################################################
# cloudflare zone analytics
# export zid=YOUR_CLOUDFLARE_DOMAIN_ZONE_ID
# export cfkey=YOUR_CLOUDFLARE_API_KEY
# export cfemail=YOUR_CLOUDFLARE_ACCOUNT_EMAIL
#
# jq -r '.data.viewer.zones | .[] | .httpRequests1mGroups[]'
################################################
# whether to use CF Global Account API Token or
# new CF specific API Tokens (in beta right now)
DEBUG='y'
CF_ENTERPRISE='n'
CF_GLOBAL_TOKEN='n'
CF_ARGO='n'
CF_LOG='cm-analytics-graphql.log'
CF_LOGARGO='cm-analytics-graphql-argo.log'
CF_LOGARGOGEO='cm-analytics-graphql-argo-geo.log'
CF_LOGFW='cm-analytics-graphql-firewall.log'
CF_ZONEINFO='cf-zoneinfo.log'
ENDPOINT='https://api.cloudflare.com/client/v4/graphql'
DATANODE='httpRequests1hGroups'
BROWSER_PV='n'
JSON_OUTPUT_SAVE='y'
JSON_TO_CSV='y'
JSON_OUTPUT_DIR='/home/cf-graphql-json-output'
################################################
SCRIPT_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))
################################################
if [ -f "${SCRIPT_DIR}/cf-analytics-graphql.ini" ]; then
  source "${SCRIPT_DIR}/cf-analytics-graphql.ini"
fi

if [[ "$JSON_TO_CSV" = [yY] ]]; then
  JSON_OUTPUT_SAVE='y'
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] && ! -d "$JSON_OUTPUT_DIR" ]]; then
  mkdir -p "$JSON_OUTPUT_DIR"
fi

if [[ -f $(which yum) && ! -f /usr/bin/datamash ]]; then
  yum -y -q install datamash
fi

if [[ -f $(which yum) && ! -f /usr/bin/jq ]]; then
  yum -y -q install jq
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX GET -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$zid" > "$CF_ZONEINFO"
  cat "$CF_ZONEINFO" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cfplan=$(cat "$CF_ZONEINFO" | jq -r '.result.plan.legacy_id')
    echo
  fi
else
  curl -4sX GET -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" "https://api.cloudflare.com/client/v4/zones/$zid" > "$CF_ZONEINFO"
  cat "$CF_ZONEINFO" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cfplan=$(cat "$CF_ZONEINFO" | jq -r '.result.plan.legacy_id')
    echo
  fi
fi

if [[ "$cfplan" = 'enterprise' ]]; then
  CF_ENTERPRISE='y'
else
  CF_ENTERPRISE='n'
fi

ip_analytics_hrs() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-iphrs.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-iphrs.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_ip=$2
  input_ip_check_multi=$(echo "$input_ip" | grep -q ','; echo $?)
  input_actionfilter=${3:-none}

  # CF plan limitations for how far back you can access
  # analytics data
  if [[ "$cfplan" = 'free' && "$since" -lt '30' ]]; then
    since=30
  fi

  back_seconds=$((60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_ip_check_multi" -eq '0' ]; then
    input_ip=$(echo $input_ip | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_ip_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    client_var="\"clientIP_in\": [$input_ip],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_ip_check_multi" -eq '0' ]; then
    client_var="\"clientIP_in\": [$input_ip],"
  elif [[ "$input_ip" != 'all' && "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    client_var="\"clientIP\": \"$input_ip\",
        \"action\": \"$input_actionfilter\","
  elif [[ "$input_ip" = 'all' && "$input_actionfilter" = 'none' ]]; then
    client_var=
  elif [[ "$input_ip" = 'all' && "$input_actionfilter" != 'none' ]]; then
    client_var="\"action\": \"$input_actionfilter\","
  else
    client_var="\"clientIP\": \"$input_ip\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query ListFirewallEvents($zoneTag: string, $filter: FirewallEventsAdaptiveFilter_InputObject) {
      viewer {
        zones(filter: { zoneTag: $zoneTag }) {
          firewallEventsAdaptive(
            filter: $filter,
            limit: $limit,
            orderBy: [datetime_DESC]
          ) {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $client_var
        $hostname_var
        $referrer_var
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for Cient IP: $input_ip"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

ip_analytics_days() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ipdays.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ipdays.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_ip=$2
  input_ip_check_multi=$(echo "$input_ip" | grep -q ','; echo $?)
  input_actionfilter=${3:-none}

  # CF plan limitations for how far back you can access
  # analytics data
  if [[ "$cfplan" = 'free' && "$since" -gt '1' ]]; then
    since=1
  elif [[ "$cfplan" = 'business' || "$cfplan" = 'enterprise' ]] && [[ "$since" -gt '3' ]]; then
    since=3
  fi

  back_seconds=$((86400 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_ip_check_multi" -eq '0' ]; then
    input_ip=$(echo $input_ip | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_ip_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    client_var="\"clientIP_in\": [$input_ip],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_ip_check_multi" -eq '0' ]; then
    client_var="\"clientIP_in\": [$input_ip],"
  elif [[ "$input_ip" != 'all' && "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    client_var="\"clientIP\": \"$input_ip\",
        \"action\": \"$input_actionfilter\","
  elif [[ "$input_ip" = 'all' && "$input_actionfilter" = 'none' ]]; then
    client_var=
  elif [[ "$input_ip" = 'all' && "$input_actionfilter" != 'none' ]]; then
    client_var="\"action\": \"$input_actionfilter\","
  else
    client_var="\"clientIP\": \"$input_ip\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_DESC]
            ) {
            dimensions {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $client_var
        $hostname_var
        $referrer_var
        \"date_gt\": \"$start_date\",
        \"date_lt\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for Request IP: $input_ip"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

ip_analytics() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ip.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ip.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_ip=$2
  input_ip_check_multi=$(echo "$input_ip" | grep -q ','; echo $?)
  input_actionfilter=${3:-none}

  # CF plan limitations for how far back you can access
  # analytics data
  if [[ "$cfplan" = 'free' && "$since" -gt '24' ]]; then
    since=24
  elif [[ "$cfplan" = 'business' || "$cfplan" = 'enterprise' ]] && [[ "$since" -gt '72' ]]; then
    since=72
  fi

  back_seconds=$((60 * 60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_ip_check_multi" -eq '0' ]; then
    input_ip=$(echo $input_ip | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_ip_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    client_var="\"clientIP_in\": [$input_ip],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_ip_check_multi" -eq '0' ]; then
    client_var="\"clientIP_in\": [$input_ip],"
  elif [[ "$input_ip" != 'all' && "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    client_var="\"clientIP\": \"$input_ip\",
        \"action\": \"$input_actionfilter\","
  elif [[ "$input_ip" = 'all' && "$input_actionfilter" = 'none' ]]; then
    client_var=
  elif [[ "$input_ip" = 'all' && "$input_actionfilter" != 'none' ]]; then
    client_var="\"action\": \"$input_actionfilter\","
  else
    client_var="\"clientIP\": \"$input_ip\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_DESC]
            ) {
            dimensions {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $client_var
        $hostname_var
        $referrer_var
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for Request IP: $input_ip"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

ruleid_fw_analytics_days() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ruleid-days.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ruleid-days.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_ruleid=$2
  input_ruleid_check_multi=$(echo "$input_ruleid" | grep -q ','; echo $?)
  input_actionfilter=$3
  back_seconds=$((86400 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_ruleid_check_multi" -eq '0' ]; then
    input_ruleid=$(echo $input_ruleid | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_ruleid_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    ruleid_var="\"ruleId_in\": [$input_ruleid],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_ruleid_check_multi" -eq '0' ]; then
    ruleid_var="\"ruleId_in\": [$input_ruleid],"
  elif [[ "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    ruleid_var="\"ruleId\": \"$input_ruleid\",
        \"action\": \"$input_actionfilter\","
  elif [ "$input_actionfilter" = 'none' ]; then
    ruleid_var="\"ruleId\": \"$input_ruleid\","
  else
    ruleid_var="\"ruleId\": \"$input_ruleid\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_DESC]
            ) {
            dimensions {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $ruleid_var
        $hostname_var
        $referrer_var
        \"date_gt\": \"$start_date\",
        \"date_lt\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for CF RuleID: $input_ruleid"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

ruleid_fw_analytics() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ruleid.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ruleid.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_ruleid=$2
  input_ruleid_check_multi=$(echo "$input_ruleid" | grep -q ','; echo $?)
  input_actionfilter=$3
  back_seconds=$((60 * 60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_ruleid_check_multi" -eq '0' ]; then
    input_ruleid=$(echo $input_ruleid | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_ruleid_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    ruleid_var="\"ruleId_in\": [$input_ruleid],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_ruleid_check_multi" -eq '0' ]; then
    ruleid_var="\"ruleId_in\": [$input_ruleid],"
  elif [[ "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    ruleid_var="\"ruleId\": \"$input_ruleid\",
        \"action\": \"$input_actionfilter\","
  elif [ "$input_actionfilter" = 'none' ]; then
    ruleid_var="\"ruleId\": \"$input_ruleid\","
  else
    ruleid_var="\"ruleId\": \"$input_ruleid\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_DESC]
            ) {
            dimensions {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $ruleid_var
        $hostname_var
        $referrer_var
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for CF RuleID: $input_ruleid"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

ruleid_fw_analytics_hrs() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ruleid-hrs.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-ruleid-hrs.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_ruleid=$2
  input_ruleid_check_multi=$(echo "$input_ruleid" | grep -q ','; echo $?)
  input_actionfilter=$3
  back_seconds=$((60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_ruleid_check_multi" -eq '0' ]; then
    input_ruleid=$(echo $input_ruleid | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_ruleid_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    ruleid_var="\"ruleId_in\": [$input_ruleid],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_ruleid_check_multi" -eq '0' ]; then
    ruleid_var="\"ruleId_in\": [$input_ruleid],"
  elif [[ "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    ruleid_var="\"ruleId\": \"$input_ruleid\",
        \"action\": \"$input_actionfilter\","
  elif [ "$input_actionfilter" = 'none' ]; then
    ruleid_var="\"ruleId\": \"$input_ruleid\","
  else
    ruleid_var="\"ruleId\": \"$input_ruleid\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query ListFirewallEvents($zoneTag: string, $filter: FirewallEventsAdaptiveFilter_InputObject) {
      viewer {
        zones(filter: { zoneTag: $zoneTag }) {
          firewallEventsAdaptive(
            filter: $filter,
            limit: $limit,
            orderBy: [datetime_DESC]
          ) {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $ruleid_var
        $hostname_var
        $referrer_var
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for CF RuleID: $input_ruleid"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

fw_analytics_days() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-firewall-day.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-firewall-day.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_rayid=$2
  input_rayid_check_multi=$(echo "$input_rayid" | grep -q ','; echo $?)
  input_actionfilter=$3
  back_seconds=$((86400 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_rayid_check_multi" -eq '0' ]; then
    input_rayid=$(echo $input_rayid | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_rayid_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    rayname_var="\"rayName_in\": [$input_rayid],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_rayid_check_multi" -eq '0' ]; then
    rayname_var="\"rayName_in\": [$input_rayid],"
  elif [[ "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    rayname_var="\"rayName\": \"$input_rayid\",
        \"action\": \"$input_actionfilter\","
  elif [ "$input_actionfilter" = 'none' ]; then
    rayname_var="\"rayName\": \"$input_rayid\","
  else
    rayname_var="\"rayName\": \"$input_rayid\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_DESC]
            ) {
            dimensions {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $rayname_var
        $hostname_var
        $referrer_var
        \"date_gt\": \"$start_date\",
        \"date_lt\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for CF RayID: $input_rayid"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

fw_analytics() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-firewall.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-firewall.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_rayid=$2
  input_rayid_check_multi=$(echo "$input_rayid" | grep -q ','; echo $?)
  input_actionfilter=$3
  back_seconds=$((60 * 60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_rayid_check_multi" -eq '0' ]; then
    input_rayid=$(echo $input_rayid | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_rayid_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    rayname_var="\"rayName_in\": [$input_rayid],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_rayid_check_multi" -eq '0' ]; then
    rayname_var="\"rayName_in\": [$input_rayid],"
  elif [[ "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    rayname_var="\"rayName\": \"$input_rayid\",
        \"action\": \"$input_actionfilter\","
  elif [ "$input_actionfilter" = 'none' ]; then
    rayname_var="\"rayName\": \"$input_rayid\","
  else
    rayname_var="\"rayName\": \"$input_rayid\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_DESC]
            ) {
            dimensions {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $rayname_var
        $hostname_var
        $referrer_var
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  echo "JSON log saved: $JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    echo "CSV converted log saved: $JSON_CSV_OUTPUT_FILE"
  fi
  echo
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for CF RayID: $input_rayid"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

fw_analytics_hrs() {
  JSON_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-firewall-hrs.json"
  JSON_CSV_OUTPUT_FILE="${JSON_OUTPUT_DIR}/cf-graphql-firewall-hrs.csv"
  req_referrer=${6:-none}
  req_referrer_check_multi=$(echo "$req_referrer" | grep -q ','; echo $?)
  req_hostname=$5
  input_limit="${4:-100}"
  DATANODE='firewallEventsAdaptiveGroups'
  since=$1
  input_rayid=$2
  input_rayid_check_multi=$(echo "$input_rayid" | grep -q ','; echo $?)
  input_actionfilter=$3
  back_seconds=$((60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  if [[ "$req_hostname" = 'none' ]]; then
    hostname_var=
  elif [ "$req_hostname" ]; then
    hostname_var="\"clientRequestHTTPHost\": \"$req_hostname\","
  else
    hostname_var=
  fi

  if [[ "$req_referrer_check_multi" -eq '0' ]]; then
    req_referrer=$(echo $req_referrer | sed 's/[^,]*/"&"/g')
    referrer_var="\"clientRefererHost_in\": [$req_referrer],"
  elif [[ "$req_referrer" = 'none' ]]; then
    referrer_var=
  elif [[ "$req_referrer" = 'empty' ]]; then
    referrer_var="\"clientRefererHost_like\": \"\","
  elif [[ "$req_referrer" = 'notempty' ]]; then
    referrer_var="\"clientRefererHost_notlike\": \"\","
  else
    referrer_var="\"clientRefererHost\": \"$req_referrer\","
  fi

  if [ "$input_rayid_check_multi" -eq '0' ]; then
    input_rayid=$(echo $input_rayid | sed 's/[^,]*/"&"/g')
  fi

  if [[ "$input_rayid_check_multi" -eq '0' && "$input_actionfilter" ]]; then
    rayname_var="\"rayName_in\": [$input_rayid],
        \"action\": \"$input_actionfilter\","
  elif [ "$input_rayid_check_multi" -eq '0' ]; then
    rayname_var="\"rayName_in\": [$input_rayid],"
  elif [[ "$input_actionfilter" && "$input_actionfilter" != 'none' ]]; then
    rayname_var="\"rayName\": \"$input_rayid\",
        \"action\": \"$input_actionfilter\","
  elif [ "$input_actionfilter" = 'none' ]; then
    rayname_var="\"rayName\": \"$input_rayid\","
  else
    rayname_var="\"rayName\": \"$input_rayid\","
  fi

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query ListFirewallEvents($zoneTag: string, $filter: FirewallEventsAdaptiveFilter_InputObject) {
      viewer {
        zones(filter: { zoneTag: $zoneTag }) {
          firewallEventsAdaptive(
            filter: $filter,
            limit: $limit,
            orderBy: [datetime_DESC]
          ) {
              action
              botScore
              botScoreSrcName
              source
              datetime
              clientIP
              clientAsn
              clientCountryName
              edgeColoName
              clientRequestHTTPProtocol
              clientRequestHTTPHost
              clientRequestPath
              clientRequestQuery
              clientRequestScheme
              clientRequestHTTPMethodName
              clientRefererHost
              clientRefererPath
              clientRefererQuery
              clientRefererScheme
              edgeResponseStatus
              clientASNDescription
              userAgent
              kind
              originResponseStatus
              ruleId
              rayName
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        $rayname_var
        $hostname_var
        $referrer_var
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$DEBUG" = [yY] ]]; then
  # echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOGFW"
  cat "$CF_LOGFW" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOGFW" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
fi

if [ -f "$CF_LOGFW" ]; then
  json_object_count=$(cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn] | length')
fi
echo "------------------------------------------------------------------"
echo "Cloudflare Firewall ($cfplan)"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "${json_object_count} Firewall Events for CF RayID: $input_rayid"
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest + ruleId
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.ruleId)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shortest
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts shorter
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing botscore x ASN counts
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"' | sort | uniq -c | sort -rn
echo "------------------------------------------------------------------"
# listing non-json
cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -r '"\(.clientIP) \(.rayName) \(.edgeResponseStatus) \(.botScore)x\(.botScoreSrcName) \(.action) \(.clientAsn) \(.clientASNDescription) \(.clientCountryName) \(.edgeColoName) \(.datetime) \(.clientRequestHTTPHost) \(.clientRequestHTTPMethodName) \(.clientRequestHTTPProtocol) \(.clientRequestPath) \(.clientRequestQuery)"'
echo "------------------------------------------------------------------"
# listing json
if [[ "$JSON_OUTPUT_SAVE" = [yY] ]]; then
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]' | tee "$JSON_OUTPUT_FILE"
  if [[ "$JSON_TO_CSV" = [yY] ]]; then
    # csv conversion
    # headers
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[0] | keys | @csv' | tr -d '"' > "$JSON_CSV_OUTPUT_FILE"
    # data
    cat "$JSON_OUTPUT_FILE" | jq -r '.results[] | [ .action,.botScore,.botScoreSrcName,.clientASNDescription,.clientAsn,.clientCountryName,.clientIP,.clientRefererHost,.clientRefererPath,.clientRefererQuery,.clientRefererScheme,.clientRequestHTTPHost,.clientRequestHTTPMethodName,.clientRequestHTTPProtocol,.clientRequestPath,.clientRequestQuery,.clientRequestScheme,.datetime,.edgeColoName,.edgeResponseStatus,.kind,.originResponseStatus,.rayName,.ruleId,.source,.userAgent ] | @csv' >> "$JSON_CSV_OUTPUT_FILE"
  fi
else
  cat "$CF_LOGFW" | jq --arg dn "$DATANODE" -r '.data.viewer.zones[] | .[$dn][] | .dimensions' | jq -n '.results |= [inputs]'
fi

}

get_analytics() {
  input_limit="${4:-10000}"
  since=$1
  back_seconds=$((60 * 60 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          httpRequests1hGroups(
            limit: $limit,
            filter: $filter,
          ) {
            sum {
              browserMap {
                pageViews
                uaBrowserFamily
              }
              bytes
              cachedBytes
              cachedRequests
              contentTypeMap {
                bytes
                requests
                edgeResponseContentTypeName
              }
              clientHTTPVersionMap {
                clientHTTPProtocol
                requests
              }
              clientSSLMap {
                requests
                clientSSLProtocol
              }
              countryMap {
                bytes
                requests
                threats
                clientCountryName
              }
              encryptedBytes
              encryptedRequests
              ipClassMap {
                requests
                ipType
              }
              pageViews
              requests
              responseStatusMap {
                requests
                edgeResponseStatus
              }
              threats
              threatPathingMap {
                requests
                threatPathingName
              }
            }
            uniq {
              uniques
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        \"datetime_geq\": \"$start_date\",
        \"datetime_leq\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOG"
  cat "$CF_LOG" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOG" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
  if [[ "$CF_ARGO" = [yY] ]]; then
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency?bins=10" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGO"
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency/colos" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGOGEO"
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOG"
  cat "$CF_LOG" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOG" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
  if [[ "$CF_ARGO" = [yY] ]]; then
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency?bins=10" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGO"
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency/colos" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGOGEO"
  fi
fi

if [[ "$CF_ARGO" = [yY] ]]; then
  # check if there's argo data in the log
  check_argo_result=$(cat "$CF_LOGARGO" | jq -r '.result')
  check_argo_success=$(cat "$CF_LOGARGO" | jq -r '.success')
fi

if [[ "$CF_ARGO" = [yY] && "$check_argo_result" != 'null' && "$check_argo_success" = 'true' ]]; then
echo "------------------------------------------------------------------"
echo "Cloudflare Argo Analytics"
echo "------------------------------------------------------------------"
cat "$CF_LOGARGO" | jq -r '.result.time_range | "  since: \(.since)\n  until: \(.until)"'
echo "------------------------------------------------------------------"
echo "Argo Response Time:"
echo "------------------------------------------------------------------"
argowithout=$(cat "$CF_LOGARGO" | jq -r '.result.data.averages[0]')
argowith=$(cat "$CF_LOGARGO" | jq -r '.result.data.averages[1]')
argopc=$(echo "scale=4; $argowith/$argowithout" | bc)
argogain=$(echo "scale=2; (1-$argopc)*100" | bc)
argoreq_without=$(cat "$CF_LOGARGO" | jq -s 'map(.result.data.counts[0][]) | add')
argoreq_with=$(cat "$CF_LOGARGO" | jq -s 'map(.result.data.counts[1][]) | add')
argorouted=$(cat "$CF_LOGARGO" | jq -r '.result.percent_smart_routed')
echo "request-without-argo: ${argoreq_without}"
echo "request-with-argo: ${argoreq_with}"
echo "argo-smarted-routed: ${argorouted}%"
echo "argo-improvement: ${argogain}%"
cat "$CF_LOGARGO" | jq -r '.result.data | "  without-argo: \(.averages[0]) (milliseconds)\n  with-argo \(.averages[1]) (milliseconds)"'
echo "------------------------------------------------------------------"
echo "Argo Cloudflare Datacenter Response Times"
echo "------------------------------------------------------------------"
cat "$CF_LOGARGOGEO" | jq -r '.result.features[] | .properties | "  \(.code) \(.argo_req_count) \(.pct_avg_change * 100) \(.no_argo_avg) \(.argo_avg)"'  | column -t | sed -e 's|\-||g' | awk '{print "  "$0}' | sort -k2 -n -r > /tmp/argo-geo.log

# each datacenter requests x response time without argo
argo_totaltime_withoutargo=$(cat /tmp/argo-geo.log | awk '{print $2*$4}' | datamash --no-strict --filler 0 sum 1)
# each datacenter requests x response time with argo
argo_totaltime_withargo=$(cat /tmp/argo-geo.log | awk '{print $2*$5}' | datamash --no-strict --filler 0 sum 1)
argo_totalreqs=$(cat /tmp/argo-geo.log | awk '{print $2}' | datamash --no-strict --filler 0 sum 1)
argo_totalavg_time_withoutargo=$(echo "scale=4; $argo_totaltime_withoutargo/$argo_totalreqs" | bc)
argo_totalavg_time_withargo=$(echo "scale=4; $argo_totaltime_withargo/$argo_totalreqs" | bc)

argogain_avg=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
argogain_avg=$(printf "%.4f\n" $argogain_avg)
argogain_min=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
argogain_min=$(printf "%.4f\n" $argogain_min)
argogain_max=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
argogain_max=$(printf "%.4f\n" $argogain_max)
argogain_stddev=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
argogain_stddev=$(printf "%.4f\n" $argogain_stddev)

argobefore_avg=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 mean 1)
argobefore_avg=$(printf "%.4f\n" $argobefore_avg)
argobefore_min=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 min 1)
argobefore_min=$(printf "%.4f\n" $argobefore_min)
argobefore_max=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 max 1)
argobefore_max=$(printf "%.4f\n" $argobefore_max)
argobefore_stddev=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 sstdev 1)
argobefore_stddev=$(printf "%.4f\n" $argobefore_stddev)

argoafter_avg=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 mean 1)
argoafter_avg=$(printf "%.4f\n" $argoafter_avg)
argoafter_min=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 min 1)
argoafter_min=$(printf "%.4f\n" $argoafter_min)
argoafter_max=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 max 1)
argoafter_max=$(printf "%.4f\n" $argoafter_max)
argoafter_stddev=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 sstdev 1)
argoafter_stddev=$(printf "%.4f\n" $argoafter_stddev)

cat /tmp/argo-geo.log
echo "total-argo-reqs: $argo_totalreqs"
echo "datacenter-calc-avg-resp-without: $argo_totalavg_time_withoutargo"
echo "datacenter-calc-avg-resp-with: $argo_totalavg_time_withargo"
echo "argo-improvement:"
echo "    min: $argogain_min"
echo "    avg: $argogain_avg"
echo "    max: $argogain_max"
echo "    stddev: $argogain_stddev"
echo "argo-resp-time-without-argo:"
echo "    min: $argobefore_min"
echo "    avg: $argobefore_avg"
echo "    max: $argobefore_max"
echo "    stddev: $argobefore_stddev"
echo "argo-resp-time-with-argo:"
echo "    min: $argoafter_min"
echo "    avg: $argoafter_avg"
echo "    max: $argoafter_max"
echo "    stddev: $argoafter_stddev"

rm -f /tmp/argo-geo.log

echo
fi

echo "------------------------------------------------------------------"
echo "Cloudflare Zone Analytics"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "Requests:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum | "non-cached-requests: \(.requests-.cachedRequests)\ncached-requests: \(.cachedRequests)\ntotal-requests: \(.requests)\nencrypted-requests: \(.encryptedRequests)"' | column -t

# echo
# echo "------------------------------------------------------------------"
# echo "Cached Requests:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.cachedRequests'

echo
echo "------------------------------------------------------------------"
echo "Pageviews:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.pageViews'

echo
echo "------------------------------------------------------------------"
echo "Requests HTTP Status Codes:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.responseStatusMap[] | "\(.edgeResponseStatus): \(.requests)"' | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests HTTP Versions:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.clientHTTPVersionMap[] | "\(.clientHTTPProtocol): \(.requests)"' | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests SSL Protocols:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.clientSSLMap[] | "\(.clientSSLProtocol): \(.requests)"' | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests Content Types:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.contentTypeMap[] | "\(.edgeResponseContentTypeName): \(.requests) bytes: \(.bytes)"' | sort -r -nk 2 | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests IP Class:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.ipClassMap[] | "\(.ipType): \(.requests)"' | column -t

if [[ "$BROWSER_PV" = [yY] ]]; then
echo
echo "------------------------------------------------------------------"
echo "Browsers Pageviews:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.browserMap[] | "\(.uaBrowserFamily): \(.pageViews)"' | sort -r -nk 2 | column -t
fi

echo
echo "------------------------------------------------------------------"
echo "Requests Country Top 50:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.requests.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.countryMap[] | "\(.clientCountryName): \(.requests) threats: \(.threats) bytes: \(.bytes)"' | sort -r -nk 2 | head -n50 | column -t
echo

# echo "------------------------------------------------------------------"
# echo "Bandwidth:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth | "  bandwidth all: \(.all)\n  bandwidth cached: \(.cached)\n  bandwidth uncached: \(.uncached)\n  bandwidth ssl-encrypted: \(.ssl.encrypted)\n  bandwidth ssl-unencrypted: \(.ssl.unencrypted)"' | tr -d '{}' | sed -r '/^\s*$/d'

# echo
# echo "------------------------------------------------------------------"
# echo "Bandwidth SSL Protocols:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.contentTypeMap[]'

# echo
# echo "------------------------------------------------------------------"
# echo "Bandwidth Content Types:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.contentTypeMap[]'

echo
echo "------------------------------------------------------------------"
echo "Bandwidth Country Top 50:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.countryMap[] | "\(.clientCountryName): \(.requests) threats: \(.threats) bytes: \(.bytes)"' | sort -r -nk 6 | head -n50 | column -t

echo
echo "------------------------------------------------------------------"
echo "Threats Country Top 50:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.countryMap[] | "\(.clientCountryName): \(.requests) threats: \(.threats) bytes: \(.bytes)"' | sort -r -nk 4 | head -n50 | column -t

echo
echo "------------------------------------------------------------------"
echo "Threats:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.threatPathingMap[] | "\(.threatPathingName): \(.requests)"'

echo
}

get_analytics_days() {
  input_limit="${4:-10000}"
  DATANODE='httpRequests1dGroups'
  since=$1
  back_seconds=$((86400 * $since))
  end_epoch=$(TZ=UTC date +'%s')
  start_epoch=$((end_epoch-$back_seconds))
  # 1s
  #start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  #end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%dT%H:%M:%SZ')
  # 1d
  start_date=$(TZ=UTC date --date="@$start_epoch" +'%Y-%m-%d')
  end_date=$(TZ=UTC date --date="@$end_epoch" +'%Y-%m-%d')

  ZoneID="$zid"
  global_key="$cfkey"
  Email="$cfemail"

  PAYLOAD='{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          httpRequests1dGroups(
            limit: $limit,
            filter: $filter
          ) {
            sum {
              browserMap {
                pageViews
                uaBrowserFamily
              }
              bytes
              cachedBytes
              cachedRequests
              contentTypeMap {
                bytes
                requests
                edgeResponseContentTypeName
              }
              clientHTTPVersionMap {
                clientHTTPProtocol
                requests
              }
              clientSSLMap {
                requests
                clientSSLProtocol
              }
              countryMap {
                bytes
                requests
                threats
                clientCountryName
              }
              encryptedBytes
              encryptedRequests
              ipClassMap {
                requests
                ipType
              }
              pageViews
              requests
              responseStatusMap {
                requests
                edgeResponseStatus
              }
              threats
              threatPathingMap {
                requests
                threatPathingName
              }
            }
            uniq {
              uniques
            }
          }
        }
      }
    }",'
  PAYLOAD="$PAYLOAD
  
    \"variables\": {
      \"zoneTag\": \"$ZoneID\",
      \"limit\": $input_limit,
      \"filter\": {
        \"date_gt\": \"$start_date\",
        \"date_lt\": \"$end_date\"
      }
    }
  }"

if [[ "$CF_ENTERPRISE" != [yY] ]]; then
  PAYLOAD=$(echo "$PAYLOAD" | sed -e 's|botScoreSrcName||' -e 's|botScore||')
fi

if [[ "$DEBUG" = [yY] ]]; then
  echo
  echo "$PAYLOAD" | sed -e "s|$ZoneID|zoneid|"
  echo
fi

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -4sX POST -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOG"
  cat "$CF_LOG" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOG" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
  if [[ "$CF_ARGO" = [yY] ]]; then
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency?bins=10" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGO"
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency/colos" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGOGEO"
  fi
else
  curl -4sX POST -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" --data "$(echo $PAYLOAD)" $ENDPOINT > "$CF_LOG"
  cat "$CF_LOG" | jq -r ' .errors[]' >/dev/null 2>&1
  err=$?
  if [[ "$err" -eq '0' ]]; then
    echo
    cat "$CF_LOG" | sed -e "s|$ZoneID|zoneid|" | jq
    echo
  fi
  if [[ "$CF_ARGO" = [yY] ]]; then
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency?bins=10" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGO"
    curl -4sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency/colos" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGOGEO"
  fi
fi

if [[ "$CF_ARGO" = [yY] ]]; then
  # check if there's argo data in the log
  check_argo_result=$(cat "$CF_LOGARGO" | jq -r '.result')
  check_argo_success=$(cat "$CF_LOGARGO" | jq -r '.success')
fi

if [[ "$CF_ARGO" = [yY] && "$check_argo_result" != 'null' && "$check_argo_success" = 'true' ]]; then
echo "------------------------------------------------------------------"
echo "Cloudflare Argo Analytics"
echo "------------------------------------------------------------------"
cat "$CF_LOGARGO" | jq -r '.result.time_range | "  since: \(.since)\n  until: \(.until)"'
echo "------------------------------------------------------------------"
echo "Argo Response Time:"
echo "------------------------------------------------------------------"
argowithout=$(cat "$CF_LOGARGO" | jq -r '.result.data.averages[0]')
argowith=$(cat "$CF_LOGARGO" | jq -r '.result.data.averages[1]')
argopc=$(echo "scale=4; $argowith/$argowithout" | bc)
argogain=$(echo "scale=2; (1-$argopc)*100" | bc)
argoreq_without=$(cat "$CF_LOGARGO" | jq -s 'map(.result.data.counts[0][]) | add')
argoreq_with=$(cat "$CF_LOGARGO" | jq -s 'map(.result.data.counts[1][]) | add')
argorouted=$(cat "$CF_LOGARGO" | jq -r '.result.percent_smart_routed')
echo "request-without-argo: ${argoreq_without}"
echo "request-with-argo: ${argoreq_with}"
echo "argo-smarted-routed: ${argorouted}%"
echo "argo-improvement: ${argogain}%"
cat "$CF_LOGARGO" | jq -r '.result.data | "  without-argo: \(.averages[0]) (milliseconds)\n  with-argo \(.averages[1]) (milliseconds)"'
echo "------------------------------------------------------------------"
echo "Argo Cloudflare Datacenter Response Times"
echo "------------------------------------------------------------------"
cat "$CF_LOGARGOGEO" | jq -r '.result.features[] | .properties | "  \(.code) \(.argo_req_count) \(.pct_avg_change * 100) \(.no_argo_avg) \(.argo_avg)"'  | column -t | sed -e 's|\-||g' | awk '{print "  "$0}' | sort -k2 -n -r > /tmp/argo-geo.log

# each datacenter requests x response time without argo
argo_totaltime_withoutargo=$(cat /tmp/argo-geo.log | awk '{print $2*$4}' | datamash --no-strict --filler 0 sum 1)
# each datacenter requests x response time with argo
argo_totaltime_withargo=$(cat /tmp/argo-geo.log | awk '{print $2*$5}' | datamash --no-strict --filler 0 sum 1)
argo_totalreqs=$(cat /tmp/argo-geo.log | awk '{print $2}' | datamash --no-strict --filler 0 sum 1)
argo_totalavg_time_withoutargo=$(echo "scale=4; $argo_totaltime_withoutargo/$argo_totalreqs" | bc)
argo_totalavg_time_withargo=$(echo "scale=4; $argo_totaltime_withargo/$argo_totalreqs" | bc)

argogain_avg=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 mean 1)
argogain_avg=$(printf "%.4f\n" $argogain_avg)
argogain_min=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 min 1)
argogain_min=$(printf "%.4f\n" $argogain_min)
argogain_max=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 max 1)
argogain_max=$(printf "%.4f\n" $argogain_max)
argogain_stddev=$(cat /tmp/argo-geo.log | awk '{print $3}' | datamash --no-strict --filler 0 sstdev 1)
argogain_stddev=$(printf "%.4f\n" $argogain_stddev)

argobefore_avg=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 mean 1)
argobefore_avg=$(printf "%.4f\n" $argobefore_avg)
argobefore_min=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 min 1)
argobefore_min=$(printf "%.4f\n" $argobefore_min)
argobefore_max=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 max 1)
argobefore_max=$(printf "%.4f\n" $argobefore_max)
argobefore_stddev=$(cat /tmp/argo-geo.log | awk '{print $4}' | datamash --no-strict --filler 0 sstdev 1)
argobefore_stddev=$(printf "%.4f\n" $argobefore_stddev)

argoafter_avg=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 mean 1)
argoafter_avg=$(printf "%.4f\n" $argoafter_avg)
argoafter_min=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 min 1)
argoafter_min=$(printf "%.4f\n" $argoafter_min)
argoafter_max=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 max 1)
argoafter_max=$(printf "%.4f\n" $argoafter_max)
argoafter_stddev=$(cat /tmp/argo-geo.log | awk '{print $5}' | datamash --no-strict --filler 0 sstdev 1)
argoafter_stddev=$(printf "%.4f\n" $argoafter_stddev)

cat /tmp/argo-geo.log
echo "total-argo-reqs: $argo_totalreqs"
echo "datacenter-calc-avg-resp-without: $argo_totalavg_time_withoutargo"
echo "datacenter-calc-avg-resp-with: $argo_totalavg_time_withargo"
echo "argo-improvement:"
echo "    min: $argogain_min"
echo "    avg: $argogain_avg"
echo "    max: $argogain_max"
echo "    stddev: $argogain_stddev"
echo "argo-resp-time-without-argo:"
echo "    min: $argobefore_min"
echo "    avg: $argobefore_avg"
echo "    max: $argobefore_max"
echo "    stddev: $argobefore_stddev"
echo "argo-resp-time-with-argo:"
echo "    min: $argoafter_min"
echo "    avg: $argoafter_avg"
echo "    max: $argoafter_max"
echo "    stddev: $argoafter_stddev"

rm -f /tmp/argo-geo.log

echo
fi

echo "------------------------------------------------------------------"
echo "Cloudflare Zone Analytics"
echo "------------------------------------------------------------------"
echo "since: $start_date"
echo "until: $end_date"
echo "------------------------------------------------------------------"
echo "Requests:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum | "non-cached-requests: \(.requests-.cachedRequests)\ncached-requests: \(.cachedRequests)\ntotal-requests: \(.requests)\nencrypted-requests: \(.encryptedRequests)"' | column -t

# echo
# echo "------------------------------------------------------------------"
# echo "Cached Requests:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.cachedRequests'

echo
echo "------------------------------------------------------------------"
echo "Pageviews:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.pageViews'

echo
echo "------------------------------------------------------------------"
echo "Requests HTTP Status Codes:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.responseStatusMap[] | "\(.edgeResponseStatus): \(.requests)"' | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests HTTP Versions:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.clientHTTPVersionMap[] | "\(.clientHTTPProtocol): \(.requests)"' | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests SSL Protocols:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.clientSSLMap[] | "\(.clientSSLProtocol): \(.requests)"' | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests Content Types:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.contentTypeMap[] | "\(.edgeResponseContentTypeName): \(.requests) bytes: \(.bytes)"' | sort -r -nk 2 | column -t

echo
echo "------------------------------------------------------------------"
echo "Requests IP Class:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.ipClassMap[] | "\(.ipType): \(.requests)"' | column -t

if [[ "$BROWSER_PV" = [yY] ]]; then
echo
echo "------------------------------------------------------------------"
echo "Browsers Pageviews:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.browserMap[] | "\(.uaBrowserFamily): \(.pageViews)"' | sort -r -nk 2 | column -t
fi

echo
echo "------------------------------------------------------------------"
echo "Requests Country Top 50:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.requests.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.countryMap[] | "\(.clientCountryName): \(.requests) threats: \(.threats) bytes: \(.bytes)"' | sort -r -nk 2 | head -n50 | column -t
echo

# echo "------------------------------------------------------------------"
# echo "Bandwidth:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth | "  bandwidth all: \(.all)\n  bandwidth cached: \(.cached)\n  bandwidth uncached: \(.uncached)\n  bandwidth ssl-encrypted: \(.ssl.encrypted)\n  bandwidth ssl-unencrypted: \(.ssl.unencrypted)"' | tr -d '{}' | sed -r '/^\s*$/d'

# echo
# echo "------------------------------------------------------------------"
# echo "Bandwidth SSL Protocols:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.contentTypeMap[]'

# echo
# echo "------------------------------------------------------------------"
# echo "Bandwidth Content Types:"
# echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.contentTypeMap[]'

echo
echo "------------------------------------------------------------------"
echo "Bandwidth Country Top 50:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.countryMap[] | "\(.clientCountryName): \(.requests) threats: \(.threats) bytes: \(.bytes)"' | sort -r -nk 6 | head -n50 | column -t

echo
echo "------------------------------------------------------------------"
echo "Threats Country Top 50:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.countryMap[] | "\(.clientCountryName): \(.requests) threats: \(.threats) bytes: \(.bytes)"' | sort -r -nk 4 | head -n50 | column -t

echo
echo "------------------------------------------------------------------"
echo "Threats:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq --arg dn "$DATANODE" -r '.data.viewer.zones | .[] | .[$dn][].sum.threatPathingMap[] | "\(.threatPathingName): \(.requests)"'

echo
}

case "$1" in
  6hrs )
    get_analytics -360
    ;;
  12hrs )
    get_analytics -720
    ;;
  24hrs )
    get_analytics -1440
    ;;
  48hrs )
    get_analytics -2880
    ;;
  week )
    get_analytics -10080
    ;;
  month )
    get_analytics -43200
    ;;
  custom )
    get_analytics -360
    ;;
  hrs )
    get_analytics "$2"
    ;;
  days )
    get_analytics_days "$2"
    ;;
  ruleid-mins )
    ruleid_fw_analytics_hrs "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  ruleid-hrs )
    ruleid_fw_analytics "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  ruleid-days )
    ruleid_fw_analytics_days "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  rayid-mins )
    fw_analytics_hrs "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  rayid-hrs )
    fw_analytics "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  rayid-days )
    fw_analytics_days "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  ip-mins )
    ip_analytics_hrs "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  ip-hrs )
    ip_analytics "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  ip-days )
    ip_analytics_days "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
  * )
    echo "Usage:"
    echo
    echo "---------------------------------------------"
    echo "Zone Analytics"
    echo "---------------------------------------------"
    echo "$0 hrs 72"
    echo "$0 days 3"
    echo
    echo "---------------------------------------------"
    echo "Firewall Events"
    echo "---------------------------------------------"
    echo "$0 ruleid-mins 60 cfruleid"
    echo "$0 ruleid-hrs 72 cfruleid"
    echo "$0 ruleid-days 3 cfruleid"
    echo "$0 rayid-mins 60 cfrayid"
    echo "$0 rayid-hrs 72 cfrayid"
    echo "$0 rayid-days 3 cfrayid"
    echo "$0 ip-mins 60 request-ip|all"
    echo "$0 ip-hrs 72 request-ip|all"
    echo "$0 ip-days 3 request-ip|all"
    echo
    echo "---------------------------------------------"
    echo "Firewall Events filter by action"
    echo "---------------------------------------------"
    echo "$0 ruleid-mins 60 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 ruleid-hrs 72 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 ruleid-days 3 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 rayid-mins 60 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 rayid-hrs 72 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 rayid-days 3 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 ip-mins 60 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 ip-hrs 72 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo "$0 ip-days 3 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none}"
    echo
    echo "---------------------------------------------"
    echo "Firewall Events filter by action + limit XX"
    echo "---------------------------------------------"
    echo "$0 ruleid-mins 60 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 ruleid-hrs 72 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 ruleid-days 3 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 rayid-mins 60 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 rayid-hrs 72 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 rayid-days 3 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 ip-mins 60 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 ip-hrs 72 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo "$0 ip-days 3 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100"
    echo
    echo "---------------------------------------------"
    echo "Firewall Events filter by action + limit XX + hostname"
    echo "---------------------------------------------"
    echo "$0 ruleid-mins 60 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 ruleid-hrs 72 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 ruleid-days 3 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 rayid-mins 60 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 rayid-hrs 72 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 rayid-days 3 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 ip-mins 60 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 ip-hrs 72 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo "$0 ip-days 3 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname"
    echo
    echo "---------------------------------------------"
    echo "Firewall Events filter by action + limit XX + hostname + referrer"
    echo "---------------------------------------------"
    echo "$0 ruleid-mins 60 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 ruleid-hrs 72 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 ruleid-days 3 cfruleid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 rayid-mins 60 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 rayid-hrs 72 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 rayid-days 3 cfrayid {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 ip-mins 60 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 ip-hrs 72 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    echo "$0 ip-days 3 request-ip|all {block|log|challenge|challenge_solved|managed_block|managed_challenge|jschallenge|allow|none} 100 hostname|none referrer|none|empty|notempty"
    ;;
esac