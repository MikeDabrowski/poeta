#!/usr/bin/ruby -w

require 'optparse'

require './poem'
require './dictionary'
require './sentence'

include Grammar

version = '4.0 pre-alpha'
dictionary = 'default'
language = 'pl'
debug = false
forced_seed = nil

OptionParser.new do |opts|
	opts.banner = "Usage: poeta.rb [options] [dictionary]"

	opts.on("-l", "--language LANGUAGE", "Use language (defaults to 'pl')") do |l|
		language = l
	end
	opts.separator ""
	opts.on("-d", "--debug", "Run in debug mode") do |d|
		debug = true
	end
	opts.on('-s', '--seed SEED', "Feed the random generator with given rand seed") do |s|
		forced_seed = s.to_i
	end

	opts.separator ""
	opts.separator "Common options:"
	opts.on_tail('-h','--help','Show full help') do
		puts opts
		exit
	end
	opts.on_tail('-v','--version','Show program version') do
		puts "Poeta v#{version}"
		exit
	end
end.parse!

raise "expects none or one argument" if ARGV.size > 1
dictionary = ARGV[0] if ARGV[0]

dictionary_file = dictionary
sentences_file = dictionary

dictionary_file += '.dic' if dictionary_file !~ /\.dic$/
sentences_file += '.cfg' if sentences_file !~ /\.cfg$/
raise "#{dictionary_file} does not exist" unless File.exists?(dictionary_file)
raise "#{sentences_file} does not exist" unless File.exists?(sentences_file)

GRAMMAR_FOR_LANGS = {'pl' => PolishGrammar}
grammar_class = GRAMMAR_FOR_LANGS[language] || GenericGrammar
grammar = grammar_class.new
grammar_file = "#{language}.aff"
raise "#{grammar_file} does not exist" unless File.exists?(grammar_file)
File.open(grammar_file) { |f| grammar.read_rules(f) }
dictionary = SmartRandomDictionary.new(5)
File.open(dictionary_file) { |f| dictionary.read(f) }
sentence_mgr = SentenceManager.new(dictionary,grammar,true,debug)
File.open(sentences_file) { |f| sentence_mgr.read(f) }

if forced_seed
	srand(forced_seed)
else
	srand
end
poem = Poem.new(dictionary,grammar,sentence_mgr)
puts poem.text

if debug
	puts
	puts "rand seed: #{srand}"
end
