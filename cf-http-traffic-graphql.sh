#!/bin/bash 
# Cloudflare HTTP Traffic Analytics Script
# dnf install -y pandoc texlive-scheme-basic texlive-xetex

DEBUG='y'
CF_GLOBAL_TOKEN='y'
ENDPOINT='https://api.cloudflare.com/client/v4/graphql'
JSON_OUTPUT_DIR='/home/cf-graphql-json-output'
HTML_OUTPUT_DIR='/home/cf-graphql-html-output'
PDF_OUTPUT_DIR='/home/cf-graphql-pdf-output'
CHART_OUTPUT_DIR='/home/cf-graphql-chart-output'

SCRIPT_DIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))

if [ -f "${SCRIPT_DIR}/cf-analytics-graphql.ini" ]; then
  source "${SCRIPT_DIR}/cf-analytics-graphql.ini"
fi

if [[ "$JSON_OUTPUT_SAVE" = [yY] && ! -d "$JSON_OUTPUT_DIR" ]]; then
  mkdir -p "$JSON_OUTPUT_DIR"
fi

# Function to query Cloudflare HTTP analytics
http_traffic_analytics() {
  local since=$1
  local input_limit=${2:-10000}

  END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  START_TIME=$(date -u -d "${since} hours ago" +"%Y-%m-%dT%H:%M:%SZ")

  QUERY=$(cat <<EOF
{
  "query": "query { 
    viewer { 
      zones(filter: {zoneTag: \"${zid}\"}) { 
        httpRequests1hGroups(
          limit: ${input_limit},
          filter: {
            datetime_geq: \"${START_TIME}\",
            datetime_leq: \"${END_TIME}\"
          }
        ) { 
          dimensions { 
            datetime
          } 
          sum {
            browserMap { 
              pageViews
              uaBrowserFamily
            }
            bytes
            cachedBytes
            cachedRequests
            clientHTTPVersionMap {
              clientHTTPProtocol
              requests
            }
            clientSSLMap {
              clientSSLProtocol
              requests
            }
            contentTypeMap {
              bytes
              edgeResponseContentTypeName
              requests
            }
            countryMap {
              bytes
              clientCountryName
              requests
              threats
            }
            encryptedBytes
            encryptedRequests
            pageViews
            requests
            responseStatusMap {
              edgeResponseStatus
              requests
            }
            threats
          }
        }
      } 
    }
  }"
}
EOF
)

  JSON_OUTPUT_FILE="$JSON_OUTPUT_DIR/cf-graphql-http-traffic.json"
  
  if [[ "$CF_GLOBAL_TOKEN" = [yY] ]]; then
    curl -s -X POST \
      -H "X-Auth-Email: ${cfemail}" \
      -H "X-Auth-Key: ${cfkey}" \
      -H "Content-Type: application/json" \
      https://api.cloudflare.com/client/v4/graphql \
      --data "$(echo $QUERY | tr -d '\n')" > "$JSON_OUTPUT_FILE"
  else
    curl -s -X POST \
      -H "Authorization: Bearer ${cfkey}" \
      -H "Content-Type: application/json" \
      https://api.cloudflare.com/client/v4/graphql \
      --data "$(echo $QUERY | tr -d '\n')" > "$JSON_OUTPUT_FILE"
  fi

  if [ -f "$JSON_OUTPUT_FILE" ]; then
    echo "JSON log saved: $JSON_OUTPUT_FILE"
    if [[ "$DEBUG" = [yY] ]]; then
      cat "$JSON_OUTPUT_FILE" | jq
    fi
  fi
}

