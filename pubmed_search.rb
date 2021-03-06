require './lib.rb'

term        = URI.encode "type I IFN dsRNA"
results_max = 20

query         = meta_search term
doc_list      = search query[:webenv], query[:querykey], results_max

text = JSON.pretty_generate(doc_list)
puts text
File.open("json/#{term}__#{results_max}_results.json", "w") do |f|
  f.write text
end
