# Architettura

- Aggiornato: 2026-09-17
- Stato: coordinatore in `Packages/GlobyCore/`; shell macOS in `Globy.xcodeproj`
- Risponde a: responsabilità interne, dipendenze e flusso dello stato

## Principio centrale

La rete non comanda direttamente l'interfaccia. Gli ingressi producono richieste di
sincronizzazione; un solo coordinatore aggiorna lo stato locale; menu, notifiche e
mascotte osservano quello stato.

```text
Chronocol HTTP ───────┐
  RSS, poi JSON        ├─> SyncCoordinator ─> Store locale ─┬─> Menu bar
Chronocol SSE ─ hint ─┘                                    ├─> Notifiche
                                                           └─> Mascotte
```

SSE può ridurre la latenza, ma l'assenza dello stream non deve cambiare la correttezza.

## Componenti

| Componente | Responsabilità | Non deve |
|---|---|---|
| `ChronocolClient` | Leggere feed, dettaglio e futuro cursore | Conservare stato UI |
| `EventHintClient` | Ascoltare SSE e chiedere un catch-up | Dichiarare da solo un VOX nuovo |
| `SyncCoordinator` | Baseline, catch-up, dedupe, retry | Mostrare finestre o notifiche |
| `ContentStore` | Persistenza di contenuti e versioni osservate | Conoscere SwiftUI |
| `PreferenceStore` | Preferenze locali | Contenere segreti in chiaro |
| `NotificationCoordinator` | Politiche, permessi e azioni | Dedurre lo stato dalla grafica |
| `MenuBarFeature` | Elenco, badge e comandi | Chiamare direttamente le API HTTP |
| `MascotFeature` | Presentare entrata, attesa e uscita del globo | Produrre eventi di dominio |
| `AppLifecycle` | Avvio, stop/risveglio, login item | Duplicare la sincronizzazione |

I nomi sono descrittivi, non una struttura di cartelle già approvata.

## Modello locale minimo

Per ogni VOX osservato servono almeno:

- `documentId`;
- permalink;
- testo o riassunto necessario all'elenco;
- timestamp ricevuti dal servizio;
- impronta o versione osservata;
- prima e ultima osservazione locale;
- `readAt`, opzionale;
- `notifiedAt`, opzionale;
- disponibilità corrente, per gestire un ritiro.

`readAt` e `notifiedAt` non sono lo stesso fatto. Un aggiornamento di un VOX letto non
lo trasforma automaticamente in una nuova pubblicazione: la politica dipenderà dal
contratto incrementale.

## Ciclo di sincronizzazione

### Primo avvio

1. Legge lo stato corrente.
2. Lo salva come baseline.
3. Non programma notifiche per gli elementi già presenti.
4. Avvia il canale di suggerimento in tempo reale, se disponibile.

### Evento SSE

1. Registra soltanto il motivo del risveglio.
2. Avvia o accoda una sincronizzazione idempotente.
3. Confronta la risposta autorevole con lo store.
4. Decide quali cambiamenti siano notificabili.

### Riconnessione o risveglio

1. Applica un breve debounce per evitare richieste duplicate.
2. Esegue il catch-up HTTP descritto nell'ADR 0002 (RSS se copre il buco, JSON altrimenti).
3. Aggiorna ritiri e modifiche.
4. Se gli arrivi sono numerosi, produce un riepilogo anziché notifiche singole.

### Errori

- retry con ritardo crescente e jitter;
- una sola sincronizzazione in volo;
- nessuna cancellazione dello stato valido per un errore temporaneo;
- fallback a polling se SSE non è disponibile o risponde 503;
- polling a macchina accesa: una sync ogni 5 minuti con jitter del 10%, ripianificata
  dopo ogni sync qualunque ne sia la causa; gli errori consecutivi raddoppiano l'attesa
  fino a 30 minuti (`PollingPolicy`). Fermo durante lo stop del Mac; al ritorno della
  rete una sync immediata (`reconnect`). Valori provvisori (`docs/CONTRATTO_API.md`,
  domanda 8);
- una sync accorpata a quella già in volo non viene presentata una seconda volta;
- distinzione tra offline, risposta non valida e contratto incompatibile.

## Concorrenza e isolamento

Il coordinamento di rete e persistenza deve avere un proprietario unico, preferibilmente
isolato con gli strumenti di concorrenza di Swift. Le viste ricevono snapshot o modelli
osservabili sul `MainActor`; non possiedono task di rete persistenti indipendenti.

## Persistenza

I contenuti osservati vivono in un file JSON in Application Support, dietro il
protocollo `ContentStore` (ADR 0004). `InMemoryContentStore` resta per i test.
`UserDefaults` soltanto per preferenze piccole; il Portachiavi non serve nella
prima versione.

## Mascotte e rendering

La mascotte è un globo 2D (ADR 0003). SwiftUI `Canvas` disegna sfera, meridiani e
occhi; AppKit adatta la finestra trasparente. RealityKit è stato confrontato nello
spike e scartato.

La finestra è un adattatore AppKit separato dal modello della mascotte. Tre
presentazioni distinte: il saluto di primo avvio e il saluto di rientro (non sono
VOX) e la conferma di un nuovo VOX. Il coordinatore dell'interfaccia richiede una sola presentazione
in basso a destra; una raffica viene aggregata invece di sovrapporre più globi.
Terminata l'animazione, la finestra si nasconde e rilascia o sospende le risorse
grafiche senza fermare l'app. Le preferenze piccole (mascotte, permanenza, suono,
pausa notifiche, avvio al login, saluto già mostrato) restano in `UserDefaults`.

Il posizionamento deve usare l'area visibile dello schermo scelto, non coordinate
globali fisse: Dock, notch, ridimensionamento e più monitor cambiano l'angolo realmente
utilizzabile.

## Confini futuri

APNs, account e funzioni editoriali richiedono componenti e confini di fiducia nuovi.
Non vanno aggiunti come casi speciali dentro il client pubblico.
