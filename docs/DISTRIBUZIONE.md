# Distribuzione

- Aggiornato: 2026-09-17
- Stato: canale scelto; su GitHub Releases DMG manuale (`Globy.dmg`) e installer Windows e
  Linux creati dalla CI, tutti non firmati
- Risponde a: come una build diventa una release installabile e aggiornabile

## Decisione

Globy si distribuisce **fuori dal Mac App Store**. Il canale ufficiale è GitHub:
sorgente nel repository, binario in Releases. Il README punta sempre a
`https://github.com/Chrono-Web/GLOBY/releases/latest/download/Globy.dmg`.

La prima strategia **non firma e non notarizza**. L'utente scarica e apre il binario
accettando l'avviso Gatekeeper (sviluppatore non identificato: apri dal menu
contestuale). Compilare da sorgente resta il percorso senza quel blocco.

Questa scelta si può sostituire in seguito con Developer ID e notarizzazione, senza
passare dallo Store. Firma e notarizzazione non costituiscono da sole un sistema di
aggiornamento: per ora l'aggiornamento è scaricare la release successiva.

## DMG

`scripts/crea-dmg.sh` compila la Release e crea `build/Globy-<versione>.dmg`, poi
ne copia una con nome stabile `build/Globy.dmg`. La finestra ha sfondo con titolo
e freccia (`scripts/dmg/sfondo.swift`), icone grandi e nessuna barra degli
strumenti; la disposizione la scrive il Finder, quindi la prima volta macOS
chiede il permesso di controllarlo. Contiene:

- `Globy.app`, firmata solo localmente, non notarizzata;
- un collegamento «Applicazioni» per installare trascinando;
- `Installa e disinstalla Globy.txt` (sorgente in `scripts/dmg/`): installazione,
  percorso Gatekeeper «Apri comunque» in Privacy e sicurezza, aggiornamento e
  disinstallazione.

La disinstallazione normale sta nell'app: Impostazioni › «Disinstalla Globy…» toglie
l'avvio al login e le notifiche consegnate, cancella dati e impostazioni e sposta l'app
nel Cestino. Il permesso notifiche resta nelle Impostazioni di Sistema.

## Windows e Linux

`.github/workflows/desktop.yml` crea gli installer da `desktop/` (ADR 0005):

| File nella Release | Sistema | Formato |
|---|---|---|
| `Globy-Windows.exe` | Windows 10 e 11 | installer NSIS per l'utente corrente, senza amministratore |
| `Globy-Linux.deb` | Ubuntu, Debian, Mint | pacchetto (~4 MB; usa WebKitGTK del sistema). È il download Linux consigliato nel README. |
| `Globy-Linux.AppImage` | Linux a 64 bit | un solo file eseguibile (~78 MB: `linuxdeploy` ci mette WebKit). Secondo download Linux nel README, per chi non ha il `.deb`. |

I nomi sono fissi a ogni versione, come `Globy.dmg`: il README punta a
`/releases/latest/download/<nome>`. Nessuno è firmato: Windows mostra SmartScreen
(«Ulteriori informazioni › Esegui comunque»). La build Linux gira su Ubuntu 22.04.

Ogni push sui rami `main` e `desktop` che tocca `desktop/` produce gli installer come
artifact dell'esecuzione: servono al collaudo (`docs/COLLAUDO_DESKTOP.md`).

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

Il repository è **pubblico**: su un repo privato GitHub risponde 404 a
`/releases/latest/download/…`, anche se la Release esiste, e il pulsante del README
non scarica nulla.

L'asset da allegare si chiama **`Globy.dmg`**, non solo `Globy-<versione>.dmg`: è il
nome nel link del README. Non segnare la Release come pre-release: GitHub esclude
le pre-release da `/releases/latest`, e il pulsante «Scarica» andrebbe a vuoto.

Dalla 0.2.0 una versione esce per i tre sistemi insieme:

1. stessa versione in `Globy.xcodeproj` (`MARKETING_VERSION`),
   `desktop/src-tauri/tauri.conf.json`, `desktop/package.json` e `desktop/Cargo.toml`;
2. tag e push: la CI crea la Release in bozza e allega Windows e Linux;
3. DMG del Mac allegato a mano, poi la bozza si pubblica come ultima versione:

```bash
git tag v0.2.0 && git push origin v0.2.0
./scripts/crea-dmg.sh
gh release upload v0.2.0 build/Globy.dmg
gh release edit v0.2.0 --draft=false --latest --notes-file note.md
```

Il numero è `CFBundleShortVersionString`. Le note si copiano da `CHANGELOG.md`.

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
