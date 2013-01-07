#!/usr/bin/ruby

require 'optparse'

require './poem'
require './dictionary'
require './configuration'
require './sentence_manager'

include Grammar

version = '4.0 pre-alpha'
dictionary = nil
language = 'pl'
debug = false
forced_seed = nil
conf = PoetryConfiguration.new

OptionParser.new do |opts|
	opts.banner = "Usage: poeta.rb [options] [dictionary]"

	opts.on("-l", "--language LANGUAGE", "Use language (defaults to 'pl')") do |l|
		language = l
	end
	opts.separator ""
	opts.on("-d", "--debug", "Run in debug mode") do |d|
		debug = true
		conf.debug = true
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
default_name = "default_#{language}"
dictionary = if ARGV[0]
	ARGV[0]
else
	default_name
end

dictionary_file = dictionary
sentences_file = dictionary

dictionary_file += '.dic' if dictionary_file !~ /\.dic$/
sentences_file += '.cfg' if sentences_file !~ /\.cfg$/
sentences_file = "#{default_name}.cfg" unless File.exists?(sentences_file)
title_sentences_file = 'titles.cfg'
raise "#{dictionary_file} does not exist" unless File.exists?(dictionary_file)
raise "#{sentences_file} does not exist" unless File.exists?(sentences_file)

GRAMMAR_FOR_LANGS = {'de' => GermanGrammar, 'en' => EnglishGrammar, 'pl' => PolishGrammar}
grammar_class = GRAMMAR_FOR_LANGS[language] || GenericGrammar
grammar = grammar_class.new
grammar_file = "#{language}.aff"
raise "#{grammar_file} does not exist" unless File.exists?(grammar_file)
File.open(grammar_file) { |f| grammar.read_rules(f) }
dictionary = SmartRandomDictionary.new(5)
File.open(dictionary_file) { |f| dictionary.read(f) }
sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
File.open(sentences_file) { |f| sentence_mgr.read(f) }
title_sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
File.open(title_sentences_file) { |f| title_sentence_mgr.read(f) }

errors = dictionary.validate_with_grammar(grammar)
unless errors.empty?
	errors.each { |err| conf.logger.warn "warn: #{err[:message]}" }
end

if forced_seed
	srand(forced_seed)
else
	srand
end
poem = Poem.new(sentence_mgr,title_sentence_mgr,conf)
puts poem.text

if debug
	puts
	puts "dictionary: #{dictionary_file} sentences: #{sentences_file} grammar: #{grammar_class}"
	puts "rand seed: #{srand}"
end
