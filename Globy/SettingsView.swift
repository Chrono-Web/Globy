import SwiftUI

struct SettingsView: View {
    @ObservedObject var session: AppSession
    @ObservedObject private var preferences: PreferenceStore
    @State private var confirmReset = false

    init(session: AppSession) {
        self.session = session
        _preferences = ObservedObject(wrappedValue: session.preferences)
    }

    var body: some View {
        Form {
            Section("Mascotte") {
                Toggle("Mostra la mascotte", isOn: $preferences.mascotEnabled)
                Toggle("Permanenza del globo", isOn: $preferences.permanence)
                Toggle("Suono", isOn: $preferences.mascotSoundEnabled)
            }
            Section {
                Toggle("Dimensioni personalizzate", isOn: $preferences.customSizesEnabled)
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
                        preferences.textScale = 1
                        preferences.buttonScale = 1
                    }
                    .disabled(!preferences.customSizesEnabled || (preferences.textScale == 1 && preferences.buttonScale == 1))
                }
            } header: {
                Text("Dimensioni")
            } footer: {
                Text("Mentre le Preferenze sono aperte Globy mostra un’anteprima in basso a destra. Se spegni le dimensioni personalizzate i valori restano salvati.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Pausa temporanea", isOn: $preferences.notificationsPaused)
            } header: {
                Text("Notifiche")
            } footer: {
                Text("Senza suono. Un permesso negato non è un errore: i VOX restano nel menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Avvio") {
                Toggle("Apri Globy al login", isOn: launchAtLoginBinding)
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
                Text("I contenuti stanno in un file JSON in Application Support. Azzerare cancella store e preferenze, non il permesso di sistema.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(width: 460, height: 680)
        .alert("Azzerare i dati locali?", isPresented: $confirmReset) {
            Button("Annulla", role: .cancel) {}
            Button("Azzera", role: .destructive) {
                Task { await session.resetLocalData() }
            }
        } message: {
            Text("Vengono cancellati elenco, stati letto/notificato e le preferenze di Globy. Poi parte di nuovo la baseline, senza notifiche sull’archivio.")
        }
    }

    private func scaleSlider(_ value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Slider(value: value, in: range, step: 0.05) {
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

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { session.launchAtLogin },
            set: { session.setLaunchAtLogin($0) }
        )
    }
}
