module epub.output;

import epub.books;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.string;
import std.uuid;
import std.zip;

/**
 * Convert the given book to epub and save it to the given path.
 */
void toEpub(Book book, string path) {
    auto zf =  new ZipArchive();
    toEpub(book, zf);
    path.write(zf.build());
}

/**
 * Convert the given book to epub. Store it in the given zip archive.
 */
void toEpub(Book book, ZipArchive zf) {
    if (book.id == null) {
        book.id = randomUUID().to!string;
    }
    foreach (i, ref c; book.chapters) {
        c.index = cast(int)i + 1;
    }
    foreach (ref attachment; book.attachments) {
        if (attachment.fileid == null) {
            attachment.fileid = randomUUID().to!string;
        }
    }

    // mimetype should be the first entry in the zip.
    // Unfortunately, this doesn't seem to happen...
    // On the other hand, most readers seem okay with mimetype not being
    // in its proper place.
    save(zf, "mimetype", "application/epub+zip");
    save(zf, "META-INF/container.xml", container_xml);
    writeZip!contentOpf(zf, "content.opf", book);
    writeZip!tocNcx(zf, "toc.ncx", book);
    foreach (chapter; book.chapters) {
        save(zf, chapter.filename, chapter.content);
    }
    foreach (attachment; book.attachments) {
        save(zf, attachment.filename, attachment.content);
    }
}

private:

enum container_xml = import("container.xml");

void save(ZipArchive zf, string name, const char[] content) {
    save(zf, name, cast(const(ubyte[]))content);
}

void save(ZipArchive zf, string name, const(ubyte[]) content) {
    auto member = new ArchiveMember();
    member.name = name;
    // std.zip isn't const-friendly
    member.expandedData = cast(ubyte[])content;
    zf.addMember(member);
}

void writeZip(alias method)(ZipArchive zf, string name, Book book) {
    save(zf, name, method(book));
}

string contentOpf(Book book) {
    Appender!string s;
    s.reserve(2000);
    s ~= `<?xml version='1.0' encoding='utf-8'?>
        <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
        <metadata xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:opf="http://www.idpf.org/2007/opf" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:language>en</dc:language>
        <dc:creator>Unknown</dc:creator>
        <dc:title>`;
    s ~= book.title;
    s ~= `</dc:title>
        <meta name="cover" content="cover"/>
        <dc:identifier id="uuid_id" opf:scheme="uuid">`;
    s ~= book.id;
    s ~= `</dc:identifier>
        </metadata>
        <manifest>`;
    foreach (chapter; book.chapters) {
        s ~= `
            <item href="`;
        s ~= chapter.filename;
        s ~= `" id="`;
        s ~= chapter.fileid;
        s ~= `" media-type="application/xhtml+xml"/>`;
    }
    s ~= `
        <item href="subtex.css" id="subtexcss" media-type="text/css"/>
        <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>
        <item href="titlepage.xhtml" id="titlepage" media-type="application/xhtml+xml"/>
    </manifest>
    <spine toc="ncx">
        <itemref idref="titlepage"/>`;
    foreach (chapter; book.chapters) {
        s ~= `
            <itemref idref="`;
        s ~= chapter.fileid;
        s ~= `"/>`;
    }
    s ~= `
    </spine>
    <guide>`;
    if (book.coverid) {
        auto coverRange = book.attachments.find!(x => x.fileid == book.coverid);
        if (!coverRange.empty) {
            auto cover = coverRange.front;
            s ~= `
        <reference href="`;
            s ~=
        `" title="Title Page" type="cover"/>`;
        }
    }
    s ~= `
    </guide>
</package>
        `;
    return s.data;
}

string tocNcx(Book book) {
    Appender!string s;
    s.reserve(1000);
    s ~= `<?xml version='1.0' encoding='utf-8'?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="en">
        <head>
        <meta content="`;
    s ~= book.id;
    s ~= `" name="dtb:uid"/>
        <meta content="2" name="dtb:depth"/>
        <meta content="bookmaker" name="dtb:generator"/>
        <meta content="0" name="dtb:totalPageCount"/>
        <meta content="0" name="dtb:maxPageNumber"/>
        </head>
        <docTitle>
        <text>`;
    s ~= book.title;
    s ~= `</text>
        </docTitle>
        <navMap>`;
    foreach (i, chapter; book.chapters) {
        s ~= `
            <navPoint id="ch`;
        s ~= chapter.id.replace("-", "");
        s ~= `" playOrder="`;
        s ~= (i + 1).to!string;
        s ~= `">
            <navLabel>
            <text>`;
        s ~= chapter.title;
        s ~= `</text>
            </navLabel>
            <content src="`;
        s ~= chapter.filename;
        s ~= `"/>
            </navPoint>`;
    }
    s ~= `
        </navMap>
        </ncx>`;
    return s.data;
}

string cover(Book book) {
    Appender!string s;
    s.reserve(1000);
    s ~= `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <svg width="350" height="475">
        <rect x="10" y="10" width="330" height="455" stroke="black" stroke-width="3" fill="#cceeff" stroke-linecap="round"/>
        <text text-anchor="middle" x="175" y="75" font-size="30" font-weight="600" font-family="serif"
        stroke-width="2" stroke-opacity="0.5" stroke="#000000" fill="#000000">`;
    s ~= book.title;
    s ~= `</text>
        <text text-anchor="middle" x="175" y="135" font-size="15">`;
    s ~= book.author;
    s ~= `</text>
        </svg>
        `;
    return s.data;
}

void htmlPrelude(OutRange)(const Book book, ref OutRange sink, bool includeStylesheets, void delegate(ref OutRange) bdy) {
    sink.put(`<?xml version='1.0' encoding='utf-8'?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
            <link rel="stylesheet" href="subtex.css" type="text/css"/>
            `);
    if (includeStylesheets && "stylesheet" in book.info) {
        foreach (stylesheet; book.info["stylesheet"]) {
            sink.put(`<link rel="stylesheet" href="`);
            sink.put(stylesheet);
            sink.put(`" type="text"/>
                    `);
        }
    }
    sink.put(`
            <title>`);
    sink.put(book.info["title"][0]);
    sink.put(`</title>
    </head>
    <body>
            `);
    bdy(sink);
    sink.put(`
    </body>
</html>`);
}
