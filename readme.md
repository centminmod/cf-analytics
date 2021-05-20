# Cloudflare Zone Analytics API Script (GraphQL)

This Cloudflare Zone Analytics API script, `cf-analytics-graphql.sh` uses the new Cloudflare GraphQL API as the old zone analytics API has been deprecated and supports both traditional Cloudflare Global API Token authentication (`CF_GLOBAL_TOKEN='y'`) and newer non-global Cloudflare permission based API Token authentication (`CF_GLOBAL_TOKEN='n'`) which is currently in beta testing. The `cf-analytics-graphql.sh` script is currently default to `CF_GLOBAL_TOKEN='n'` for testing purposes.

If you have Cloudflare Argo enabled on your CF zone, also set `CF_ARGO='y'` - currently enabled by default for testing purposes.

## Required Cloudflare API Token Permissions

By default the `cf-analytics-graphql.sh` script sets `CF_GLOBAL_TOKEN='n'` to use Cloudflare API Token. If you intend to use Cloudflare API Token, you'll need the account or zone level permissions for `Logs:Read` and `Analytics:Read` generated at [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens).

## Usage

Where `YOUR_CLOUDFLARE_API_KEY` can either be your Cloudflare Global API Token or your generated Cloudflare API Token.

```
export zid=YOUR_CLOUDFLARE_DOMAIN_ZONE_ID
export cfkey=YOUR_CLOUDFLARE_API_KEY
export cfemail=YOUR_CLOUDFLARE_ACCOUNT_EMAIL
```

Supported options include querying the Cloudflare Firewall GraphQL API filtering by ruleId, rayID and client visitor IP address.

```
./cf-analytics-graphql.sh


Usage:

---------------------------------------------
Zone Analytics
---------------------------------------------
./cf-analytics-graphql.sh hrs 72
./cf-analytics-graphql.sh days 3

---------------------------------------------
Firewall Events
---------------------------------------------
./cf-analytics-graphql.sh ruleid-mins 60 cfruleid
./cf-analytics-graphql.sh ruleid-hrs 72 cfruleid
./cf-analytics-graphql.sh ruleid-days 3 cfruleid
./cf-analytics-graphql.sh rayid-mins 60 cfrayid
./cf-analytics-graphql.sh rayid-hrs 72 cfrayid
./cf-analytics-graphql.sh rayid-days 3 cfrayid
./cf-analytics-graphql.sh ip-mins 60 request-ip
./cf-analytics-graphql.sh ip-hrs 72 request-ip
./cf-analytics-graphql.sh ip-days 3 request-ip

---------------------------------------------
Firewall Events filter by action
---------------------------------------------
./cf-analytics-graphql.sh ruleid-mins 60 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh ruleid-hrs 72 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh ruleid-days 3 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh rayid-mins 60 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh rayid-hrs 72 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh rayid-days 3 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh ip-mins 60 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh ip-hrs 72 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}
./cf-analytics-graphql.sh ip-days 3 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow}

---------------------------------------------
Firewall Events filter by action + limit XX
---------------------------------------------
./cf-analytics-graphql.sh ruleid-mins 60 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh ruleid-hrs 72 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh ruleid-days 3 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh rayid-mins 60 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh rayid-hrs 72 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh rayid-days 3 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh ip-mins 60 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh ip-hrs 72 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100
./cf-analytics-graphql.sh ip-days 3 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100

---------------------------------------------
Firewall Events filter by action + limit XX + hostname
---------------------------------------------
./cf-analytics-graphql.sh ruleid-mins 60 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh ruleid-hrs 72 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh ruleid-days 3 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh rayid-mins 60 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh rayid-hrs 72 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh rayid-days 3 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh ip-mins 60 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh ip-hrs 72 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname
./cf-analytics-graphql.sh ip-days 3 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname


---------------------------------------------
Firewall Events filter by action + limit XX + hostname + referrer
---------------------------------------------
./cf-analytics-graphql.sh ruleid-mins 60 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh ruleid-hrs 72 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh ruleid-days 3 cfruleid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh rayid-mins 60 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh rayid-hrs 72 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh rayid-days 3 cfrayid {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh ip-mins 60 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh ip-hrs 72 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
./cf-analytics-graphql.sh ip-days 3 request-ip {block|log|challenge|managed_block|managed_challenge|jschallenge|allow} 100 hostname|none referrer|none|empty
```

## Example Web Analytics For Past 72hrs

Example web traffic analytics for Cloudflare Zone site where Cloudflare Argo is enabled and thus `CF_ARGO='y' is set in script.

```
./cf-analytics-graphql.sh hrs 72



{ "query":
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
    }",
  
    "variables": {
      "zoneTag": "zoneid",
      "limit": 10000,
      "filter": {
        "datetime_geq": "2021-03-27T09:26:14Z",
        "datetime_leq": "2021-03-30T09:26:14Z"
      }
    }
  }

