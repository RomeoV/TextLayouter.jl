using TextLayouter

text1 = "The quick brown fox jumps over the lazy dog. Over the lazy dog jumps the quick brown fox."
text2 = "For most users, you should install the 'Current stable release', and whenever Julia releases a new version of the current stable release, you should update your version of Julia. Note that any code you write on one version of the current stable release will continue to work on all subsequent releases."
row_width = 25
@time res = layout_text(text1, row_width; print_summary=true);
display_solution(res..., row_width; print_width=true)
