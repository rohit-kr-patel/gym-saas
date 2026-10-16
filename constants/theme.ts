export const colors = {
  background: '#0B1426',
  surface: '#121E36',
  surfaceRaised: '#1A2A4A',
  border: '#27385C',
  text: '#F3F6FC',
  textMuted: '#9AA9C7',
  accent: '#F5A524',
  accentText: '#0B1426',
  danger: '#F2555A',
  success: '#3DD598',
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
} as const;

export const radius = {
  sm: 8,
  md: 12,
  lg: 16,
} as const;

export const typography = {
  title: { fontSize: 24, fontWeight: '700' as const },
  heading: { fontSize: 18, fontWeight: '600' as const },
  body: { fontSize: 16, fontWeight: '400' as const },
  caption: { fontSize: 13, fontWeight: '400' as const },
} as const;

/** Minimum touch target for gym-floor use (Android guideline is 48dp). */
export const TOUCH_TARGET = 56;
