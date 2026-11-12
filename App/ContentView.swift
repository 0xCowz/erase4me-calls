import SwiftUI
import CallKit

/// Identifiant de l'extension = identifiant de l'app + ".blocker" (voir project.yml).
/// Si ton outil de sideload change l'identifiant de l'app, l'extension suit : on le déduit donc de l'identifiant courant.
private var extensionID: String { (Bundle.main.bundleIdentifier ?? "com.erase4me.calls") + ".blocker" }

struct ContentView: View {
    @State private var status = "Vérification…"
    @State private var enabled = false
    @State private var message = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("État")) {
                    HStack {
                        Circle().fill(enabled ? Color.green : Color.orange).frame(width: 10, height: 10)
                        Text(status)
                    }
                    Button("Ouvrir les réglages de blocage") {
                        CXCallDirectoryManager.sharedInstance.openSettings { error in
                            message = error?.localizedDescription ?? ""
                        }
                    }
                    Button("Recharger la liste") { reload() }
                }
                Section(header: Text("Comment l'activer")) {
                    Text("Réglages > Téléphone > Blocage d'appels et identification > active « Anti-démarchage ».")
                        .font(.footnote)
                }
                Section(header: Text("Ce que ça bloque")) {
                    Text("Les tranches de numéros que l'ARCEP réserve à la prospection commerciale (03 77, 03 78, 09 48, 09 49), attribuées à des opérateurs.")
                        .font(.footnote)
                    Text("Un appel venant d'un 06, d'un 07 ou d'un numéro usurpé n'est pas bloqué.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                if !message.isEmpty {
                    Section { Text(message).font(.footnote).foregroundColor(.red) }
                }
            }
            .navigationTitle("Anti-démarchage")
            .onAppear(perform: refresh)
        }
    }

    private func refresh() {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionID) { s, error in
            DispatchQueue.main.async {
                switch s {
                case .enabled: status = "Activé"; enabled = true
                case .disabled: status = "Désactivé : active-le dans les Réglages"; enabled = false
                default: status = "Inconnu" + (error.map { " (\($0.localizedDescription))" } ?? ""); enabled = false
                }
            }
        }
    }

    private func reload() {
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionID) { error in
            DispatchQueue.main.async {
                message = error.map { "Échec du rechargement : \($0.localizedDescription)" } ?? "Liste rechargée."
                refresh()
            }
        }
    }
}
