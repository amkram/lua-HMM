require "src/HMM"

--HMM.load("example/2nd_order_hmm.txt")
HMM.load("example/1st_order_hmm.txt")


emitted_symbols, emitted_states = HMM.emit(1000)
decoded_states = HMM.decode(emitted_symbols)

--HMM.print_list(emitted_symbols)
--HMM.print_list(emitted_states)
--HMM.print_list(decoded_states)

HMM.print_stats(emitted_states, decoded_states)