------------------------------------------------------------------
Cloudflare Argo Analytics
------------------------------------------------------------------
  since: 2021-03-28T09:25:00Z
  until: 2021-03-30T09:25:00Z
------------------------------------------------------------------
Argo Response Time:
------------------------------------------------------------------
request-without-argo: 19535
request-with-argo: 177170
argo-smarted-routed: 69%
argo-improvement: 63.9700%
  without-argo: 505 (milliseconds)
  with-argo 182 (milliseconds)
------------------------------------------------------------------
Argo Cloudflare Datacenter Response Times
------------------------------------------------------------------
  SIN  29928  66.35914740653341   926.361061419201    311.63575915530606
  SCL  29037  64.11976911817536   568.6848635235732   204.04544202224747
  MEL  26015  62.50412858804896   816.4853044086774   306.1482798385547
  AMS  8267   57.09213687101159   321.40695067264573  137.90885448167413
  DFW  7366   64.41476705708077   345.3693528693529   122.90048873201195
  FRA  6951   63.84892040657324   275.80409356725147  99.70615738742627
  LHR  6918   59.93690301038376   224.18741355463348  89.81642093090488
  ATL  6879   62.76396415442681   284.34              105.87694432330281
  MXP  6875   45.72770180212848   84.16883963494134   45.68036363636364
  MIA  6872   54.16696837456991   110.22667542706965  50.52022700814901
  PRG  6867   55.690435837799825  91.20322580645161   40.41175185670598
  CDG  6864   35.4306049437425    45.15862944162436   29.158653846153847
  LAX  6847   66.75273582985896   246.56369426751593  81.9756827807799
  SJC  6827   66.2770115194605    463.4505208333333   156.2893657536253
  SYD  6814   68.00495069273235   846.3161764705883   270.77927795714703
  IAD  6805   24.665475866227325  35.37247474747475   26.647685525349008
  ARN  642    59.229363786066536  625.4310344827586   254.99221183800623
  MAD  423    58.42195555004257   537.8389830508474   223.6229314420804
total-argo-reqs: 177197
datacenter-calc-avg-resp-without: 507.1424
datacenter-calc-avg-resp-with: 182.5987
argo-improvement:
    min: 24.6655
    avg: 57.5226
    max: 68.0050
    stddev: 11.5409
argo-resp-time-without-argo:
    min: 35.3725
    avg: 380.4650
    max: 926.3611
    stddev: 284.4499
argo-resp-time-with-argo:
    min: 26.6477
    avg: 142.1176
    max: 311.6358
    stddev: 96.8914

------------------------------------------------------------------
Cloudflare Zone Analytics
------------------------------------------------------------------
since: 2021-03-27T09:26:14Z
until: 2021-03-30T09:26:14Z
------------------------------------------------------------------
Requests:
------------------------------------------------------------------
non-cached-requests:  323848
cached-requests:      452713
total-requests:       776561
encrypted-requests:   744993

------------------------------------------------------------------
Pageviews:
------------------------------------------------------------------
383197

------------------------------------------------------------------
Requests HTTP Status Codes:
------------------------------------------------------------------
101:  11
200:  665556
201:  5
204:  20645
206:  9
301:  5178
302:  10006
303:  274
304:  6453
307:  11344
308:  8
400:  13
401:  1
403:  49432
404:  5570
405:  24
409:  27
416:  32
499:  1801
500:  7
503:  11
520:  134
521:  14
524:  6

------------------------------------------------------------------
Requests HTTP Versions:
------------------------------------------------------------------
HTTP/1.0:  26712
HTTP/1.1:  428006
HTTP/2:    245951
HTTP/3:    75892

------------------------------------------------------------------
Requests SSL Protocols:
------------------------------------------------------------------
none:     31568
TLSv1.2:  122015
TLSv1.3:  622978

------------------------------------------------------------------
Requests Content Types:
------------------------------------------------------------------
html:     459383  bytes:  20494621328
js:       127196  bytes:  1412620506
png:      60180   bytes:  292665356
empty:    31516   bytes:  12842897
css:      29641   bytes:  280338412
webp:     25491   bytes:  222653641
woff:     13967   bytes:  851518637
json:     10031   bytes:  13483492
txt:      5765    bytes:  14734200
xml:      4461    bytes:  59048229
ico:      3593    bytes:  4404109
js:       2391    bytes:  23764243
jpeg:     1335    bytes:  19159073
bin:      930     bytes:  1317517253
gif:      342     bytes:  22968741
unknown:  183     bytes:  36692272
rss:      43      bytes:  4870403
eot:      38      bytes:  4003776
ttf:      36      bytes:  4945194
xml:      25      bytes:  9227113
svg:      8       bytes:  3121478
zip:      6       bytes:  111969

