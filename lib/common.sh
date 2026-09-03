#!/usr/bin/env bash

source /opt/ithaca-security/lib/colors.sh

SCORE=${SCORE:-100}
WARN=${WARN:-0}
CRIT=${CRIT:-0}

ok() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
    WARN=$((WARN+1))
    SCORE=$((SCORE-3))
}

crit() {
    printf "${RED}✗${NC} %s\n" "$1"
    CRIT=$((CRIT+1))
    SCORE=$((SCORE-10))
}

info() {
    printf "${CYAN}•${NC} %s\n" "$1"
}

section() {
    echo
    printf "${BLUE}${BOLD}====================================================${NC}\n"
    printf "${WHITE}%s${NC}\n" "$1"
    printf "${BLUE}${BOLD}====================================================${NC}\n"
}

clamp_score() {
    (( SCORE < 0 )) && SCORE=0
}
