#!/bin/bash
################################################
# cloudflare zone analytics
# export zid=YOUR_CLOUDFLARE_DOMAIN_ZONE_ID
# export cfkey=YOUR_CLOUDFLARE_API_KEY
# export cfemail=YOUR_CLOUDFLARE_ACCOUNT_EMAIL
################################################
# whether to use CF Global Account API Token or
# new CF specific API Tokens (in beta right now)
CF_GLOBAL_TOKEN='n'
CF_ARGO='y'
CF_LOG='cm-analytics.log'
CF_LOGARGO='cm-analytics-argo.log'
CF_LOGARGOGEO='cm-analytics-argo-geo.log'

get_analytics() {
  since=$1

if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
  curl -sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/dashboard?since=${since}&continuous=true" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOG"
  if [[ "$CF_ARGO" = [yY] ]]; then
    curl -sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency?bins=10" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGO"
    curl -sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency/colos" \
     -H "X-Auth-Email: $cfemail" -H "X-Auth-Key: $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGOGEO"
  fi
else
  curl -sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/dashboard?since=${since}&continuous=true" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOG"
  if [[ "$CF_ARGO" = [yY] ]]; then
    curl -sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency?bins=10" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGO"
    curl -sX GET "https://api.cloudflare.com/client/v4/zones/${zid}/analytics/latency/colos" \
     -H "Authorization: Bearer $cfkey" -H "Content-Type: application/json" > "$CF_LOGARGOGEO"
  fi
fi

if [[ "$CF_ARGO" = [yY] ]]; then
echo "------------------------------------------------------------------"
echo "  Cloudflare Argo Analytics"
echo "------------------------------------------------------------------"
cat "$CF_LOGARGO" | jq -r '.result.time_range | "  since: \(.since)\n  until: \(.until)"'
echo "------------------------------------------------------------------"
echo "  Argo Response Time:"
echo "------------------------------------------------------------------"
argowithout=$(cat "$CF_LOGARGO" | jq -r '.result.data.averages[0]')
argowith=$(cat "$CF_LOGARGO" | jq -r '.result.data.averages[1]')
argopc=$(echo "scale=4; $argowith/$argowithout" | bc)
argogain=$(echo "scale=2; (1-$argopc)*100" | bc)
argoreq_without=$(cat "$CF_LOGARGO" | jq -s 'map(.result.data.counts[0][]) | add')
argoreq_with=$(cat "$CF_LOGARGO" | jq -s 'map(.result.data.counts[1][]) | add')
argorouted=$(cat "$CF_LOGARGO" | jq -r '.result.percent_smart_routed')
echo "  request-without-argo: ${argoreq_without}"
echo "  request-with-argo: ${argoreq_with}"
echo "  argo-smarted-routed: ${argorouted}%"
echo "  argo-improvement: ${argogain}%"
cat "$CF_LOGARGO" | jq -r '.result.data | "  without-argo: \(.averages[0]) (milliseconds)\n  with-argo \(.averages[1]) (milliseconds)"'

echo
fi

echo "------------------------------------------------------------------"
echo "  Cloudflare Zone Analytics"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals | "  since: \(.since)\n  until: \(.until)"' | tr -d '{}' | sed -r '/^\s*$/d'
echo "------------------------------------------------------------------"
echo "  Requests:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.requests | "  requests all: \(.all)\n  requests cached: \(.cached)\n  requests uncached: \(.uncached)\n  requests ssl-encrypted: \(.ssl.encrypted)\n  requests ssl-unencrypted: \(.ssl.unencrypted)"' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Pageviews:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.pageviews' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Requests HTTP Status Codes:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.requests.http_status' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Requests SSL Protocols:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.requests.ssl_protocol' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Requests Content Types:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.requests.content_type' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Requests IP Class:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.requests.ip_class' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Requests Country Top 20:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.requests.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq -r '.result.totals.requests.country' | tr -d '{}' | sed -e 's|,||g' | sed -r '/^\s*$/d' | sort -r -nk 2 | head -n20 
echo

echo "------------------------------------------------------------------"
echo "  Bandwidth:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.bandwidth | "  bandwidth all: \(.all)\n  bandwidth cached: \(.cached)\n  bandwidth uncached: \(.uncached)\n  bandwidth ssl-encrypted: \(.ssl.encrypted)\n  bandwidth ssl-unencrypted: \(.ssl.unencrypted)"' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Bandwidth SSL Protocols:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.bandwidth.ssl_protocol' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Bandwidth Content Types:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.bandwidth.content_type' | tr -d '{}' | sed -r '/^\s*$/d'

echo
echo "------------------------------------------------------------------"
echo "  Bandwidth Country Top 20:"
echo "------------------------------------------------------------------"
# cat "$CF_LOG" | jq -r '.result.totals.bandwidth.country' | tr -d '{}' | sed -r '/^\s*$/d'
cat "$CF_LOG" | jq -r '.result.totals.bandwidth.country' | tr -d '{}' | sed -e 's|,||g' | sed -r '/^\s*$/d' | sort -r -nk 2 | head -n20 

echo
echo "------------------------------------------------------------------"
echo "  Threats:"
echo "------------------------------------------------------------------"
cat "$CF_LOG" | jq -r '.result.totals.threats' | tr -d '{}' | sed -r '/^\s*$/d'

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
  week )
    get_analytics -10080
    ;;
  month )
    get_analytics -43200
    ;;
  custom )
    get_analytics -360
    ;;
  * )
    echo "$0 {6hrs|12hrs|24hrs|week|month|custom}"
    ;;
esac