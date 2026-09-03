# Ithaca Security Toolkit — Specifica tecnica v1.2

**Stato:** proposta pronta per implementazione  
**Baseline compatibile:** v1.1.0 “Sentinel”  
**Target:** Ubuntu Server, installazione predefinita in `/opt/ithaca-security`  
**Entry point stabile:** `ithaca-check`

## 1. Scopo

La versione 1.2 separa il toolkit in tre livelli:

- **Core:** avvio, configurazione, discovery, registro dei check, esecuzione, logging e report.
- **Modules:** controlli ufficiali distribuiti con il toolkit.
- **Plugins:** controlli aggiuntivi installabili senza modificare il Core.

La migrazione deve essere incrementale. In ogni fase `sudo ithaca-check` deve continuare a produrre un risultato equivalente alla v1.1, inclusi conteggi `Warnings`, `Critical`, `Score` e percorso del report testuale.

## 2. Principi architetturali

1. **Compatibilità prima di tutto.** Il comando, i percorsi operativi e l’output umano della v1.1 restano validi durante la migrazione.
2. **Core indipendente dai check.** Il Core non contiene riferimenti ad Apache, TLS, PostgreSQL o altri servizi.
3. **Contratto stabile.** Moduli e plugin comunicano con il Core solo tramite funzioni pubbliche documentate.
4. **Discovery deterministica.** I componenti vengono caricati in ordine prevedibile e validati prima dell’esecuzione.
5. **Failure isolation.** Il guasto di un check non interrompe gli altri check.
6. **Output separato dai dati.** Un check emette risultati strutturati; logger e reporter decidono come rappresentarli.
7. **Sicurezza per impostazione predefinita.** Il toolkit non carica file scrivibili da utenti non privilegiati e non esegue plugin non validi.
8. **Bash conservativo.** Compatibilità minima con Bash 4.4 e con le utility standard di Ubuntu Server 22.04 o successive.

## 3. Struttura prevista

```text
/opt/ithaca-security/
├── VERSION
├── bin/
│   ├── ithaca-check
│   └── ithaca-inventory
├── config/
│   ├── ithaca.conf
│   └── conf.d/
│       └── *.conf
├── core/
│   ├── bootstrap.sh
│   ├── config.sh
│   ├── registry.sh
│   ├── discovery.sh
│   ├── runner.sh
│   ├── result.sh
│   ├── logger.sh
│   ├── reporter.sh
│   └── errors.sh
├── modules/
│   ├── apache.sh
│   ├── azurearc.sh
│   ├── certs.sh
│   ├── fail2ban.sh
│   ├── firewall.sh
│   ├── geoserver.sh
│   ├── postgres.sh
│   ├── ssh.sh
│   ├── system.sh
│   └── tls.sh
├── plugins.d/
│   └── <plugin-id>/
│       ├── plugin.conf
│       └── checks/
│           └── *.sh
├── templates/
├── assets/
├── docs/
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── fixtures/
│   └── smoke/
├── logs/
├── reports/
└── backups/
```

`logs/`, `reports/` e `backups/` sono dati runtime e non devono essere versionati. La directory legacy `lib/`, se già presente, può restare come compatibilità temporanea e diventare un sottile wrapper verso `core/`.

## 4. Responsabilità del Core

### 4.1 Bootstrap

`core/bootstrap.sh`:

- determina `ITHACA_BASE_DIR` senza dipendere dalla directory corrente;
- carica `VERSION` e configurazione;
- inizializza logger, registro e reporter;
- avvia discovery ed esecuzione;
- installa i trap per uscita e segnali;
- restituisce un exit code conforme alla sezione 11.

`bin/ithaca-check` deve diventare progressivamente un wrapper sottile. Durante la migrazione mantiene un percorso di fallback verso il motore v1.1.

### 4.2 API pubblica del Core

Le sole funzioni che moduli e plugin possono chiamare sono:

```bash
register_check ID FUNCTION CATEGORY DESCRIPTION [DEFAULT_ENABLED] [TIMEOUT]
result_ok CHECK_ID MESSAGE [DETAILS]
result_warn CHECK_ID MESSAGE [DETAILS]
result_critical CHECK_ID MESSAGE [DETAILS]
result_skip CHECK_ID MESSAGE [DETAILS]
result_error CHECK_ID MESSAGE [DETAILS]
config_get KEY [DEFAULT]
config_is_enabled KEY [DEFAULT]
log_debug MESSAGE
log_info MESSAGE
log_warn MESSAGE
log_error MESSAGE
command_exists COMMAND
require_command COMMAND
```

