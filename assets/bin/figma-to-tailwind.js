#!/usr/bin/env node
/**
 * This scripts takes the design token JSON & converts them to a JSON that can be read by tailwind config
 * 
 *  npm run figma-to-tailwind
 *  # Or if you're in the backend path
 *  npm run figma-to-tailwind --prefix assets
 */
const { TinyColor } = require('@ctrl/tinycolor');
const { kebabCase } = require('lodash');
const path = require('path');

const figmaPath = path.join(__dirname, "..", "figma");

const StyleDictionary = require('style-dictionary').extend({
    source: [
        path.join(figmaPath, "input.json")
    ],
    platforms: {
        "web/json": {
            transformGroup: "css",
            files: [
                {
                    destination: path.join(figmaPath, "generated-properties.json"),
                    format: "json/nested-kebab"
                }
            ],
            transforms: ["webGradient", "webShadow"],
        }
    }
});

// webGradient and webShadow taken from https://github.com/lukasoppermann/design-tokens/tree/main/examples/libs/web
StyleDictionary.registerTransform({
    name: "webGradient",
    type: 'value',
    matcher: function (token) {
        return token.type === 'custom-gradient'
    },
    transformer: function ({ value }) {
        const stopsString = value.stops.map(stop => {
            return `${new TinyColor(stop.color).toRgbString()} ${stop.position * 100}%`
        }).join(', ')
        if (value.gradientType === 'linear') {
            return `linear-gradient(${value.rotation}deg, ${stopsString})`
        }
        if (value.gradientType === 'radial') {
            return `radial-gradient(${stopsString})`
        }
    }
});

StyleDictionary.registerTransform({
    name: "webShadow",
    type: "value",
    matcher: function (token) {
        return token.type === "custom-shadow" && token.value !== 0
    },
    transformer: function ({ value }) {
        return `${value.shadowType === "innerShadow" ? "inset " : ''}${value.offsetX}px ${value.offsetY}px ${value.radius}px ${value.spread}px ${new TinyColor(value.color).toRgbString()}`
    }
});

// Taken from https://github.com/amzn/style-dictionary/blob/main/lib/common/formatHelpers/minifyDictionary.js#L29
//  and modified the map keys so it'll use kebabcase
function minifyDictionary(obj) {
    if (typeof obj !== 'object' || Array.isArray(obj)) {
        return obj;
    }

    if (obj.hasOwnProperty("value")) {
        return obj.value;
    } 
    const toRet = {};
    for (const name in obj) {
        if (obj.hasOwnProperty(name)) {
            toRet[kebabCase(name)] = minifyDictionary(obj[name]);
        }
    }
    return toRet;
}

StyleDictionary.registerFormat({
    name: "json/nested-kebab",
    formatter: function ({ dictionary }) {
        return JSON.stringify(minifyDictionary(dictionary.tokens), null, 2);
    }
})

StyleDictionary.buildAllPlatforms();