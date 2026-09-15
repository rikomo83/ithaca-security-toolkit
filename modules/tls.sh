#!/usr/bin/env bash

check_tls() {
  section "TLS"

  HOSTS=$(apache2ctl -S 2>/dev/null \
    | awk '/port 443 namevhost/ {print $4}' \
    | sort -u)

  if [ -z "$HOSTS" ]; then
    warn "Nessun VirtualHost HTTPS rilevato"
    return
  fi

  for host in $HOSTS; do
    local tls_target="${TLS_IP:-$host}"
    echo "Host: $host"

    if echo | openssl s_client -connect "$tls_target:443" -servername "$host" -tls1_2 >/dev/null 2>&1; then
      ok "$host TLS 1.2 attivo"
    else
      warn "$host TLS 1.2 non verificato"
    fi

    if echo | openssl s_client -connect "$tls_target:443" -servername "$host" -tls1_3 >/dev/null 2>&1; then
      ok "$host TLS 1.3 attivo"
    else
      warn "$host TLS 1.3 non verificato"
    fi

    TMP_TLS1="$(mktemp)"
    echo | openssl s_client -connect "$tls_target:443" -servername "$host" -tls1 >"$TMP_TLS1" 2>&1 || true

    if grep -q "Cipher is (NONE)" "$TMP_TLS1"; then
      ok "$host TLS 1.0 bloccato"
    else
      warn "$host TLS 1.0 potrebbe essere attivo"
    fi

    rm -f "$TMP_TLS1"
    echo ""
  done
}
