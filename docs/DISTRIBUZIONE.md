# Distribuzione

- Aggiornato: 2026-09-16
- Stato: canale scelto, pipeline non costruita
- Risponde a: come una build diventa una release installabile e aggiornabile

## Decisione

Globy si distribuisce **fuori dal Mac App Store**. Il canale ufficiale è GitHub:
sorgente nel repository, binari eventualmente in Releases.

La prima strategia **non firma e non notarizza**. L'utente scarica e apre il binario
accettando l'avviso Gatekeeper (sviluppatore non identificato: apri dal menu
contestuale). Compilare da sorgente resta il percorso senza quel blocco.

Questa scelta si può sostituire in seguito con Developer ID e notarizzazione, senza
passare dallo Store. Firma e notarizzazione non costituiscono da sole un sistema di
aggiornamento: per ora l'aggiornamento è scaricare la release successiva.

## Requisiti comuni

- bundle identifier stabile: `com.chronocol.globy`, casa `docs/SVILUPPO.md`;
- versione minima di macOS 15, stessa casa;
- numero di versione e build riproducibili;
- asset con provenienza e licenza registrate;
- privacy e permessi coerenti con il comportamento reale;
- release notes;
- test su un Mac o utente pulito;
- possibilità di compilare senza credenziali di distribuzione.

## GitHub

Ogni binario pubblicato deve corrispondere a un tag il cui sorgente è nello stesso
repository (obbligo GPL). La Release indica il tag, il sistema operativo minimo e che
il pacchetto non è notarizzato.

Non versionare certificati, profili o password. Non servono alla strategia attuale.

## Canali

- **Debug locale:** fixture o staging;
- **Beta:** gruppo limitato, diagnostica manuale, binario GitHub non firmato;
- **Stable:** stesso canale, contratto compatibile e criteri della roadmap `[x]`.

Una beta non deve usare automaticamente la produzione per operazioni che modificano
contenuti. Le sole letture pubbliche possono essere collaudate contro produzione con
frequenza rispettosa dei limiti.

## Gate di release

- build e test automatici riusciti;
- sorgente del tag coincidente con il binario;
- avvio su installazione pulita provato, compreso il percorso Gatekeeper;
- notifiche consentite e negate provate;
- login item abilitato e disabilitato provato;
- consumo a riposo entro le soglie ancora da fissare;
- `LICENSE` e registro asset allineati al bundle;
- `CHANGELOG.md`, privacy e documentazione aggiornati.

## Credenziali

Certificati, password, profili e token non entrano nella repository. La compilazione
non firmata deve restare possibile in locale senza credenziali di distribuzione.
