import React from 'react';
import { PageTasks as Tasks } from '../tasks';

export default {
  component: Tasks,
  title: 'Pages/Tasks',
}

export const Default = () => (
  <p>@TODO: Doesn't work yet. subscribeToMore() causes browser to freeze.</p>
  // <Tasks
  //   router={{
  //     query: {
  //       openshiftProjectName: 'Example',
  //     },
  //   }}
  // />
);
