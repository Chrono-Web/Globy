# Architettura

- Aggiornato: 2026-09-16
- Stato: proposta, nessun codice presente
- Risponde a: responsabilità interne, dipendenze e flusso dello stato

## Principio centrale

La rete non comanda direttamente l'interfaccia. Gli ingressi producono richieste di
sincronizzazione; un solo coordinatore aggiorna lo stato locale; menu, notifiche e
mascotte osservano quello stato.

```text
Chronocol HTTP ───────┐
                      ├─> SyncCoordinator ─> Store locale ─┬─> Menu bar
Chronocol SSE ─ hint ─┘                                    ├─> Notifiche
                                                           └─> Mascotte
```

SSE può ridurre la latenza, ma l'assenza dello stream non deve cambiare la correttezza.

## Componenti

| Componente | Responsabilità | Non deve |
|---|---|---|
| `ChronocolClient` | Leggere feed, dettaglio e futuro cursore | Conservare stato UI |
| `EventHintClient` | Ascoltare SSE e chiedere un catch-up | Dichiarare da solo una VOX nuova |
| `SyncCoordinator` | Baseline, catch-up, dedupe, retry | Mostrare finestre o notifiche |
| `ContentStore` | Persistenza di contenuti e versioni osservate | Conoscere SwiftUI |
| `PreferenceStore` | Preferenze locali | Contenere segreti in chiaro |
| `NotificationCoordinator` | Politiche, permessi e azioni | Dedurre lo stato dalla grafica |
| `MenuBarFeature` | Elenco, badge e comandi | Chiamare direttamente Strapi |
| `MascotFeature` | Presentare entrata, attesa e uscita del globo | Produrre eventi di dominio |
| `AppLifecycle` | Avvio, stop/risveglio, login item | Duplicare la sincronizzazione |

I nomi sono descrittivi, non una struttura di cartelle già approvata.

## Modello locale minimo

Per ogni VOX osservata servono almeno:

- `documentId`;
- permalink;
- testo o riassunto necessario all'elenco;
- timestamp ricevuti dal servizio;
- impronta o versione osservata;
- prima e ultima osservazione locale;
- `readAt`, opzionale;
- `notifiedAt`, opzionale;
- disponibilità corrente, per gestire un ritiro.

`readAt` e `notifiedAt` non sono lo stesso fatto. Un aggiornamento di una VOX letta non
la trasforma automaticamente in una nuova pubblicazione: la politica dipenderà dal
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
2. Esegue il catch-up HTTP.
3. Aggiorna ritiri e modifiche.
4. Se gli arrivi sono numerosi, produce un riepilogo anziché notifiche singole.

### Errori

- retry con ritardo crescente e jitter;
- una sola sincronizzazione in volo;
- nessuna cancellazione dello stato valido per un errore temporaneo;
- fallback a polling se SSE non è disponibile o risponde 503;
- distinzione tra offline, risposta non valida e contratto incompatibile.

## Concorrenza e isolamento

Il coordinamento di rete e persistenza deve avere un proprietario unico, preferibilmente
isolato con gli strumenti di concorrenza di Swift. Le viste ricevono snapshot o modelli
osservabili sul `MainActor`; non possiedono task di rete persistenti indipendenti.

## Persistenza

La tecnologia non è ancora scelta. Lo spike deve confrontare almeno:

- SwiftData o Core Data per contenuti e stato;
- `UserDefaults` soltanto per preferenze piccole;
- Keychain soltanto per eventuali segreti futuri.

La scelta dipende anche dalla versione minima di macOS. Qualunque implementazione deve
essere sostituibile da uno store in memoria nei test.

## Mascotte e rendering

Lo spike grafico confronta una soluzione RealityKit con una rappresentazione 2D. Deve
misurare qualità, consumo, trasparenza della finestra, input, multi-monitor e Space.

La finestra è un adattatore AppKit separato dal modello della mascotte. Dopo la conferma
di una nuova VOX, il coordinatore dell'interfaccia richiede una sola presentazione in
basso a destra; una raffica viene aggregata invece di sovrapporre più globi. Terminata
l'animazione, la finestra si nasconde e rilascia o sospende le risorse grafiche senza
fermare l'app.

Il posizionamento deve usare l'area visibile dello schermo scelto, non coordinate
globali fisse: Dock, notch, ridimensionamento e più monitor cambiano l'angolo realmente
utilizzabile.

## Confini futuri

APNs, account e funzioni editoriali richiedono componenti e confini di fiducia nuovi.
Non vanno aggiunti come casi speciali dentro il client pubblico.
