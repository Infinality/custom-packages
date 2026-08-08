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

## Chromium Based Browsers

### Subpixel Filtering

This is not a package for Fedora but a script that should run fine on most distros to adjust the LCD filtering.  I'm working with LLMs to attempt to create binary patches for chromium to fix some of the subpixel rendering related things they broke or made unconfigurable at runtime, but the script that exists in the chromium folder is just for applying the Gibson LCD filter to subpixel rendered text across all chromium based browsers (Chrome, Chromium, Edge, Vivaldi, Opera, Brave, etc.)  See the details of what it does below, in the Freetype section regarding the Gibson filter.

The script started out as a simple bgrep command followed by a dd to perform the replacement, but I had Claude fill it in with useful options.  See the script for usage, but basically, the simplest invocation of it is to close all chromium based browsers, then run (without parameters) with sudo or as root to patch them.  This will of course need to be run every time the browser(s) is updated.  I found the original script to do this online, perhaps over 10 years ago, but I can't find it anymore to give credit to the original author for the concept and execution.

### Mimicking the Grayscale FIR Filter

For chromium based browsers, even when using LCD rendering (via flags like this: `--disable-font-subpixel-positioning --disable-prefer-compositing-to-lcd-text --enable-lcd-text --enable-features=AllowLCDTextWithFilter`), chromium will still revert to grayscale frequently when compositing is required, meaning you're going to get grayscale text on some spots on many sites.  Chromium based browsers don't fully use the system's freetype for the grayscale rendering path, meaning the Grayscale FIR filter patch for freetype (below) can't be leveraged.  But the filter can be mimicked through CSS text-shadow, and applied globally or per-site by the StyleBot extension.  This dramatically smooths out the striking visual differences of the grayscale text (particularly the non-uniformity of stems) compared to LCD rendered text, at the expense of sharpness.  Because this is CSS, it can often also be used in Electron apps as long as there is a way to apply custom CSS.

This (imperfectly) mimics what FIR filtering does, by cloning the text at a very low opacity, then shifting the clones to both the left and right side of the text.  The reason it is imperfect it because it's not truly distributing the intensities across neighboring pixels;  It's *adding* more intensity on both sides.  This can be compensated for by reducing the opacity of the original text using `-webkit-text-fill-color`, but this noticeably lightens the text with anything below ~90%.  In general, expect heavier looking text.

```
body {
  text-shadow:
    -0.666667px 0 0 rgb(from currentColor r g b / 7.5%),
    0.666667px 0 0 rgb(from currentColor r g b / 7.5%);

  -webkit-text-fill-color:
    rgb(from currentColor r g b / 97.5%);
}
```


The percentages in the text-shadow can be adjusted up and down for a stronger or lighter effect, with 7.5% / 97.5% being the best middle point of the tradeoffs.

In Stylebot options, you would add a new style, and apply it either globally, with  `*` (not recommended unless using `--disable-lcd-text` which globally disables subpixel rendering), or on a per-site basis with specific domains like this:  `gemini.google.com, chatgpt.com, github.com, teams.cloud.microsoft, *.elastic.co`.  You can also create additional rules, using stronger or lighter values, to apply to other sites that need different amounts of smoothing.  One drawback here is that there is no way to differentiate between LCD and grayscale text;  it applies to the site and element(s) you choose, regardless.  But often, for sites imapacted by grayscale text, most of the site needs treatment, and the spots that don't, which use subpixel rendering, are an acceptable sacrifice to unnecessarily smooth further.

Notably, since this is done in CSS, you can use this on *any* platform, including Windows, to smooth out some pretty rough text that happens by default.


## Freetype

https://copr.fedorainfracloud.org/coprs/infinality/freetype/

Freetype with patches and settings I like:

- Bytecode Interpreter enabled
- No emboldening in the vertical direction when emboldening is requested
- LCD Filter Patch
    - Gibson LCD filter instead of default LCD filter
    - Extra Smooth LCD filter instead of light LCD filter
- Grayscale FIR filter similar to the LCD filter but for grayscale

### LCD Filter Patch

The patch overrides the default and light filters with a smooth and extra smooth filter, and allows configuration of these values with environment variables.  Available in the freetype directory.

#### Gibson LCD Filter