# Function to generate HTML report
generate_html_report() {
    local json_file=$1
    local html_output_file="$HTML_OUTPUT_DIR/cf-http-traffic-report.html"

    if ! command -v python3 &> /dev/null; then
        echo "Python3 could not be found. Please install it to generate HTML report."
        return 1
    fi

    mkdir -p "$HTML_OUTPUT_DIR"
    mkdir -p "$HTML_OUTPUT_DIR/images"

    python3 <<EOF
import json
import os
from datetime import datetime
import matplotlib.pyplot as plt

try:
    with open("$json_file") as f:
        data = json.load(f)

    if not data or 'data' not in data or not data['data']:
        raise ValueError("No data found in JSON response")

    # Extract data from the most recent entry
    latest_data = data['data']['viewer']['zones'][0]['httpRequests1hGroups'][0]['sum']
    
    # Create browser distribution chart
    browser_data = sorted(latest_data['browserMap'], 
                         key=lambda x: x['pageViews'], 
                         reverse=True)[:10]
    browsers = [b['uaBrowserFamily'] for b in browser_data]
    pageviews = [b['pageViews'] for b in browser_data]
    
    plt.figure(figsize=(12, 6))
    plt.bar(browsers, pageviews, color='#2196F3')
    plt.xticks(rotation=45, ha='right')
    plt.title('Top 10 Browsers by Page Views')
    plt.ylabel('Page Views')
    plt.grid(True, axis='y', linestyle='--', alpha=0.7)
    plt.tight_layout()
    browser_chart = os.path.join("$HTML_OUTPUT_DIR/images", "browser_distribution.png")
    plt.savefig(browser_chart, dpi=300, bbox_inches='tight')
    plt.close()

    # Create HTTP version distribution chart
    http_data = latest_data['clientHTTPVersionMap']
    http_versions = [v['clientHTTPProtocol'] for v in http_data]
    http_requests = [v['requests'] for v in http_data]
    
    plt.figure(figsize=(8, 8))
    plt.pie(http_requests, labels=http_versions, autopct='%1.1f%%', 
            colors=['#2196F3', '#4CAF50', '#FFC107', '#F44336'])
    plt.title('HTTP Version Distribution')
    plt.axis('equal')
    http_chart = os.path.join("$HTML_OUTPUT_DIR/images", "http_versions.png")
    plt.savefig(http_chart, dpi=300, bbox_inches='tight')
    plt.close()

    # Create country traffic chart
    country_data = sorted(latest_data['countryMap'], 
                         key=lambda x: x['requests'], 
                         reverse=True)[:10]
    countries = [c['clientCountryName'] for c in country_data]
    country_requests = [c['requests'] for c in country_data]
    
    plt.figure(figsize=(12, 6))
    plt.bar(countries, country_requests, color='#4CAF50')
    plt.xticks(rotation=45, ha='right')
    plt.title('Top 10 Countries by Traffic')
    plt.ylabel('Requests')
    plt.grid(True, axis='y', linestyle='--', alpha=0.7)
    plt.tight_layout()
    country_chart = os.path.join("$HTML_OUTPUT_DIR/images", "country_distribution.png")
    plt.savefig(country_chart, dpi=300, bbox_inches='tight')
    plt.close()

    # Traffic composition chart
    plt.figure(figsize=(8, 8))
    labels = ['Cached', 'HTTPS', 'Normal']
    sizes = [
        latest_data['cachedRequests'],
        latest_data['encryptedRequests'],
        latest_data['requests'] - latest_data['cachedRequests']
    ]
    colors = ['#2ecc71', '#3498db', '#95a5a6']
    plt.pie(sizes, labels=labels, colors=colors, autopct='%1.1f%%')
    plt.title('Traffic Composition')
    plt.axis('equal')
    traffic_chart = os.path.join("$HTML_OUTPUT_DIR/images", "traffic_composition.png")
    plt.savefig(traffic_chart, dpi=300, bbox_inches='tight')
    plt.close()

    html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>Cloudflare Traffic Analytics Report</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        :root {{
            --primary-color: #2196F3;
            --secondary-color: #1a73e8;
            --background-color: #f0f2f5;
            --box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            --border-radius: 8px;
            --spacing-unit: 20px;
        }}
        
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}
        
        body {{ 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            background: var(--background-color);
            padding: var(--spacing-unit);
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            width: 100%;
        }}
        
        .header {{ 
            text-align: center; 
            margin-bottom: var(--spacing-unit);
            padding: var(--spacing-unit);
            background: white;
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
        }}
        
        .header h1 {{
            color: var(--secondary-color);
            font-size: clamp(1.5rem, 4vw, 2.5rem);
            margin-bottom: 0.5rem;
        }}
        
        .header p {{
            color: #666;
            font-size: clamp(0.875rem, 2vw, 1rem);
        }}
        
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: var(--spacing-unit);
            margin-bottom: var(--spacing-unit);
        }}
        
        .stat-box {{ 
            padding: var(--spacing-unit);
            background: white;
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
        }}
        
        .stat-box h3 {{
            font-size: clamp(1rem, 2.5vw, 1.25rem);
            color: #333;
            margin-bottom: 0.5rem;
        }}
        
        .stat-value {{ 
            font-size: clamp(1.5rem, 4vw, 2rem);
            font-weight: bold; 
            color: var(--primary-color);
        }}
        
        .section {{ 
            margin: var(--spacing-unit) 0;
            padding: var(--spacing-unit);
            background: white;
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
        }}
        
        .section h2 {{
            color: var(--secondary-color);
            font-size: clamp(1.25rem, 3vw, 1.75rem);
            margin-bottom: var(--spacing-unit);
        }}
        
        .chart-container {{
            width: 100%;
            overflow-x: auto;
            margin: var(--spacing-unit) 0;
        }}
        
        img {{ 
            max-width: 100%; 
            height: auto; 
            display: block;
            margin: 0 auto;
            border-radius: var(--border-radius);
        }}
        
        .table-container {{
            width: 100%;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            margin: var(--spacing-unit) 0;
            background: white;
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
        }}
        
        table {{ 
            width: 100%;
            border-collapse: collapse;
            background: white;
            min-width: 600px;
        }}
        
        th, td {{ 
            padding: 12px; 
            border: 1px solid #dee2e6; 
            text-align: left;
            font-size: clamp(0.875rem, 2vw, 1rem);
        }}
        
        th {{ 
            background: #f8f9fa;
            position: sticky;
            top: 0;
            z-index: 10;
        }}
        
        @media (max-width: 768px) {{
            :root {{
                --spacing-unit: 16px;
            }}
            
            body {{
                padding: 12px;
            }}
            
            .stats-grid {{
                gap: 12px;
            }}
            
            .stat-box {{
                padding: 16px;
            }}
            
            .section {{
                padding: 16px;
            }}
            
            .chart-container {{
                margin: 16px 0;
            }}
        }}
        
        @media (max-width: 480px) {{
            .header {{
                padding: 16px;
            }}
            
            .stats-grid {{
                grid-template-columns: 1fr;
            }}
            
            .chart-container {{
                margin: 12px -16px;
                padding: 0 16px;
            }}
            
            .table-container {{
                margin: 12px -16px;
                border-radius: 0;
            }}
        }}

        @media print {{
            body {{
                background: white;
                padding: 0;
            }}
            
            .container {{
                max-width: none;
            }}
            
            .section, .stat-box, .header {{
                box-shadow: none;
                break-inside: avoid;
            }}
            
            .chart-container img {{
                max-width: 100%;
                height: auto;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Cloudflare Traffic Analytics Report</h1>
            <p>Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
        </div>

        <div class="stats-grid">
            <div class="stat-box">
                <h3>Total Requests</h3>
                <div class="stat-value">{latest_data['requests']:,}</div>
            </div>
            <div class="stat-box">
                <h3>Total Traffic</h3>
                <div class="stat-value">{latest_data['bytes']/1024/1024:.2f} MB</div>
            </div>
            <div class="stat-box">
                <h3>Cache Hit Ratio</h3>
                <div class="stat-value">{(latest_data['cachedRequests'] / latest_data['requests'] * 100 if latest_data['requests'] > 0 else 0):.1f}%</div>
            </div>
            <div class="stat-box">
                <h3>HTTPS Ratio</h3>
                <div class="stat-value">{(latest_data['encryptedRequests'] / latest_data['requests'] * 100 if latest_data['requests'] > 0 else 0):.1f}%</div>
            </div>
            <div class="stat-box">
                <h3>Security Threats</h3>
                <div class="stat-value">{latest_data['threats']:,}</div>
            </div>
            <div class="stat-box">
                <h3>Page Views</h3>
                <div class="stat-value">{latest_data['pageViews']:,}</div>
            </div>
        </div>

        <div class="section">
            <h2>Browser Distribution</h2>
            <div class="chart-container">
                <img src="images/browser_distribution.png" alt="Browser Distribution">
            </div>
        </div>

        <div class="section">
            <h2>HTTP Version Distribution</h2>
            <div class="chart-container">
                <img src="images/http_versions.png" alt="HTTP Version Distribution">
            </div>
        </div>

        <div class="section">
            <h2>Top 10 Countries by Traffic</h2>
            <div class="chart-container">
                <img src="images/country_distribution.png" alt="Country Distribution">
            </div>
        </div>

        <div class="section">
            <h2>Traffic Composition</h2>
            <div class="chart-container">
                <img src="images/traffic_composition.png" alt="Traffic Composition">
            </div>
        </div>

        <div class="section">
            <h2>Response Status Codes</h2>
            <div class="table-container">
                <table>
                    <tr>
                        <th>Status Code</th>
                        <th>Requests</th>
                        <th>Percentage</th>
                    </tr>
    """

    for status in latest_data['responseStatusMap']:
        percentage = (status['requests'] / latest_data['requests'] * 100) if latest_data['requests'] > 0 else 0
        html_content += f"""
                    <tr>
                        <td>{status['edgeResponseStatus']}</td>
                        <td>{status['requests']:,}</td>
                        <td>{percentage:.1f}%</td>
                    </tr>
        """

    html_content += """
                </table>
            </div>
        </div>
    </div>
</body>
</html>
    """

    with open("$html_output_file", "w") as f:
        f.write(html_content)

    print(f"HTML report saved: $html_output_file")

except Exception as e:
    print(f"Error generating report: {str(e)}")
    exit(1)
EOF
}

# Main execution
echo "Starting Cloudflare HTTP traffic analysis..."
if http_traffic_analytics 24 10000; then
  generate_html_report "$JSON_OUTPUT_DIR/cf-graphql-http-traffic.json"
fi