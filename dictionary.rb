#!/usr/bin/ruby -w

require 'grammar'
require 'randomized_choice'

module Grammar
	MASCULINE,FEMININE,NEUTER = *(1..3)
	GENDERS = [MASCULINE,FEMININE,NEUTER]

	OBJECT_ONLY = 'OO'
	NO_NOUN_NOUN = 'NO_NOUN_NOUN'

	class Word
		attr_reader :text, :gram_props, :frequency

		def initialize(text,gram_props=[],frequency=100)
			gram_props ||= []
			@text,@frequency,@gram_props=text,frequency,gram_props
			unless gram_props.respond_to?(:each) && gram_props.respond_to?(:size):
				raise "expect gram_props to behave like an array but got #{gram_props.inspect}"
			end
			if !gram_props.empty? && !gram_props[0].kind_of?(String):
				raise "gram_props should be an array of strings"
			end
			if frequency < 0:
				raise "invalid frequency for #{text}: #{frequency}"
			end
			if text == '':
				raise "word text is empty"
			end
		end
	end

	class Noun < Word
		def initialize(text,gram_props,frequency,gender)
			super(text,gram_props,frequency)
			@gender = gender
			raise "invalid gender #{gender}" unless(GENDERS.include?(gender))
		end

		def Noun.parse(text,gram_props,frequency,line)
			Noun.new(text,gram_props,frequency,MASCULINE) # TODO TEMP
		end
	end

	class Verb < Word
		def initialize(text,gram_props,frequency,preposition,object)
			super(text,gram_props,frequency)
		end

		def Verb.parse(text,gram_props,frequency,line)
			Verb.new(text,gram_props,frequency,'','') # TODO TEMP
		end
	end

	class Adjective < Word
		def initialize(text,gram_props,frequency)
			super(text,gram_props,frequency)
		end

		def Adjective.parse(text,gram_props,frequency,line)
			Adjective.new(text,gram_props,frequency) # TODO TEMP
		end
	end

	class Words
		private_class_method :new
		def Words.get_class(speech_part)
			case speech_part
				when NOUN: Noun
				when VERB: Verb
				when ADJECTIVE: Adjective
				else raise "unknown speech part: #{speech_part}"
			end
		end
	end

	class Dictionary
		def initialize
			@words = {}
		end

		def to_s
			retval = 'Dictionary; '
			word_stats = []
			@words.keys.sort.each do |speech_part|
				word_stats << "#{@words[speech_part].size}x #{Grammar.describe_speech_part(speech_part)}"
			end
			retval += word_stats.join(', ')
		end

		def get_random(speech_part)
			index = get_random_index(speech_part)
			index == -1 ? nil : @words[speech_part][index]
		end

		def read(source)
			source.each_line do |line|
				begin
					next if line =~ /^#/ || line !~ /\w/
					line.chomp!
					speech_part, rest = read_speech_part(line)
					frequency, rest = read_frequency(rest)
					word_text, gram_props, rest = read_word(rest)
					word = Words.get_class(speech_part).parse(word_text,gram_props,frequency,rest)

					@words[speech_part] ||= []
					@words[speech_part] << word
# 					puts "#{word.inspect}"
				rescue DictParseError => e
					puts "error: #{e.message}"
				end
			end
		end

		protected

		class DictParseError < RuntimeError
		end

		# returns index of random word or -1 if none can be selected
		def get_random_index(speech_part)
			return -1 unless(@words.has_key?(speech_part))
			index = ByFrequencyChoser.choose_random_index(@words[speech_part])
# 			puts "random #{speech_part}: #{index}"
			index
		end

		private

		def read_speech_part(line)
			unless line =~ /^(\w)\s+/:
				raise DictParseError, "cannot read speech part from line '#{line}'"
			end
			speech_part,rest = $1,$'
			if !SPEECH_PARTS.include?(speech_part):
				raise DictParseError, "unknown speech part #{speech_part} in line '#{line}'"
			end
			[speech_part,rest]
		end

		def read_frequency(line)
			unless line =~ /^\s*(\d+)\s+/:
				raise DictParseError, "cannot read frequency from '#{line}'"
			end
			frequency,rest = $1.to_i,$'
			[frequency,rest]
		end

		def read_word(line)
			word,gram_props,rest=nil,[],nil
			if line =~ /^"([^"]+)"/:
				word,rest = $1,$'
			elsif line =~ /^([^\s\/]+)/:
				word,rest = $1,$'
			else
				raise DictParseError, "cannot read word from '#{line}'"
			end

			if rest =~ %r{^/(\w*)}:
				if $1.empty?:
					raise DictParseError, "cannot read word gram props from '#{line}'"
				end
				gram_props,rest = $1.split(//),$'
			end
			[word,gram_props,rest]
		end

	end

end
