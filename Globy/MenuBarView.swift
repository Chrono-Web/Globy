import AppKit
import GlobyCore
import SwiftUI

struct MenuBarView: View {
    static let width: CGFloat = 348
    @ObservedObject var session: AppSession
    var onPreferences: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !session.preferences.didOnboard {
                onboarding
                menuDivider
            }
            header
            menuDivider
            if session.recent.isEmpty {
                Text(session.isSyncing ? "Sincronizzazione…" : "Nessun VOX ancora.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            } else {
                // I VOX scorrono; intestazione e azioni restano sempre visibili.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(session.recent, id: \.documentId) { record in
                            Button {
                                session.open(record)
                                onDismiss()
                            } label: {
                                VoxRow(record: record, isUnread: session.isUnread(record))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 380)
                .fixedSize(horizontal: false, vertical: true)
            }
            #if DEBUG
            if session.usesFixture {
                menuDivider
                debugActions
            }
            #endif
            menuDivider
            MenuActionRow(title: "Impostazioni…") {
                onPreferences()
            }
            MenuActionRow(title: "Esci") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .frame(width: Self.width + 12)
    }

    private var unreadTitle: String {
        switch session.unreadCount {
        case 0: "Nessun VOX non letto"
        case 1: "1 VOX non letto"
        case let n: "\(n) VOX non letti"
        }
    }

    private var header: some View {
        HStack {
            Text(unreadTitle)
                .font(.headline)
            Spacer()
            if session.isSyncing {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Due cose, poi basta")
                .font(.headline)
            Text("Globy legge i VOX pubblici di Chronocol. L’archivio già presente non viene notificato: in questo menu trovi gli ultimi VOX, con in evidenza quelli nuovi non letti.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Nelle Impostazioni puoi tenere Globy sempre a schermo, togliere il suono, cambiare le dimensioni o passare alle notifiche di sistema al posto di Globy.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ho capito") {
                session.finishOnboarding()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(10)
    }

    #if DEBUG
    private var debugActions: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Fixture locale, niente rete")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 4)
            MenuActionRow(title: "Simula nuovo VOX") {
                Task { await session.simulatePublication() }
            }
            MenuActionRow(title: "Simula raffica (3 VOX)") {
                Task { await session.simulateBurst() }
            }
        }
    }

    #endif

    private var menuDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
    }
}

private struct MenuActionRow: View {
    var title: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(hovering ? 0.14 : 0))
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct VoxRow: View {
    var record: VoxRecord
    var isUnread: Bool
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(VoxText.readable(record.listText))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .font(.system(size: 13))
                .fontWeight(isUnread ? .semibold : .regular)
                .multilineTextAlignment(.leading)
            // L'archivio del primo avvio non ha etichetta finché non lo apri.
            if isUnread || record.readAt != nil || record.notifiedAt != nil {
                HStack(spacing: 6) {
                    if isUnread {
                        Text("Non letto")
                    } else if record.readAt != nil {
                        Text("Letto")
                    }
                    if record.notifiedAt != nil {
                        Text("Notificato")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(hovering ? 0.14 : 0))
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
