const express = require('express')
const bodyParser = require('body-parser')
const redis = require('redis')
const app = express()
const port = 8080
const redisUrl = process.env.REDIS_URL
app.use(bodyParser.urlencoded({extended: true}))

app.get('/', function(req, res, next) {
  var redisClient = null

    var message = ""
    redisClient = redis.createClient({ 
      host: redisUrl, 
      retry_strategy: function(args) {
        return undefined
      }  
    })

    redisClient.on("error", function(err) {
      console.log("Error: " + err)
      message = err
      res.send(`
          <h1>App served by Consul and HAProxy!</h1>
          <form action="/" method="post">
            <label for="message">Add message</label>
            <input type="text" name="message" />
            <input type="submit" value="Save to Redis" />
          </form>
          <p>Message: ${message}</p>`)
      next()
    })

    redisClient.get('message', function(err, reply) {
      if (err != null) {
        console.log("Error: " + err)
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
    
    redisClient.quit()
})

app.post('/', function(req, res, next) {
  var redisClient = null
  var message = req.body.message

  redisClient = redis.createClient({ 
    host: redisUrl, 
    retry_strategy: function(args) {
      return undefined
    }  
  })

  redisClient.on("error", function(err) {
    console.log("Error: " + err)
    next()
  })

  redisClient.set('message', message)
  redisClient.quit()
  res.redirect(303, '/')
})

app.listen(port, function() {
  console.log(`Listening on port ${port}`)
})