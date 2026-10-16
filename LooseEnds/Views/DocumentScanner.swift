#if os(iOS)
import OSLog
import SwiftUI
import VisionKit

/// The system's document camera (#442): finds the page edges, straightens them and takes several
/// pages in a row. Hands the pages back as images; cancelling or an error hands back none.
struct DocumentScanner: UIViewControllerRepresentable {
    let finish: @MainActor ([CGImage]) -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(finish: finish) }

    @MainActor final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let finish: @MainActor ([CGImage]) -> Void
        private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

        init(finish: @escaping @MainActor ([CGImage]) -> Void) { self.finish = finish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            finish(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            finish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            Self.logger.error("Scanning failed: \(error, privacy: .public)")
            finish([])
        }
    }
}
#endif
