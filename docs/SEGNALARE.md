# Segnalare un problema

- Aggiornato: 2026-09-17
- Vale per: Globy su Mac, Windows e Linux
- Risponde a: come dire che qualcosa non va, in modo che si possa correggere

Globy per Windows e Linux è **in test**: se qualcosa non funziona, segnalarlo è il modo
più utile per aiutare. Serve un account GitHub (gratuito).

## Come fare

1. Apri [le issue di Globy](https://github.com/Chrono-Web/Globy/issues) e cerca se
   qualcuno ha già segnalato lo stesso problema. Se sì, aggiungi un commento con il tuo
   sistema invece di aprirne un'altra.
2. Altrimenti premi **New issue** › **Problema** e compila il modulo.
3. Trascina nel modulo screenshot o video: valgono più di molte parole.

## Cosa scrivere

- **Sistema e versioni.** Globy (è nel titolo della Release che hai scaricato), sistema
  operativo e, su Linux, distribuzione e ambiente (GNOME, KDE…).
- **Linux: X11 o Wayland.** Apri un terminale e scrivi `echo $XDG_SESSION_TYPE`.
- **Passaggi precisi.** «Ho cliccato la X del fumetto e il globo è rimasto a schermo» è
  utile; «il globo è strano» no.
- **Cosa ti aspettavi.** A volte il problema è una spiegazione che manca.
- **Se succede sempre**, e se succede anche dopo aver chiuso e riaperto Globy.

Per un problema di consumo scrivi quanta CPU usa Globy, con Globy nascosto e a schermo:
su Windows da **Gestione attività**, su Linux con `top`, sul Mac da **Monitoraggio Attività**.

## Cosa non scrivere

Le issue sono pubbliche. Non incollare password, token o dati personali. I file di Globy
contengono solo VOX pubblici e impostazioni, ma non servono quasi mai: li chiediamo noi
se occorrono. Per un problema di sicurezza segui [`SECURITY.md`](../SECURITY.md).

## Proposte

Un'idea o un comportamento diverso non è un problema: usa **New issue** › **Proposta**.

## Chi collauda su richiesta

Se stai facendo il collaudo completo, segui [`COLLAUDO_DESKTOP.md`](COLLAUDO_DESKTOP.md) e
apri una issue per ogni riga ❌.
