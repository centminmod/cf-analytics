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

if [[ -f $(which yum) && ! -f /usr/bin/datamash ]]; then
  yum -y -q install datamash
fi

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
echo "------------------------------------------------------------------"
echo "  Argo Cloudflare Datacenter Response Times"
echo "------------------------------------------------------------------"
cat "$CF_LOGARGOGEO" | jq -r '.result.features[] | .properties | "  \(.code) \(.argo_req_count) \(.pct_avg_change) \(.no_argo_avg) \(.argo_avg)"'  | column -t | sed -e 's|\-||g' | awk '{print "  "$0}' | sort -k2 -n -r > /tmp/argo-geo.log

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
echo "  total-argo-reqs: $argo_totalreqs"
echo "  datacenter-calc-avg-resp-without: $argo_totalavg_time_withoutargo"
echo "  datacenter-calc-avg-resp-with: $argo_totalavg_time_withargo"
echo "  argo-improvement:"
echo "      min: $argogain_min"
echo "      avg: $argogain_avg"
echo "      max: $argogain_max"
echo "      stddev: $argogain_stddev"
echo "  argo-resp-time-without-argo:"
echo "      min: $argobefore_min"
echo "      avg: $argobefore_avg"
echo "      max: $argobefore_max"
echo "      stddev: $argobefore_stddev"
echo "  argo-resp-time-with-argo:"
echo "      min: $argoafter_min"
echo "      avg: $argoafter_avg"
echo "      max: $argoafter_max"
echo "      stddev: $argoafter_stddev"

rm -f /tmp/argo-geo.log

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