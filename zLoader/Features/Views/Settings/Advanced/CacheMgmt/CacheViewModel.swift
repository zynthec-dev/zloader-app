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

struct CacheItem: Identifiable, Equatable {
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

    let formatter = ByteCountFormatter()

    private func formatBytes(_ size: Int64) -> String {
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func loadCacheItems() {
        self.isLoading = true
        
        let internalAppURLs = CacheManager.shared.fetchInternalApps()
        let resignedAppURLs = CacheManager.shared.fetchResignedApps()
        
        // Fetch all database apps to map display names & icons
        let context = DatabaseManager.shared.viewContext
        var dbAppsByFingerprint: [String: (name: String, bundleID: String, fileURL: URL, alternateIconURL: URL, hasAlternateIcon: Bool)] = [:]
        
        context.performAndWait {
            let apps = InstalledApp.all(in: context)
            for app in apps {
                guard let fingerprint = app.appBundleFingerprint else { continue }
                dbAppsByFingerprint[fingerprint] = (
                    name: app.name,
                    bundleID: app.bundleIdentifier,
                    fileURL: app.fileURL,
                    alternateIconURL: app.alternateIconURL,
                    hasAlternateIcon: app.hasAlternateIcon
                )
            }
        }
        
        // Process on background queue
        Task.detached {
            var internalItems: [CacheItem] = []
            var resignedItems: [CacheItem] = []
            
            // 1. Process Internal Cache Items
            for shaDirURL in internalAppURLs {
                let sha = shaDirURL.lastPathComponent
                let appURL = shaDirURL.appendingPathComponent("App.app")
                let size = CacheManager.shared.calculateSize(of: shaDirURL)
                let sizeStr = await self.formatBytes(size)
                
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
                let filename = url.lastPathComponent
                let size = CacheManager.shared.calculateSize(of: url)
                let sizeStr = await self.formatBytes(size)
                
                let metadata = try? SignedIPAInspection.read(url)
                let displayName = metadata?.name ?? filename.replacingOccurrences(of: ".app", with: "")
                                          .replacingOccurrences(of: ".ipa", with: "")
                
                var iconImage: UIImage? = metadata?.iconData.flatMap { UIImage(data: $0) }
                if let appIcon = ALTApplication(fileURL: url)?.icon {
                    iconImage = appIcon
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
            
            // Sort by size descending
            internalItems.sort { $0.sizeInBytes > $1.sizeInBytes }
            resignedItems.sort { $0.sizeInBytes > $1.sizeInBytes }
            
            DispatchQueue.main.async {
                self.internalApps = internalItems
                self.resignedApps = resignedItems
                self.isLoading = false
            }
        }
    }
    
    func deleteItem(_ item: CacheItem) {
        self.isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try CacheManager.shared.delete(at: item.url)
                DispatchQueue.main.async {
                    self.loadCacheItems()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
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