By default, the Gibson filter replaces the default LCD filter in ftlcdfil.c with one that spreads the intensities more broadly across subpixels, resulting in a smoother, less "color fringey", and more uniform appearance.

This:
`{ 0x08, 0x4d, 0x56, 0x4d, 0x08 }`

Becomes this:
`{ 0x1c, 0x38, 0x56, 0x38, 0x1c }`

See the chromium folder for a script that is able to patch chromium-based browser binaries, which do not use the system's freetype.  (Requires:  bgrep)

#### Extra Smooth LCD Filter

By default, the Extra Smooth LCD filter replaces the light LCD filter in ftlcdfil.c with one that spreads the intensities even more broadly across subpixels, resulting in a smoother appearance than the Gibson LCD filter.  Replacing the stock "light" filter with this made sense since it's doubtful many people even use it.  The use case might be for programs, fonts, or font sizes that need more filtering that the default.

This:
`{ 0x00, 0x55, 0x56, 0x55, 0x00 }`

Becomes this:
`{ 0x20, 0x38, 0x49, 0x38, 0x20 }`

This can be leveraged in fontconfig rules this way:

```
  <!-- lcddefault, lcdlight, lcdnone, lcdlegacy -->
  <edit mode="assign" name="lcdfilter">
   <const>lcdlight</const>
  </edit>
```
#### Configuration

These values can be controlled with environment variables

```
export FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT=1c,38,56,38,1c
export FREETYPE_LCD_FILTER_WEIGHTS_LIGHT=00,1D,C6,1D,00
```

Some other values to try with FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT and FREETYPE_LCD_FILTER_WEIGHTS_LIGHT:

```
Minimum:     00,00,FF,00,00    (For reference - No filtering)
Very Sharp:  00,55,56,55,00    (Freetype "light" filtering)
Sharp:       04,51,56,51,04
Medium:      08,4D,56,4D,08    (Freetype "default" filtering)
Smooth:      10,45,56,45,10
Smooth:      1c,38,56,38,1c    (Gibson filter)
Very Smooth: 20,38,49,38,20    (Extra Smooth filter)
Maximum:     33,33,33,33,33    (For reference - Fully distributed)
```

##### FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT

Environment variable that controls the LCD filter values for freetype's "default" filter.  Leveraged in fontconfig like this:

```
  <!-- lcddefault, lcdlight, lcdnone, lcdlegacy -->
  <edit mode="assign" name="lcdfilter">
   <const>lcddefault</const>
  </edit>
```

##### FREETYPE_LCD_FILTER_WEIGHTS_LIGHT

Environment variable that controls the LCD filter values for freetype's "light" filter.  Leveraged in fontconfig like this:

```
  <!-- lcddefault, lcdlight, lcdnone, lcdlegacy -->
  <edit mode="assign" name="lcdfilter">
   <const>lcdlight</const>
  </edit>
```

With neither variable set:

```
unset FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT
unset FREETYPE_LCD_FILTER_WEIGHTS_LIGHT
```

you get the patched defaults:

```
DEFAULT = 1c,38,56,38,1c
LIGHT   = 20,38,49,38,20
```

You could then experiment:

```
FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT=10,40,70,40,10 some-program
```

or:

```
FREETYPE_LCD_FILTER_WEIGHTS_LIGHT=00,40,80,40,00 some-program
```

It also accepts:

```
FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT='0x1c, 0x38, 0x56, 0x38, 0x1c'
```

For both, an invalid value such as:

```
FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT='1c,38,999,38,1c'
```

or:

```
FREETYPE_LCD_FILTER_WEIGHTS_DEFAULT='1c,38,56'
```

simply falls back to:

```
1c,38,56,38,1c
```

rather than partially changing the filter.

Note that if the sum of the weights is more than `0xFF` (255 decimal) you may see artifacts.


See the chromium folder for a script that is able to patch chromium-based browser binaries, which do not use the system's freetype.  (Requires:  bgrep)

### Grayscale FIR Filter Patch

