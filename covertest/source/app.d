import epub;

void main()
{
    auto b = new Book;
    b.id = "somebook";
    b.title = "Must Go Faster";
    b.author = "Neia Neutuladh";
    b.generator = "covertest";
    b.renderPngCover("cover.png");
    b.renderSvgCover("cover.svg");
}
