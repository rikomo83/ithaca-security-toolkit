# Changelog

## v1.2.0-rc.2 "Odyssey" - 2026-09-14

### Added

- Isolamento di ogni check Core API 1 in un processo dedicato.
- Timeout effettivo basato sul valore registrato dal modulo.
- Cattura sicura di stdout e stderr inattesi nei dettagli del risultato.
- Test di regressione per timeout, crash e prosecuzione dei check successivi.

### Changed

- Timeout, crash, risultati non validi e check senza risultato vengono
  convertiti in stato `ERROR` senza interrompere l'audit.
- La terminazione copre l'intero albero dei processi avviati dal check.

## v1.2.0-rc.1 "Odyssey" - 2026-09-14

### Added

- Core API 1 con registro dei check, risultati canonici e runner.
- Moduli v1.2 per system, firewall, fail2ban, SSH, Apache, TLS, PostgreSQL,
  GeoServer, Azure Arc e certificati.
- Discovery sicura dei plugin con validazione di metadati, namespace,
  proprietà e permessi.
- Report JSON atomico con `schema_version: 1`, metadati e durata dei check.
- Suite di test Core, moduli, compatibilità, plugin e reporter.

### Changed

- Il motore v1.2 è ora il percorso predefinito di `ithaca-check`.
- Il report testuale e la formula dello score restano compatibili con Sentinel.

### Compatibility

- Il motore v1.1 Sentinel rimane disponibile con
  `sudo env ITHACA_ENGINE=legacy ithaca-check`.
- Il tag `v1.1.0` resta la baseline per il rollback completo.

## v1.1.0 "Sentinel" - 2026-09-03

### Added

- Baseline Git verificata e report golden del toolkit Sentinel.

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
