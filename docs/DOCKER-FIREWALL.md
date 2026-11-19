# Firewall su host Docker e firewall del provider

Guida operativa ai check `firewall.*` introdotti nella v1.3, per server Ubuntu
che eseguono Docker (anche in modalità Swarm) dietro il firewall di un
provider, per esempio Hetzner Robot o Hetzner Cloud.

## Perché "UFW attivo" non basta

Docker scrive direttamente le proprie regole iptables (tabella `nat`, catene
`DOCKER`, `DOCKER-INGRESS` e `FORWARD`). Il traffico verso una porta pubblicata
da un container (`ports:` in Compose o Swarm) viene inoltrato al container
prima di passare dalle catene di UFW. Di conseguenza:

- `ufw deny 5432` **non** blocca un PostgreSQL pubblicato da Docker;
- `ufw status` può mostrare una policy restrittiva mentre il database è
  raggiungibile da Internet;
- le porte del routing mesh di Swarm (`mode: ingress`) sono gestite da
  `dockerd` e seguono la stessa logica.

## Modello a livelli

| Livello | Cosa protegge | Strumento |
|---|---|---|
| 1. Firewall del provider | tutto ciò che arriva al server, comprese le porte Docker | Hetzner Robot/Cloud firewall |
| 2. Firewall dell'host | servizi dell'host (sshd, agent, demoni locali) | UFW |
| 3. Pubblicazione dei container | cosa Docker espone | bind su `127.0.0.1`, reti overlay senza `ports:` |
| 4. Filtro dei container (opzionale) | traffico inoltrato ai container | catena `DOCKER-USER` |

Il livello 1 è l'unico che copre in modo affidabile le porte pubblicate da
Docker. Il livello 3 è la correzione strutturale: un servizio che non deve
essere pubblico non va pubblicato.

## Note sul firewall Hetzner Robot (server dedicati)

- È **stateless**: le risposte alle connessioni in uscita vanno consentite
  esplicitamente. Il template di Hetzner usa una regola TCP con flag `ack`
  verso le porte effimere `32768-65535`; non va rimossa.
- Le risposte UDP (DNS verso resolver esterni, NTP) sono scartate, salvo che
  provengano dai servizi Hetzner con l'opzione **Hetzner Services** attiva.
- Il numero di regole in ingresso è limitato (10): raggruppare le porte
  (`80,443`) e usare intervalli.
- **"Filter IPv6 packets" è disattivato di default**: se il server ha un
  indirizzo IPv6 globale, tutto il traffico IPv6 passa senza filtri. Attivarlo
  e dichiarare `HETZNER_FILTER_IPV6="yes"` nella configurazione.
- Le regole sono valutate in ordine: l'ultima regola deve essere un `discard`
  generale.

## Configurazione del toolkit

```bash
DOCKER="auto"                 # "no" disattiva i check Docker/Swarm
SSH_PORT="22"
ALLOWED_PUBLIC_PORTS="80,443" # porte che possono essere pubbliche, oltre a SSH
HETZNER="yes"
HETZNER_FILTER_IPV6="yes"     # solo dopo averlo attivato nel pannello
```

| Check | Esito tipico | Significato |
|---|---|---|
| `firewall.ufw_rules` | WARN | policy incoming non `deny`, nessuna regola SSH o IPv6 non gestito |
| `firewall.exposed_listeners` | WARN/CRITICAL | servizi dell'host in ascolto pubblico fuori da `ALLOWED_PUBLIC_PORTS`; CRITICAL per porte di database |
| `firewall.docker_bypass` | WARN/CRITICAL | porte pubblicate da Docker che UFW non filtra |
| `firewall.swarm_ports` | WARN | porte 2377/7946/4789 in ascolto; con un solo nodo non servono dall'esterno |
| `firewall.ipv6` | WARN | IPv6 globale presente ma non filtrato da UFW o dal provider |

Il toolkit legge solo lo stato dell'host: le regole del provider non sono
verificabili da qui. Confermarle sempre con una scansione esterna.

## Procedura sicura per attivare UFW su un host Docker

Eseguire da una sessione SSH che resta aperta fino alla fine.

```bash
# 1. Stato iniziale (sola lettura)
sudo ss -tulpn
sudo iptables -S DOCKER-USER
grep '^IPV6=' /etc/default/ufw

# 2. Regole prima dell'attivazione
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp comment 'SSH'
sudo ufw allow 80,443/tcp comment 'HTTP/HTTPS'
sudo ufw show added

# 3. Attivazione
sudo ufw --force enable
sudo ufw status verbose

# 4. Verifica da una seconda sessione SSH e dei servizi web
curl -sSI https://<dominio> | head -1
```

`ufw limit` blocca un indirizzo dopo 6 connessioni in 30 secondi: valutare
`allow` al posto di `limit` se pipeline di deploy o script aprono molte
connessioni SSH ravvicinate. Con Fail2Ban attivo la protezione resta.

Rollback immediato: `sudo ufw disable`. Le regole di Docker non vengono
toccate né dall'attivazione né dalla disattivazione di UFW.

## Verifica esterna

Da un host esterno autorizzato:

```bash
nmap -Pn -p 1-65535 --open <ip-server>
nmap -Pn -6 -p 1-65535 --open <ipv6-server>   # se presente
```

Devono risultare aperte solo le porte previste (SSH e `ALLOWED_PUBLIC_PORTS`).
