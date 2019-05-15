require "src/Tools"

-- An HMM consists of some global tables that are updated when a file is loaded
HMM = {states, symbols, transition_probs, emission_probs, order}

-----------------------
--  Public Functions --
-----------------------

-- Loads a file in the format specified in file_template.txt
function HMM.load(filename)
  HMM.states, HMM.state_nums, HMM.symbols,
  HMM.transition_probs, HMM.emission_probs, HMM.ords, HMM.order = HMM.parse_file(filename)
end

-- Returns n emitted symbols and their states using the currently defined HMM
function HMM.emit(n)
  emitted_states = HMM:generate_state_sequence(n)
  emitted_symbols = HMM:generate_symbols(emitted_states)
  return emitted_symbols, emitted_states
end

-- Returns the Viterbi best guess for the emitting states
function HMM.decode(emitted_symbols)
  return HMM:viterbi(emitted_symbols)
end

-- Prints a list (the emitted symbol list, for example)
function HMM.print_list(list)
  for k,v in pairs(list) do
    io.write(v)
  end
  print()
end

-- Prints the accuracy of decoding compared to the actual emitted states
function HMM.print_stats(emitted_states, decoded_states)
  matches = 0
  for k,v in pairs(emitted_states) do
    if v == decoded_states[k] then
      matches = matches + 1
    end
  end
  percent_match = matches / #emitted_states
  print("==== Viterbi Results ====")
  print("Accuracy: " .. percent_match*100 .. "%")

end

--End Public Functions--


-------------------------
-- "Private" Functions --
-------------------------

-- Generates a sequence of states using the currently loaded HMM
function HMM:generate_state_sequence(n)
  local emitted_states = {}

  emitted_states[0] = "begin"

  for i = 1, n do
    arg = "" --concatenate states to arg appropriately depending on the order
    for j = 1, self.order do
      if emitted_states[i-j] == "begin" then
        arg = "begin"
        break
      end
      arg = emitted_states[i-j] .. arg
    end
    --given the last "order" states (in arg), pick a new state
    emitted_states[i] = Tools.rand_from_distribution(self.transition_probs[arg])
  end
  return emitted_states
end

-- Generates a symbol for each state in emitted_states
function HMM:generate_symbols(emitted_states)
  local emitted_symbols = {}
  for i, v in ipairs(emitted_states) do
    emitted_symbols[i] = Tools.rand_from_distribution(self.emission_probs[v])
  end
  return emitted_symbols
end

-- Builds a Viterbi table and returns the most probable state sequence given a list of symbols
function HMM:viterbi(emitted_symbols)
  L = #emitted_symbols --length of symbol string

  -- set the first column to initial probabilities (from begin state)
  vtable = {}
  for l = 1, #self.states do
    state = self.states[l]
    vtable[l] = {}

    -- track the state (row) and previous element so we can trace back the state sequence later
    vtable[l][1] = {prob, prev, state}
    vtable[l][1].prev = nil
    vtable[l][1].prob = math.log(self.transition_probs["begin"][state] * self.emission_probs[state][emitted_symbols[1]])
    vtable[l][1].state = state
  end

  -- for each symbol...
  for t = 2, L do
    -- for each state...
    for l = 1 ,#self.states do
      state = self.states[l]
      vtable[l][t] = {prob, prev, state}
      -- the emission probability of symbol t in state l
      e = math.log(self.emission_probs[state][emitted_symbols[t]])
      -- find the most probable previous state
      max_prob, max_state = HMM:arg_max(t, state, vtable)

      vtable[l][t].prob = e + max_prob
      vtable[l][t].prev = vtable[max_state][t-1]
      vtable[l][t].state = state
    end
  end

  -- find the entry with maximum probability in the last column of vtable
  max_prob = -math.huge
  max_state = -1
  for k = 1, #self.states do
    prob = vtable[k][L].prob
    if prob > max_prob then
      max_prob = prob
      max_state = k
    end
  end

  -- build a list of states that the algorithm predicts were the real states
  max = vtable[max_state][L]
  decoded_states = {}
  for i = L,1,-1 do
    decoded_states[i] = max.state
    max = max.prev
  end

  return decoded_states

end


-- Finds the maximum state and its probability for symbol t-1 leading to state l,
-- considering multiple previous states depending on order of the model
function HMM:arg_max(t, state_l, vtable)
  max_prob = -math.huge
  max_state = 1
  for k = 1, #self.ords do
    states_k = self.ords[k] -- a string of "order" states concatenated to each other
    state_num_k = self.state_nums[string.sub(self.ords[k], -1)] -- the number of the most recent state in that string
    -- the entry in vtable is already log'd
    new_prob = vtable[state_num_k][t-1].prob + math.log(self.transition_probs[states_k][state_l])
    if(new_prob > max_prob) then
      max_prob = new_prob
      max_state = state_num_k
    end
  end
  return max_prob, max_state
end

function HMM.parse_file(filename)
  local lines = {}
  local states, symbols, transition_probs, emission_probs = {},{},{},{}

  -- remove spaces
  for line in io.lines(filename) do
    if string.len(line) ~= 0 then
      line = line:gsub("%s+", "")
      table.insert(lines, line)
    end
  end

  -- parse the HMM's data
  for i, line in ipairs(lines) do
    if line == "<order>" then
      order = tonumber(lines[i+1])
    elseif line == "<states>" then
      k = 1
      state_nums = {}
      for state in lines[i+1]:gmatch('[^,%s]+') do
        states[#states+1] = state
        state_nums[state] = k
        k = k + 1
      end
    elseif line == "<symbols>" then
      for symbol in lines[i+1]:gmatch('[^,%s]+') do
        symbols[#symbols+1] = symbol
      end

    elseif line == "<transitionprobabilities>" then
      states_cpy = {}
      for i = 2, #states-1 do
        states_cpy[i-1] = states[i]
      end
      ords = Tools.get_orderings(states_cpy, order)
      for key, ord in ipairs(ords) do
        transition_probs[ord] = {}
      end
      transition_probs["begin"] = {}
      transition_probs["end"] = {}
      k = 1
      for val in lines[i+1]:gmatch('[^,%s]+') do
        transition_probs["begin"][states[k]] = val
        k = k + 1
      end
      k = 1
      for val in lines[i+#ords+2]:gmatch('[^,%s]+') do
        transition_probs["end"][states[k]] = val
        k = k + 1
      end
      for key, ord in ipairs(ords) do
        k = 1
        transition_probs[ord][states[k]] = {}
        for val in lines[i+key+1]:gmatch('[^,%s]+') do
          transition_probs[ord][states[k]] = val
          k = k + 1
        end

      end
    elseif line == "<emissionprobabilities>" then

      for j,s in ipairs(states) do
        emission_probs[s] = {}
        k = 1
        for val in lines[i+j]:gmatch('[^,%s]+') do
          emission_probs[s][symbols[k]] = val
          k = k + 1
        end
      end
    end
  end
  return states, state_nums, symbols, transition_probs, emission_probs, ords, order

end

--End Private Functions--
