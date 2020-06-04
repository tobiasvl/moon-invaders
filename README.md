Moon Invaders
=============

A _Space Invaders_ emulator made with [LÖVE](https://love2d.org).

![Moon Invaders](screenshot.png)

Features
--------

* Persistent high scores
* Authentic-looking shaders
* Customizable colored gel overlay
* Backdrop support
* Sound support (TBA)

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

Setup
-----

You will need to supply the emulator with ROM files, and some additional optional assets, in order to play.

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

Not supported yet.
