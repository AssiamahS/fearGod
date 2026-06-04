import SwiftUI

struct ChapterListView: View {
    let book: Book
    @State private var chapterCount = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...max(1, chapterCount), id: \.self) { chapter in
                    NavigationLink(destination: ReadingView(book: book, chapter: chapter)) {
                        Text("\(chapter)")
                            .font(.title3.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(book.nameEn)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if chapterCount == 0 {
                chapterCount = BibleDatabase.shared.chapterCount(bookId: book.id)
            }
        }
    }
}
