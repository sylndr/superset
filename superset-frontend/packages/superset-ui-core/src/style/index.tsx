/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
import emotionStyled from '@emotion/styled';
import { useTheme as useThemeBasic } from '@emotion/react';
import createCache from '@emotion/cache';

export {
  css,
  keyframes,
  jsx,
  ThemeProvider,
  CacheProvider as EmotionCacheProvider,
  withTheme,
} from '@emotion/react';
export { default as createEmotionCache } from '@emotion/cache';

declare module '@emotion/react' {
  // eslint-disable-next-line @typescript-eslint/no-empty-interface
  export interface Theme extends SupersetTheme {}
}

export function useTheme() {
  const theme = useThemeBasic();
  // in the case there is no theme, useTheme returns an empty object
  if (Object.keys(theme).length === 0 && theme.constructor === Object) {
    throw new Error(
      'useTheme() could not find a ThemeContext. The <ThemeProvider/> component is likely missing from the app.',
    );
  }
  return theme;
}

export const emotionCache = createCache({
  key: 'superset',
});

export const styled = emotionStyled;

const defaultTheme = {
  borderRadius: 4,
  colors: {
    text: {
      label: '#a5cfbe',
      help: '#737373',
    },
    primary: {
      base: '#009B5D',
      dark1: '#008d55',
      dark2: '#007144',
      light1: '#2eaa7a',
      light2: '#71bf95',
      light3: '#99d3bc',
      light4: '#b9ead5',
      light5: '#d1f3ea',
    },
    secondary: {
      base: '#002d5d',
      dark1: '#004690',
      dark2: '#001c3a',
      dark3: '#1b222a',
      light1: '#33577d',
      light2: '#6c96c4',
      light3: '#9fb7d6',
      light4: '#b3c9e4',
      light5: '#cbe0f4',
    },
    grayscale: {
      base: '#4b5f74',
      dark1: '#2b3743',
      dark2: '#002d5d',
      light1: '#A4B4C5',
      light2: '#c9dae9',
      light3: '#f2f3f5',
      light4: '#F7F7F7',
      light5: '#FFFFFF',
    },
    error: {
      base: '#C82256',
      dark1: '#99395C',
      dark2: '#5a0922',
      light1: '#ED7286',
      light2: '#fdeaf0',
    },
    warning: {
      base: '#F57B56',
      dark1: '#7F3F21',
      dark2: '#7B3E2B',
      light1: '#F89C80',
      light2: '#FFF2EC',
    },
    alert: {
      base: '#FCC550',
      dark1: '#BD943C',
      dark2: '#7d6300',
      light1: '#FEE2A8',
      light2: '#fef9e6',
    },
    success: {
      base: '#01CE7C',
      dark1: '#41A77E',
      dark2: '#017044',
      light1: '#7DDEAF',
      light2: '#e8fbf3',
    },
    info: {
      base: '#ABC922',
      dark1: '#80971A',
      dark2: '#687a14',
      light1: '#D5E491',
      light2: '#e6f0ba',
    },
  },
  opacity: {
    light: '10%',
    mediumLight: '35%',
    mediumHeavy: '60%',
    heavy: '80%',
  },
  typography: {
    families: {
      sansSerif: `'Inter', Helvetica, Arial`,
      serif: `Georgia, 'Times New Roman', Times, serif`,
      monospace: `'Fira Code', 'Courier New', monospace`,
    },
    weights: {
      light: 200,
      normal: 400,
      medium: 500,
      bold: 600,
    },
    sizes: {
      xxs: 9,
      xs: 10,
      s: 12,
      m: 14,
      l: 16,
      xl: 21,
      xxl: 28,
    },
  },
  zIndex: {
    aboveDashboardCharts: 10,
    dropdown: 11,
    max: 3000,
  },
  transitionTiming: 0.3,
  gridUnit: 4,
  brandIconMaxWidth: 37,
};

export type SupersetTheme = typeof defaultTheme;

export interface SupersetThemeProps {
  theme: SupersetTheme;
}

export const supersetTheme = defaultTheme;
