const express = require('express')
const bodyParser = require('body-parser')
const redis = require('redis')
const app = express()
const port = 8080
const redisUrl = process.env.REDIS_URL
app.use(bodyParser.urlencoded({extended: true}))

app.get('/', function(req, res) {
  var message = ""
  var redisClient = redis.createClient({ host: redisUrl })
  redisClient.get('message', function(err, reply) {

    if (err != null) {
      res.send("Error: " + err)
    }
    else {
      message = reply
      res.send(`
        <h1>App served by Consul and HAProxy!</h1>
        <form action="/" method="post">
          <label for="message">Add message</label>
          <input type="text" name="message" />
          <input type="submit" value="Save to Redis" />
        </form>
        <p>Message: ${message}</p>`)
    }
  })
})

app.post('/', function(req, res) {
  var message = req.body.message
  var redisClient = redis.createClient({ host: redisUrl })
  redisClient.set('message', message)
  res.redirect(303, '/')
})

app.listen(port, function() {
  console.log(`Listening on port ${port}`)
})