# epub: make epubs in D

This is a little library to create ebooks in epub format in D.

## Getting it

Add `"epub": "~>1.0.1"` to your dub.json.

## Using it

To create an epub, you first assemble your book, then call `toEpub` on it.

A quick example:

```D
import epub;
void main()
{
    auto book = new Book;
    book.title = "Grunthos the Flatulent";
    book.author = "Ode to a Small Lump of Green Putty";

    book.coverImage = Attachment(
        // file ID
        "cover",
        // filename
        "cover.png",
        // MIME type
        "image/png",
        // content
        import("cover.png"));

    book.chapters ~= Chapter(
        // title
        "The Putty",
        // show in table of contents?
        true,
        // body as XHTML document
        import("poem.xhtml"));
    book.toEpub("putty.epub");
}
```

If you don't want to emit directly to a file, you can call `toEpub` with a ZipArchive from std.zip
instead of a filename.


## Bugs?

Please file any issues at https://github.com/dhasenan/epub/issues !
