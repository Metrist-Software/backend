const defaultTheme = require('tailwindcss/defaultTheme');
const colors = require('tailwindcss/colors');
const figmaProperties = require('./figma/generated-properties.json');
const { backgroundColor, invert } = require('tailwindcss/defaultTheme');
var _ = require('lodash')
var flattenColorPalette = require('tailwindcss/lib/util/flattenColorPalette').default

/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: 'class',
  content: [
    '../lib/*_web.ex',
    '../lib/*_web/**/*.*ex',
    './js/**/*.js',
    '../deps/petal_components/**/*.*ex'
  ],
  safelist: [
    'green-shade',
    'yellow-shade',
    'red-shade',
    'bg-green-shade',
    'bg-yellow-shade',
    'bg-red-shade',
    'bg-healthy',
    'bg-issues',
    'bg-degraded',
    'bg-down',
    'border-green-shade',
    'border-yellow-shade',
    'border-blue-shade',
    'border-red-shade',
    'border-healthy',
    'border-issues',
    'border-degraded',
    'border-down',
    'bg-gray-500',
    'border-gray-500',
    'link-app-banner'
  ],
  theme: {
    // exclude 2xl breakpoint
    screens: Object.fromEntries(
      Object.entries(defaultTheme.screens).filter(([key, _]) => {
        return key !== "2xl";
      })
    ),

    colors: {
      ...colors,
      transparent: 'transparent',
      current: 'currentColor',

      secondary: colors.slate,
      primary: colors.green,
      danger: colors.red,
      warning: colors.amber,
      success: colors.lime,
      info: colors.sky,
      disabled: colors.slate,

      gray: colors.zinc,
      teal: colors.teal,
      red: colors.red,
      yellow: colors.amber,
      green: colors.lime,
      white: colors.white,
      purple: colors.purple,
      blue: colors.sky,
    },

    borderColor: (theme) => ({
      ...theme('colors'),
      // DEFAULT: theme('colors.gray.400'),
    }),

    extend: {
      fontFamily: {
        'lato': ['lato', 'sans-serif'],
        'roboto': ['roboto', 'sans-serif'],
        'inter': ['inter', 'sans-serif'],
        'noto-sans': ['NotoSans', 'Lucida Grande', 'Lucida Sans Unicode', 'sans-serif']
      },
      screens: {
        print: { raw: "print" },
      },
      colors: {
        // Spread the palette here so that we can access
        //  the palette colors easily
        ...Object.fromEntries(Object.entries(figmaProperties.color.palette).map(translateHexColor)),
        ...Object.fromEntries(Object.entries(figmaProperties.color.alert).map(translateHexColor)),
        text: figmaProperties.color.text,
        structure: figmaProperties.color.structure,
      },
      backgroundImage: {
        ...figmaProperties.gradient.gradient,
      },
      typography: (theme) => ({
        DEFAULT: {
          css: {
            color: theme("black"),
            a: {
              color: theme("colors.primary.500"),
              fontWeight: "inherit",
              textDecoration: "none",
              "&:visited": { color: theme("colors.primary.700") },
              "&:hover,&:focus": { textDecoration: "underline" },
            },
            h1: { fontWeight: "400" },
            h2: { fontWeight: "400" },
            h3: { fontWeight: "400" },
            h4: { fontWeight: "400" },
            blockquote: { color: theme("colors.gray.700") },
            strong: { color: theme("colors.gray.700") },
            code : { color: theme("colors.pink.700"), backgroundColor: theme("colors.gray.100"), padding: '5px', fontWeight: 'normal' },
            'code::before': {
              content: '""',
            },
            'code::after': {
              content: '""',
            },
          },
        },

        dark: {
          css: {
            color: theme("colors.gray.100"),
            li: {
              "&::before": { color: theme("colors.gray.100") },
            },
            h1: { color: theme("colors.gray.100") },
            h2: { color: theme("colors.gray.100") },
            h3: { color: theme("colors.gray.100") },
            h4: { color: theme("colors.gray.100") },
            h5: { color: theme("colors.gray.100") },
            h6: { color: theme("colors.gray.100") },
            blockquote: { color: theme("colors.gray.400") },
            strong: { color: theme("colors.gray.400") },
            code : { color: theme("colors.pink.700"), padding: '5px', fontWeight: 'normal' },
            'code::before': {
              content: '""',
            },
            'code::after': {
              content: '""',
            },
          },
        },

        docs: {
          css: {
            h1: { fontSize: "250%" },
            h2: { fontSize: "200%" },
            h3: { fontSize: "150%" },
            h4: { fontSize: "125%" },
            pre: {
              "background-color": theme("colors.secondary.700"),
            },
          },
        },

        banner: {
          css: {
            img: {
              display: "inline",
              margin: "0",
              height: "2rem"
            },
            svg: {
              display: "inline",
              margin: "0",
              height: "1rem"
            },
            p: {
              margin: "0"
            }
          }
        }
      }),

      width: {
        'fit': 'fit-content'
      }
    },

    container: {
      center: true,
    },
  },
  plugins: [
    // Commented out = stuff from the old Vue app we don't need (yet)
    require("@tailwindcss/typography"),
    // require("@tailwindcss/forms"),
    // require("@tailwindcss/aspect-ratio"),
  ],
};

// Need to translate hex colours into functions that can take opacity values and return a css rgba() function
function translateHexColor([name, hex]) {
  let [, r, g, b] = hex.match(/#(..)(..)(..)/)
  r = parseInt(r, 16)
  g = parseInt(g, 16)
  b = parseInt(b, 16)

  const fn = ({ opacityVariable, opacityValue }) =>{
    if (opacityValue !== undefined) {
      return `rgba(${r}, ${g}, ${b}, ${opacityValue})`
    }
    if (opacityVariable !== undefined) {
      return `rgba(${r}, ${g}, ${b}, var(${opacityVariable}, 1))`
    }
    return `rgb(${r}, ${g}, ${b})`
  }

  return [name, fn]
}
