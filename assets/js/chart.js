// Wrapper around apexcharts so we can make things
// cleanly LiveView-compatible.
import ApexCharts from "apexcharts";
import deepMerge from "deepmerge";

import resolveConfig from 'tailwindcss/resolveConfig'
import tailwindConfig from '../tailwind.config'

const fullConfig = resolveConfig(tailwindConfig)

const chartDefaults = {
  chart: {
    type: "area",
    background: "transparent",
    animations: {
      enabled: false,
    },
    toolbar: {
      show: false,
    },
    zoom: {
      enabled: false,
    },
    height: "300px",
    width: "100%",
  },
  theme: {
    mode: localStorage.getItem('metrist.theme')
  },
  colors: [
    fullConfig.theme.colors.primary["400"],
    fullConfig.theme.colors.secondary["500"],
  ],
  grid: {
    borderColor: fullConfig.theme.colors.secondary["200"],
    clipMarkers: false,
    yaxis: {
      lines: {
        show: false,
      },
    },
  },
  dataLabels: {
    enabled: false,
  },
  xaxis: {
    type: "datetime",
    tooltip: {
      enabled: false,
    },
  },
  yaxis: {
    min: 0,
    labels: {
      minWidth: 1,
      formatter: (v) => `${Math.round(v)} ms`,
    },
    forceNiceScale: true,
  },
  legend: {
    show: false,
  },
  tooltip: {
    x: {
      format: "MMM dd yyyy, HH:mm:ss",
    },
  },
};

class Chart {
  constructor(ctx, series, annotations) {
    const opts = deepMerge(chartDefaults, {
      series,
      annotations: {
        yaxis: annotations.y ?? [],
        xaxis: annotations.x ?? [],
      },
    });
    this.chart = new ApexCharts(ctx, opts);
    this.chart.render();

    document.addEventListener('toggle-dark-mode', (e) => {
      this.chart.updateOptions({
        theme: {
          mode: e.detail
        }
      })
    })
  }

  updateAnnotations(annotations) {
    this.chart.clearAnnotations()
    this.chart.updateOptions({
      annotations: {
        xaxis: applyThemeToAnnotations(annotations.x ?? []),
        yaxis: applyThemeToAnnotations(annotations.y ?? [])
      }
    })
  }
}

export const applyThemeToAnnotations = (annotations) => {
  return annotations.map(annotation => ({
    ...annotation,
    borderColor: applyThemeColor(annotation.borderColor),
    fillColor: applyThemeColor(annotation.fillColor),
    label: {
      ...annotation.label,
      borderColor: applyThemeColor(annotation.label.borderColor),
      style: {
        ...annotation.label.style,
        background: applyThemeColor(annotation.label.style.background)
      }
    }
  }))
}

const applyThemeColor = (declaration) => {
  if (typeof declaration !== 'object') return declaration
  return fullConfig.theme.colors[declaration.variant][declaration.shade]
}

export default Chart;
