util = require('..').util
fs = require 'fs'

testFormat = (opts) ->
  x = []
  for i in [0..100]
    x.push i
  for i in [0..100]
    x.push util.uid(util.randomIntRange(2, 8))
  for i in [0..200]
    x.push i
    unless i % 27
      x.push util.uid(util.randomIntRange(50, 80))
  console.log util.formatList x, opts

testFormat()

testFormat(indent:":", sep:"-", eol:"...\n", limit:60)

readme = fs.readFileSync("#{__dirname}/README").toString()
console.log readme
console.log util.indentMsg readme
console.log util.indentMsg(readme, {indent: "__", eol: "/\n"})
