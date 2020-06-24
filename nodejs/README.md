# Node.js Installation
The scripts provided in this directory can be used to agnostically build, install, test and deploy [Node.js](https://nodejs.org) applications using `bash`.

The script utilizes [nvm (Node Version Management)](https://github.com/nvm-sh/nvm) so each application can define it's own `.nvmrc` file that contains the version of Node.js that should be used to build, deploy and run the app.

## Deployment
The following steps are performed by [`node-app-cicd.sh`](node-app-cicd.sh) when using the `DEPLOY` or `DEPLOY_CLEAN` execution type:

<kbd>![Deploy Flow](img/deploy.png)</kbd>
