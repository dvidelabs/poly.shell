# min .. max integer range, both incl.
exports.randomIntRangeIncl = (min, max) ->
  Math.floor(Math.random() * (max - min + 1)) + min

# min .. max integer range, max excl.
exports.randomIntRange = (min, max) ->
  Math.floor(Math.random() * (max - min)) + min

# 0 .. max integer range, both incl.
exports.randomIntIncl = (max) ->
  Math.floor(Math.random() * (max + 1))

# 0 .. max integer range, max excl.
exports.randomInt = (max) ->
  Math.floor(Math.random() * max)
  
# Creates a fixed length random string from a given alphabet.
# Default length is 10 with the alphabet A-Za-z0-9.
exports.uid = (len = 10, alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') ->
  uid = ''
  n = alphabet.length
  for i in [0..len]
    uid += alphabet[Math.floor(Math.random() * n)]
  uid

# Takes a map (object) and creates an array of one element at the given key
# or pushes to an already existing array.
exports.pushmap = (map, key, elem) -> a = map[key]; if a then a.push elem else map[key] = [elem]

# Takes a map (object) and increments a value at the given key
# or creates a first value plus increment. Increment defaults to 1 and first
# value defaults to zero. Function can also operate on strings if first is given
# as a string type. For example as keyed message buffers.
exports.addmap = (map, key, inc = 1, first = 0) -> val = map[key] or first; map[key] = val + inc

# Compare two arrays interpreted as sets.
# True if x and y has the same members. Duplicates ignored.
exports.eqSet = eqSet = (x, y) ->
  h = {}
  for v in x
    h[v] = true
  for v in y
    return false unless h[v]
  return true

# Like eqSet, but the number of duplicates must match.
exports.eqlSet = (x, y) ->
    return false if x.length != y.length
    return eqSet(x, y)
