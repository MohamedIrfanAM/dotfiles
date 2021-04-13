// an example to create a new mapping `ctrl-y`
mapkey("<Ctrl-y>", "Show me the money", function () {
  Front.showPopup(
    "a well-known phrase uttered by characters in the 1996 film Jerry Maguire (Escape to close)."
  );
});

// an example to replace `T` with `gt`, click `Default mappings` to see how `T` works.
map("gt", "T");

// yf to copy url from current tab
map("yf", "ya");

// Mapping Tab left and right
map("J", "E");
map("K", "R");

// Open tabs, links, history search in new tab
mapkey("O", "#8Open a URL", function () {
  Front.openOmnibar({ type: "URLs", extra: "getAllSites" });
});
// Open tabs, links, history, searhc in currnet tab
map("o", "go");

// Edit current url refresh
map("ge", ";U");

// Edit current url and open in new tab
map("gE", ";u");

// History back
map("H", "S");

// History forward
map("L", "D");

// Ctrl+ jk to cycle through omnibar suggesons
cmap("<Ctrl-j>", "<Tab>");
cmap("<Ctrl-k>", "<Shift-Tab>");

// Mapping jk and kj as vim escape keys
aceVimMap("jk", "<Esc>", "insert");
aceVimMap("kj", "<Esc>", "insert");

// Hind on left of the word
settings.hintAlign = "left";

// F for opening in new tab
mapkey("F", "#1Open a link in active new tab", function () {
  Hints.create("", Hints.dispatchMouseClick, { tabbed: true, active: true });
});

// alt + f for opening multiple links
mapkey("<Alt-f>", "#1Open multiple links in a new tab", function () {
  Hints.create("", Hints.dispatchMouseClick, { multipleHits: true });
});

// new tab
mapkey("t", "#3Open newtab", function () {
  tabOpenLink("chrome://newtab/");
});

// Undo close
map("u", "X");

// an example to remove mapkey `Ctrl-i`
unmap("<Ctrl-i>");

// DuckDuckgo as default search engine
settings.defaultSearchEngine = "d";

// Increasing stepsize
settings.scrollStepSize = 100;

//Omnibar focus on first candidate
settings.focusFirstCandidate = true;

//Search tabs with omnibar
settings.tabsThreshold = 0;
// changing hind characters
Hints.characters = "asdfghjkl;";

// ctrl+d and ctrl + u to scroll like vim
map("<Ctrl-d>", "d");
map("<Ctrl-u>", "e");

// P to open url from clipboard in new tab
mapkey(
  "P",
  "#7Open selected link or link from clipboard in new tab",
  function () {
    if (window.getSelection().toString()) {
      tabOpenLink(window.getSelection().toString());
    } else {
      Clipboard.read(function (response) {
        tabOpenLink(response.data);
      });
    }
  }
);

// p to open url from clipboard in cureent tab
mapkey(
  "p",
  "#7Open selected link or link from clipboard in current tab",
  function () {
    if (window.getSelection().toString()) {
      window.location.href = window.getSelection().toString();
    } else {
      Clipboard.read(function (response) {
        window.location.href = response.data;
      });
    }
  }
);
// Map B for bookmark
mapkey("b", "#8Open a bookmark in current tab", function () {
  Front.openOmnibar({ type: "Bookmarks", tabbed: false });
});
mapkey("B", "#8Open a bookmark in new tab", function () {
  Front.openOmnibar({ type: "Bookmarks", tabbed: true });
});

// get out of text field
imap("kj", "<Esc>");
0;
imap("jk", "<Esc>");

// custom theme for hinds
Hints.style(
  "border: solid 3px #0080FF; color:#efe1eb; background: initial; background-color: #0080FF;"
);
Hints.style(
  "border: solid 3px #0080FF; padding:0px;  background: #0080FF",
  "text"
);

// set theme
settings.theme = `
.sk_theme {
    font-family: Input Sans Condensed, Charcoal, sans-serif;
    font-size: 10pt;
    background: #24272e;
    color: #abb2bf;
}
.sk_theme tbody {
    color: #fff;
}
.sk_theme input {
    color: #d0d0d0;
}
.sk_theme .url {
    color: #61afef;
}
.sk_theme .annotation {
    color: #56b6c2;
}
.sk_theme .omnibar_highlight {
    color: #528bff;
}
.sk_theme .omnibar_timestamp {
    color: #e5c07b;
}
.sk_theme .omnibar_visitcount {
    color: #98c379;
}
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
    background: #303030;
}
.sk_theme #sk_omnibarSearchResult ul li.focused {
    background: #3e4452;
}
#sk_status, #sk_find {
    font-size: 20pt;
}
:root {
    --theme-ace-bg:#2e3440ab; /*Note the fourth channel, this adds transparency*/
    --theme-ace-bg-accent:#536479;
    --theme-ace-fg:#afb0bd;
    --theme-ace-fg-accent:#afb0bd;
    --theme-ace-cursor:#7d95ab;
    --theme-ace-select:#458588;
}
#sk_editor {
    height: 50% !important; /*Remove this to restore the default editor size*/
    background: var(--theme-ace-bg) !important;
}
.ace_dialog-bottom{
    border-top: 1px solid var(--theme-ace-bg) !important;
}
.ace-chrome .ace_print-margin, .ace_gutter, .ace_gutter-cell, .ace_dialog{
    background: var(--theme-ace-bg-accent) !important;
}
.ace-chrome{
    color: var(--theme-ace-fg) !important;
}
.ace_gutter, .ace_dialog {
    color: var(--theme-ace-fg-accent) !important;
}
.ace_cursor{
    color: var(--theme-ace-cursor) !important;
}
.normal-mode .ace_cursor{
    background-color: var(--theme-ace-cursor) !important;
    border: var(--theme-ace-cursor) !important;
}
.ace_marker-layer .ace_selection {
    background: var(--theme-ace-select) !important;
} `;
// click `Save` button to make above settings to take effect.
