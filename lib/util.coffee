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