------------------------------------------------------------------
Requests IP Class:
------------------------------------------------------------------
unknown:            176706
badHost:            1593
searchEngine:       127174
allowlist:          333
monitoringService:  12234
noRecord:           457907
tor:                614

------------------------------------------------------------------
Requests Country Top 50:
------------------------------------------------------------------
US:  319791  threats:  9982  bytes:  7766722228
AU:  54805   threats:  870   bytes:  1137255376
DE:  44106   threats:  4545  bytes:  1775162169
NL:  42078   threats:  7486  bytes:  2856619221
FR:  40743   threats:  4905  bytes:  1750683099
GB:  38951   threats:  3372  bytes:  1495543935
IN:  21923   threats:  207   bytes:  477654529
SG:  19866   threats:  1488  bytes:  1119673003
JP:  16690   threats:  70    bytes:  379603356
IT:  15428   threats:  112   bytes:  91506265
RU:  14421   threats:  1216  bytes:  636223533
CN:  13501   threats:  449   bytes:  350017187
CZ:  12850   threats:  18    bytes:  41797999
CA:  11252   threats:  1661  bytes:  633472854
VN:  7123    threats:  809   bytes:  288185237
ID:  7098    threats:  603   bytes:  231629020
UA:  6613    threats:  3623  bytes:  1038477251
BR:  6525    threats:  258   bytes:  125749928
ES:  5800    threats:  777   bytes:  291560069
IL:  4615    threats:  19    bytes:  85188456
PL:  4517    threats:  46    bytes:  63677688
KR:  4425    threats:  1056  bytes:  326642777
HK:  3891    threats:  44    bytes:  152155967
TR:  2429    threats:  38    bytes:  66302068
CL:  2365    threats:  14    bytes:  306968910
BG:  2241    threats:  540   bytes:  165048553
TH:  2236    threats:  391   bytes:  129354213
TW:  2218    threats:  68    bytes:  44067860
EC:  2140    threats:  22    bytes:  16520043
RO:  2111    threats:  90    bytes:  35253314
SE:  1895    threats:  32    bytes:  44182202
PH:  1864    threats:  19    bytes:  21147520
FI:  1828    threats:  83    bytes:  25863731
GR:  1818    threats:  13    bytes:  15896350
NO:  1764    threats:  1     bytes:  23079302
MY:  1749    threats:  21    bytes:  23324092
PT:  1745    threats:  6     bytes:  20028038
MX:  1619    threats:  407   bytes:  123074157
IE:  1519    threats:  168   bytes:  47492847
PK:  1413    threats:  129   bytes:  47516020
CH:  1229    threats:  65    bytes:  28712086
AT:  1167    threats:  10    bytes:  21705223
XX:  1149    threats:  53    bytes:  52165989
AR:  1140    threats:  29    bytes:  21405448
IR:  1104    threats:  187   bytes:  61209609
HU:  1088    threats:  25    bytes:  16885023
CO:  875     threats:  25    bytes:  15074114
EG:  858     threats:  6     bytes:  10241328
SK:  844     threats:  7     bytes:  12676860
RS:  715     threats:  15    bytes:  9074126


------------------------------------------------------------------
Bandwidth Country Top 50:
------------------------------------------------------------------
US:  319791  threats:  9982  bytes:  7766722228
NL:  42078   threats:  7486  bytes:  2856619221
DE:  44106   threats:  4545  bytes:  1775162169
FR:  40743   threats:  4905  bytes:  1750683099
GB:  38951   threats:  3372  bytes:  1495543935
AU:  54805   threats:  870   bytes:  1137255376
SG:  19866   threats:  1488  bytes:  1119673003
UA:  6613    threats:  3623  bytes:  1038477251
RU:  14421   threats:  1216  bytes:  636223533
CA:  11252   threats:  1661  bytes:  633472854
IN:  21923   threats:  207   bytes:  477654529
JP:  16690   threats:  70    bytes:  379603356
CN:  13501   threats:  449   bytes:  350017187
KR:  4425    threats:  1056  bytes:  326642777
CL:  2365    threats:  14    bytes:  306968910
ES:  5800    threats:  777   bytes:  291560069
VN:  7123    threats:  809   bytes:  288185237
ID:  7098    threats:  603   bytes:  231629020
BG:  2241    threats:  540   bytes:  165048553
HK:  3891    threats:  44    bytes:  152155967
TH:  2236    threats:  391   bytes:  129354213
BR:  6525    threats:  258   bytes:  125749928
MX:  1619    threats:  407   bytes:  123074157
IT:  15428   threats:  112   bytes:  91506265
IL:  4615    threats:  19    bytes:  85188456
LT:  646     threats:  280   bytes:  82788092
TR:  2429    threats:  38    bytes:  66302068
PL:  4517    threats:  46    bytes:  63677688
IR:  1104    threats:  187   bytes:  61209609
AD:  193     threats:  193   bytes:  52355696
XX:  1149    threats:  53    bytes:  52165989
PK:  1413    threats:  129   bytes:  47516020
IE:  1519    threats:  168   bytes:  47492847
KE:  361     threats:  159   bytes:  45132590
SE:  1895    threats:  32    bytes:  44182202
TW:  2218    threats:  68    bytes:  44067860
CZ:  12850   threats:  18    bytes:  41797999
T1:  614     threats:  579   bytes:  38929925
RO:  2111    threats:  90    bytes:  35253314
CH:  1229    threats:  65    bytes:  28712086
FI:  1828    threats:  83    bytes:  25863731
BD:  666     threats:  128   bytes:  25474902
SC:  31      threats:  1     bytes:  24413207
NZ:  554     threats:  66    bytes:  23532949
MY:  1749    threats:  21    bytes:  23324092
KH:  190     threats:  81    bytes:  23202908
NO:  1764    threats:  1     bytes:  23079302
AT:  1167    threats:  10    bytes:  21705223
AR:  1140    threats:  29    bytes:  21405448
PH:  1864    threats:  19    bytes:  21147520

