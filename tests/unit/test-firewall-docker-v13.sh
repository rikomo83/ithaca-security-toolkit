#!/usr/bin/env bash
set -u

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ITHACA_BASE_DIR="$(cd "$TEST_DIR/../.." && pwd -P)"
export ITHACA_BASE_DIR

source "$ITHACA_BASE_DIR/core/bootstrap.sh"
source "$ITHACA_BASE_DIR/core/runner.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
printf 'IPV6=yes\n' > "$TMP_DIR/ufw-ok"
printf 'IPV6=no\n' > "$TMP_DIR/ufw-no6"
export ITHACA_UFW_DEFAULTS="$TMP_DIR/ufw-ok"

ITHACA_CONFIG_VALUES[HETZNER]="yes"
ITHACA_CONFIG_VALUES[ALLOWED_PUBLIC_PORTS]="80,443"
MOCK_UFW=inactive
MOCK_SWARM_NODES=1
MOCK_DOCKER_USER=empty
MOCK_IPV6=yes
MOCK_SS=haiti

# Profilo simile a un host GeoNode in Docker Swarm a nodo singolo.
ss() {
    case "$MOCK_SS" in
        haiti)
            printf '%s\n' \
                'tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=10,fd=3))' \
                'tcp LISTEN 0 128 [::]:22 [::]:* users:(("sshd",pid=10,fd=4))' \
                'tcp LISTEN 0 4096 *:80 *:* users:(("dockerd",pid=20,fd=30))' \
                'tcp LISTEN 0 4096 *:443 *:* users:(("dockerd",pid=20,fd=31))' \
                'tcp LISTEN 0 4096 0.0.0.0:8884 0.0.0.0:* users:(("docker-proxy",pid=30,fd=4))' \
                'tcp LISTEN 0 4096 0.0.0.0:5432 0.0.0.0:* users:(("docker-proxy",pid=31,fd=4))' \
                'tcp LISTEN 0 4096 *:2377 *:* users:(("dockerd",pid=20,fd=10))' \
                'tcp LISTEN 0 4096 *:7946 *:* users:(("dockerd",pid=20,fd=11))' \
                'udp UNCONN 0 0 *:7946 *:* users:(("dockerd",pid=20,fd=12))' \
                'tcp LISTEN 0 50 0.0.0.0:5938 0.0.0.0:* users:(("teamviewerd",pid=40,fd=5))' \
                'tcp LISTEN 0 50 127.0.0.1:5939 0.0.0.0:* users:(("teamviewerd",pid=40,fd=6))' \
                'udp UNCONN 0 0 127.0.0.53%lo:53 0.0.0.0:* users:(("systemd-resolve",pid=50,fd=13))' \
                'udp UNCONN 0 0 0.0.0.0:68 0.0.0.0:* users:(("dhclient",pid=60,fd=6))'
            ;;
        clean)
            printf '%s\n' \
                'tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=10,fd=3))' \
                'tcp LISTEN 0 4096 *:443 *:* users:(("dockerd",pid=20,fd=31))' \
                'tcp LISTEN 0 4096 127.0.0.1:5432 0.0.0.0:* users:(("docker-proxy",pid=31,fd=4))'
            ;;
    esac
}

systemctl() {
    [[ "${1:-}" == "is-active" && "${3:-}" == "docker" ]]
}

docker() {
    case "${3:-}" in
        '{{.Swarm.LocalNodeState}}') printf 'active\n' ;;
        '{{.Swarm.Nodes}}') printf '%s\n' "$MOCK_SWARM_NODES" ;;
    esac
}

iptables() {
    printf '%s\n' '-N DOCKER-USER'
    if [[ "$MOCK_DOCKER_USER" == rules ]]; then
        printf '%s\n' '-A DOCKER-USER -i eth0 -p tcp --dport 5432 -j DROP'
    fi
    printf '%s\n' '-A DOCKER-USER -j RETURN'
}

ip() {
    [[ "$MOCK_IPV6" == yes ]] && printf '%s\n' '2: eth0    inet6 2a01:4f8:1:2::2/64 scope global'
    return 0
}

ufw() {
    if [[ "$MOCK_UFW" == inactive ]]; then
        printf 'Status: inactive\n'
        return 0
    fi
    printf '%s\n' \
        'Status: active' \
        'Logging: on (low)' \
        'Default: deny (incoming), allow (outgoing), deny (routed)' \
        '' \
        'To                         Action      From' \
        '--                         ------      ----' \
        '22/tcp                     LIMIT IN    Anywhere' \
        '80,443/tcp                 ALLOW IN    Anywhere'
}

ithaca_core_init
source "$ITHACA_BASE_DIR/modules-v12/firewall.sh"
_ithaca_registry_lock

failures=0
fail() { printf 'not ok - %s\n' "$1" >&2; failures=$((failures + 1)); }

