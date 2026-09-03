#!/usr/bin/env bash

check_ssh() {
  section "SSH"

  SSHD="$(sshd -T 2>/dev/null || true)"

  echo "$SSHD" | grep -q "^passwordauthentication no" && \
    ok "SSH password disabilitata" || crit "SSH password abilitata"

  echo "$SSHD" | grep -q "^permitrootlogin no" && \
    ok "Root login SSH disabilitato" || crit "Root login SSH abilitato"
}
