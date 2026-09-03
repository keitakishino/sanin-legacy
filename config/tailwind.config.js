module.exports = {
  content: [
    './app/views/**/*.{html,html.erb}',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js',
    './app/components/**/*.{rb,html.erb}'
  ],
  theme: {
    extend: {
      colors: {
        // Design tokens
        accent: 'oklch(48% 0.14 264)',
        'accent-hover': 'oklch(40% 0.14 264)',
        'accent-soft': 'oklch(94% 0.025 264)',
        offer: 'oklch(52% 0.12 231)',
        'offer-soft': 'oklch(95% 0.02 231)',
        'offer-text': 'oklch(38% 0.1 231)',
        want: 'oklch(52% 0.1 150)',
        'want-soft': 'oklch(95% 0.025 150)',
        'want-text': 'oklch(38% 0.09 150)',
        success: 'oklch(48% 0.12 165)',
        'success-soft': 'oklch(94% 0.035 165)',
        warning: 'oklch(50% 0.12 75)',
        'warning-soft': 'oklch(95% 0.045 75)',
        'neutral-soft': 'oklch(93% 0.006 90)',
      },
    },
  },
  plugins: [],
}
