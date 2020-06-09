Moon Invaders
=============

A _Space Invaders_ emulator made with [LÖVE](https://love2d.org).

![Moon Invaders](screenshot.png)

Features
--------

* Persistent high scores that are saved between runs!
* Authentic-looking CRT shaders
* Customizable colored gel overlay
* Backdrop support
* Sound support (for user-provided sound files)

Controls
--------

| Key        | Action              |
|------------|---------------------|
| Arrow keys | Move (both players) |
| Space      | Fire (both players) |
| C          | Insert coin         |
| 1          | Start 1 player mode |
| 2          | Start 2 player mode |
| T          | Tilt                |

How to run
----------

If you're on Windows or macOS, the easiest is to download the latest release from the [Releases](https://github.com/tobiasvl/moon-invaders/releases) page.

If you're on Linux, clone or download this repository (remember the submodules!). You will also need the following:

* [LÖVE 11.3](https://love2d.org); might be in your distro's package repository (it might work with earlier versions of LÖVE, but no guarantees)
* [love-imgui](https://github.com/slages/love-imgui) (optional; displays a menu on the top)

Setup
-----

You will then need to supply the emulator with ROM files, and some additional optional assets, in order to play.

For all the following files, put them in the following locations:

* Windows, one of the following:
  * The `assets` directory inside the game's folder (containing the `.exe` file)
  * `C:\Users\<your username>\AppData\Roaming\Moon Invaders\assets\`
* Linux, one of the following:
  * `$XDG_DATA_HOME/love/Moon\ Invaders/assets/`
  * `~/.local/share/love/Moon\ Invaders/assets/`
* macOS: `/Users/<your username>/Library/Application Support/LOVE/Moon Invaders/assets/`

<h3>ROM</h3>

You will need to supply your own Space Invaders ROM files. There are four files:

* `invaders.e`
* `invaders.f`
* `invaders.g`
* `invaders.h`

<h3>Images</h3>

These are optional:

* `background.png`: Background image
* `overlay.png`: Colored gel overlay, see the default one for the format

<h3>Sounds</h3>

The sound files found online have different file names, so two variations per file are supported. These are optional.

* `0.wav` / `ufo_highpitch.wav` (UFO flying)
* `1.wav` / `shoot.wav` (player firing)
* `2.wav` / `explosion.wav` (player death)
* `3.wav` / `invaderkilled.wav` (alien death)
* `4.wav` / `fastinvader1.wav` (alien fleet movement "heartbeat")
* `5.wav` / `fastinvader2.wav`
* `6.wav` / `fastinvader3.wav`
* `7.wav` / `fastinvader4.wav`
* `8.wav` / `ufo_lowpitch.wav` (UFO death)
* `9.wav` / `extendedplay.wav` (extra life)

Note that at least one website that provides these files for download have swapped the names o `shoot.wav` and `invaderkilled.wav`.

I have also been unable to find `9.wav`/`extendedplay.wav` online, so those names are just guesses. In port/bit sequence, it should actually have been `4.wav`. If anyone has found the sound file online, please let me know!
