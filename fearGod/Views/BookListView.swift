import SwiftUI

struct BookListView: View {
    @State private var books: [Book] = []
    @State private var searchText = ""

    private var otBooks: [Book] { books.filter { $0.testament == 0 && matches($0) } }
    private var ntBooks: [Book] { books.filter { $0.testament == 1 && matches($0) } }

    @ViewBuilder
    private func bookSection(title: String, books: [Book]) -> some View {
        if !books.isEmpty {
            Section(title) {
                ForEach(books) { book in
                    NavigationLink(destination: ChapterListView(book: book)) {
                        BookRow(book: book)
                    }
                }
            }
        }
    }

    private func matches(_ b: Book) -> Bool {
        searchText.isEmpty || b.nameEn.localizedCaseInsensitiveContains(searchText)
            || b.nameTwi.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        NavigationStack {
            List {
                bookSection(title: "Old Testament", books: otBooks)
                bookSection(title: "New Testament", books: ntBooks)
            }
            .navigationTitle("Twi Bible")
            .searchable(text: $searchText, prompt: "Search books…")
            .onAppear {
                if books.isEmpty {
                    books = BibleDatabase.shared.allBooks()
                }
            }
        }
    }
}

private struct BookRow: View {
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.nameEn)
                .font(.body)
            Text(book.nameTwi)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