Of particular note is the Grayscale FIR Filter, available in the freetype directory.  As far as I know, no such patch has ever been developed, and it would have been better to have 15 years ago.  I developed it with the help of ChatGPT, to apply essentially the same logic that the standard LCD filter does to subpixels, but to whole pixels.  The need arose because often you will encounter grayscale text that looks very different than its subpixel equivalent, with a mix of sharp and blurry vertical stems.  Like the LCD filter does with subpixels, the grayscale filter splits the intensities across neighboring pixels, which makes it slightly blurry but substantially more uniform and nearly indistinguishable from subpixel rendering except upon close examination (at least on my 4k monitors).  This is always the tradeoff with rasterized fonts- blurry but uniform vs. sharp but uneven.  Admittedly, the need for a patch like this dwindles as resolutions increase, however I still notice problems even on 4k monitors, and I'm a font-rendering and smoothness maxxer.

Unfortunately, the place you most often encounter grayscale text is in chromium-based browsers and electron apps, due to chromium's aggressive reduction to grayscale during compositing steps, and since chromium brought most font rendering into its codebase, this patch will have no effect for such applications.  The difference *can* be seen desktop applications that use freetype directly, like firefox, thunderbird, gtk and Qt apps, and calibre, which renders its reader text in grayscale (via qtwebengine) and can't be changed to use subpixel rendering through flags, settings, or environment variables.  Firefox and Thunderbird still have instances where text is rendered in grayscale though, even when subpixel rendering is set in about:config.

It's implemented as a 5-tap filter, but practically, only 3 would ever be needed.  It's also implemented in 2 rendering paths:
 - ftsmooth.c (impacts firefox, thunderbird, gtk)
 - ftoutln.c (qtwebengine, others)

It's enabled by default with the values specified below but can be adjusted with the environment variables:

```
export FREETYPE_GRAY_FILTER=1
export FREETYPE_GRAY_FILTER_PPEM=22
export FREETYPE_GRAY_FILTER_WEIGHTS=00,10,E0,10,00
export FREETYPE_GRAY_FILTER_WEIGHTS_FINAL=00,1D,C6,1D,00
```

For serif fonts like EB Garamond in calibre, I found that less aggressive filtering was good at smaller point sizes but not at higher ones, meaning it made sense to add a cutoff point where the filter changes to something stronger.  Serif fonts typically need stronger values than sans serif fonts, and having environment variables lets you customize launchers per-program to suit the need.  Many people would find that setting both FREETYPE_GRAY_FILTER_WEIGHTS and FREETYPE_GRAY_FILTER_WEIGHTS_FINAL to the same value looks just fine, but the variables are there for tweaking.

Some other values to try:

```
Very Light:  00,08,F0,08,00
Light:       00,10,E0,10,00
Medium:      00,15,D6,15,00
Strong:      00,1D,C6,1D,00
Very Strong: 00,25,B6,25,00
```


#### FREETYPE_GRAY_FILTER

 - 1 turns it on (default)
 - 0 turns it off

#### FREETYPE_GRAY_FILTER_PPEM

For the ftsmooth.c rendering path, this controls which filter values are used at particular point sizes.  Setting it to 22 means:

```
ppem <= 22  →  00,10,E0,10,00  (FREETYPE_GRAY_FILTER_WEIGHTS)
ppem >  22  →  00,1D,C6,1D,00  (FREETYPE_GRAY_FILTER_WEIGHTS_FINAL)
```

This has no effect in the ftoutln.c path because it doesn't know about glyph ppem.  In that case, the FREETYPE_GRAY_FILTER_WEIGHTS_FINAL is always used.


#### FREETYPE_GRAY_FILTER_WEIGHTS

Grayscale filter weights that will be used **at or below** the specified point size in the ftsmooth.c render path.  The values should typically add up to 0x100 or 256 in decimal, but don't have to if you want to add or remove weight.  Typically the first and last values should remain at 00.  This has no effect in the ftoutln.c path because it doesn't know about glyph ppem.  In that case, the FREETYPE_GRAY_FILTER_WEIGHTS_FINAL is always used.


#### FREETYPE_GRAY_FILTER_WEIGHTS_FINAL

Grayscale filter weights that will be used **above** the specified point size in the ftsmooth.c render path.  The values should typically add up to 0x100 or 256 in decimal, but don't have to if you want to add or remove weight.  Typically the first and last values should remain at 00.  The weights specified for this are always used in the ftoutln.c path.




