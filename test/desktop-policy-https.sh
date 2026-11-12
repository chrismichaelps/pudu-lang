#!/bin/sh
set -eu

if [ "$(uname -s)" != Linux ] || [ "$(id -u)" != 0 ] || [ "${PUDU_POLICY_TEST_TRUST:-}" != 1 ]; then
  echo "HTTPS conformance requires an isolated Linux root test with explicit test trust" >&2
  exit 2
fi
if [ ! -e /.dockerenv ] && [ "${CI:-}" != true ]; then
  echo "HTTPS conformance is limited to containers and CI" >&2
  exit 2
fi
if [ "$#" != 1 ]; then echo "provide the native network executable" >&2; exit 2; fi
scratch=$(mktemp -d /tmp/pudu-policy-tls.XXXXXX)
trusted="/usr/local/share/ca-certificates/$(basename "$scratch").crt"
cleanup() {
  previous=$?
  trap - EXIT
  cleanup_status=0
  if ! rm -f "$trusted"; then cleanup_status=1; fi
  if ! update-ca-certificates >/dev/null 2>&1; then
    echo "could not rebuild the test trust bundle during cleanup" >&2
    cleanup_status=1
  elif [ -f "$scratch/cert.pem" ]; then
    if [ ! -r /etc/ssl/certs/ca-certificates.crt ]; then
      echo "could not verify removal from the test trust bundle" >&2
      cleanup_status=1
    elif openssl verify -no-CApath -no-CAstore -CAfile /etc/ssl/certs/ca-certificates.crt "$scratch/cert.pem" >/dev/null 2>&1; then
      echo "the test certificate remains in the trust bundle" >&2
      cleanup_status=1
    fi
  fi
  if ! rm -rf "$scratch"; then cleanup_status=1; fi
  if [ "$previous" -ne 0 ]; then exit "$previous"; fi
  exit "$cleanup_status"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=Pudu Policy Test' \
  -addext 'subjectAltName=IP:127.0.0.1' -addext 'basicConstraints=critical,CA:TRUE' \
  -keyout "$scratch/key.pem" -out "$scratch/cert.pem" >/dev/null 2>&1
cp "$scratch/cert.pem" "$trusted"
update-ca-certificates >/dev/null 2>&1
openssl verify -no-CApath -no-CAstore -CAfile /etc/ssl/certs/ca-certificates.crt "$scratch/cert.pem" >/dev/null
export PUDU_POLICY_TLS_KEY="$scratch/key.pem" PUDU_POLICY_TLS_CERT="$scratch/cert.pem"
export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 LIBGL_ALWAYS_SOFTWARE=1
xvfb-run -a sh -c 'openbox >/tmp/pudu-https-window-manager.log 2>&1 & node test/desktop-policy-network.mjs "$1" --https' sh "$1"
