module epub.books;

@safe:

import std.conv;
import std.uuid;
import std.experimental.logger;
import cairo.Context;
import cairo.Surface;

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

    /**
     * Preferred fonts for the book's cover.
     *
     * These should be ordered by priority: the first option will be used if possible, falling back
     * to the second, falling back to the third, etc.
     *
     * The last resort is hard-coded as Sans.
     */
    string[] coverFontPreferences;

    /**
     * Target size for generated covers.
     *
     * The defaults are taken from Kindle Direct Publishing's recommendations.
     */
    uint width = 1600, height = 2560;

    /** The name of the program that generated this ebook. */
    string generator;
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
    const(ubyte[]) content;
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

/**
 * Create a cover for this book in SVG format.
 */
Attachment svgCover(Book book)
{
    import std.array : Appender;
    Appender!string s;
    s.reserve(1000);
    s ~= `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <svg width="350" height="475">
        <rect x="10"
            y="10"
            width="330"
            height="455"
            stroke="black"
            stroke-width="3"
            fill="#cceeff"
            stroke-linecap="round"/>
        <text text-anchor="middle"
            x="175"
            y="75"
            font-size="30"
            font-weight="600"
            font-family="serif"
        stroke-width="2" stroke-opacity="0.5" stroke="#000000" fill="#000000">`;
    s ~= book.title;
    s ~= `</text>
        <text text-anchor="middle" x="175" y="135" font-size="15">`;
    s ~= book.author;
    s ~= `</text>
        </svg>
        `;
    return Attachment(
            "cover",
            "cover.svg",
            "image/svg+xml",
            cast(const(ubyte[]))s.data);
}

/**
 * Create a PNG cover for the book.
 *
 * This will fail if you haven't linked in Cairo or if you have a Cairo that doesn't have PNG
 * functions included.
 */
Attachment pngCover(Book book)
{
    import std.file : read, remove;
    auto tmpFileName = "/tmp/" ~ book.id ~ ".png";
    renderPngCover(book, tmpFileName);
    auto content = tmpFileName.read;
    import std.stdio : writefln;
    writefln("cover image generated at %s; read %s bytes", tmpFileName, content.length);
    tmpFileName.remove;
    return Attachment(
            "cover",
            "cover.png",
            "image/png",
            cast(const(ubyte[]))content);
}

public void renderCover(Book book, Surface surface) @trusted
{
    import std.file;
    import std.experimental.logger;
    import cairo.c.types;

    auto context = Context.create(surface);
    context.save;

    context.selectFontFace(
            "Sans",
            CairoFontSlant.NORMAL,
            CairoFontWeight.BOLD);

    foreach (font; book.coverFontPreferences)
    {
        try
        {
            context.selectFontFace(
                    font,
                    CairoFontSlant.NORMAL,
                    CairoFontWeight.BOLD);
            break;
        }
        catch (Exception e)
        {
            infof("failed to select font %s; falling back", font);
        }
    }

    // A nice neutral gray background
    context.rectangle(0, 0, book.width, book.height);
    context.setSourceRgb(0.95, 0.95, 0.95);
    context.fill;
    context.restore;

    // A heavy red border
    context.save;
    context.setSourceRgb(0.55, 0.1, 0.1);
    context.setLineWidth(30);
    auto margin = book.width * 0.05;
    context.rectangle(margin, margin, book.width - (2 * margin), book.height - (2 * margin));

    context.stroke;
    context.restore;

    // Title, author, generator
    context.save;
    auto titleScale = drawText(context, book, book.title, book.height * 0.25, 90);
    drawText(context, book, book.author, book.height * 0.5, titleScale * 0.8);
    if (book.generator)
    {
        drawText(
                context,
                book,
                "Generated by " ~ book.generator,
                book.height * 0.9,
                titleScale * 0.5);
    }

    context.restore;
}

public void renderPngCover(Book book, string filename) @trusted
{
    import cairo.ImageSurface;
    auto surface = ImageSurface.create(CairoFormat.ARGB32, book.width, book.height);
    renderCover(book, surface);
    surface.writeToPng(filename);
}

public void renderSvgCover(Book book, string filename) @trusted
{
    import cairo.SvgSurface;
    auto surface = SvgSurface.create(filename, book.width, book.height);
    renderCover(book, surface);
    surface.flush;
    surface.finish;
}

private double drawText(Context context, Book book, string text, double y, double scale)
    @trusted
{
    // TODO split text onto multiple lines?
    double happyWidth = book.width * 0.8;
    double actualWidth;
    while (scale > 5)
    {
        context.setFontSize(scale);
        cairo_text_extents_t extents;
        context.textExtents(text, &extents);
        actualWidth = extents.width;
        if (actualWidth <= happyWidth)
        {
            auto dx = (book.width - actualWidth) * 0.5;
            infof("writing text %s at size %s at position (%s, %s)", text, scale, dx, y);
            context.setFontSize(scale);
            context.moveTo(dx, y);
            break;
        }
        scale -= 5;
    }

    context.textPath(text);
    context.setSourceRgb(0.2, 0.25, 0.55);
    context.fillPreserve;
    context.setSourceRgb(0, 0, 0);
    context.setLineWidth(scale * 0.025);
    context.stroke;
    return scale;
}
