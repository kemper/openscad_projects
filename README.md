## Openscad projects

```bash
brew install openscad

# build all .scad files across all subdirectories
make build

# build only one subdirectory
make build dir=shelf

# build a single file
make build_one file=src/shelf/shelf.scad

# generate a png preview for visual verification
make preview file=src/shelf/shelf.scad
```

## Previews

- [Shelf designs](docs/shelf-previews.md)

## Notes

You will have to fiddle with apple settings until it allows you to run openscad as an app.
Be sure to preview rendering it in openscad, or use a web version of openscad such <https://makerworld.com/en/makerlab/parametricModelMaker>