Ogni altra funzione del Core usa il prefisso `_ithaca_` ed è privata. La compatibilità dell’API pubblica è garantita per tutta la major version 1.x.

## 5. Convenzioni per moduli e check

### 5.1 Identità

- Nome file: minuscolo, ASCII, `^[a-z][a-z0-9_-]*\.sh$`.
- ID check: namespace puntato, ad esempio `apache.syntax`, `tls.protocols`, `postgres.listen`.
- Funzione: prefisso `check_`, con punti e trattini dell’ID convertiti in underscore, ad esempio `check_apache_syntax`.
- Categoria: una fra `system`, `security`, `network`, `web`, `database`, `application`, `cloud`, `backup` oppure un valore documentato dal plugin.
- Un modulo può registrare uno o più check.

### 5.2 Ciclo di vita

Il caricamento di un file deve soltanto definire funzioni e chiamare `register_check`. Non deve:

- eseguire controlli;
- modificare il server;
- produrre output diretto;
- terminare il processo con `exit`;
- cambiare opzioni globali della shell;
- leggere segreti o fare connessioni di rete.

Il corpo del check esegue il controllo e deve emettere almeno un risultato tramite `result_*`. I check sono **read-only** nella v1.2: non applicano hardening o remediation.

### 5.3 Esempio minimo

```bash
check_apache_service() {
    if ! command_exists systemctl; then
        result_skip "apache.service" "systemctl non disponibile"
        return 0
    fi

    if systemctl is-active --quiet apache2; then
        result_ok "apache.service" "Apache attivo"
    else
        result_critical "apache.service" "Apache non attivo"
    fi
}

register_check \
    "apache.service" \
    "check_apache_service" \
    "web" \
    "Verifica che Apache sia attivo" \
    "yes" \
    "10"
```

### 5.4 Regole di qualità

- Variabili locali dichiarate con `local`.
- Espansioni di variabili sempre quotate, salvo casi intenzionali commentati.
- Nessun `eval`.
- File temporanei creati in modo sicuro e rimossi con `trap` locale.
- Comandi potenzialmente bloccanti protetti dal timeout fornito dal runner.
- Messaggi destinati al report privi di sequenze colore.
- Nessun dato sensibile nei risultati o nei log.
- Lo stesso check eseguito due volte sullo stesso stato deve restituire lo stesso stato logico.

## 6. Registrazione automatica e discovery

### 6.1 Ordine di caricamento

1. Moduli ufficiali in `${ITHACA_BASE_DIR}/modules/*.sh`.
2. Plugin in `${ITHACA_PLUGIN_DIR:-${ITHACA_BASE_DIR}/plugins.d}`.

I file sono ordinati con locale `C` e percorso completo, così l’ordine è riproducibile. L’ordine di esecuzione predefinito segue categoria, priorità e ID; non deve dipendere dall’ordine restituito dal filesystem.

### 6.2 Validazione del registro

`register_check` rifiuta:

- ID o nome funzione non validi;
- ID duplicati;
- funzioni non definite;
- categorie o timeout non validi;
- registrazioni successive alla chiusura del registro.

Un errore in un modulo ufficiale viene registrato come errore interno e gli altri moduli continuano. Un plugin non valido viene escluso integralmente.

### 6.3 Sicurezza dei file caricati

Prima di fare `source`, il Core verifica che file e directory:

- siano file regolari, non symlink;
- appartengano a `root` oppure all’utente operativo configurato;
- non siano scrivibili da group/others;
- risiedano sotto un percorso canonico consentito;
- abbiano estensione `.sh`.

La v1.2 non promette sandboxing: un plugin Bash caricato ha i privilegi del processo. Per questo installazione e aggiornamento dei plugin richiedono un’azione amministrativa esplicita.

## 7. Formato dei plugin

Ogni plugin vive in `plugins.d/<plugin-id>/` e contiene `plugin.conf`:

