import epub;

void main()
{
    auto b = new Book;
    b.id = "somebook";
    b.title = "Must Go Faster";
    b.author = "Neia Neutuladh";
    Cover cover = {
        generator: "covertest",
        book: b,
        fontPreferences: ["Droid Sans Mono", "Inconsolata"]
    };
    cover.renderPngCover("cover.png");
    cover.renderSvgCover("cover.svg");
}
