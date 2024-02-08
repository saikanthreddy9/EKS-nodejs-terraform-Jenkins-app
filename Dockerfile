FROM node:14-alpine

WORKDIR /usr/src/app

COPY src/backend/package.json .
COPY src/backend/index.js .

RUN npm install

CMD ["npm", "start"]
