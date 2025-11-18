//
//  ValueSnapshotFormView.swift
//  Summa
//
//  Created by Till Gartner on 10.08.25.
//

import Foundation
import SwiftData
import SwiftUI
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ValueSnapshotEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Series.sortOrder) var allSeries: [Series]

    let snapshot: ValueSnapshot?

    @State private var date = Date.now
    @State private var value: Double = 0
    @State private var selectedSeries: Series?

    // Image attachment states
    @State private var selectedImage: PlatformImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var existingImageData: Data?
    @State private var showingFullScreenImage = false
    @State private var fullScreenImage: PlatformImage?

    var body: some View {
        Form {
            Section("Series") {
                if !allSeries.isEmpty {
                    Picker("Series", selection: $selectedSeries) {
                        ForEach(allSeries) { series in
                            HStack {
                                Circle()
                                    .fill(SeriesManager.shared.colorFromHex(series.color))
                                    .frame(width: 12, height: 12)
                                Text(series.name)
                            }
                            .tag(series as Series?)
                        }
                    }
                } else {
                    Text("No series available")
                        .foregroundColor(.secondary)
                }
            }

            Section("Details") {
                TextField("Value", value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif

                DatePicker("Date", selection: $date)
            }

            Section("Screenshot") {
                // Show existing image or new selection
                if let selectedImage = selectedImage {
                    VStack {
                        #if os(iOS)
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                fullScreenImage = selectedImage
                                showingFullScreenImage = true
                            }
                        #elseif os(macOS)
                        Image(nsImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                fullScreenImage = selectedImage
                                showingFullScreenImage = true
                            }
                        #endif

                        HStack {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Change Screenshot", systemImage: "photo.on.rectangle")
                            }
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task { @MainActor in
                                    if let newItem {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = PlatformImage.fromData(data) {
                                            self.selectedImage = image
                                        }
                                    }
                                }
                            }

                            Button(role: .destructive) {
                                self.selectedImage = nil
                                self.selectedPhotoItem = nil
                                self.existingImageData = nil
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                } else if let existingImageData = existingImageData,
                          let uiImage = PlatformImage.fromData(existingImageData) {
                    // Show existing image from database
                    VStack {
                        #if os(iOS)
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                fullScreenImage = uiImage
                                showingFullScreenImage = true
                            }
                        #elseif os(macOS)
                        Image(nsImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                fullScreenImage = uiImage
                                showingFullScreenImage = true
                            }
                        #endif

                        HStack {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Change Screenshot", systemImage: "photo.on.rectangle")
                            }
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                Task { @MainActor in
                                    if let newItem {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = PlatformImage.fromData(data) {
                                            self.selectedImage = image
                                            self.existingImageData = nil
                                        }
                                    }
                                }
                            }

                            Button(role: .destructive) {
                                self.existingImageData = nil
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    // No image selected
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Attach Screenshot", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task { @MainActor in
                            if let newItem {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let image = PlatformImage.fromData(data) {
                                    self.selectedImage = image
                                }
                            }
                        }
                    }
                }
            }
        }
                .navigationTitle(snapshot == nil ? "Add Entry" : "Edit Entry")
                #if os(macOS)
                .padding()
                #endif
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if let snapshot = snapshot {
                                // Edit existing snapshot
                                snapshot.date = date
                                snapshot.value = value
                                snapshot.series = selectedSeries

                                // Handle image update
                                if let selectedImage = selectedImage,
                                   let imageData = selectedImage.compressedJPEGData(maxSizeKB: 1024) {
                                    snapshot.sourceImage = imageData
                                    snapshot.imageAttachedDate = Date()
                                } else if existingImageData == nil && selectedImage == nil {
                                    // User removed the image
                                    snapshot.sourceImage = nil
                                    snapshot.imageAttachedDate = nil
                                }
                            } else {
                                // Create new snapshot
                                let valueSnapshot = ValueSnapshot(
                                    on: date,
                                    value: value,
                                    series: selectedSeries
                                )

                                // Add image if selected
                                if let selectedImage = selectedImage,
                                   let imageData = selectedImage.compressedJPEGData(maxSizeKB: 1024) {
                                    valueSnapshot.sourceImage = imageData
                                    valueSnapshot.imageAttachedDate = Date()
                                }

                                modelContext.insert(valueSnapshot)
                            }

                            // Remember last used series
                            if let selectedSeries = selectedSeries {
                                SeriesManager.shared.setLastUsedSeries(selectedSeries)
                            }

                            try? modelContext.save()
                            dismiss()
                        }
                        .disabled(selectedSeries == nil)
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let snapshot = snapshot {
                                // Edit existing snapshot
                                snapshot.date = date
                                snapshot.value = value
                                snapshot.series = selectedSeries

                                // Handle image update
                                if let selectedImage = selectedImage,
                                   let imageData = selectedImage.compressedJPEGData(maxSizeKB: 1024) {
                                    snapshot.sourceImage = imageData
                                    snapshot.imageAttachedDate = Date()
                                } else if existingImageData == nil && selectedImage == nil {
                                    // User removed the image
                                    snapshot.sourceImage = nil
                                    snapshot.imageAttachedDate = nil
                                }
                            } else {
                                // Create new snapshot
                                let valueSnapshot = ValueSnapshot(
                                    on: date,
                                    value: value,
                                    series: selectedSeries
                                )

                                // Add image if selected
                                if let selectedImage = selectedImage,
                                   let imageData = selectedImage.compressedJPEGData(maxSizeKB: 1024) {
                                    valueSnapshot.sourceImage = imageData
                                    valueSnapshot.imageAttachedDate = Date()
                                }

                                modelContext.insert(valueSnapshot)
                            }

                            // Remember last used series
                            if let selectedSeries = selectedSeries {
                                SeriesManager.shared.setLastUsedSeries(selectedSeries)
                            }

                            try? modelContext.save()
                            dismiss()
                        }
                        .disabled(selectedSeries == nil)
                    }
                    #endif
                }
                .onAppear {
                    if let snapshot = snapshot {
                        // Editing existing snapshot
                        date = snapshot.date
                        value = snapshot.value
                        selectedSeries = snapshot.series
                        existingImageData = snapshot.sourceImage
                    } else {
                        // Adding new snapshot - set default series to last used
                        if selectedSeries == nil {
                            selectedSeries = SeriesManager.shared.getLastUsedSeries(from: allSeries)
                        }
                    }
                }
                .sheet(isPresented: $showingFullScreenImage) {
                    NavigationStack {
                        if let fullScreenImage = fullScreenImage {
                            ImageViewer(image: fullScreenImage)
                        }
                    }
                }
    }
}

// Full-screen image viewer
struct ImageViewer: View {
    let image: PlatformImage
    @Environment(\.dismiss) private var dismiss
    @GestureState private var zoom = 1.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .scaleEffect(zoom)
                    .gesture(
                        MagnificationGesture()
                            .updating($zoom) { value, gestureState, _ in
                                gestureState = value
                            }
                    )
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .scaleEffect(zoom)
                    .gesture(
                        MagnificationGesture()
                            .updating($zoom) { value, gestureState, _ in
                                gestureState = value
                            }
                    )
                #endif
            }
        }
        .navigationTitle("Screenshot")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
            #else
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            #endif
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    NavigationStack {
        ValueSnapshotEditView(snapshot: nil)
    }
    .modelContainer(for: [ValueSnapshot.self, Series.self])
}
    
