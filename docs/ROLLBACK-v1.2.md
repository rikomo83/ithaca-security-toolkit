# Rollback v1.2 Odyssey

Questa procedura ripristina il comportamento Sentinel senza modificare la
configurazione dei servizi controllati. I check sono read-only.

## Rollback operativo immediato

Eseguire una singola verifica con il motore v1.1:

```bash
sudo env ITHACA_ENGINE=legacy ithaca-check
```

Il comando deve produrre il report testuale Sentinel e mantenere la sua
semantica storica degli exit code.

Per un job schedulato, anteporre `ITHACA_ENGINE=legacy` al comando finché il
problema v1.2 non è stato analizzato. Non modificare o cancellare
`bin/ithaca-check-legacy` e `modules/` durante tutta la minor release 1.2.

## Verifica comparativa

```bash
sudo env ITHACA_ENGINE=legacy ithaca-check > /tmp/ithaca-legacy.txt 2>&1
LEGACY_RC=$?

sudo env ITHACA_ENGINE=v12 ithaca-check > /tmp/ithaca-v12.txt 2>&1
V12_RC=$?

echo "Legacy: $LEGACY_RC"
echo "V1.2: $V12_RC"
grep -E 'Warnings|Critical|Score' /tmp/ithaca-legacy.txt
grep -E 'Warnings|Critical|Score' /tmp/ithaca-v12.txt
```

## Rollback completo al tag v1.1.0

Usare questa procedura soltanto in una finestra di manutenzione e dopo aver
salvato eventuali modifiche locali. Verificare prima:

```bash
cd /opt/ithaca-security
sudo git status --short
sudo git tag --list v1.1.0
```

Se la working tree è pulita, il tag può essere collaudato senza cancellare il
branch Odyssey:

```bash
sudo git switch --detach v1.1.0
sudo ithaca-check
```

Per tornare alla release candidate:

```bash
sudo git switch feature/v1.2-core
sudo ithaca-check
```

Se la working tree non è pulita, non eseguire lo switch: raccogliere
`git status`, conservare i report e richiedere una revisione prima del rollback.

## Evidenze da conservare

- commit o tag in esecuzione;
- exit code;
- `check-latest.txt` e, per v1.2, `check-latest.json`;
- output di `git status --short`;
- motivo e durata del rollback.
