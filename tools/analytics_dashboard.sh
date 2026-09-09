#!/usr/bin/env bash
# Installs tools/analytics_dashboard.json as the `settle` dashboard on the shared
# analytics service. Logs in to Authelia with a prompted username and password
# (never stored, never echoed), reads the current revision, PUTs the layout and
# prints the HTTP status and the new revision. A 409 means the dashboard was
# edited in the browser since the GET: run it again.
#
#   tools/analytics_dashboard.sh
#   ANALYTICS_BASE=http://localhost:8789 ANALYTICS_READ_KEY=x tools/analytics_dashboard.sh   # local compose, no login
set -euo pipefail

base="${ANALYTICS_BASE:-https://analytics.jeremyvun.com}"
auth="${AUTHELIA_BASE:-https://auth.jeremyvun.com}"
project="${ANALYTICS_PROJECT:-settle}"
layout="$(cd "$(dirname "$0")" && pwd)/analytics_dashboard.json"
api="$base/ui/api/dashboard?project=$project"

jar="$(mktemp -t settle-dash-XXXXXX)"
trap 'rm -f "$jar"' EXIT

curl_args=(--silent --show-error --cookie "$jar" --cookie-jar "$jar" -H "Origin: $base")
if [[ -n "${ANALYTICS_READ_KEY:-}" ]]; then
  curl_args+=(-H "X-Analytics-Key: $ANALYTICS_READ_KEY")
else
  read -r -p "Authelia username: " username
  read -r -s -p "Authelia password: " password
  echo
  # Credentials travel on stdin only, so they never appear in a process list.
  login="$(printf '%s\n%s' "$username" "$password" | python3 -c '
import json, sys
u = sys.stdin.readline().rstrip("\n")
p = sys.stdin.read()
print(json.dumps({"username": u, "password": p, "keepMeLoggedIn": False}))')"
  unset password
  status="$(curl "${curl_args[@]}" -o /dev/null -w '%{http_code}' \
    -H 'content-type: application/json' --data "$login" "$auth/api/firstfactor")"
  unset login
  if [[ "$status" != "200" ]]; then
    echo "login failed: HTTP $status" >&2
    exit 1
  fi
fi

current="$(curl "${curl_args[@]}" "$api")"
revision="$(printf '%s' "$current" | python3 -c '
import json, sys
body = json.load(sys.stdin)
print(body.get("revision") or 0)')"

payload="$(python3 -c '
import json, sys
print(json.dumps({"config": json.load(open(sys.argv[1])), "revision": int(sys.argv[2])}))' "$layout" "$revision")"

response="$(mktemp -t settle-dash-XXXXXX)"
trap 'rm -f "$jar" "$response"' EXIT
status="$(curl "${curl_args[@]}" -o "$response" -w '%{http_code}' -X PUT \
  -H 'content-type: application/json' --data "$payload" "$api")"
echo "HTTP $status"
if [[ "$status" != "200" ]]; then
  cat "$response" >&2
  echo
  [[ "$status" == "409" ]] && echo "someone saved the dashboard since; run again" >&2
  exit 1
fi
python3 -c '
import json, sys
print("revision", json.load(open(sys.argv[1])).get("revision"))' "$response"
