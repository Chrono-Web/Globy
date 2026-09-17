import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @ObservedObject private var preferences: PreferenceStore
    @State private var confirmReset = false
    @State private var confirmSystemNotifications = false
    @State private var confirmUninstall = false

    init(session: AppSession) {
        self.session = session
        _preferences = ObservedObject(wrappedValue: session.preferences)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Mostra sempre Globy", isOn: $preferences.permanence)
                    .disabled(!preferences.mascotEnabled)
                Toggle("Apri Globy al login", isOn: launchAtLoginBinding)
                Toggle("Suono", isOn: $preferences.mascotSoundEnabled)
                    .disabled(!preferences.mascotEnabled)
                Toggle("Gli occhi seguono il puntatore", isOn: $preferences.gazeFollowsPointer)
                    .disabled(!preferences.mascotEnabled)
            } header: {
                Text("Globy")
            } footer: {
                if !preferences.mascotEnabled {
                    footnote("Globy è spento mentre sono attive le notifiche di sistema.")
                } else if preferences.permanence {
                    footnote(preferences.gazeFollowsPointer
                        ? "Con Globy sempre visibile potrebbe aumentare il consumo della batteria, soprattutto se gli occhi seguono il puntatore: si ridisegnano a ogni movimento del mouse."
                        : "Con Globy sempre visibile potrebbe aumentare un po' il consumo della batteria.")
                }
            }
            Section {
                Toggle("Dimensioni personalizzate", isOn: $preferences.customSizesEnabled)
                LabeledContent("Globy") {
                    scaleSlider($preferences.globeScale, range: MascotMetrics.globeRange)
                }
                .disabled(!preferences.customSizesEnabled)
                LabeledContent("Testo") {
                    scaleSlider($preferences.textScale, range: MascotMetrics.textRange)
                }
                .disabled(!preferences.customSizesEnabled)
                LabeledContent("Pulsanti") {
                    scaleSlider($preferences.buttonScale, range: MascotMetrics.buttonRange)
                }
                .disabled(!preferences.customSizesEnabled)
                LabeledContent("") {
                    Button("Ripristina standard") {
                        preferences.globeScale = 1
                        preferences.textScale = 1
                        preferences.buttonScale = 1
                    }
                    .disabled(!preferences.customSizesEnabled || isStandardSize)
                }
            } header: {
                Text("Dimensioni")
            } footer: {
                footnote("Mentre le Impostazioni sono aperte Globy mostra un’anteprima in basso a destra. Se spegni le dimensioni personalizzate i valori restano salvati.")
            }
            .disabled(!preferences.mascotEnabled)
            Section {
                Toggle("Notifiche di sistema", isOn: systemNotificationsBinding)
            } header: {
                Text("Notifiche")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    footnote("Al posto di Globy, i nuovi VOX arrivano come notifiche del Mac, senza suono.")
                    if let note = session.notificationStatusNote {
                        footnote(note)
                    }
                }
            }
            Section {
                LabeledContent("Dati locali") {
                    Button("Azzera…", role: .destructive) {
                        confirmReset = true
                    }
                }
            } header: {
                Text("Dati")
            } footer: {
                footnote("I contenuti stanno in un file JSON in Application Support. Azzerare cancella store e impostazioni, non il permesso di sistema.")
            }
            Section {
                LabeledContent("Rimuovi Globy da questo Mac") {
                    Button("Disinstalla Globy…", role: .destructive) {
                        confirmUninstall = true
                    }
                }
            } header: {
                Text("Disinstalla")
            } footer: {
                footnote("Chiude Globy, lo sposta nel Cestino e cancella VOX salvati, impostazioni e avvio al login.")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(width: 460, height: 680)
        .alert("Passare alle notifiche di sistema?", isPresented: $confirmSystemNotifications) {
            Button("Annulla", role: .cancel) {}
            Button("Attiva") {
                Task { await session.enableSystemNotifications() }
            }
        } message: {
            Text("Attivando le notifiche di sistema, disattiverai la visualizzazione di Globy. I nuovi VOX arriveranno come notifiche del Mac.")
        }
        .alert("Disinstallare Globy?", isPresented: $confirmUninstall) {
            Button("Annulla", role: .cancel) {}
            Button("Disinstalla", role: .destructive) {
                session.uninstall()
            }
        } message: {
            Text("Globy viene chiuso e spostato nel Cestino. Vengono cancellati i VOX salvati, le impostazioni e l’avvio al login. Il permesso notifiche, se l’hai dato, resta in Impostazioni di Sistema › Notifiche.")
        }
        .alert("Azzerare i dati locali?", isPresented: $confirmReset) {
            Button("Annulla", role: .cancel) {}
            Button("Azzera", role: .destructive) {
                Task { await session.resetLocalData() }
            }
        } message: {
            Text("Vengono cancellati elenco, stati letto/notificato e le impostazioni di Globy. Poi parte di nuovo la baseline, senza notifiche sull’archivio.")
        }
    }

    private func scaleSlider(_ value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Slider(value: haptic(value), in: range, step: 0.05) {
                EmptyView()
            } minimumValueLabel: {
                Text("A").font(.system(size: 10))
            } maximumValueLabel: {
                Text("A").font(.system(size: 15))
            }
            .frame(width: 190)
            Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    /// Un tocco del trackpad a ogni scatto del cursore, più marcato sul 100%.
    private func haptic(_ value: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { new in
                let old = value.wrappedValue
                value.wrappedValue = new
                guard abs(new - old) > 0.001 else { return }
                let pattern: NSHapticFeedbackManager.FeedbackPattern = abs(new - 1) < 0.001 ? .levelChange : .alignment
                NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
            }
        )
    }

    private var isStandardSize: Bool {
        preferences.globeScale == 1 && preferences.textScale == 1 && preferences.buttonScale == 1
    }

    /// Accendere chiede conferma (spegne Globy); spegnere riporta Globy subito.
    private var systemNotificationsBinding: Binding<Bool> {
        Binding(
            get: { !preferences.mascotEnabled },
            set: { on in
                if on {
                    confirmSystemNotifications = true
                } else {
                    session.disableSystemNotifications()
                }
            }
        )
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { session.launchAtLogin },
            set: { session.setLaunchAtLogin($0) }
        )
    }
}