------------------------------------------------------------------
Threats Country Top 50:
------------------------------------------------------------------
US:  319791  threats:  9982  bytes:  7766722228
NL:  42078   threats:  7486  bytes:  2856619221
FR:  40743   threats:  4905  bytes:  1750683099
DE:  44106   threats:  4545  bytes:  1775162169
UA:  6613    threats:  3623  bytes:  1038477251
GB:  38951   threats:  3372  bytes:  1495543935
CA:  11252   threats:  1661  bytes:  633472854
SG:  19866   threats:  1488  bytes:  1119673003
RU:  14421   threats:  1216  bytes:  636223533
KR:  4425    threats:  1056  bytes:  326642777
AU:  54805   threats:  870   bytes:  1137255376
VN:  7123    threats:  809   bytes:  288185237
ES:  5800    threats:  777   bytes:  291560069
ID:  7098    threats:  603   bytes:  231629020
T1:  614     threats:  579   bytes:  38929925
BG:  2241    threats:  540   bytes:  165048553
CN:  13501   threats:  449   bytes:  350017187
MX:  1619    threats:  407   bytes:  123074157
TH:  2236    threats:  391   bytes:  129354213
LT:  646     threats:  280   bytes:  82788092
BR:  6525    threats:  258   bytes:  125749928
IN:  21923   threats:  207   bytes:  477654529
AD:  193     threats:  193   bytes:  52355696
IR:  1104    threats:  187   bytes:  61209609
IE:  1519    threats:  168   bytes:  47492847
KE:  361     threats:  159   bytes:  45132590
PK:  1413    threats:  129   bytes:  47516020
BD:  666     threats:  128   bytes:  25474902
IT:  15428   threats:  112   bytes:  91506265
RO:  2111    threats:  90    bytes:  35253314
FI:  1828    threats:  83    bytes:  25863731
KH:  190     threats:  81    bytes:  23202908
AM:  213     threats:  71    bytes:  18899888
JP:  16690   threats:  70    bytes:  379603356
TW:  2218    threats:  68    bytes:  44067860
NZ:  554     threats:  66    bytes:  23532949
CH:  1229    threats:  65    bytes:  28712086
XX:  1149    threats:  53    bytes:  52165989
PL:  4517    threats:  46    bytes:  63677688
HK:  3891    threats:  44    bytes:  152155967
TR:  2429    threats:  38    bytes:  66302068
SE:  1895    threats:  32    bytes:  44182202
AR:  1140    threats:  29    bytes:  21405448
ZA:  641     threats:  26    bytes:  13656693
HU:  1088    threats:  25    bytes:  16885023
CO:  875     threats:  25    bytes:  15074114
SA:  407     threats:  22    bytes:  5338196
EC:  2140    threats:  22    bytes:  16520043
MY:  1749    threats:  21    bytes:  23324092
AL:  313     threats:  21    bytes:  4214500

------------------------------------------------------------------
Threats:
------------------------------------------------------------------
bic.ban.unknown: 49
user.ban.ip: 3
```

## Example Cloudflare Firewall GraphQL IP Address Filter

Querying the Cloudflare Firewall GraphQL API filtering by IP address `119.92.185.135` for past 24hrs for Firewall events with action = `block`

```
./cf-analytics-graphql.sh ip-hrs 24 119.92.185.135 block



{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_ASC]
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
    }",
  
    "variables": {
      "zoneTag": "zoneid",
      "limit": 100,
      "filter": {
        "clientIP": "119.92.185.135",
        "action": "block",
        
        "datetime_geq": "2021-03-29T09:37:21Z",
        "datetime_leq": "2021-03-30T09:37:21Z"
      }
    }
  }

