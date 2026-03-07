//
//  ImageStorageService.swift
//  KnowEat
//

import UIKit

final class ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let jpegQuality: CGFloat = 0.8

    private var baseDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("MenuImages", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func save(images: [UIImage], forMenuId menuId: UUID) -> [String] {
        let menuDir = baseDirectory.appendingPathComponent(menuId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: menuDir, withIntermediateDirectories: true)

        var fileNames: [String] = []
        for (index, image) in images.enumerated() {
            let fileName = "page_\(index).jpg"
            let fileURL = menuDir.appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: jpegQuality) {
                try? data.write(to: fileURL, options: .atomic)
                fileNames.append(fileName)
            }
        }
        return fileNames
    }

    func loadImages(forMenuId menuId: UUID) -> [UIImage] {
        let menuDir = baseDirectory.appendingPathComponent(menuId.uuidString, isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(atPath: menuDir.path) else { return [] }

        return files.sorted().compactMap { fileName in
            let fileURL = menuDir.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return UIImage(data: data)
        }
    }

    func loadImage(forMenuId menuId: UUID, fileName: String) -> UIImage? {
        let fileURL = baseDirectory
            .appendingPathComponent(menuId.uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deleteImages(forMenuId menuId: UUID) {
        let menuDir = baseDirectory.appendingPathComponent(menuId.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: menuDir)
    }

    func hasImages(forMenuId menuId: UUID) -> Bool {
        let menuDir = baseDirectory.appendingPathComponent(menuId.uuidString, isDirectory: true)
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: menuDir.path, isDirectory: &isDir) && isDir.boolValue
    }
}
