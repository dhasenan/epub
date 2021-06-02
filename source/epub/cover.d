/**
 * Cover generation.
 *
 * This requires a dependency on GTK to provide Cairo.
 */
module epub.cover;

import epub.books;
import std.experimental.logger;

@safe:

/**
 * A Cover is a description of what sort of cover to generate for a book.
 */
class Cover
{
    /** Formats you can generate covers in. */
    enum Format
    {
        /// Standard HTML
        html,
        /// SVG image format
        svg,
        /// PNG image format. This is recommended.
        png
    }

    /// The preferred format for this cover. May be ignored.
    Format format = Format.svg;

    /**
     * Preferred fonts for the book's cover.
     *
     * These should be ordered by priority: the first option will be used if possible, falling back
     * to the second, falling back to the third, etc.
     *
     * The last resort is hard-coded as Sans.
     */
    string[] fontPreferences;

    /**
     * Target size for generated covers.
     *
     * The defaults are taken from Kindle Direct Publishing's recommendations.
     */
    uint width = 1600, height = 2560;

    /**
     * The name of the program that generated this ebook.
     *
     * Leave null to omit the generator line.
     */
    string generator;
}

void addTitlePage(ref Book book)
{
    import std.string : format;

    Chapter chapter;
    chapter.title = "Title Page";
    chapter.showInTOC = false;
    book.chapters = [chapter] ~ book.chapters;

    if (book.cover.format == Cover.Format.html)
    {
        chapter.content = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" >
  <head>
    <title>Title Page</title>
    <style type="text/css">
    body {
        text-align: center;
    }
    h1 {
        padding-bottom: 5pt;
        border-bottom: 1pt solid black;
        margin-bottom: 20pt;
    }
    </style>
  </head>
  <body>
    <h1>%s</h1>
    <h3>%s</h3>
  </body>
</html>`.format(book.title, book.author);
    }

    auto coverImage = render(book, book.cover);
    book.attachments ~= coverImage;
    chapter.content = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" >
  <head>
  </head>
  <body>
    <img src="%s" />
  </body>
</html>`.format(coverImage.filename);
}

/**
 * Render the cover into an attachment.
 */
Attachment render(Book book, Cover cover)
{
    final switch (cover.format) with (Cover.Format)
    {
        case html:
            return Attachment.init;
        case png:
            return pngCover(book, cover);
        case svg:
            return svgCover(book, cover);
    }
}

private:

version (Have_gtk_d)
{
    import cairo.Context;
    import cairo.Surface;

    Attachment pngCover(Cover cover)
    {
        import std.file : read, remove, tempDir;
        import std.path : buildPath;

        auto tmpFileName = buildPath(tempDir, book.id ~ ".png");
        renderPngCover(book, cover, tmpFileName);
        auto content = tmpFileName.read;
        tmpFileName.remove;
        return Attachment(
                "cover",
                "cover.png",
                "image/png",
                cast(const(ubyte[]))content);
    }

    void renderCover(Book book, Cover cover, Surface surface) @trusted
    {
        import std.file;
        import std.experimental.logger;
        import cairo.c.types;

        auto context = Context.create(surface);
        context.save;

        // A nice neutral gray background
        context.rectangle(0, 0, cover.width, cover.height);
        context.setSourceRgb(0.95, 0.95, 0.95);
        context.fill;
        context.restore;

        // A heavy red border
        context.save;
        context.setSourceRgb(0.55, 0.1, 0.1);
        context.setLineWidth(30);
        auto margin = cover.width * 0.05;
        context.rectangle(margin, margin, cover.width - (2 * margin), cover.height - (2 * margin));

        context.stroke;
        context.restore;

        // Title, author, generator
        context.save;

        context.selectFontFace(
                "Sans",
                CairoFontSlant.NORMAL,
                CairoFontWeight.BOLD);

        foreach (font; cover.fontPreferences)
        {
            context.selectFontFace(
                    font,
                    CairoFontSlant.NORMAL,
                    CairoFontWeight.BOLD);
            if (context.status == CairoStatus.SUCCESS)
            {
                infof("successfully chose font %s", font);
                break;
            }
            infof("failed to select font %s; falling back", font);
        }

        auto titleScale = drawText(context, cover, book.title, cover.height * 0.25, 90);
        drawText(context, cover, book.author, cover.height * 0.5, titleScale * 0.8);
        if (cover.generator)
        {
            drawText(
                    context,
                    cover,
                    "Generated by " ~ cover.generator,
                    cover.height * 0.9,
                    titleScale * 0.5);
        }

        context.restore;
    }

    /// Visible for testing
    public void renderPngCover(Book book, Cover cover, string filename) @trusted
    {
        import cairo.ImageSurface;
        auto surface = ImageSurface.create(CairoFormat.ARGB32, cover.width, cover.height);
        renderCover(book, cover, surface);
        surface.writeToPng(filename);
    }

    /// Visible for testing
    public void renderSvgCover(Book book, Cover cover, string filename) @trusted
    {
        import cairo.SvgSurface;
        auto surface = SvgSurface.create(filename, cover.width, cover.height);
        renderCover(book, cover, surface);
        surface.flush;
        surface.finish;
    }

    double drawText(Context context, Cover cover, string text, double y, double scale)
        @trusted
    {
        // TODO split text onto multiple lines?
        double happyWidth = cover.width * 0.8;
        double actualWidth;
        while (scale > 5)
        {
            context.setFontSize(scale);
            cairo_text_extents_t extents;
            context.textExtents(text, &extents);
            actualWidth = extents.width;
            if (actualWidth <= happyWidth)
            {
                auto dx = (cover.width - actualWidth) * 0.5;
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
}
else
{

    Attachment pngCover(Book book, Cover cover)
    {
        return svgCover(book, cover);
    }

    Attachment svgCover(Book book, Cover cover)
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
                font-family="`;
        foreach (font; cover.fontPreferences)
        {
            s ~= font;
            s ~= ",";
        }
        s ~= `serif"
                stroke-width="2"
                stroke-opacity="0.5"
                stroke="#000000"
                fill="#000000">`;
        s ~= book.title;
        s ~= `</text>
            <text text-anchor="middle" x="175" y="135" font-size="15">`;
        s ~= book.author;
        s ~= `</text>
            </svg>`;
        return Attachment(
                "cover",
                "cover.svg",
                "image/svg+xml",
                cast(const(ubyte[]))s.data);
    }

}
