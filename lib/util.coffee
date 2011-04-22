exports._ = require '../vendor/underscore-min-1.1.6.js'

# min .. max integer range, both incl.
exports.randomIntRangeIncl = (min, max) ->
  Math.floor(Math.random() * (max - min + 1)) + min

# min .. max integer range, max excl.
exports.randomIntRange = (min, max) ->
  Math.floor(Math.random() * (max - min)) + min

# 0 .. max integer range, both incl.
exports.randomIntIncl = (max) ->
  Math.floor(Math.random() * (max + 1))

# 0 .. max integer range, both max excl.
exports.randomInt = (max) ->
  Math.floor(Math.random() * max)
  
# fixed length random string of given alphabet
# default length 10 from the A-Za-z0-9 alphabet
exports.uid = (len = 10, alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') ->
  uid = ''
  n = alphabet.length
  for i in [0..len]
    uid += alphabet[Math.floor(Math.random() * n)]
  uid

exports.pushmap = (m, x, y) -> a = m[x]; if a then a.push y else m[x] = [y]

# also works for strings when setting first = ""
exports.addmap = (m, x, y, first = 0) -> a = m[x] or first; m[x] = a + y

# true if x and y has the same members, regardless of duplicates
exports.eqSet = eqSet = (x, y) ->
  h = {}
  for v in x
    h[v] = true
  for v in y
    return false unless h[v]
  return true

# only true if x and y are proper sets, or have same number of duplicates
exports.eqlSet = (x, y) ->
    return false if x.length != y.length
    return eqSet(x, y)

