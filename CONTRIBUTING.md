# Contributing

Thank you for helping improve Ithaca Security Toolkit.

## Before you start

- Discuss substantial changes in an issue before implementation.
- Base changes on `master` and keep each pull request focused.
- Never commit credentials, private keys, public production addresses,
  internal hostnames, generated reports or `config/ithaca.conf`.
- Use neutral examples such as `example.com`, `192.0.2.0/24`,
  `198.51.100.0/24` or `203.0.113.0/24`.

## Development workflow

1. Create a feature or fix branch.
2. Implement the smallest coherent change.
3. Add or update tests under `tests/unit/`.
4. Run the complete suite:

   ```bash
   bash tests/run.sh
   ```

5. Confirm the repository contains no private configuration or sensitive
   operational data.
6. Open a pull request and describe behavior, tests and security impact.

Pull requests must pass Odyssey Guard on Ubuntu 22.04 and Ubuntu 24.04 and
must resolve all review conversations before merge.

## Shell conventions

- Target Bash and validate modified scripts with `bash -n`.
- Quote expansions unless intentional word splitting is required.
- Preserve deterministic output and explicit error handling.
- Keep checks isolated and bounded by their registered timeout.
- Do not weaken plugin ownership, permission or namespace validation.

## Security fixes

Do not open a public pull request for an undisclosed vulnerability. Follow
[SECURITY.md](SECURITY.md) so remediation can be coordinated privately.

## License

Unless explicitly stated otherwise, contributions intentionally submitted for
inclusion in this project are provided under the Apache License 2.0, in line
with section 5 of the license.
