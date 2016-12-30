#!/usr/bin/env /Users/andreaascari/.nvm/versions/node/v6.9.2/bin/node

const request = require('../utils/request');
const renderIndicator = require('../utils/renderIndicator');
const config = require('../utils/config');
const getRepoNameFromRepoURL = require('../utils/getRepoNameFromRepoURL');

var ISSUE_ICON_BASE64 = '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';


function fetchIssues(organization) {
  return request(organization, { path: '/search/issues?q=assignee:ascariandrea+state:open' })
    .then(({ items, total_count }) => ({ organization, items, total_count }))
    .catch((err) => renderIndicator('x'));
}

Promise.all(config.organizations.map(fetchIssues))
  .then((values) => {
    const totalItemsCount = values.reduce((acc, v) => acc + v.total_count, 0);
    renderIndicator(totalItemsCount, ISSUE_ICON_BASE64)
    values.forEach((value) => {
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
