# Changelog

## v1.0.0 - 2026-07-09

### Added
- Struttura base `/opt/ithaca-security`
- Configurazione centralizzata `ithaca.conf`
- Script `ithaca-inventory`
- Script modulare `ithaca-check`
- Moduli:
  - system
  - firewall
  - fail2ban
  - ssh
  - apache
  - tls
  - postgres
  - geoserver
  - azurearc
  - certs
- Report automatici in `/opt/ithaca-security/reports`
- Symlink globali in `/usr/local/sbin`

### Security baseline
- UFW attivo
- Fail2Ban attivo
- SSH hardening
- Apache hardening
- TLS 1.2/1.3 OK
- TLS 1.0 bloccato
- PostgreSQL solo localhost
