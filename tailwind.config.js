module.exports = {
  plugins: [
    require('daisyui')
  ],
  daisyui: {
    themes: [
      {
        signflow: {
          'color-scheme': 'light',
          // Brand blue. Primary actions route through this via .base-button
          // and btn-primary; `neutral` stays a true dark so text-neutral
          // labels and table headings remain readable rather than turning blue.
          primary: '#2563EB',
          'primary-content': '#ffffff',
          secondary: '#1D4ED8',
          'secondary-content': '#ffffff',
          accent: '#0EA5E9',
          'accent-content': '#ffffff',
          neutral: '#1E293B',
          'neutral-content': '#ffffff',
          'base-100': '#ffffff',
          'base-200': '#F1F5F9',
          'base-300': '#E2E8F0',
          'base-content': '#0F172A',
          info: '#0EA5E9',
          success: '#16A34A',
          warning: '#F59E0B',
          error: '#DC2626',
          '--rounded-btn': '1.9rem',
          '--tab-border': '2px',
          '--tab-radius': '.5rem'
        }
      }
    ]
  }
}