```bash
PLUGIN_ID="docker"
PLUGIN_NAME="Docker checks"
PLUGIN_VERSION="1.0.0"
PLUGIN_API="1"
PLUGIN_VENDOR="ITHACA"
PLUGIN_DESCRIPTION="Controlli di sicurezza Docker"
PLUGIN_ENABLED="yes"
```

Regole:

- `PLUGIN_ID` coincide con il nome della directory.
- `PLUGIN_VERSION` segue SemVer.
- `PLUGIN_API=1` indica compatibilità con il contratto Core 1.x.
- I check del plugin vivono in `checks/*.sh` e usano l’ID `<plugin-id>.<check>`.
- Un plugin non può sovrascrivere funzioni pubbliche del Core né ID già registrati.
- I plugin sono disabilitabili con `PLUGIN_<ID>_ENABLED=no` nella configurazione locale.

Firma e repository remoto dei plugin sono fuori scope per v1.2; diventano requisiti prima di introdurre installazione automatica da rete.

## 8. Configurazione

### 8.1 Precedenza

Dalla priorità minore alla maggiore:

1. default interni del Core;
2. `/opt/ithaca-security/config/ithaca.conf`;
3. `/opt/ithaca-security/config/conf.d/*.conf`, in ordine lessicografico;
4. opzioni CLI consentite.

Le variabili d’ambiente non sovrascrivono automaticamente la configurazione, salvo quelle esplicitamente documentate (`ITHACA_BASE_DIR`, `ITHACA_CONFIG`, `ITHACA_PLUGIN_DIR`) e solo quando l’esecuzione non è privilegiata o dopo validazione.

### 8.2 Compatibilità v1.1

Le chiavi esistenti restano valide, incluse:

```text
HOSTNAME COMPANY ROLE PUBLIC_IP WEB_SERVER DATABASE POSTGRES_VERSION
PHP GEOSERVER WORDPRESS AZURE_ARC FAIL2BAN UFW
REPORTS LOGS BACKUPS
CHECK_TLS CHECK_POSTGRES CHECK_GEOSERVER CHECK_CERTS CHECK_AZUREARC
CHECK_FAIL2BAN CHECK_APACHE CHECK_SSH CHECK_FIREWALL
```

I moduli usano `config_get` e `config_is_enabled`; non fanno direttamente `source` della configurazione. Le vecchie chiavi `CHECK_*` vengono mappate agli ID dei nuovi check. Una chiave sconosciuta genera un warning, non un arresto.

### 8.3 Parsing sicuro

I file di configurazione sono un formato `KEY=VALUE`, non script Bash generici. Sono ammessi commenti, righe vuote e valori quotati. Sono vietati sostituzioni di comando, backtick, redirezioni e definizioni di funzione. Il parser deve validare le chiavi e non usare `eval`.

## 9. Risultati, logging e report

### 9.1 Stati canonici

| Stato | Significato | Effetto score |
|---|---|---:|
| `OK` | Conforme o operativo | 0 |
| `WARN` | Problema non bloccante | compatibile v1.1 |
| `CRITICAL` | Problema urgente | compatibile v1.1 |
| `SKIP` | Non applicabile o dipendenza assente | 0 |
| `ERROR` | Check non completato per errore interno | configurabile; default come `CRITICAL` |

La formula di score della v1.1 non cambia in v1.2. Qualunque futura modifica richiederà un campo `score_model` nel report e una release minor esplicita.

### 9.2 Record logico del risultato

Ogni risultato contiene almeno:

```text
run_id, timestamp, host, check_id, category, status, message,
details, duration_ms, module_version, toolkit_version
```

`message` è breve e adatto all’utente. `details` contiene diagnostica non sensibile. Il Core assegna timestamp, durata e metadati: il modulo non deve costruirli manualmente.

### 9.3 Logging

- Livelli: `DEBUG`, `INFO`, `WARN`, `ERROR`.
- Formato file: una riga per evento, timestamp ISO 8601 con timezone.
- Destinazione predefinita: `${LOGS}/ithaca-check.log`.
- Permessi raccomandati: directory `0750`, file `0640`.
- Colori solo su terminale interattivo; mai nei file.
- `--debug` abilita dettagli diagnostici, ma non stampa segreti.
- Rotazione demandata a `logrotate` con policy documentata.

### 9.4 Report

Per la v1.2 sono obbligatori:

