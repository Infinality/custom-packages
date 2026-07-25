# custom-packages
Customized Packages for Fedora and RHEL Variants



## bgrep

https://copr.fedorainfracloud.org/coprs/infinality/bgrep/

Binary grep utility that returns locations of matching hex values.  This is simply a Fedora package of upstream:  https://github.com/tmbinc/bgrep


## Better Blur DX

https://copr.fedorainfracloud.org/coprs/infinality/kwin-effects-better-blur-dx/

This kwin effect allows additional customization of the blur parameters.  This is simply a Fedora package of upstream:   https://github.com/xarblu/kwin-effects-better-blur-dx


## Fontforge

https://copr.fedorainfracloud.org/coprs/infinality/fontforge/

This is a build of Fontforge that has Truetype debugging enabled, but is otherwise identical to the fedora version.  Note that there is likely an upstream bug that prevents the debugger from fully working (says "no instrs" when run).  The same issue happens on the Windows version, but doesn't happen on the 2023 version, which is what makes me think it's an upstream regression.

## Chromium Browsers

This is not a package for Fedora but a script that should run fine on most distros.  I have plans for several binary patches for chromium to fix some of the things they broke or made unconfigurable at runtime, but the one that exists in the chromium folder is for applying the Gibson LCD filter to subpixel rendered text across all chromium based browsers (Chrome, Chromium, Edge, Vivaldi, Opera, Brave, etc.)  The script started out as a simple bgrep command followed by a dd to perform the replacement, but I had Claude fill it in with useful options.  See the script for usage, but basically, the simplest invocation of it is to close all browsers, then run (without parameters) with sudo or as root to patch all chomium based browsers.  This will of course need to be run every time the browser(s) is updated.  The original script to do this was found online, perhaps over 10 years ago, but I can't find the original anymore to give credit to the original author for the concept.


## Freetype

https://copr.fedorainfracloud.org/coprs/infinality/freetype/

Freetype with patches I like:

- Bytecode Interpreter enabled
- Gibson LCD filter instead of default LCD filter
- Extra weight Gibson LCD filter instead of light LCD filter
- Grayscale FIR filter similar to the LCD filter but for grayscale
- No emboldening in the vertical direction when emboldening is requested

### Gibson LCD Filter

The Gibson filter replaces the default LCD filter in ftlcdfil.c with one that spreads the intensities more broadly across subpixels, resulting in a smoother, less "color fringey" appearance.

This:
`{ 0x08, 0x4d, 0x56, 0x4d, 0x08 }`

Becomes this:
`{ 0x1c, 0x38, 0x56, 0x38, 0x1c }`

See the chromium folder for a script that is able to patch chromium-based browser binaries, which do not use the system's freetype.  (Requires:  bgrep)

### Extra Weight Gibson LCD Filter

The Extra-Weight Gibson filter replaces the light LCD filter in ftlcdfil.c with one that spreads the intensities more broadly across subpixels, *and adds extra weight*, resulting in a smoother, heavier, and less "color fringey" appearance.  Replacing the stock "light" filter with this made sense since it's doubtful many people even use it.

This:
`{ 0x00, 0x55, 0x56, 0x55, 0x00 }`

Becomes this:
`{ 0x1c, 0x38, 0x61, 0x38, 0x1c }`

This can be leveraged in fontconfig rules this way:

```
  <!-- lcddefault, lcdlight, lcdnone, lcdlegacy -->
  <edit mode="assign" name="lcdfilter">
   <const>lcdlight</const>
  </edit>
```

See the chromium folder for a script that is able to patch chromium-based browser binaries, which do not use the system's freetype.  (Requires:  bgrep)

### Grayscale FIR Filter

Of particular note is the Grayscale FIR Filter.  As far as I know, no such patch has ever been developed or available.  I developed it with the help of ChatGPT to apply essentially the same logic that the standard LCD filter does to subpixels, but to whole pixels.  The need arose because often you will encounter grayscale text that looks very different than its subpixel equivalent, with a mix of sharp and blurry stems.  The filter splits the intensities across neighboring pixels, which makes it slightly blurry but substantially more uniform and nearly indistinguishable from subpixel rendering except upon examination (at least on my 4k monitors).

Unfortunately, the place you most often encounter grayscale text is in chromium-derived browsers and electron apps, due to their aggressive reduction to grayscale during compositing steps.  Chromium brought most font rendering into its codebase, meaning that this patch will have no effect for those applications.  The difference can be seen desktop applications that use freetype directly, e.g. calibre, which renders its reader text in grayscale (qtwebengine), and also firefox, thunderbird, gtk, etc.

It's implemented as a 5-tap filter, but practically, only 3 would ever be needed.  It's also implemented in 2 rendering paths:
 - ftsmooth.c (impacts firefox, thunderbird, gtk)
 - ftoutln.c (qtwebengine, others)

It's enabled by default with the values specified below but can be adjusted with the environment variables:

```
export FREETYPE_GRAY_FILTER=1
export FREETYPE_GRAY_FILTER_PPEM=22
export FREETYPE_GRAY_FILTER_WEIGHTS=00,15,D6,15,00
export FREETYPE_GRAY_FILTER_WEIGHTS_FINAL=00,25,B6,25,00
```

I found that less aggressive filtering was good at smaller point sizes but not at higher ones, meaning it made sense to add a cutoff point where the filter changes to something stronger.


#### FREETYPE_GRAY_FILTER

1 turns it on (default)
0 turns it off

#### FREETYPE_GRAY_FILTER_PPEM

For the ftsmooth.c rendering path, this controls which filter values are used at particular point sizes.  Setting it to 22 means:

```
ppem <= 22  →  00,15,D6,15,00  (FREETYPE_GRAY_FILTER_WEIGHTS)
ppem >  22  →  00,25,B6,25,00  (FREETYPE_GRAY_FILTER_WEIGHTS_FINAL)
```

This has no effect in the ftoutln.c path because it doesn't know about glyph ppem.  In that case, the FREETYPE_GRAY_FILTER_WEIGHTS_FINAL is always used.


#### FREETYPE_GRAY_FILTER_WEIGHTS

Grayscale filter weights that will be used **at or below** the specified point size in the ftsmooth.c render path.  The values should typically add up to 0x100 or 256 in decimal, but don't have to if you want to add or remove weight.  Typically the first and last values should remain at 00.  This has no effect in the ftoutln.c path because it doesn't know about glyph ppem.  In that case, the FREETYPE_GRAY_FILTER_WEIGHTS_FINAL is always used.


#### FREETYPE_GRAY_FILTER_WEIGHTS_FINAL

Grayscale filter weights that will be used **above** the specified point size in the ftsmooth.c render path.  The values should typically add up to 0x100 or 256 in decimal, but don't have to if you want to add or remove weight.  Typically the first and last values should remain at 00.  The weights specified for this are always used in the ftoutln.c path.




