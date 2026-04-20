import Foundation
import Combine

#if canImport(Sparkle)
import Sparkle
#endif

final class AppUpdateService: ObservableObject {
    @Published private(set) var status: String = ""

#if canImport(Sparkle)
    private lazy var updaterController: SPUStandardUpdaterController = .init(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
#endif

    @MainActor
    func checkForUpdates() {
#if canImport(Sparkle)
        updaterController.checkForUpdates(nil)
        status = "Checking for updates…"
#else
        status = "Sparkle is not linked. Configure release appcast and regenerate project."
#endif
    }
}
