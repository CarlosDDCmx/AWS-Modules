const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  const version = process.env.APP_VERSION || '1.0.0';
  res.send(`Hello World! Application Version: ${version}`);
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});