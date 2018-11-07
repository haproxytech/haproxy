const express = require('express')
const app = express()
const port = 80

var hamsters = [
    "robo-hamster",
    "space-hamster",
    "commando-hamster",
    "pirate-hmaster"
]

app.get('/api/hamsters', function (req, res) {
    res.send(hamsters)
})

app.post('/api/hamsters/:name', function (req, res) {
  hamsters.push(req.params.name)
  res.send(hamsters)
})

app.delete('/api/hamsters/:name', function(req, res) {
    var index = hamsters.indexOf(req.params.name)

    if (index > -1) {
        hamsters.splice(index, 1)
    }

    res.send(hamsters)
})

app.listen(port, () => console.log(`Listening on port ${port}`))