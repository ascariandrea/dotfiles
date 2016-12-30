module.exports = function getRepoNameFromRepositoryUrl(repositoryURL) {
  const splitRepositoryURL = repositoryURL.split('/');
  return splitRepositoryURL[splitRepositoryURL.length - 1];
}
