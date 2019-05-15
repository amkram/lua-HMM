local P = {}

Tools = P
math.randomseed( os.time() )

-- Picks an element from set using a given probability distribution (key: element name, val: probability)
function P.rand_from_distribution(distribution)
  sum = 0
  rand = math.random()
  for k,v in pairs(distribution) do
    sum = sum + v
    if rand <= sum then
      return k
    end
  end
end

-- Returns all strings of length n over alphabet in list (in lex. order)
function P.get_orderings(list, n)
  ret = {}
  for i = 1, #list do
    lex(list[i], n, list, ret)
  end
  return ret
end
function lex(s, n, a, ret)
  if #s == n then
    ret[#ret+1] = s
    return
  end
  for i = 1,#a do
    lex(s..a[i], n, a, ret)
  end
end
