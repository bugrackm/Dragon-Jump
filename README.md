# Dragon Jump

A casual 2D vertical platformer inspired by Doodle Jump: guide a brave dragon ever upward across platforms, dodge enemies, breathe fire and grab coins.

**Play in your browser:** https://bugrackm.github.io/Dragon-Jump/

## Controls

| Action | Keyboard | Touch |
| --- | --- | --- |
| Move | Left / Right arrows | Hold the left/right half of the screen, or tilt |
| Double jump | Double-press Space | Double tap |
| Glide | Double-press and hold Space | Double tap and hold |
| Fire breath | F | FIRE button |
| Back / pause | Esc | Pause button |

## Tech Stack

- **Engine:** Godot 4.7 (Compatibility renderer)
- **Language:** GDScript
- **Target:** Web (GitHub Pages)

## Running locally

Open the project in Godot 4.7 and press Play.

## Web build

The live build is published from the `gh-pages` branch. To rebuild it (Web export templates for 4.7.1 must be installed):

```sh
godot --headless --export-release "Web" build/web/index.html
```

The preset is single-threaded on purpose: GitHub Pages cannot send the COOP/COEP headers that threaded web builds need.

## Contributing

Issues and pull requests are welcome.

## Credits

Third-party assets and their licenses are listed in [docs/CREDITS.md](docs/CREDITS.md).
