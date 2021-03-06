#!/bin/bash

ETH_2_BEACON_URL="${ETH_2_BEACON_URL:-http://beacon:5052}"
ETH_2_ETH1_URL="${ETH_2_ETH1_URL:-http://eth1:8545}"
ETH_2_INTERNAL_PORT="${ETH_2_INTERNAL_PORT:-5025}"
ETH_2_KEYSTORE="${ETH_2_KEYSTORE:-.lighthouse}"
ETH_2_MODULE="${ETH_2_MODULE:-beacon}"
ETH_2_NETWORK="${ETH_2_NETWORK:-pyrmont}"
ETH_2_PASSWORD_FILE="${ETH_2_PASSWORD_FILE:-/run/secrets/password}"

ETH_2_DATADIR="${ETH_2_DATADIR:-/data/lighthouse/$ETH_2_NETWORK}"

echo "Starting Lighthouse in env:"
echo "- ETH_2_BEACON_URL=$ETH_2_BEACON_URL"
echo "- ETH_2_DATADIR=$ETH_2_DATADIR"
echo "- ETH_2_ETH1_URL=$ETH_2_ETH1_URL"
echo "- ETH_2_INTERNAL_PORT=$ETH_2_INTERNAL_PORT"
echo "- ETH_2_KEYSTORE=$ETH_2_KEYSTORE"
echo "- ETH_2_MODULE=$ETH_2_MODULE"
echo "- ETH_2_NETWORK=$ETH_2_NETWORK"
echo "- ETH_2_PASSWORD_FILE=$ETH_2_PASSWORD_FILE"

function waitfor {
  no_proto=${1#*://}
  hostname=${no_proto%%/*}
  echo "waiting for $hostname to wake up..."
  wait-for -q -t 60 "$hostname" 2>&1 | sed '/nc: bad address/d'
}

if [[ "$ETH_2_MODULE" == "beacon" ]]
then
  waitfor "$ETH_2_ETH1_URL"
  echo "Running Lighthouse Beacon"
  exec lighthouse --network "$ETH_2_NETWORK" beacon \
    --datadir="$ETH_2_DATADIR" \
    --eth1-endpoints="$ETH_2_ETH1_URL" \
    --http \
    --http-address="0.0.0.0" \
    --http-allow-origin="*" \
    --http-port="$ETH_2_INTERNAL_PORT"

elif [[ "$ETH_2_MODULE" == "validator" ]]
then

  if [[ ! -f "$ETH_2_PASSWORD_FILE" ]]
  then echo "Password file does not exist at $ETH_2_PASSWORD_FILE, skipping validator import"
  else
    echo "Importing validator accounts from keystore"
    lighthouse --network "$ETH_2_NETWORK" account validator import \
      --datadir="$ETH_2_DATADIR" \
      --validator-dir="$ETH_2_KEYSTORE" \
      --password-file="$ETH_2_PASSWORD_FILE" \
      --reuse-password
  fi
  waitfor "$ETH_2_BEACON_URL"
  echo "Running Lighthouse Validator"
  exec lighthouse --network "$ETH_2_NETWORK" validator \
    --datadir="$ETH_2_DATADIR" \
    --beacon-nodes="$ETH_2_BEACON_URL"

else
  echo "Unknown Lighthouse module: $ETH_2_MODULE"
  exit 1

fi
