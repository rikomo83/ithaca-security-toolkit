# Ithaca Security Toolkit

Version: **1.2.0 “Odyssey”**

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
| `config/ithaca.conf.example` | Modello pubblico della configurazione locale |
| `core/` | Registro, runner, discovery, risultati e reporter |
| `modules-v12/` | Moduli ufficiali Core API 1 |
| `plugins.d/` | Plugin installabili e caricati automaticamente |
| `modules/` | Moduli v1.1 mantenuti per il rollback Sentinel |
| `reports/` | Report generati automaticamente |
| `docs/` | Documentazione |

---

# Comandi principali

```bash
sudo ithaca-check

sudo ithaca-inventory
```

`ithaca-check` usa il motore v1.2 per impostazione predefinita. Per eseguire
temporaneamente il motore v1.1 Sentinel:

```bash
sudo env ITHACA_ENGINE=legacy ithaca-check
```

Le procedure operative complete sono disponibili in
`docs/ROLLBACK-v1.2.md`.

---

# Report

Ogni esecuzione v1.2 genera dalla stessa raccolta di risultati:

- `reports/check-YYYY-MM-DD_HH-MM-SS.txt`, compatibile con Sentinel;
- `reports/check-YYYY-MM-DD_HH-MM-SS.json`, schema versionato `1`;
- i collegamenti `check-latest.txt` e `check-latest.json`.

Il report JSON include run ID, host, versione toolkit, categoria, stato,
messaggio, dettagli e durata dei singoli risultati.

---

# Plugin

I plugin risiedono in `plugins.d/<plugin-id>/`, dichiarano `PLUGIN_API=1` e
registrano i check senza modificare il Core. File, directory, metadati e
namespace vengono validati prima del caricamento. Un plugin non valido viene
escluso e non impedisce l'esecuzione dei moduli ufficiali.

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
├── core/
├── modules/
├── modules-v12/
├── plugins.d/
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

Creare la configurazione locale partendo dal modello pubblico:

```bash
sudo cp config/ithaca.conf.example config/ithaca.conf
sudo chmod 0600 config/ithaca.conf
sudo editor config/ithaca.conf
```

`config/ithaca.conf` non viene tracciato da Git. Valori specifici del server,
indirizzi e altri dati operativi devono rimanere esclusivamente nel file locale.
Se `TLS_IP` non e impostato, i controlli TLS usano il nome di ciascun VirtualHost.

---

# Versione

Consultare il file:

```text
/opt/ithaca-security/VERSION
```

---

# Licenza

Ithaca Security Toolkit e distribuito come software open source secondo i
termini della [Apache License 2.0](../LICENSE).