- **text:** compatibile con l’attuale report v1.1;
- **JSON:** formato strutturato versionato `schema_version: 1`.

HTML è facoltativo nella v1.2 e deve essere generato dagli stessi record, senza rieseguire i check. Nome consigliato:

```text
check-YYYY-MM-DD_HH-MM-SS.<txt|json|html>
```

La scrittura è atomica: file temporaneo nella directory di destinazione, permessi impostati, quindi rename. Un errore di un reporter non invalida i risultati degli altri reporter, ma produce exit code operativo non-zero.

## 10. Runner ed error handling

Ogni check viene eseguito in un contesto isolato dal runner, con:

- misurazione durata;
- timeout configurabile, default 30 secondi;
- cattura di stdout/stderr inattesi;
- conversione di ritorni anomali in `ERROR`;
- prosecuzione con il check successivo.

Un check deve usare `return`, mai `exit`. I segnali `INT` e `TERM` interrompono ordinatamente l’esecuzione, chiudono il report parziale e rimuovono i file temporanei.

Classi di errore:

- **configuration:** configurazione invalida; avvio rifiutato se riguarda un parametro essenziale;
- **discovery:** modulo/plugin non caricabile; componente escluso, esecuzione restante continua;
- **check:** controllo non completato; risultato `ERROR`;
- **reporting:** impossibile produrre una destinazione; le altre destinazioni continuano;
- **internal:** violazione del contratto Core; registrata con contesto e senza stack sensibile.

## 11. Exit code

| Codice | Significato |
|---:|---|
| `0` | Esecuzione completata, nessun `CRITICAL` o `ERROR` |
| `1` | Uno o più `WARN` |
| `2` | Uno o più `CRITICAL` |
| `3` | Configurazione o bootstrap non validi |
| `4` | Errore interno, discovery o report incompleto |
| `130` | Interruzione tramite `SIGINT` |

Durante la fase di compatibilità, l’exit code legacy può essere mantenuto come default e la nuova semantica attivata con `STRICT_EXIT_CODES=yes`; diventerà predefinita solo dopo test e documentazione operativa.

## 12. Versioning e compatibilità

- Toolkit e plugin seguono **Semantic Versioning**.
- `VERSION` resta leggibile dalla v1.1:

```bash
VERSION="1.2.0"
CODENAME="TBD"
BUILD="YYYY.MM.DD"
CORE_API="1"
REPORT_SCHEMA="1"
```

- Patch: correzioni compatibili.
- Minor: nuove funzionalità, check o campi opzionali.
- Major: rottura di CLI, Core API o schema report.
- La rimozione di una chiave o funzione richiede almeno una minor release di deprecazione con warning.
- Moduli ufficiali hanno la stessa versione del toolkit; plugin esterni hanno versione propria e dichiarano `PLUGIN_API`.

Il codename della v1.2 non viene fissato da questa specifica; deve essere scelto prima del rilascio senza modificare l’API.

## 13. Strategia di test

### 13.1 Test statici

- `bash -n` su tutti i file `.sh`.
- ShellCheck senza errori; eccezioni annotate vicino alla riga interessata.
- verifica permessi, shebang, newline e assenza di `eval`.

### 13.2 Unit test

Coprono parser configurazione, registro, duplicati, ordinamento, score, serializzazione JSON, redazione dei segreti ed exit code. I comandi di sistema vengono sostituiti con fixture e stub.

### 13.3 Integration test

Coprono discovery di moduli/plugin, timeout, crash di un check, plugin incompatibile, reporter multipli, segnali e directory non scrivibili.

### 13.4 Compatibility test v1.1

Su una fixture che riproduce il server Sentinel si confrontano:

- set e ordine delle sezioni visibili;
- conteggi OK/WARN/CRITICAL;
- score finale;
- presenza del report testuale;
- supporto delle chiavi `CHECK_*` esistenti;
- funzionamento invariato di `sudo ithaca-check` senza nuove opzioni.

### 13.5 Smoke test su server

Prima di ogni release:

```text
installazione pulita → check → report → secondo check → rollback → check legacy
```

Il test non deve modificare configurazioni di Apache, SSH, firewall o database.

## 14. Migrazione incrementale da v1.1

### Fase 0 — Baseline e rollback

