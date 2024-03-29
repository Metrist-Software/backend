Sync Design System From Figma and Tailwind Config
----

[design-token]: https://www.figma.com/community/plugin/888356646278934516/Design-Tokens "Design Tokens"
[metrist-design-system]: https://www.figma.com/file/1aj4l2tbqUTZlDfZGwMFvn/Metrist-Design-System "Metrist Design System"


The [Metrist Design System](metrist-design-system) Figma file is the source of truth for the CSS properties we use in the backend. In order to export the CSS properties we use the [Design Token][design-token] plugin and process it with [Styled Dictionary](https://amzn.github.io/style-dictionary/#/) to turn it to a JSON that Tailwind config can read.

## Setup

- Create a figma account. Make sure you can view this file [Metrist Design System](metrist-design-system)
- Install the [Design Tokens][design-token] plugin. We use this to export the Figma file to a Design Token JSON file
- Make sure all NPM packages are installed by running `npm install --prefix assets`


## Files

* `assets/figma/input.json` - JSON file generated by [Design Tokens][design-token] plugin
* `assets/figma/generated-properties.json` - A generated file that tailwind config reads

## Exporting Design Token to Tailwind JSON
- Goto [Metrist Design System](metrist-design-system)
- `Figma icon` -> `Plugins` -> `Export Design Token File` -> Save it to `assets/figma/input.json`
- Run `npm run figma-to-tailwind --prefix assets`
