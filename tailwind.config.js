module.exports = {
  plugins: [
    require('daisyui')
  ],
  daisyui: {
    themes: [
      {
        signdocumate: {
          'color-scheme': 'light',
          // Taken from the logo: the deep green of the tile carries primary
          // actions (white text sits on it at a comfortable contrast), and the
          // lime of the check badge is the accent. Lime is far too bright to
          // hold white text, so it is never a primary fill — it marks success
          // and highlights, against dark green text.
          primary: '#0F3D34',
          'primary-content': '#FFFFFF',
          secondary: '#1B5A4C',
          'secondary-content': '#FFFFFF',
          accent: '#D4F23C',
          'accent-content': '#0F3D34',
          neutral: '#1F2A27',
          'neutral-content': '#FFFFFF',
          'base-100': '#FFFFFF',
          'base-200': '#F1F5F2',
          'base-300': '#DEE7E1',
          'base-content': '#10201C',
          info: '#1B5A4C',
          success: '#15803D',
          warning: '#B45309',
          error: '#B91C1C',
          '--rounded-btn': '1.9rem',
          '--tab-border': '2px',
          '--tab-radius': '.5rem'
        }
      }
    ]
  }
}