------------------------------------------------------------------
Cloudflare Firewall
------------------------------------------------------------------
since: 2021-03-29T09:37:21Z
until: 2021-03-30T09:37:21Z
------------------------------------------------------------------
1 Firewall Events for Request IP: 119.92.185.135
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC GET HTTP/1.1 bd706145258349c686ddb32b94dxxxxx
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC GET HTTP/1.1
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC domain.com GET HTTP/1.1
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC domain.com GET HTTP/1.1 /wp-login.php 
------------------------------------------------------------------
119.92.185.135 637f925cbec96d7c 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC 2021-03-30T07:19:47Z domain.com GET HTTP/1.1 /wp-login.php 
------------------------------------------------------------------
{
  "results": [
    {
      "action": "block",
      "botScore": 1,
      "botScoreSrcName": "Heuristics",
      "clientASNDescription": "IPG-AS-AP Philippine Long Distance Telephone Company",
      "clientAsn": "9299",
      "clientCountryName": "PH",
      "clientIP": "119.92.185.135",
      "clientRefererHost": "",
      "clientRefererPath": "",
      "clientRefererQuery": "",
      "clientRefererScheme": "unknown",
      "clientRequestHTTPHost": "domain.com",
      "clientRequestHTTPMethodName": "GET",
      "clientRequestHTTPProtocol": "HTTP/1.1",
      "clientRequestPath": "/wp-login.php",
      "clientRequestQuery": "",
      "clientRequestScheme": "https",
      "datetime": "2021-03-30T07:19:47Z",
      "edgeColoName": "SJC",
      "edgeResponseStatus": 403,
      "kind": "firewall",
      "originResponseStatus": 0,
      "rayName": "637f925cbec96d7c",
      "ruleId": "bd706145258349c686ddb32b94dxxxxx",
      "source": "firewallrules",
      "userAgent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)"
    }
  ]
}
```

## Example Cloudflare Firewall GraphQL Multiple IP Addresses Filter

Querying the Cloudflare Firewall GraphQL API filtering multiple IP addresses in comma separated list on command line `119.92.185.135,92.97.221.160` for past 24hrs for Firewall events with action = `block`

```
./cf-analytics-graphql.sh ip-hrs 24 119.92.185.135,92.97.221.160 block



{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_ASC]
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
    }",
  
    "variables": {
      "zoneTag": "zoneid",
      "limit": 100,
      "filter": {
        "clientIP_in": ["119.92.185.135","92.97.221.160"],
        "action": "block",
        
        "datetime_geq": "2021-03-29T09:43:34Z",
        "datetime_leq": "2021-03-30T09:43:34Z"
      }
    }
  }

