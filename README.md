# custom-packages
Customized Packages for Fedora and RHEL Variants



### Freetype

https://copr.fedorainfracloud.org/coprs/infinality/freetype/

Freetype with patches I like:

- Bytecode Interpreter enabled
- Gibson LCD filter instead of default LCD filter
- Extra weight Gibson LCD filter instead of light LCD filter
- Grayscale FIR filter similar to the LCD filter but for grayscale
- No emboldening in the vertical direction when emboldening is requested

#### Grayscale FIR Filter

Of particular note is the Grayscale FIR Filter.  As far as I know, no such patch has ever been developed or available.  I developed it with the help of ChatGPT to apply essentially the same logic that the standard LCD filter does to subpixels, but to whole pixels.  The need arose because often you will encounter grayscale text that looks very different than its subpixel equivalent, with a mix of sharp and blurry stems.  The filter splits the intensities across neighboring pixels, which makes it slightly blurry but substantially more uniform and nearly indistinguishable from subpixel rendering except upon examination.

Unfortunately, the place you most often encounter grayscale text is in chromium-derived browsers and electron apps, due to their aggressive reduction to grayscale during compositing.  Chromium brought most font rendering into its codebase, meaning that this patch will have no effect for those applications.  The difference can be seen in ftview however.

#### Gibson LCD Filter

The Gibson filter replaces the default LCD filter in ftlcdfil.c with one that spreads the intensities more broadly across subpixels, resulting in a smoother, less "color fringey" appearance.

This:
`{ 0x08, 0x4d, 0x56, 0x4d, 0x08 }`

Becomes this:
`{ 0x1c, 0x38, 0x56, 0x38, 0x1c }`

See the chromium folder for a script that is able to patch chromium-based browser binaries, which do not use the system's freetype.

#### Extra Weight Gibson LCD Filter

The Gibson filter replaces the light LCD filter in ftlcdfil.c with one that spreads the intensities more broadly across subpixels, *and adds extra weight*, resulting in a smoother, less "color fringey" appearance.

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

See the chromium folder for a script that is able to patch chromium-based browser binaries, which do not use the system's freetype.

### bgrep

https://copr.fedorainfracloud.org/coprs/infinality/bgrep/

Binary grep utility that returns locations of matching hex values.  This is simply a Fedora package of upstream:  https://github.com/tmbinc/bgrep


### Better Blur DX

https://copr.fedorainfracloud.org/coprs/infinality/kwin-effects-better-blur-dx/

This kwin effect allows additional customization of the blur parameters.  This is simply a Fedora package of upstream:   https://github.com/xarblu/kwin-effects-better-blur-dx


### Fontforge

https://copr.fedorainfracloud.org/coprs/infinality/fontforge/

This is a build of Fontforge that has Truetype debugging enabled, but is otherwise identical to the fedora version.

