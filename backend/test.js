const request = require('supertest');
const app = require('./index');

request(app)
  .get('/')
  .expect(200)
  .expect('Backend API is running successfully!')
  .then(() => {
    console.log('Backend test passed');
  })
  .catch((err) => {
    console.error('Backend test failed');
    console.error(err);
    process.exit(1);
  });