#!/bin/sh

set -eu

LE_DIR="/etc/letsencrypt"
LIVE_DIR="${LE_DIR}/live/${SERVER_HOSTNAME}"
ARCHIVE_DIR="${LE_DIR}/archive/${SERVER_HOSTNAME}"
RENEWAL_DIR="${LE_DIR}/renewal"

if [ -e "${LIVE_DIR}/fullchain.pem" ] && [ -e "${LIVE_DIR}/privkey.pem" ]; then
  echo "Reusing existing certificate for ${SERVER_HOSTNAME}!"
  exit 0
fi

mkdir -p "${LIVE_DIR}" "${ARCHIVE_DIR}" "${RENEWAL_DIR}"

san_ips="${SAN_IPS:-${IPV4_NETWORK}.240}"
san_entries=""
i=1
for ip in $san_ips; do
  san_entries="${san_entries}IP.${i} = ${ip}
"
  i=$((i + 1))
done

cat > "${ARCHIVE_DIR}/san.cnf" <<EOF
[ req ]
distinguished_name = dn
req_extensions = req_ext
prompt = no

[ dn ]
CN = ${SERVER_HOSTNAME}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${SERVER_HOSTNAME}
${san_entries}
EOF

openssl ecparam -name prime256v1 -genkey -noout -out "${ARCHIVE_DIR}/privkey1.pem"

SERIAL_HEX="0x$(openssl rand -hex 16)"
if [ -n "${CA_CERT_PATH:-}" ] && [ -n "${CA_KEY_PATH:-}" ]; then
  label="CA-signed"
  openssl req -new \
    -key "${ARCHIVE_DIR}/privkey1.pem" \
    -config "${ARCHIVE_DIR}/san.cnf" \
  | openssl x509 -req \
    -CA "${CA_CERT_PATH}" \
    -CAkey "${CA_KEY_PATH}" \
    -set_serial "${SERIAL_HEX}" \
    -out "${ARCHIVE_DIR}/cert1.pem" \
    -days 365 \
    -sha256 \
    -extfile "${ARCHIVE_DIR}/san.cnf" \
    -extensions req_ext
else
  label="self-signed"
  openssl req -new \
    -key "${ARCHIVE_DIR}/privkey1.pem" \
    -config "${ARCHIVE_DIR}/san.cnf" \
  | openssl x509 -req \
    -signkey "${ARCHIVE_DIR}/privkey1.pem" \
    -set_serial "${SERIAL_HEX}" \
    -out "${ARCHIVE_DIR}/cert1.pem" \
    -days 365 \
    -sha256 \
    -extfile "${ARCHIVE_DIR}/san.cnf" \
    -extensions req_ext
fi

cp "${ARCHIVE_DIR}/cert1.pem" "${ARCHIVE_DIR}/chain1.pem"
cat "${ARCHIVE_DIR}/cert1.pem" "${ARCHIVE_DIR}/chain1.pem" > "${ARCHIVE_DIR}/fullchain1.pem"

ln -sf "../../archive/${SERVER_HOSTNAME}/cert1.pem" "${LIVE_DIR}/cert.pem"
ln -sf "../../archive/${SERVER_HOSTNAME}/chain1.pem" "${LIVE_DIR}/chain.pem"
ln -sf "../../archive/${SERVER_HOSTNAME}/fullchain1.pem" "${LIVE_DIR}/fullchain.pem"
ln -sf "../../archive/${SERVER_HOSTNAME}/privkey1.pem" "${LIVE_DIR}/privkey.pem"

cat <<EOF > "${RENEWAL_DIR}/${SERVER_HOSTNAME}.conf"
# Mock renewal configuration
version = 1.0.0
archive_dir = ${ARCHIVE_DIR}
cert = ${LIVE_DIR}/cert.pem
privkey = ${LIVE_DIR}/privkey.pem
chain = ${LIVE_DIR}/chain.pem
fullchain = ${LIVE_DIR}/fullchain.pem
EOF

echo "Generated ${label} certificate for ${SERVER_HOSTNAME}!"
