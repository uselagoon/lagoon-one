// Import the mocked next.config before importing decorators.
import config from './next.mock-config';
import requireContext from 'require-context.macro';
import { addDecorator, addParameters, configure } from '@storybook/react';
import { withA11y } from '@storybook/addon-a11y';
import { withKnobs } from '@storybook/addon-knobs';
import storySort from './storySort';
import withApiConnection from './decorators/ApiConnection';
import withGlobalStyles from './decorators/GlobalStyles';
import lagoonTheme from './lagoonTheme';

addParameters({
  options: {
    theme: lagoonTheme,
    showRoots: true,
    storySort: storySort({
      method: 'alphabetical',
      order: ['Home', 'Pages', ['Projects', 'Project', 'Environment', 'Deployments', 'Deployment', 'Backups', 'Tasks', 'Task'], 'Components']
    }),
  },
  a11y: {
    options: {
      restoreScroll: true,
    },
  },
  viewport: {
    viewports: {
      tiny: {
        name: 'Small mobile',
        styles: {
          width: '450px',
          height: '675px',
        },
        type: 'mobile',
      },
      xs: {
        name: 'Large mobile',
        styles: {
          width: '600px',
          height: '900px',
        },
        type: 'mobile',
      },
      tablet: {
        name: 'Tablet',
        styles: {
          width: '768px',
          height: '1024px',
        },
        type: 'tablet',
      },
      desktop: {
        name: 'Desktop',
        styles: {
          width: '960px',
          height: 'calc(100% - 20px)',
        },
        type: 'desktop',
      },
      wide: {
        name: 'Wide desktop',
        styles: {
          width: '1200px',
          height: 'calc(100% - 20px)',
        },
        type: 'desktop',
      },
      extraWide: {
        name: 'Extra-wide desktop',
        styles: {
          width: '1400px',
          height: 'calc(100% - 20px)',
        },
        type: 'desktop',
      },
    },
  },
});

// Add global decorators.
addDecorator(withA11y);
addDecorator(withKnobs);
addDecorator(withApiConnection);
addDecorator(withGlobalStyles);

const loaderFn = () => {
  const allExports = [];

  // Automatically import all *.stories.js in these folders.
  const storiesSrc = requireContext('../src', true, /\.stories\.js$/);
  storiesSrc.keys().forEach(fname => allExports.push(storiesSrc(fname)));
  allExports.push(require('./Home.stories'));

  return allExports;
};
configure(loaderFn, module);
