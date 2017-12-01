#!/usr/local/bin/node

const request = require('../utils/request');
const renderIndicator = require('../utils/renderIndicator');
const config = require('../utils/config');
const getRepoNameFromRepoURL = require('../utils/getRepoNameFromRepoURL');

const PR_ICON_BASE64= 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAgCAYAAAAIXrg4AAAAAXNSR0IArs4c6QAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAVlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KTMInWQAAAn1JREFUSA3tlk9OFEEYxRthoUGCrkR2SpAtC+/F2sQ4iZkDSMIdnGQijDtWbL0AF2BHwIgmQ1AQ8P2q681U91T3DMG48iVv6vX3t6q6u3qKosQDDfNRM6CxpZjThW1b0qvRib0VaeHHioSGfRSx7krfik9jkJvGy/ywIfNAPI1EYwMLoou/k6b4iZhOhCbEZVdDoXORxOtI9FB0E8miI2KH38QX4lKkhhE8mZFhT4qknvgsEo3tswjei1xfiTeRNIHH4hfxjUhDUGnCTC9FihtoCh6JO1H/1khx7E2k2WsRhCbsHcH3BRP8JTKxgziy3eEB+CRBk764EonGxs0GuS06k/2rSHFiWd3PqD9oBNz4Yl38LhJ0EYnGhs/oSGCH7P1LkT1/Lu6L2FkF46FYwaau3J0ANDYwy2O6pjjy2BZGHuNlcYRFKd4BnBCNDfBsQz8ZXWli/KJJFk9Etsv5rDD4wx7p4qHoApJBY+P9ACSyx9y0tyITeCRyHwB2aBAf4AYk11G3OYnVbItemWed5uMLSLva1ja6GHlu2BZfWVZrYM1ZX13NPb686wrGmTOq/w2mbtQ/26Jco5ytaca52GCzg7OHc8RAY5sVjfluwKnprxFF0T5J0yMEXwr72vJnOq49kbS4bRT/IfJmZ4/73ejsa1yJRJPA9xp4puVV+WsbMcTm8qkd/j3kvsl8gzk1/fdkdIDJZo2PGGL5XBpoag69TDv+9hgORC/xo6rTGfZEnAMReDvKq/LXNmKIJaeeH7a47Y/Xq7JW9tT16omZ+seNIGbCfkK0i3umMk3Avrb8yvK5ab6pVHOBicqJIY1pzGe5aSDaW5DUapSN+X8AUQa8vvuT+nkAAAAASUVORK5CYII=';

function fetchPRs(organization) {
  return request(organization, { path: '/search/issues?q=type:pr+assignee:ascariandrea+state:open' })
    .then(({ items, total_count }) => ({ organization, items, total_count }))
    .catch(err => renderIndicator('x'));
}


Promise.all(config.organizations.map(o => fetchPRs(o)))
  .then(values => {
    const totalItemsCount = values.reduce((acc, v) => acc + v.total_count, 0);
    renderIndicator(totalItemsCount, PR_ICON_BASE64);
    values.forEach(value => {
      if (value.items.length) {
        console.log('---');
        console.log(value.organization.name);
        value.items.forEach((pr) => {
          const title = getRepoNameFromRepoURL(pr.repository_url) + '#' + pr.number;
          const href = 'href=' + pr.html_url;
          console.log(title + ' | ' + href );
        });
      }
    });
  });
