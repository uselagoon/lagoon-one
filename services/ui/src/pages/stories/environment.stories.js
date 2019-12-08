import React from 'react';
import LinkTo from '@storybook/addon-links/react';
import { PageEnvironment as Environment } from '../environment';

export default {
  component: Environment,
  title: 'Pages/Environment',
}

// @TODO Fix Internal Server Error on initial load.
export const Default = () => (
  <Environment
    router={{
      query: {
        openshiftProjectName: 'enhancedinfomediaries-pr-100',
      },
    }}
  />
);

export const TODO = () => (
  <>
    <h4>Known bug:</h4>
    <p>
      If the
      {' '}
      <LinkTo
        kind="Pages/Deployment"
        story="Default"
        className="hover-state"
      >
        <code>Deployment</code> page
      </LinkTo>
      {' '}
      is viewed in Storybook before the <code>Environment</code> page, then
      the <code>Environment</code> page shows an "Internal Server Error". Reload
      the page and it will appear properly.
    </p>
  </>
);
TODO.story = {
  name: '@TODO',
};
