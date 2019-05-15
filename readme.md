# Cloudflare Zone Analytics API Script

This Cloudflare Zone Analytics API script supports both traditional Cloufdlare Global API Token authentication (`CF_GLOBAL_TOKEN='y'`) and newer non-global Cloudflare permission based API Token authentication (`CF_GLOBAL_TOKEN='n'`) which is currently in beta testing. The `cf-analytics.sh` script is currently default to `CF_GLOBAL_TOKEN='n'` for testing purposes.

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
  since: 2019-05-13T21:53:00Z
  until: 2019-05-15T02:05:00Z
------------------------------------------------------------------
  Argo Response Time:
------------------------------------------------------------------
  request-without-argo: 4518
  request-with-argo: 40407
  argo-smarted-routed: 85.7%
  argo-improvement: 60.5200%
  without-argo: 385 (milliseconds)
  with-argo 152 (milliseconds)

------------------------------------------------------------------
  Cloudflare Zone Analytics
------------------------------------------------------------------
  since: 2019-05-14T02:00:00Z
  until: 2019-05-15T02:00:00Z
------------------------------------------------------------------
  Requests:
------------------------------------------------------------------
  requests all: 187627
  requests cached: 128129
  requests uncached: 59498
  requests ssl-encrypted: 168823
  requests ssl-unencrypted: 18804

------------------------------------------------------------------
  Pageviews:
------------------------------------------------------------------
  "all": 51941,
  "search_engine": 
    "applebot": 126,
    "baiduspider": 66,
    "bingbot": 2141,
    "duckduckgobot": 18,
    "facebookexternalhit": 41,
    "googlebot": 3789,
    "linkedinbot": 2,
    "twitterbot": 11,
    "yandexbot": 330

------------------------------------------------------------------
  Requests HTTP Status Codes:
------------------------------------------------------------------
  "200": 146370,
  "206": 11,
  "301": 2371,
  "302": 16815,
  "303": 10023,
  "304": 3348,
  "307": 1287,
  "400": 1,
  "401": 48,
  "403": 4702,
  "404": 1299,
  "405": 28,
  "416": 36,
  "499": 1190,
  "500": 48,
  "502": 1,
  "520": 45,
  "521": 3,
  "524": 1

------------------------------------------------------------------
  Requests SSL Protocols:
------------------------------------------------------------------
  "TLSv1.2": 80144,
  "TLSv1.3": 88679,
  "none": 18804

------------------------------------------------------------------
  Requests Content Types:
------------------------------------------------------------------
  "css": 11923,
  "empty": 4525,
  "gif": 1444,
  "html": 88564,
  "javascript": 34935,
  "jpeg": 3951,
  "json": 2664,
  "octet-stream": 799,
  "other": 7139,
  "plain": 599,
  "png": 17984,
  "svg": 11,
  "webp": 11598,
  "xml": 1491

------------------------------------------------------------------
  Requests IP Class:
------------------------------------------------------------------
  "badHost": 242,
  "monitoringService": 1183,
  "noRecord": 154233,
  "searchEngine": 20725,
  "tor": 72,
  "unknown": 10300,
  "whitelist": 872

------------------------------------------------------------------
  Requests Country Top 20:
------------------------------------------------------------------
  "US": 68780
  "DE": 11720
  "GB": 9429
  "IN": 8835
  "AU": 6862
  "CN": 5953
  "JP": 5871
  "NL": 5808
  "FR": 5758
  "SG": 5372
  "RU": 4676
  "BR": 4409
  "VN": 4070
  "UA": 2644
  "ID": 2350
  "ES": 1983
  "CA": 1848
  "XX": 1763
  "PL": 1734
  "IT": 1657

------------------------------------------------------------------
  Bandwidth:
------------------------------------------------------------------
  bandwidth all: 3595946745
  bandwidth cached: 2746769374
  bandwidth uncached: 849177371
  bandwidth ssl-encrypted: 3570669805
  bandwidth ssl-unencrypted: 25276940

------------------------------------------------------------------
  Bandwidth SSL Protocols:
------------------------------------------------------------------
  "TLSv1.2": 80144,
  "TLSv1.3": 88679,
  "none": 18804

------------------------------------------------------------------
  Bandwidth Content Types:
------------------------------------------------------------------
  "css": 123611895,
  "empty": 1621079,
  "gif": 16641629,
  "html": 1050430864,
  "javascript": 409950221,
  "jpeg": 20657369,
  "json": 3022633,
  "octet-stream": 1329457933,
  "other": 334682700,
  "plain": 9850973,
  "png": 181846041,
  "svg": 827119,
  "webp": 88108697,
  "xml": 25237592

------------------------------------------------------------------
  Bandwidth Country Top 20:
------------------------------------------------------------------
  "US": 1095191391
  "DE": 479357144
  "SG": 288633246
  "GB": 158154017
  "RU": 135627248
  "CN": 118224166
  "JP": 111421170
  "VN": 108421088
  "UA": 104634594
  "IN": 93319034
  "AU": 80125082
  "FR": 79563506
  "NL": 63371670
  "RO": 53371299
  "CA": 47859154
  "KR": 45258434
  "XX": 43649461
  "BR": 43097946
  "FI": 37583707
  "BY": 28441850

------------------------------------------------------------------
  Threats:
------------------------------------------------------------------
  "all": 22,
  "type": 
    "bic.ban.unknown": 22
  ,
  "country": 
    "CN": 4,
    "IT": 1,
    "NG": 3,
    "RO": 3,
    "SE": 1,
    "T1": 2,
    "US": 8
```