------------------------------------------------------------------
Cloudflare Firewall
------------------------------------------------------------------
since: 2021-03-29T09:43:34Z
until: 2021-03-30T09:43:34Z
------------------------------------------------------------------
2 Firewall Events for Request IP: "119.92.185.135","92.97.221.160"
------------------------------------------------------------------
      1 92.97.221.160 403 2xMachine Learning block 5384 EMIRATES-INTERNET Emirates Internet AE AMS GET HTTP/1.1 bd706145258349c686ddb32b94dxxxxx
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC GET HTTP/1.1 bd706145258349c686ddb32b94dxxxxx
------------------------------------------------------------------
      1 92.97.221.160 403 2xMachine Learning block 5384 EMIRATES-INTERNET Emirates Internet AE AMS GET HTTP/1.1
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC GET HTTP/1.1
------------------------------------------------------------------
      1 92.97.221.160 403 2xMachine Learning block 5384 EMIRATES-INTERNET Emirates Internet AE AMS domain.com GET HTTP/1.1
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC domain.com GET HTTP/1.1
------------------------------------------------------------------
      1 92.97.221.160 403 2xMachine Learning block 5384 EMIRATES-INTERNET Emirates Internet AE AMS domain.com GET HTTP/1.1 /wp-login.php 
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC domain.com GET HTTP/1.1 /wp-login.php 
------------------------------------------------------------------
92.97.221.160 637f7b964f7bc765 403 2xMachine Learning block 5384 EMIRATES-INTERNET Emirates Internet AE AMS 2021-03-30T07:04:15Z domain.com GET HTTP/1.1 /wp-login.php 
119.92.185.135 637f925cbec96d7c 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC 2021-03-30T07:19:47Z domain.com GET HTTP/1.1 /wp-login.php 
------------------------------------------------------------------
{
  "results": [
    {
      "action": "block",
      "botScore": 2,
      "botScoreSrcName": "Machine Learning",
      "clientASNDescription": "EMIRATES-INTERNET Emirates Internet",
      "clientAsn": "5384",
      "clientCountryName": "AE",
      "clientIP": "92.97.221.160",
      "clientRefererHost": "",
      "clientRefererPath": "",
      "clientRefererQuery": "",
      "clientRefererScheme": "unknown",
      "clientRequestHTTPHost": "domain.com",
      "clientRequestHTTPMethodName": "GET",
      "clientRequestHTTPProtocol": "HTTP/1.1",
      "clientRequestPath": "/wp-login.php",
      "clientRequestQuery": "",
      "clientRequestScheme": "https",
      "datetime": "2021-03-30T07:04:15Z",
      "edgeColoName": "AMS",
      "edgeResponseStatus": 403,
      "kind": "firewall",
      "originResponseStatus": 0,
      "rayName": "637f7b964f7bc765",
      "ruleId": "bd706145258349c686ddb32b94dxxxxx",
      "source": "firewallrules",
      "userAgent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)"
    },
    {
      "action": "block",
      "botScore": 1,
      "botScoreSrcName": "Heuristics",
      "clientASNDescription": "IPG-AS-AP Philippine Long Distance Telephone Company",
      "clientAsn": "9299",
      "clientCountryName": "PH",
      "clientIP": "119.92.185.135",
      "clientRefererHost": "",
      "clientRefererPath": "",
      "clientRefererQuery": "",
      "clientRefererScheme": "unknown",
      "clientRequestHTTPHost": "domain.com",
      "clientRequestHTTPMethodName": "GET",
      "clientRequestHTTPProtocol": "HTTP/1.1",
      "clientRequestPath": "/wp-login.php",
      "clientRequestQuery": "",
      "clientRequestScheme": "https",
      "datetime": "2021-03-30T07:19:47Z",
      "edgeColoName": "SJC",
      "edgeResponseStatus": 403,
      "kind": "firewall",
      "originResponseStatus": 0,
      "rayName": "637f925cbec96d7c",
      "ruleId": "bd706145258349c686ddb32b94dxxxxx",
      "source": "firewallrules",
      "userAgent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)"
    }
  ]
}
```

## Example Cloudflare Firewall GraphQL RayId Address Filter

Querying the Cloudflare Firewall GraphQL API filtering by RayId `637f925cbec96d7c` for past 24hrs for Firewall events with action = `block`

```
./cf-analytics-graphql.sh rayid-hrs 24 637f925cbec96d7c block



