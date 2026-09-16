# Privacy

- Aggiornato: 2026-09-16
- Stato: politica prevista per la prima versione
- Risponde a: quali dati tratta Globy e dove restano

## Sintesi

La prima versione non richiede account e non contiene telemetria. Legge contenuti
pubblici di Chronocol e conserva sul Mac soltanto lo stato necessario al funzionamento.

## Dati conservati localmente

- preferenze dell'app;
- identificativi e metadati delle VOX mostrate;
- stato letto/non letto;
- stato già notificato;
- ultima sincronizzazione riuscita e cursore, se il contratto lo prevede;
- posizione e visibilità della mascotte;
- diagnostica locale strettamente necessaria, con contenuto limitato.

L'elenco pubblico di Chronocol può contenere campi che non servono a Globy.
Quei campi non vanno conservati, mostrati o copiati in questa documentazione.

La durata di conservazione e l'azione “Azzera dati locali” vanno definite prima della
release.

## Richieste di rete

Globy contatta la base URL Chronocol configurata per:

- leggere contenuti pubblici;
- effettuare catch-up periodici;
- opzionalmente mantenere una connessione SSE mentre è in esecuzione.

Il server e gli intermediari possono osservare metadati ordinari di rete, compreso
l'indirizzo IP. Globy non deve aggiungere un identificativo persistente del dispositivo
alle richieste pubbliche.

## Notifiche

Titolo e anteprima possono comparire sulla schermata di blocco secondo le impostazioni
di macOS. Prima di richiedere il permesso, l'interfaccia deve spiegare questa conseguenza
e offrire una modalità con contenuto ridotto se il prodotto la richiederà.

## Telemetria e crash reporting

Assenti nella prima versione. Aggiungere analytics, crash reporting remoto o logging
centralizzato richiede:

1. decisione esplicita;
2. minimizzazione dei dati;
3. aggiornamento di questo documento;
4. consenso o altra base appropriata;
5. possibilità di disattivazione quando necessaria.

## Segreti

Le API pubbliche non richiedono credenziali. Se una fase futura introduce un account,
i token vanno nel Portachiavi di macOS e la parte autenticata deve essere isolata dal
client pubblico.

## Esportazione e cancellazione

Prima della release devono esistere:

- un comando per azzerare stato e preferenze locali;
- una spiegazione di che cosa viene cancellato;
- una verifica che la disinstallazione non lasci dati sensibili non documentati.
