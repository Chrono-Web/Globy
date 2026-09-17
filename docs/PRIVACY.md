# Privacy

- Aggiornato: 2026-09-17
- Stato: vale per la versione 0.1.0
- Risponde a: quali dati tratta Globy e dove restano

## Sintesi

La prima versione non richiede account e non contiene telemetria. Legge contenuti
pubblici di Chronocol e conserva sul Mac soltanto lo stato necessario al funzionamento.

## Dati conservati localmente

Tutto resta sul Mac, nell'account dell'utente:

- `~/Library/Application Support/Globy/com.chronocol.globy/content.json`: per ogni VOX
  visto, identificativo, testo dell'elenco, permalink, date di pubblicazione e di
  osservazione, stato letto e già notificato; data dell'ultima sincronizzazione;
- impostazioni dell'app nel dominio `com.chronocol.globy` di `UserDefaults`, compresi
  «saluto già mostrato», «onboarding concluso» e l'ora dell'ultimo saluto di rientro.

Non vengono conservate la posizione di Globy, diagnostica o log. L'elenco pubblico di
Chronocol può contenere campi che non servono a Globy: non vengono salvati.

I dati restano finché l'utente non li cancella con «Azzera…» o «Disinstalla Globy…».

## Richieste di rete

Globy contatta la base URL Chronocol configurata per:

- leggere contenuti pubblici con sole GET: il feed RSS all'avvio, al risveglio, al
  ritorno della rete e circa ogni 5 minuti; l'elenco JSON solo per coprire un buco;
- aprire nel browser il permalink di un VOX scelto dall'utente.

La versione 0.1.0 non usa lo stream SSE.

Il server e gli intermediari possono osservare metadati ordinari di rete, compreso
l'indirizzo IP. Globy non deve aggiungere un identificativo persistente del dispositivo
alle richieste pubbliche.

## Notifiche

Globy chiede il permesso solo se l'utente attiva «Notifiche di sistema» nelle
Impostazioni, dopo una conferma. Titolo e testo del VOX possono comparire sulla
schermata di blocco secondo le impostazioni di macOS.

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

## Cancellazione

- **Impostazioni › Azzera…:** cancella VOX salvati e impostazioni, poi riparte con una
  nuova baseline.
- **Impostazioni › Disinstalla Globy…:** toglie l'avvio al login e le notifiche
  consegnate, cancella la cartella dei dati e le impostazioni e sposta l'app nel Cestino.
- Il permesso notifiche, se dato, resta in Impostazioni di Sistema › Notifiche: macOS
  non lascia a un'app toglierselo.
