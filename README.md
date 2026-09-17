# Ithaca Security Toolkit

[![Odyssey Guard](https://github.com/rikomo83/ithaca-security-toolkit/actions/workflows/odyssey-guard.yml/badge.svg)](https://github.com/rikomo83/ithaca-security-toolkit/actions/workflows/odyssey-guard.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Security assessment, inventory and hardening baseline for Ubuntu servers.
Version **1.2.0 “Odyssey”** provides an isolated check runner, extensible
plugins and atomic text and JSON reports while retaining an explicit rollback
path to the v1.1 Sentinel engine.

## Highlights

- checks for system health, firewall, Fail2Ban, SSH, Apache, TLS, PostgreSQL,
  GeoServer, Azure Arc and certificates;
- isolated execution with enforced timeouts and error containment;
- secure plugin discovery with API and permission validation;
- Sentinel-compatible text output and versioned JSON schema;
- regression tests on Ubuntu 22.04 and Ubuntu 24.04;
- local configuration excluded from version control by design.

## Quick start

The production layout is `/opt/ithaca-security`. Create a private local
configuration from the public example before running an assessment:

```bash
sudo cp config/ithaca.conf.example config/ithaca.conf
sudo chmod 0600 config/ithaca.conf
sudo editor config/ithaca.conf
sudo ithaca-check
```

`config/ithaca.conf` may contain server-specific information and must never be
committed. Review all checks and configuration on a non-production host before
deployment.

## Reports

Each v1.2 run produces matching text and JSON reports under `reports/`, plus
`check-latest.txt` and `check-latest.json` links. The JSON report uses schema
version `1` and includes run metadata, individual result status and duration.

## Documentation

- [Complete usage and architecture overview](docs/README.md)
- [Technical specification](docs/TECHNICAL-SPEC-v1.2.md)
- [Rollback procedure](docs/ROLLBACK-v1.2.md)
- [Changelog](docs/CHANGELOG.md)
- [Security policy](SECURITY.md)
- [Contribution guide](CONTRIBUTING.md)

## Contributing

Contributions are welcome. Run `bash tests/run.sh` before opening a pull
request and follow the security and sanitization requirements in
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the [Apache License 2.0](LICENSE).
