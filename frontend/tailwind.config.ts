import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        'oled-black': '#000000',
        'surface': '#0a0a0a',
        'card': '#111111',
        'border-dark': '#222222',
      },
    },
  },
  plugins: [],
};

export default config;
