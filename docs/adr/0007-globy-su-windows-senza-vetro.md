# 0007 — Su Windows Globy non ha il vetro Acrylic: solo globo e fumetto scuri

- Stato: accettato
- Data: 2026-10-03
- Accettato: 2026-10-03
- Proprietario: progetto Globy
- Vincolante per: `desktop/src-tauri/src/mascot.rs`, `desktop/src/mascot/`
- Nasce da: su Windows Globy compariva dentro un grande rettangolo grigio in basso a destra
- Sostituisce: per la sola finestra di Globy, il punto «vetro Acrylic su Windows» dell'ADR 0005

## Contesto

La finestra di Globy è un rettangolo trasparente grande quanto globo più fumetto. Su
Windows la ritagliamo sulla forma di globo e fumetto (`SetWindowRgn`) e ci mettevamo
dietro il vetro Acrylic, con `window-vibrancy`.

Fatto verificato il 2026-10-03 con le foto del workflow «Foto su Windows», su Windows
Server 2022 (Acrylic in stile Windows 10) e 2025 (backdrop di sistema di Windows 11):
in entrambi i casi il vetro copre **tutto il rettangolo** della finestra e ignora il
ritaglio. Con la superficie scura, nella stessa prova, si vedono soltanto globo e
fumetto, come sul Mac.

## Decisione

La finestra di Globy su Windows non applica il vetro: globo e fumetto usano la
superficie scura che Linux già usa. Il ritaglio resta, perché decide dove arrivano i
clic. L'elenco dei VOX, che è rettangolare per scelta, tiene il vetro.

Escluse: un vetro imitato nella pagina (senza sfocatura vera è solo un grigio
semitrasparente, e su sfondi chiari il globo chiaro sparisce); disegnare il vetro con
un'altra API di Windows senza una prova che rispetti la forma.

## Come si verifica

- le foto del workflow «Foto su Windows» mostrano globo e fumetto senza rettangolo,
  su Windows Server 2022 e 2025;
- la voce corrispondente di `docs/COLLAUDO_DESKTOP.md` passa su un PC Windows 11.

## Conseguenze

- su Windows Globy ha lo stesso aspetto che su Linux, non quello del Mac con Liquid
  Glass;
- una sola strada di disegno per il globo nella pagina: niente variante «vetro» né
  variabile `GLOBY_SURFACE`.

## Quando riesaminare

1. Esiste un modo di avere un vetro di sistema limitato a una forma, provato con le
   foto del workflow e su un PC vero.
2. Chi usa Globy su Windows trova il globo scuro poco leggibile su sfondi scuri.