# Funzione di appartenenza alle liste di porte.
_ithaca_port_in_list 5434 "5432-5439" || fail "intervallo porte"
_ithaca_port_in_list 443 "22, 80,443" || fail "lista con spazi"
_ithaca_port_in_list 8080 "80,443" && fail "porta fuori lista"
_ithaca_port_in_list abc "80" && fail "porta non numerica"

# Scenario 1: host esposto.
for id in firewall.ufw_rules firewall.exposed_listeners firewall.docker_bypass \
          firewall.swarm_ports firewall.ipv6; do
    _ithaca_run_registered_check_id "$id"
done

[[ "${ITHACA_RESULT_STATUSES[0]}" == SKIP ]] || fail "ufw_rules SKIP con UFW inattivo"
[[ "${ITHACA_RESULT_STATUSES[1]}" == WARN ]] || fail "exposed_listeners WARN"
[[ "${ITHACA_RESULT_DETAILS[1]}" == "tcp/5938 (teamviewerd)" ]] ||
    fail "exposed_listeners elenca solo teamviewerd: ${ITHACA_RESULT_DETAILS[1]}"
[[ "${ITHACA_RESULT_STATUSES[2]}" == CRITICAL ]] || fail "docker_bypass CRITICAL con 5432"
[[ "${ITHACA_RESULT_DETAILS[2]}" == *"tcp/5432 (docker-proxy)"* &&
   "${ITHACA_RESULT_DETAILS[2]}" == *"tcp/8884 (docker-proxy)"* ]] ||
    fail "docker_bypass elenca 5432 e 8884"
[[ "${ITHACA_RESULT_DETAILS[2]}" != *"2377"* ]] || fail "docker_bypass esclude le porte Swarm"
[[ "${ITHACA_RESULT_DETAILS[2]}" == *"DOCKER-USER vuota"* &&
   "${ITHACA_RESULT_DETAILS[2]}" == *"firewall Hetzner"* ]] || fail "docker_bypass nota Hetzner"
[[ "${ITHACA_RESULT_STATUSES[3]}" == WARN &&
   "${ITHACA_RESULT_MESSAGES[3]}" == *"nodo singolo"* ]] || fail "swarm_ports nodo singolo"
[[ "${ITHACA_RESULT_DETAILS[3]}" == *"tcp/2377"* && "${ITHACA_RESULT_DETAILS[3]}" == *"udp/7946"* ]] ||
    fail "swarm_ports elenca 2377 e 7946/udp"
[[ "${ITHACA_RESULT_STATUSES[4]}" == WARN &&
   "${ITHACA_RESULT_DETAILS[4]}" == *"Filter IPv6 packets"* ]] || fail "ipv6 Hetzner non dichiarato"

# Scenario 2: host pulito, UFW attivo, IPv6 filtrato.
_ithaca_results_reset
MOCK_SS=clean
MOCK_UFW=active
MOCK_SWARM_NODES=3
ITHACA_CONFIG_VALUES[HETZNER_FILTER_IPV6]="yes"
for id in firewall.ufw_rules firewall.exposed_listeners firewall.docker_bypass \
          firewall.swarm_ports firewall.ipv6; do
    _ithaca_run_registered_check_id "$id"
done
for i in 0 1 2 3 4; do
    [[ "${ITHACA_RESULT_STATUSES[$i]}" == OK ]] ||
        fail "scenario pulito: risultato $i = ${ITHACA_RESULT_STATUSES[$i]} ${ITHACA_RESULT_MESSAGES[$i]}"
done

# Scenario 3: UFW senza IPv6 e senza Docker.
_ithaca_results_reset
export ITHACA_UFW_DEFAULTS="$TMP_DIR/ufw-no6"
ITHACA_CONFIG_VALUES[DOCKER]="no"
for id in firewall.ufw_rules firewall.docker_bypass firewall.swarm_ports firewall.ipv6; do
    _ithaca_run_registered_check_id "$id"
done
[[ "${ITHACA_RESULT_STATUSES[0]}" == WARN ]] || fail "ufw_rules WARN senza IPV6"
[[ "${ITHACA_RESULT_STATUSES[1]}" == SKIP && "${ITHACA_RESULT_STATUSES[2]}" == SKIP ]] ||
    fail "check Docker in SKIP con DOCKER=no"
[[ "${ITHACA_RESULT_STATUSES[3]}" == WARN ]] || fail "ipv6 WARN con UFW senza IPv6"

if (( failures == 0 )); then
    printf 'ok 1 - riconosce liste e intervalli di porte\n'
    printf 'ok 2 - separa servizi host, porte Docker e porte Swarm\n'
    printf 'ok 3 - segnala porte Docker sensibili che UFW non filtra\n'
    printf 'ok 4 - segnala IPv6 non filtrato e regole UFW incomplete\n'
    printf 'ok 5 - host conforme senza falsi positivi\n'
    printf '5 test superati\n'
    exit 0
fi
exit 1
