//
//  CacheViewModel.swift
//  ZLoader
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import CoreData
import SideSign
import ImageIO

struct CacheItem: Identifiable, Equatable, @unchecked Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let sizeString: String
    let sizeInBytes: Int64
    let url: URL
    let isDirectory: Bool
    let image: UIImage?
}

@MainActor
class CacheViewModel: ObservableObject {
    @Published var internalApps: [CacheItem] = []
    @Published var resignedApps: [CacheItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil {
        didSet {
            showErrorAlert = errorMessage != nil
        }
    }
    @Published var showErrorAlert = false
    
    // Deletion states
    @Published var itemToDelete: CacheItem? = nil {
        didSet {
            showDeleteAlert = itemToDelete != nil
        }
    }
    @Published var showDeleteAlert = false
    
    // Export/Share states
    @Published var activeExportURL: URL? = nil

    private typealias Snapshot = (internalApps: [CacheItem], resignedApps: [CacheItem])
    private typealias AppMetadata = (name: String, bundleID: String, fileURL: URL, alternateIconURL: URL, hasAlternateIcon: Bool)
    private var loadTask: Task<Snapshot?, Never>?
    private var generation = UUID()
    private var includesInternalApps = true

    func cancelLoading() {
        generation = UUID()
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func loadCacheItems(includeInternalApps: Bool = true) async {
        cancelLoading()
        includesInternalApps = includeInternalApps
        let current = UUID()
        generation = current
        isLoading = true
        var databaseApps: [String: AppMetadata] = [:]
        if includeInternalApps {
            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            databaseApps = await context.perform {
                var values: [String: AppMetadata] = [:]
                for app in InstalledApp.all(in: context) {
                    guard let fingerprint = app.appBundleFingerprint else { continue }
                    values[fingerprint] = (app.name, app.bundleIdentifier, app.fileURL, app.alternateIconURL, app.hasAlternateIcon)
                }
                return values
            }
        }
        guard generation == current, !Task.isCancelled else { return }
        let dbAppsByFingerprint = databaseApps
        let worker = Task.detached(priority: .userInitiated) { () -> Snapshot? in
            let internalAppURLs = includeInternalApps ? CacheManager.shared.fetchInternalApps() : []
            let resignedAppURLs = includeInternalApps ? [] : CacheManager.shared.fetchResignedApps()
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useAll]
            formatter.countStyle = .file
            var internalItems: [CacheItem] = []
            var resignedItems: [CacheItem] = []
            // 1. Process Internal Cache Items
            for shaDirURL in internalAppURLs {
                if Task.isCancelled { return nil }
                let sha = shaDirURL.lastPathComponent
                let appURL = shaDirURL.appendingPathComponent("App.app")
                let size = CacheManager.shared.calculateSize(of: shaDirURL)
                let sizeStr = formatter.string(fromByteCount: size)
                
                let appBundle = ALTApplication(fileURL: appURL)
                let bundleID = appBundle?.bundleIdentifier
                
                var displayName = appBundle?.name ?? sha
                var iconImage: UIImage? = appBundle?.icon
                
                if let dbInfo = dbAppsByFingerprint[sha] {
                    displayName = dbInfo.name
                    
                    if dbInfo.hasAlternateIcon,
                       let data = try? Data(contentsOf: dbInfo.alternateIconURL) {
                        iconImage = UIImage(data: data)
                    } else if let appIcon = ALTApplication(fileURL: dbInfo.fileURL)?.icon {
                        iconImage = appIcon
                    }
                }
                
                let item = CacheItem(
                    id: sha,
                    name: displayName,
                    bundleIdentifier: bundleID,
                    sizeString: sizeStr,
                    sizeInBytes: size,
                    url: shaDirURL,
                    isDirectory: true,
                    image: iconImage
                )
                internalItems.append(item)
            }
            
            // 2. Process Resigned App Items
            for url in resignedAppURLs {
                if Task.isCancelled { return nil }
                let filename = url.lastPathComponent
                let size = CacheManager.shared.calculateSize(of: url)
                let sizeStr = formatter.string(fromByteCount: size)
                
                let metadata = try? SignedIPASummary.read(url)
                let displayName = metadata?.name ?? filename.replacingOccurrences(of: ".app", with: "")
                                          .replacingOccurrences(of: ".ipa", with: "")
                
                let iconImage: UIImage? = metadata?.iconData.flatMap { data -> UIImage? in
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 160
                          ] as CFDictionary) else { return nil }
                    return UIImage(cgImage: image)
                }
                
                let item = CacheItem(
                    id: filename,
                    name: displayName,
                    bundleIdentifier: metadata?.bundleID,
                    sizeString: sizeStr,
                    sizeInBytes: size,
                    url: url,
                    isDirectory: url.hasDirectoryPath,
                    image: iconImage
                )
                resignedItems.append(item)
            }
            

            internalItems.sort { $0.sizeInBytes > $1.sizeInBytes }
            resignedItems.sort { $0.sizeInBytes > $1.sizeInBytes }
            return (internalItems, resignedItems)
        }
        loadTask = worker
        let result = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        guard generation == current else { return }
        loadTask = nil
        isLoading = false
        guard !Task.isCancelled, let result else { return }
        internalApps = result.internalApps
        resignedApps = result.resignedApps
    }

    func deleteItem(_ item: CacheItem) {
        if item.isDirectory && AppManager.shared.isActivelyManagingAnyApp {
            errorMessage = NSLocalizedString("Wait for app operations to finish before deleting the refresh cache.", comment: "")
            return
        }
        cancelLoading()
        isLoading = true
        itemToDelete = nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try CacheManager.shared.delete(at: item.url) }.value
                await loadCacheItems(includeInternalApps: includesInternalApps)
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

}

