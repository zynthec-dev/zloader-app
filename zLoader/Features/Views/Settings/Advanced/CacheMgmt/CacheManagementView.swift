//
//  CacheManagementView.swift
//  ZLoader
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI

struct CacheManagementView: View {
    var signedIPAsOnly: Bool = false
    var onInstall: ((URL) -> Void)? = nil
    @StateObject private var viewModel = CacheViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.internalApps.isEmpty && viewModel.resignedApps.isEmpty {
                ProgressView("Loading Cache...")
                    .scaleEffect(1.1)
            } else {
                List {
                    if !signedIPAsOnly {
                    Section(header: Text("Internal App Cache"), footer: Text("Cached unzipped app bundles stored in zLoader's private container. These are used during automatic background refreshes and resigns.")) {
                        if viewModel.internalApps.isEmpty {
                            Text("No cached internal apps.")
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 4)
                        } else {
                            ForEach(viewModel.internalApps) { item in
                                CacheItemRow(item: item, onExport: {
                                    let appURL = item.url.appendingPathComponent("App.app")
                                    viewModel.activeExportURL = FileManager.default.fileExists(atPath: appURL.path) ? appURL : item.url
                                }, onDelete: {
                                    viewModel.itemToDelete = item
                                })
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    viewModel.itemToDelete = viewModel.internalApps[index]
                                }
                            }
                        }
                    }.listRowBackground(ZLoaderGlassBackground())
                    
                    }
                    Section(header: Text("Signed IPAs"), footer: Text("Saved signed IPA files. Tap a file to share it or save it to Files.")) {
                        if viewModel.resignedApps.isEmpty {
                            Text("No signed IPAs saved yet.")
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 4)
                        } else {
                            ForEach(viewModel.resignedApps) { item in
                                CacheItemRow(item: item, tapToExport: true, onInstall: onInstall.map { install in { install(item.url) } }, onExport: {
                                    viewModel.activeExportURL = item.url
                                }, onDelete: {
                                    viewModel.deleteItem(item)
                                })
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    viewModel.deleteItem(viewModel.resignedApps[index])
                                }
                            }
                        }
                    }
                    .listRowBackground(ZLoaderGlassBackground())
                }
                #if !os(tvOS)
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
                .background(ZLoaderAppBackground())
                #else
                .listStyle(GroupedListStyle())
                #endif
            }
            
            if viewModel.isLoading && !(viewModel.internalApps.isEmpty && viewModel.resignedApps.isEmpty) {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                ProgressView()
                    .padding()
                    #if !os(tvOS)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                    #else
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.8)))
                    #endif
                    .shadow(radius: 10)
            }
        }
        .navigationTitle(signedIPAsOnly
                         ? NSLocalizedString("IPA Library", comment: "Signed IPA file library")
                         : NSLocalizedString("Cache Management", comment: ""))
        .refreshable { viewModel.loadCacheItems() }
        .onAppear {
            viewModel.loadCacheItems()
        }
        .alert(isPresented: $viewModel.showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $viewModel.showDeleteAlert) {
            let appName = viewModel.itemToDelete?.name ?? "this app"
            return Alert(
                title: Text("Delete Cached App?"),
                message: Text("If deleted, zLoader will require the original IPA file during reinstall, backup, resign, or refresh procedures. Are you sure you want to delete the cached app bundle for “\(appName)” ?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let item = viewModel.itemToDelete {
                        viewModel.deleteItem(item)
                    }
                },
                secondaryButton: .cancel {
                    viewModel.itemToDelete = nil
                }
            )
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.activeExportURL != nil },
            set: { if !$0 { viewModel.activeExportURL = nil } }
        )) {
            if let url = viewModel.activeExportURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }
}

struct CacheItemRow: View {
    let item: CacheItem
    var tapToExport: Bool = false
    var onInstall: (() -> Void)? = nil
    let onExport: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
            } else {
                Image(systemName: "square.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundColor(.secondary)
                    .padding(4)
                    #if !os(tvOS)
                    .background(Color(.systemGray6))
                    #else
                    .background(Color.gray.opacity(0.2))
                    #endif
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if let bundleID = item.bundleIdentifier {
                    Text(bundleID)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(item.sizeString)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if tapToExport { onExport() } }
        .contextMenu {
            if let onInstall {
                SwiftUI.Button(action: onInstall) {
                    Label("Install IPA", systemImage: "square.and.arrow.down")
                }
            }
            SwiftUI.Button(action: onExport) {
                Label(tapToExport ? NSLocalizedString("Share IPA", comment: "") : NSLocalizedString("Export/Share", comment: ""), systemImage: "square.and.arrow.up")
            }
            SwiftUI.Button(role: .destructive, action: onDelete) {
                Label(tapToExport ? NSLocalizedString("Delete IPA", comment: "") : NSLocalizedString("Delete Cache", comment: ""), systemImage: "trash")
            }
        }
    }
}
