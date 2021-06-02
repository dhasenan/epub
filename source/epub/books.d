module epub.books;

@safe:

import std.conv;
import std.uuid;
import std.experimental.logger;

/**
 * A Book is the object model for an epub file.
 */
class Book
{
    /** The ID of the book.
     * If you don't specify one, we will create it for you.
     */
    string id;

    /// The title of the book.
    string title;

    /// The author of the book.
    string author;

    /// The fileid of the cover image, which should be present as an attachment.
    string coverid;

    /// The chapters of the book, in the order to present them.
    Chapter[] chapters;

    /// Attachments (extra files) to include in the epub.
    Attachment[] attachments;

    /// The attachment to use as a cover image.
    Attachment coverImage;

    import epub.cover;

    /// The cover page to generate. If not set, no cover page is generated.
    Cover cover;
}

/**
 * An Attachment is a file to include in the epub document.
 *
 * For instance, if you want to include an image or stylesheet in the epub,
 * you should create an Attachment for it.
 */
struct Attachment
{
    /// The ID of the file. Generated if you don't provide it.
    string fileid;

    /// The path in the epub to this file.
    string filename;

    /// The mime type of the file.
    string mimeType;

    /// The file contents.
    const(ubyte)[] content;
}

/**
 * A Chapter is like an Attachment, but it appears in the main content of
 * the book.
 *
 * Chapter content must be a valid XHTML document. The content type is
 * always "application/xhtml+xml". If you specify invalid XHTML, it is
 * unlikely that your epub will work.
 */
struct Chapter
{
    /// The title of this chapter, if it's in the table of contents.
    string title;

    /// Whether to show this chapter in the table of contents.
    bool showInTOC;

    /// The contents of this chapter.
    const(char)[] content;

    package int index;

    package string fileid()
    {
        return `chapter` ~ index.to!string;
    }

    package string filename()
    {
        return `chapter` ~ index.to!string ~ `.html`;
    }

    package string id()
    {
        return title.sha1UUID().to!string;
    }
}

