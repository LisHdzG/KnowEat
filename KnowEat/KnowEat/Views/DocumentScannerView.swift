//
//  DocumentScannerView.swift
//  KnowEat
//
//  Created by Lisette HG on 20/02/26.
//

import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanCompleted: ([UIImage]) -> Void
    let onCancelled: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanCompleted: onScanCompleted, onCancelled: onCancelled)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanCompleted: ([UIImage]) -> Void
        let onCancelled: () -> Void

        init(onScanCompleted: @escaping ([UIImage]) -> Void, onCancelled: @escaping () -> Void) {
            self.onScanCompleted = onScanCompleted
            self.onCancelled = onCancelled
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true) { [onScanCompleted] in
                onScanCompleted(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { [onCancelled] in
                onCancelled()
            }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) { [onCancelled] in
                onCancelled()
            }
        }
    }
}