{ "query":
    "query {
      viewer {
        zones(filter: {zoneTag: $zoneTag}) {
          firewallEventsAdaptiveGroups(
            limit: $limit,
            filter: $filter,
            orderBy: [datetime_ASC]
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
    }",
  
    "variables": {
      "zoneTag": "zoneid",
      "limit": 100,
      "filter": {
        "rayName": "637f925cbec96d7c",
        "action": "block",
        
        "datetime_geq": "2021-03-29T09:40:25Z",
        "datetime_leq": "2021-03-30T09:40:25Z"
      }
    }
  }

------------------------------------------------------------------
Cloudflare Firewall
------------------------------------------------------------------
since: 2021-03-29T09:40:25Z
until: 2021-03-30T09:40:25Z
------------------------------------------------------------------
1 Firewall Events for CF RayID: 637f925cbec96d7c
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC GET HTTP/1.1 bd706145258349c686ddb32b94dxxxxx
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC GET HTTP/1.1
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC domain.com GET HTTP/1.1
------------------------------------------------------------------
      1 119.92.185.135 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC domain.com GET HTTP/1.1 /wp-login.php 
------------------------------------------------------------------
119.92.185.135 637f925cbec96d7c 403 1xHeuristics block 9299 IPG-AS-AP Philippine Long Distance Telephone Company PH SJC 2021-03-30T07:19:47Z domain.com GET HTTP/1.1 /wp-login.php 
------------------------------------------------------------------
{
  "results": [
    {
      "action": "block",
      "botScore": 1,
      "botScoreSrcName": "Heuristics",
      "clientASNDescription": "IPG-AS-AP Philippine Long Distance Telephone Company",
      "clientAsn": "9299",
      "clientCountryName": "PH",
      "clientIP": "119.92.185.135",
      "clientRefererHost": "",
      "clientRefererPath": "",
      "clientRefererQuery": "",
      "clientRefererScheme": "unknown",
      "clientRequestHTTPHost": "domain.com",
      "clientRequestHTTPMethodName": "GET",
      "clientRequestHTTPProtocol": "HTTP/1.1",
      "clientRequestPath": "/wp-login.php",
      "clientRequestQuery": "",
      "clientRequestScheme": "https",
      "datetime": "2021-03-30T07:19:47Z",
      "edgeColoName": "SJC",
      "edgeResponseStatus": 403,
      "kind": "firewall",
      "originResponseStatus": 0,
      "rayName": "637f925cbec96d7c",
      "ruleId": "bd706145258349c686ddb32b94dxxxxx",
      "source": "firewallrules",
      "userAgent": "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)"
    }
  ]
}
```

# Cloudflare Zone Analytics API Script (deprecated)

This Cloudflare Zone Analytics API script, `cf-analytics.sh` is now deprecated due to Cloudflare switching Zone analytics API to the new Cloudflare GraphQL API. This script supports both traditional Cloudflare Global API Token authentication (`CF_GLOBAL_TOKEN='y'`) and newer non-global Cloudflare permission based API Token authentication (`CF_GLOBAL_TOKEN='n'`) which is currently in beta testing. The `cf-analytics.sh` script is currently default to `CF_GLOBAL_TOKEN='n'` for testing purposes.

If you have Cloudflare Argo enabled on your CF zone, also set `CF_ARGO='y'` - currently enabled by default for testing purposes.

## Usage

```
export zid=YOUR_CLOUDFLARE_DOMAIN_ZONE_ID
export cfkey=YOUR_CLOUDFLARE_API_KEY
export cfemail=YOUR_CLOUDFLARE_ACCOUNT_EMAIL
```

```
./cf-analytics.sh 
./cf-analytics.sh {6hrs|12hrs|24hrs|week|month|custom}
```

```
./cf-analytics.sh 24hrs                  
------------------------------------------------------------------
  Cloudflare Argo Analytics
------------------------------------------------------------------
  since: 2019-05-14T08:25:00Z
  until: 2019-05-16T08:25:00Z
------------------------------------------------------------------
  Argo Response Time:
------------------------------------------------------------------
  request-without-argo: 12444
  request-with-argo: 112867
  argo-smarted-routed: 86.9%
  argo-improvement: 60.3600%
  without-argo: 391 (milliseconds)
  with-argo 155 (milliseconds)
------------------------------------------------------------------
  Argo Cloudflare Datacenter Response Times
------------------------------------------------------------------
  ATL  27726  0.6412169622075149   332.2533929162529   119.20688162735338
  IAD  20332  0.637232322143707    325.6395870736086   118.13151682077513
  FRA  12189  0.5799126291327171   456.80453879941433  191.89781770448766
  AMS  11529  0.5992252513882197   449.694421657096    180.22616879174257
  SEA  7162   0.40508913312922673  115.13461538461539  68.49483384529461
  CDG  3421   0.6144501422449614   516.3040345821325   199.06094709149372
  SIN  3294   0.5962180930008604   595.7072829131653   240.53582270795386
  LHR  2993   0.607285979424051    495.1811594202899   194.46458402940195
  KBP  2628   0.630100508063133    664.1783216783217   245.67922374429224
  EWR  2165   0.5481618158546426   301.8181818181818   136.3729792147806
  HKG  1858   0.5351932505240897   481.1136363636364   223.6248654467169
  ARN  1776   0.5904696408044352   523.052995391705    214.2060810810811
  NRT  1719   0.5622481824455847   371.9059405940594   162.8025014543339
  YVR  1579   0.47559111222426925  143.32914572864323  75.16307789740343
  DME  1438   0.6299202921502316   715.1506024096385   264.6627260083449
  MIA  1396   0.5052764125545139   274.3493150684931   135.72707736389685
  AKL  1229   0.47349360130316764  678.6486486486486   357.3128559804719
  GRU  1228   0.5791630868985488   727.2328244274809   306.0464169381107
  DUB  1085   0.7477442456057896   723.125             182.41244239631337
  MUC  958    0.5202992390439672   476.3429752066116   228.50208768267223
  ORD  827    0.5596108552294217   200.08823529411765  88.11668681983072
  ATH  646    0.6528382488219177   682.1794871794872   236.8266253869969
  HAM  645    0.3746478854738678   347.1470588235294   217.0891472868217
  LED  624    0.5968830264246223   589                 237.43589743589743
  SJC  538    0.5174183945246018   384.4718309859155   185.53903345724908
  DFW  537    0.49549020899323587  166.60714285714286  84.05493482309124
  MXP  496    0.6310643720804437   537.8921568627451   198.44758064516128
  BUD  496    0.6345091268874329   590.5392156862745   215.8366935483871
  LAX  480    0.33667051911778867  163.25471698113208  108.29166666666667
  total-argo-reqs: 112994
  datacenter-calc-avg-resp-without: 391.3434
  datacenter-calc-avg-resp-with: 155.0828
  argo-improvement:
      min: 0.3367
      avg: 0.5613
      max: 0.7477
      stddev: 0.0890
  argo-resp-time-without-argo:
      min: 115.1346
      avg: 449.2464
      max: 727.2328
      stddev: 187.9968
  argo-resp-time-with-argo:
      min: 68.4948
      avg: 186.7645
      max: 357.3129
      stddev: 69.3717

------------------------------------------------------------------
  Cloudflare Zone Analytics
------------------------------------------------------------------
  since: 2019-05-15T08:00:00Z
  until: 2019-05-16T08:00:00Z
------------------------------------------------------------------
  Requests:
------------------------------------------------------------------
  requests all: 210786
  requests cached: 121962
  requests uncached: 88824
  requests ssl-encrypted: 192936
  requests ssl-unencrypted: 17850

------------------------------------------------------------------
  Pageviews:
------------------------------------------------------------------
  "all": 68410,
  "search_engine": 
    "applebot": 48,
    "baiduspider": 59,
    "bingbot": 3425,
    "duckduckgobot": 16,
    "facebookexternalhit": 32,
    "googlebot": 8782,
    "twitterbot": 21,
    "yandexbot": 191

------------------------------------------------------------------
  Requests HTTP Status Codes:
------------------------------------------------------------------
  "200": 158097,
  "206": 56,
  "301": 5664,
  "302": 16122,
  "303": 20509,
  "304": 3239,
  "307": 2725,
  "400": 6,
  "401": 48,
  "403": 1122,
  "404": 2213,
  "405": 31,
  "416": 20,
  "499": 836,
  "500": 49,
  "520": 30,
  "521": 4,
  "522": 13,
  "524": 2

------------------------------------------------------------------
  Requests SSL Protocols:
------------------------------------------------------------------
  "TLSv1.2": 107921,
  "TLSv1.3": 85015,
  "none": 17850

------------------------------------------------------------------
  Requests Content Types:
------------------------------------------------------------------
  "css": 11045,
  "empty": 4068,
  "gif": 1601,
  "html": 116691,
  "javascript": 32455,
  "jpeg": 3845,
  "json": 2687,
  "octet-stream": 687,
  "other": 7722,
  "plain": 541,
  "png": 17120,
  "svg": 16,
  "webp": 10769,
  "xml": 1539

------------------------------------------------------------------
  Requests IP Class:
------------------------------------------------------------------
  "backupService": 8,
  "badHost": 266,
  "monitoringService": 1187,
  "noRecord": 164488,
  "searchEngine": 26197,
  "tor": 36,
  "unknown": 17720,
  "whitelist": 884

------------------------------------------------------------------
  Requests Country Top 20:
------------------------------------------------------------------
  "US": 75093
  "DE": 25898
  "FR": 12666
  "GB": 9121
  "IN": 8321
  "NL": 6328
  "AU": 6125
  "JP": 5803
  "SG": 5646
  "CN": 4989
  "RU": 4236
  "VN": 3769
  "BR": 3207
  "IT": 2620
  "UA": 2540
  "ID": 2433
  "CA": 2113
  "IE": 1946
  "ES": 1822
  "PL": 1702

------------------------------------------------------------------
  Bandwidth:
------------------------------------------------------------------
  bandwidth all: 3965159403
  bandwidth cached: 2828614040
  bandwidth uncached: 1136545363
  bandwidth ssl-encrypted: 3942345957
  bandwidth ssl-unencrypted: 22813446

------------------------------------------------------------------
  Bandwidth SSL Protocols:
------------------------------------------------------------------
  "TLSv1.2": 107921,
  "TLSv1.3": 85015,
  "none": 17850

------------------------------------------------------------------
  Bandwidth Content Types:
------------------------------------------------------------------
  "css": 110432021,
  "empty": 1613685,
  "gif": 23706010,
  "html": 1378194797,
  "javascript": 383366648,
  "jpeg": 22221380,
  "json": 3169046,
  "octet-stream": 1421601743,
  "other": 318212843,
  "plain": 7690615,
  "png": 179223248,
  "svg": 444479,
  "webp": 82602938,
  "xml": 32679950

------------------------------------------------------------------
  Bandwidth Country Top 20:
------------------------------------------------------------------
  "US": 1170533462
  "DE": 546377403
  "SG": 339702426
  "CA": 194209335
  "FR": 160271949
  "GB": 149483971
  "RU": 149136945
  "JP": 138803647
  "CN": 116845836
  "VN": 114655733
  "NL": 100682606
  "IN": 89108683
  "UA": 76885477
  "AU": 75727230
  "XX": 56446705
  "IT": 53701367
  "ID": 43347263
  "BR": 32500156
  "IE": 26437821
  "ES": 23383311

------------------------------------------------------------------
  Threats:
------------------------------------------------------------------
  "all": 59,
  "type": 
    "bic.ban.unknown": 59
  ,
  "country": 
    "BG": 1,
    "CA": 4,
    "DE": 1,
    "ES": 1,
    "PL": 1,
    "RO": 3,
    "UA": 46,
    "US": 2
```
