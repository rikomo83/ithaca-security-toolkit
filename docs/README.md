# Ithaca Security Toolkit

Version: **1.0.0**

Toolkit interno per l'inventory, l'hardening e il Security Assessment dei server Ubuntu di ITHACA.

---

# Obiettivi

- Inventario completo del server
- Verifica della sicurezza
- Controllo dei servizi principali
- Report automatici
- Baseline riutilizzabile su tutti i server Ubuntu

---

# Componenti

| Componente | Descrizione |
|------------|-------------|
| `ithaca-check` | Security Assessment del server |
| `ithaca-inventory` | Inventario completo hardware e software |
| `config/ithaca.conf` | Configurazione centralizzata |
| `modules/` | Moduli di verifica |
| `reports/` | Report generati automaticamente |
| `docs/` | Documentazione |

---

# Comandi principali

```bash
sudo ithaca-check

sudo ithaca-inventory
```

---

# Security Score

| Score | Stato |
|-------:|-------|
| 100/100 | Server conforme alla baseline |
| 90-99 | Ottimo |
| 80-89 | Buono |
| <80 | Richiede interventi |

---

# Struttura del progetto

```text
/opt/ithaca-security
│
├── bin/
├── config/
├── modules/
├── lib/
├── reports/
├── logs/
├── backups/
└── docs/
```

---

# Installazione

Il toolkit viene installato in:

```text
/opt/ithaca-security
```

Comandi globali:

```text
/usr/local/sbin/ithaca-check
/usr/local/sbin/ithaca-inventory
```

---

# Versione

Consultare il file:

```text
/opt/ithaca-security/VERSION
```

---

# Licenza

Toolkit interno ITHACA.
