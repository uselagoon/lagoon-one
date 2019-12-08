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
      order: ['Home', 'Pages', ['Projects', 'Project', 'Environment', 'Deployments', 'Deployment', 'Backups', 'Tasks', 'Task'], 'Components']
    }),
  },
  a11y: {
    restoreScroll: true,
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
