#!/usr/local/bin/node

const request = require('../utils/request');
const renderIndicator = require('../utils/renderIndicator');
const config = require('../utils/config');
const getRepoNameFromRepoURL = require('../utils/getRepoNameFromRepoURL');

const MERGE_ICON_BASE64= 'iVBORw0KGgoAAAANSUhEUgAAAA8AAAAQCAYAAADJViUEAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAACXBIWXMAAAsTAAALEwEAmpwYAAABWWlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNS40LjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgpMwidZAAABlElEQVQoFY2Suy5EURSGzw3jkqHwAigVqDUkCpUgGonoJBKNRms6oiC8gFsnoaGmEIUoKKZQTEJMQkRCQifOOXz/nrOGkUj8ybfX2nvttfY19DwvgE8w5XAGYR26oAgJpCD9nu8GG2ib4AJUbAbOM38MKzVWzHfbgbsVBMFuFEVD+LegZK0kK2aJL/i+f4Q/DVLg0yxDCTYhgk5oA8mSr/E/oB02YA6eNFkFdC6pFe7hTh2kmAo0wzs8wGPWdyspqLNK/ZAHXZASJcW1yCmoqHzFnSNrOjTnD6uCujQVqCaruheG4QimBWL4uXJ9kiQnjGnbl/AK1WQ3kQnHjOmWTbZlva00CXbMZ7d8NqCgbroOrIDib6BLPINekFZgwJLdCI1+l3AXgtXHeYF56AGpzJtvp2lasGQ7n85jiZqouM7fDXpfPVeRxFFsnyXj11yYCuhsOX5VKY7jA/x90FOOwwSsgbcEGpTsYiq92naR7g2UYQfc31jFGYb/KM8kreqkbe9BAabAzo7rpL62b1Yf5MpF2OUX4Y1iVq0qIuAAAAAASUVORK5CYII=';

function fetchPRs(organization) {
  return request(organization, { path: '/search/issues?q=review-requested:ascariandrea+type:pr+state:open' })
    .then(({ items, total_count }) => ({ organization, items, total_count }))
    .catch((err) => renderIndicator('x'));
}

Promise.all(config.organizations.map(o => fetchPRs(o)))
  .then(values => {
    const totalItemsCount = values.reduce((acc, v) => acc + v.total_count, 0);
    renderIndicator(totalItemsCount, MERGE_ICON_BASE64);
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
