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


## Cover images

If you link gtk-d (for libcairo), you can generate a cover.

First, create a `Cover` object:

```D
import epub.cover;
Cover cover = {
    book: myAwesomeBook,
    generator: "lovely-epub-gen-2.0.7",
    width: 1600,
    height: 2560,
    fontPreferences: ["Brioso Pro", "Garamond"],
    format: Cover.Format.png
};
```

Then render it:

```D
book.coverImage = cover.render;
```


## License

This project is licensed under the Microsoft Public License. If you wish to include this in a
project you are working on and its license is incompatible, please file an issue detailing your
project and what license you need.