- tag Git `v1.1.0` sul commit Sentinel verificato;
- acquisizione di un report golden e degli exit code correnti;
- backup dei file operativi e verifica del comando di rollback;
- nessun cambiamento a `ithaca-check`.

**Gate:** il checkout del tag ripristina il comportamento noto.

### Fase 1 — Core passivo

- aggiunta di `core/` con logger, result model e registry testati;
- nessun modulo v1.1 spostato;
- `ithaca-check` continua a usare il percorso legacy.

**Gate:** suite statica/unit verde; output produzione invariato.

### Fase 2 — Adapter v1.1

- wrapper che converte le funzioni/output legacy in risultati canonici;
- flag `ITHACA_ENGINE=legacy|v12`, default `legacy`;
- esecuzione shadow facoltativa del nuovo motore senza sostituire il report ufficiale.

**Gate:** parità di stati e score su due esecuzioni consecutive.

### Fase 3 — Migrazione dei moduli ufficiali

- migrazione uno alla volta: `system`, `firewall`, `fail2ban`, `ssh`, `apache`, `tls`, `postgres`, `geoserver`, `azurearc`, `certs`;
- dopo ogni modulo: test, confronto report, commit dedicato e rollback verificato;
- le chiavi `CHECK_*` continuano ad abilitarli/disabilitarli.

**Gate:** tutti i check v1.1 presenti e semanticamente equivalenti.

### Fase 4 — Plugin e JSON

- attivazione discovery `plugins.d/` con validazione proprietà/permessi;
- introduzione reporter JSON schema 1;
- test con plugin fixture valido, duplicato, incompatibile e in timeout.

**Gate:** nessun plugin può impedire l’esecuzione dei moduli ufficiali.

### Fase 5 — Cutover controllato

- default `ITHACA_ENGINE=v12` in release candidate;
- percorso legacy mantenuto per almeno una minor release;
- smoke test sul server dedicato;
- rilascio `v1.2.0` solo dopo approvazione del report di confronto.

**Gate:** `sudo ithaca-check` non richiede modifiche operative e il rollback a v1.1 è documentato.

## 15. Roadmap

### v1.2 — Core modulare

- registry e discovery automatici;
- API Core 1;
- migrazione dei moduli Sentinel;
- configurazione validata;
- logging centralizzato;
- report text + JSON;
- plugin locali amministrati;
- test di compatibilità e rollback.

### v1.3 — Distribuzione e lifecycle

- `install.sh`, `update.sh`, `uninstall.sh` idempotenti;
- pacchetto di release e checksum;
- gestione backup configurazione;
- validazione pre/post aggiornamento;
- documentazione per installazione multi-server.

### v1.4 — Report e remediation controllata

- report HTML/PDF dagli stessi dati strutturati;
- storico e confronto fra run;
- remediation separate dai check, con dry-run, conferma e rollback;
- restore verificato.

### v2.0 — Servizio e dashboard

- API locale autenticata;
- dashboard web;
- scheduler e retention;
- modello plugin firmato;
- aggregazione multi-server, previa progettazione di sicurezza dedicata.

## 16. Criteri di accettazione v1.2

La release è accettabile quando:

1. `sudo ithaca-check` funziona senza cambiare comando o configurazione esistente.
2. Tutti i controlli v1.1 sono presenti e configurabili.
3. Il Core non nomina servizi specifici.
4. Aggiungere un plugin valido non richiede modifiche al Core o a `ithaca-check`.
5. ID duplicati, plugin incompatibili e file con permessi insicuri vengono rifiutati.
6. Il crash o timeout di un check non interrompe gli altri.
7. Report text e JSON derivano dallo stesso insieme di risultati.
8. Score e riepilogo v1.1 restano equivalenti sulla fixture Sentinel.
9. Test statici, unitari, integrazione, compatibilità e smoke sono verdi.
10. Esistono istruzioni di rollback testate verso il tag `v1.1.0`.

## 17. Decisioni rinviate

Richiedono una decisione separata prima della relativa implementazione:

- codename v1.2;
- framework di test Bash (`bats-core` o harness interno);
- policy esatta di penalizzazione `ERROR` dopo il periodo compatibilità;
- formato di firma e canale distributivo dei plugin;
- retention predefinita di log e report;
- supporto ufficiale oltre Ubuntu Server.

Queste decisioni non bloccano l’avvio delle Fasi 0 e 1.
