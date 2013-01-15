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

GRAMMAR_FOR_LANGS = {'de' => GermanGrammar, 'en' => EnglishGrammar, 'pl' => PolishGrammar}
GRAMMAR_FOR_LANGS.default = GenericGrammar

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
grammar_file = "#{language}.aff"
general_config_file = 'poetry.yml'
dictionary_config_file = "#{dictionary}.yml"

[dictionary_file, sentences_file, title_sentences_file, grammar_file].each do |file|
	raise "#{file} does not exist" unless File.exists?(file)
end

grammar = GRAMMAR_FOR_LANGS[language].new

File.open(grammar_file) { |f| grammar.read_rules(f) }
dictionary = SmartRandomDictionary.new(5)
File.open(dictionary_file) { |f| dictionary.read(f) }
sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
File.open(sentences_file) { |f| sentence_mgr.read(f) }
title_sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
File.open(title_sentences_file) { |f| title_sentence_mgr.read(f) }

used_config_files = []
[general_config_file, dictionary_config_file].each do |file|
	next unless File.exists?(file)
	File.open(file) { |f| conf.read(f) && used_config_files << file }
end

errors = dictionary.validate_with_grammar(grammar)
unless errors.empty?
	errors.each { |err| conf.logger.warn "warn: #{err[:message]}" }
end

if forced_seed
	srand(forced_seed)
else
	srand
end

begin
	poem = Poem.new(sentence_mgr,title_sentence_mgr,conf)
	puts poem.text
rescue
	puts 'Error: ', $!.inspect, $@
end

if debug
	puts
	puts "dictionary: #{dictionary_file} sentences: #{sentences_file} grammar: #{grammar.class}"
	puts "config files: #{used_config_files.join(' ')}"
	puts "configuration: #{conf.summary}"
	puts "rand seed: #{srand}"
end
