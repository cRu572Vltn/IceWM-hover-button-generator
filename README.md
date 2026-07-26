## Preview
![Hover preview](https://i.ibb.co/fG0DrhtR/hoverpreview.gif)
## Requirements
**As for the script itself, none.** Every Unix system already ships `/bin/sh`, `sed`, `cut`, `tr`, `tail`, `grep`, `cat`, `printf`, `basename`, `mv` and `rm`. These are part of the POSIX standard and have been on every Linux/BSD system for decades. There are no extra dependencies to install unless your system doesn't include those for some reason.

**For themes, this is XPM-only.** This script only handles `.xpm` button images. IceWM also supports `.png` for buttons, but while I have never personally come across a theme that uses PNGs instead of XPMs for that, I'm sure they exist somewhere, probably recently made themes. If a theme uses PNG images, this script will not work for it. Converting a PNG-based theme would require ImageMagick or similar tools. You can convert PNG files to XPM, run the script, then convert them back to PNG if you want.

## Usage
Process a single theme directory:

`icewm_hover_final.sh ~/.icewm/themes/YourThemeWithNoHoverSupport`

Batch process all themes at once (while it is possible, avoid it if you are not sure how your individual themes handle hovering):

`icewm_hover_final.sh ~/.icewm/themes/*`

The script will
- Create `*O.xpm` (hover) images for every button that has an `*A.xpm` (active variant) file
- Add or update `RolloverButtonsSupported=1` in `default.theme`
After running, restart IceWM or switch away and back to the theme.

## How it works
As you probably know, IceWM button images (`*A.xpm` in this case) are split vertically, the top half is the normal look, the bottom half is the pressed (active/"lit") look. The script copies the bottom half into both halves of a new `*O.xpm` image, so the button appears "lit" when the mouse hovers over it.

As you may have guessed, this hover is extremely **rudimentary**. When you hover over a button it will look "pressed", lit up, highlighted, or whichever look the theme author chose for the pressed state. But when you *actually click* the button, it will still look the same. Most people don't understand that **hover** and **pressed** are not the same thing. There is no darkened or extra-deep effect on click, which is what you would *probably* expect.

A proper three state system would need a normal look (not hovered, not clicked), a hover look (mouse over, not clicked) and a pressed look (mouse down/clicked, what people call "Active" in IceWM).

Most themes for this WM only ship two states split into one image (not hovered, not clicked, and clicked), so the best we can do is reuse the pressed look for hover. A true darkened/click effect would require either a dedicated pressed image or a real time darkening filter, which isn't feasible to do automatically.

Why can't we just darken the image automatically, you ask? Because themes use wildly different button formats, weird XPMs, transparent areas, gradients, rounded buttons, buttons surrounded by specific gaps, buttons that depend on hardcoded color values on `default.theme` and so on... Darkening the whole image would also darken gaps around the button, making it look like a muddy rectangle. There is no universal way to do it.

The pressed state, on the other hand, is indeed standardized, every IceWM theme splits its `*A.xpm` button into normal (top) and pressed (bottom) halves, so we can reliably reuse the bottom half for hover.

I still personally recommend the classic IceWM flat look (`RolloverButtonsSupported=0`) where buttons only change when pressed, with no hover effects at all. It's cleaner and more consistent. I made this just because some people can't live without hover visual feedback. Even if darkening to achieve a "pressed" look isn't possible, this should already save you a lot of work in case you want to make proper pressed images yourself.