/// Read the resulting IPA, including each separately signed extension.
struct SignedIPAInspection: Sendable {
    struct Component: Identifiable, Sendable {
        let id: String
        let name: String
        let team: String
        let profile: String
        let expires: Date?
        let devices: [String]
        let certificates: [String]
        let kind: String
        let entitlements: [(String, String)]
    }
    let name: String
    let bundleID: String
    let iconData: Data?
    let components: [Component]

    static func read(_ url: URL) throws -> SignedIPAInspection {
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temporary) }
        let appURL = try fm.unzipAppBundle(at: url, to: temporary)
        guard let app = ALTApplication(fileURL: appURL) else { throw OperationError.invalidApp(reason: "Invalid IPA") }
        let components = ([app] + app.appExtensions.sorted { $0.bundleIdentifier < $1.bundleIdentifier }).map { component in
            let profile = component.provisioningProfile
            let kind: String
            if profile == nil { kind = "No Embedded Profile" }
            else if profile?.isFreeProvisioningProfile == true { kind = "Free Development" }
            else if profile?.entitlements["get-task-allow"] as? Bool == true { kind = "Development" }
            else if profile?.deviceIDs.isEmpty == false { kind = "Ad Hoc Distribution" }
            else { kind = "Distribution" }
            return Component(id: component.bundleIdentifier, name: component.name,
                team: profile.map { $0.teamName + " · " + $0.teamIdentifier } ?? "—",
                profile: profile.map { $0.name + " · " + $0.uuid.uuidString } ?? "—",
                expires: profile?.expirationDate, devices: profile?.deviceIDs ?? [],
                certificates: profile?.certificates.map { $0.name + " · " + $0.serialNumber } ?? [],
                kind: kind, entitlements: component.entitlements.sorted { $0.key < $1.key }.map { ($0.key, String(describing: $0.value)) })
        }
        return SignedIPAInspection(name: app.name, bundleID: app.bundleIdentifier, iconData: app.icon?.pngData(), components: components)
    }
}
