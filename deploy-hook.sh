#!/bin/sh
set -eu

LE_DIR=/etc/letsencrypt

if [ "${GENERATE_DHPARAMS:-0}" = "1" ]; then
  DHPARAMS_PEM=${LE_DIR}/dhparams.pem
  [ -e "${DHPARAMS_PEM}" ] || openssl dhparam -out ${DHPARAMS_PEM} 2048
fi

cp ${LE_DIR}/live/${SERVER_HOSTNAME}/privkey.pem   ${LE_DIR}/live/privkey.pem
cp ${LE_DIR}/live/${SERVER_HOSTNAME}/fullchain.pem ${LE_DIR}/live/fullchain.pem

if [ -n "${RELOAD_SERVICES:-}" ]; then
  /docker-reload.py ${RELOAD_SERVICES}
fi
