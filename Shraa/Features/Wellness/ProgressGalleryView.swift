import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Main View

struct ProgressGalleryView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var allPhotos: [ProgressPhoto]
    @State private var selectedCategory: ProgressPhotoCategory = .gym
    @State private var showAdd = false
    @State private var fullscreenPhoto: ProgressPhoto?

    private var filtered: [ProgressPhoto] {
        allPhotos.filter { $0.category == selectedCategory }
    }

    private var byWeek: [(String, [ProgressPhoto])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filtered) { photo -> String in
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: photo.date)
            let start = cal.date(from: comps)!
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let end = cal.date(byAdding: .day, value: 6, to: start)!
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
        return grouped.sorted { a, b in
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return (f.date(from: String(a.0.prefix(6))) ?? .distantPast) >
                   (f.date(from: String(b.0.prefix(6))) ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    categoryPicker
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        weeksContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.surfaceBase)
            .navigationTitle("Progress Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "camera.badge.plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddProgressPhotoSheet(preselectedCategory: selectedCategory)
            }
            .fullScreenCover(item: $fullscreenPhoto) { photo in
                FullscreenPhotoView(photo: photo)
            }
        }
    }

    // MARK: Category Picker

    private var categoryPicker: some View {
        HStack(spacing: 12) {
            ForEach(ProgressPhotoCategory.allCases) { cat in
                PhotoCategoryChip(cat: cat, isSelected: selectedCategory == cat) {
                    withAnimation(.spring(response: 0.3)) { selectedCategory = cat }
                }
            }
            Spacer()
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCategory.icon)
                .font(.system(size: 56))
                .foregroundStyle(LinearGradient.brand)
                .padding(.top, 50)
            Text("No \(selectedCategory.label) photos yet")
                .font(.title3.bold())
            Text("Add your first photo to start tracking your progress over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button { showAdd = true } label: {
                Label("Add Photo", systemImage: "camera.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LinearGradient.brand)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: Weeks

    private var weeksContent: some View {
        VStack(spacing: 24) {
            ForEach(byWeek, id: \.0) { week, photos in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Week of \(week)")
                            .font(.headline)
                        Spacer()
                        Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    photoGrid(photos: photos)
                }
            }
        }
    }

    private func photoGrid(photos: [ProgressPhoto]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(photos) { photo in
                PhotoTile(photo: photo) {
                    fullscreenPhoto = photo
                } onDelete: {
                    ctx.delete(photo)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Category Chip

private struct PhotoCategoryChip: View {
    let cat: ProgressPhotoCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                Text(cat.label).fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? AnyView(LinearGradient.brand) : AnyView(Color.clear))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Photo Tile

private struct PhotoTile: View {
    let photo: ProgressPhoto
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var showDelete = false

    var body: some View {
        Group {
            if let img = UIImage(data: photo.imageData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
                    .onLongPressGesture { showDelete = true }
                    .confirmationDialog("Delete photo?", isPresented: $showDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) { onDelete() }
                    }
            } else {
                Rectangle()
                    .fill(Color.surface)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
    }
}

// MARK: - Fullscreen Photo

private struct FullscreenPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let photo: ProgressPhoto

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let img = UIImage(data: photo.imageData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(alignment: .trailing, spacing: 6) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, 60)
                .padding(.trailing, 20)
                if !photo.note.isEmpty {
                    Text(photo.note)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.trailing, 20)
                }
                Text(photo.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

// MARK: - Add Photo Sheet

struct AddProgressPhotoSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let preselectedCategory: ProgressPhotoCategory

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var category: ProgressPhotoCategory
    @State private var note = ""
    @State private var date = Date.now

    init(preselectedCategory: ProgressPhotoCategory) {
        self.preselectedCategory = preselectedCategory
        _category = State(initialValue: preselectedCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            if let img = selectedImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.surface)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "camera.badge.plus")
                                            .foregroundStyle(Color.brandCoral)
                                            .imageScale(.large)
                                    )
                            }
                            Text(selectedImage == nil ? "Choose a photo" : "Change photo")
                                .foregroundStyle(Color.brandCoral)
                        }
                    }
                    .onChange(of: selectedItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let img = UIImage(data: data) {
                                selectedImage = img
                            }
                        }
                    }
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ProgressPhotoCategory.allCases) { cat in
                            Label(cat.label, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(3)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.surfaceBase)
            .navigationTitle("Add Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let img = selectedImage,
                              let data = img.jpegData(compressionQuality: 0.7) else { return }
                        let p = ProgressPhoto(imageData: data, category: category, note: note, date: date)
                        ctx.insert(p)
                        dismiss()
                    }
                    .disabled(selectedImage == nil)
                }
            }
        }
    }
}
