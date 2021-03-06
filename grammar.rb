# -*- encoding: utf-8 -*-

module Grammar

	NOUN = 'N'
	VERB = 'V'
	ADJECTIVE = 'A'
	ADVERB = 'D'
	OTHER = 'O'
	SPEECH_PARTS = [NOUN,VERB,ADJECTIVE,ADVERB,OTHER]

	NOMINATIVE,GENITIVE,DATIVE,ACCUSATIVE,INSTRUMENTAL,LOCATIVE,VOCATIVE = *(1..7)
	CASES = [NOMINATIVE,GENITIVE,DATIVE,ACCUSATIVE,INSTRUMENTAL,LOCATIVE,VOCATIVE]
	CASE_NAMES = %w{M D C B N Ms W}
	CASE2STRING = Hash[*CASES.zip(CASE_NAMES).flatten]
	CASE_NAME_LEN = 2

	MASCULINE,NEUTER,FEMININE = *(1..3)
	GENDERS = [MASCULINE,NEUTER,FEMININE]
	GENDER_NAMES = %w{m n f}
	GENDER2STRING = Hash[*GENDERS.zip(GENDER_NAMES).flatten]

	SINGULAR,PLURAL = *(1..2)
	# all supported grammatical numbers (like singular or plural)
	NUMBERS = [SINGULAR,PLURAL]
	NUMBER_NAMES = %w{Sg Pl}
	# persons present in each number (like: we, you, they)
	PERSONS = [1,2,3]
	NUMBER2STRING = Hash[*NUMBERS.zip(NUMBER_NAMES).flatten]

	class GrammarError < RuntimeError
	end

	class SpeechParts
		private_class_method :new
		def SpeechParts.describe(s)
			case s
				when NOUN then 'noun'
				when VERB then 'verb'
				when ADJECTIVE then 'adjective'
				when ADVERB then 'adverb'
				when OTHER then 'other'
				else raise "unknown speech part #{s}"
			end
		end
	end

	class Rule
		def initialize(remove,add,find,*required_props)
			@remove,@add,@find,@required_props=remove,add,find,required_props
			if !@required_props.empty? && !@required_props[0].kind_of?(String)
				raise "required properties don't contain strings: #{@required_props.inspect}"
			end
			@required_props ||= []
		end

		def matches?(word,*word_props)
			return false if word_props.nil?
			if word_props.empty? && word_props[0].kind_of?(String)
				raise "word properties don't contain strings: #{word_props.inspect}"
			end

			not_included = @required_props - word_props
			if !not_included.empty?
# 				puts "#{word} does not have #{not_included.inspect} #{@required_props[0].class}"
				return false
			end
			word =~ /#{@find}$/
		end

		def inflect(word,*word_props)
			return word unless(matches?(word,*word_props))
			result = word.gsub(/#{@remove}$/, '')
			result + @add
		end
	end

	class GenericGrammar

		def initialize
			@rules={}
			SPEECH_PARTS.each do |part|
				@rules[part] = {}
			end
		end

		# returns complete number of rules for all parts of speech
		def size
			retval = 0
			@rules.values.each do |part_forms|
				part_forms.values.each do |form_rules|
					retval += form_rules.size
				end
			end
			retval
		end

		def read_rules(source)
			initialize
			source.each_line do |line|
				line.gsub!(/#.*/, '')
				next if line !~ /\w/
				line.chomp!
				speech_part,pattern,form,remove,add,condition = line.split(/\s+/)
				unless speech_part && pattern && form && remove && add && condition
					print "wrong line: '#{line}'"
					next
				end
				forms = read_forms(form)
				find,required = condition.split(/\//)
				remove = '' if (remove == '0')
				add = '' if (add == '0')
				required_props = [pattern]
				if required
					required.split().each { |r| required_props << r }
				end
				unless SPEECH_PARTS.include?(speech_part)
					print "no such speed part: #{speech_part}"
					next
				end
				forms.each do |f|
					f = f.to_i
					@rules[speech_part][f] ||= []
					@rules[speech_part][f] << Rule.new(remove,add,find,*required_props)
				end
			end
		end

		def has_rule_for?(speech_part, word, *gram_props)
			@rules[speech_part].each do |form, rules|
				rules.each do |rule|
					return true if rule.matches?(word,*gram_props)
				end
			end
			false
		end

		def inflect_noun(noun,form,*gram_props)
			raise ":case has to be passed '#{form[:case]}'" unless form[:case]
			form_id = form[:case]
			noun_number = form[:number] || 1
			form_id += 10 if noun_number == 2

			gram_props << PREPOSITION_FORM if form[:preposition]
			inflected = get_inflected_form(NOUN,form_id,noun,*gram_props)
			inflected || noun
		end

		def inflect_adjective(adjective,form,*gram_props)
			raise GrammarError, ":case has to be passed '#{form[:case]}'" unless form[:case]
			raise GrammarError, ":gender has to be passed '#{form[:gender]}'" unless form[:gender]
			raise GrammarError, "wrong gender: #{form[:gender]}" unless GENDERS.include? form[:gender]

			inflected = get_inflected_form(ADJECTIVE,adjective_form_id(form),adjective,*gram_props)
			inflected || adjective
		end

		def inflect_verb(text,form,reflexive=false,*gram_props)
			raise GrammarError, "both :invinitive and :person" if form[:infinitive] && form[:person]
			return text if form[:infinitive]
			raise GrammarError, ":person has to be passed '#{form.inspect}'" unless form[:person]
			raise GrammarError, "invalid person: #{form[:person]}" unless PERSONS.include? form[:person]
			number = form[:number] || 1
			raise GrammarError, "invalid number: #{number}"  unless NUMBERS.include? number
			form_id = form[:person].to_int
			form_id += (number-1) * 10
			form_id += 100 if form[:imperative]
# 			puts "verb form id: #{form_id} #{@rules[VERB].keys.sort.inspect}"

			inflected = get_inflected_form(VERB,form_id,text,*gram_props)
			inflected ||= text
			inflected
		end

		# allows subclasses to modify preposition if certain letters meet
		def join_preposition_object(preposition,object)
			preposition + ' ' + object
		end

		# joins main noun and noun serving as an attribute_noun
		# may reject the attribute noun and return only main noun
		def join_attribute_noun(main_noun, attribute_noun)
			if noun_join_allowed?(main_noun, attribute_noun)
				joined_attribute_noun(main_noun, attribute_noun)
			else
				main_noun
			end
		end

		protected

		# grammar property added to the noun's properties if the noun
		# is used with a preposition as an object
		PREPOSITION_FORM = 'p'

		def read_forms(form_str)
			forms = case form_str
				when /^(\d+)-(\d+)$/
					from,to = Integer($1),Integer($2)
					raise "wrong range: #{$&}" unless(to > from)
					(from..to).to_a
				when /^\d+(?:,\d+)+$/
					form_str.split(',')
				when /^\d+$/
					[Integer(form_str)]
				else
					raise "should be either a number or a range: '#{form_str}'"
			end
			unique = forms.uniq
			puts "warning: duplicates in #{form_str}" if unique.size != forms.size
			unique
		end

		# returns inflected form or nil if not found
		def get_inflected_form(speech_part,form_id,word,*gram_props)
			if @rules[speech_part].has_key?(form_id)
				@rules[speech_part][form_id].each() do |rule|
					if rule.matches?(word,*gram_props)
						return rule.inflect(word,*gram_props)
					end
				end
			end
			nil
		end

		def adjective_form_id(form)
			gram_case = form[:case]
			number = form[:number] || 1
			gender = form[:gender] || MASCULINE

			form_id = gram_case
			form_id += (number-1) * 10
			form_id += gender * 100
			form_id
		end

		def noun_join_allowed?(main_noun, attribute_noun)
			true
		end

		def joined_attribute_noun(main_noun, attribute_noun)
			main_noun + ' ' + attribute_noun
		end
	end

	# using classes need to implement private method 'reflexive_word()' returning a string
	module SimpleReflexiveVerbsHandler
		def inflect_verb(text,form,reflexive=false,*gram_props)
			if form[:infinitive] && reflexive
				return reflexive_word + '~' + text
			end

			inflected = super

			inflected += '~' + reflexive_word if (reflexive)
			inflected
		end
	end

	class PolishGrammar < GenericGrammar
		include SimpleReflexiveVerbsHandler

		def join_preposition_object(preposition,object)
			prep = preposition.clone
			consonants = %w{b c d f g h j k l ł m n p r s t w z}
			cons_match = "[#{consonants.join}]"
			case
				when prep == 'z' &&
					object =~ /^(z#{cons_match}|s[#{(consonants-['z']).join}]|sz#{cons_match}|ws|śl)/u
					then prep = 'ze'
				when prep == 'z' && ['mną','mnie'].include?(object) then prep = 'ze'
				when prep == 'w' &&
					object =~ /^w#{cons_match}|^mnie\b/
					then prep = 'we'
				when prep == 'od' && object == 'mnie' then prep = 'ode'
			end
			prep + '~' + object
		end

		protected
		def adjective_form_id(form)
			gram_case = form[:case]
			number = form[:number] || 1
			gender = form[:gender]
			if form.include?(:animate) && form[:animate] == false && gender == MASCULINE
				if number == 2
					gender = NEUTER
				elsif gram_case == ACCUSATIVE
					gram_case = NOMINATIVE
				end
			end

			form_id = gram_case
			form_id += (number-1) * 10
			form_id += gender * 100
			form_id
		end

		private
		def reflexive_word
			'się'
		end
	end

	class GermanGrammar < GenericGrammar
		include SimpleReflexiveVerbsHandler

		protected
		def joined_attribute_noun(main_noun, attribute_noun)
			# TODO implement this the correct way
			main_noun + ' des ' + attribute_noun
		end

		private
		def reflexive_word
			'sich'
		end
	end

	class EnglishGrammar < GenericGrammar
		protected
		def joined_attribute_noun(main_noun, attribute_noun)
			main_noun + ' of ' + attribute_noun
		end
	end

	class GrammarForm
		def self.pretty_print(form)
			parts = []
			parts << format_gender(form[:gender]) if form[:gender]
			parts << format_number(form[:number]) if form[:number]
			parts << format_case(form[:case]) if form[:case]
			parts << format_person(form[:person]) if form[:person]
			parts << 'Inf' if form[:infinitive]
			parts << 'Imp' if form[:imperative]
			parts << 'anim' if form[:animate]
			form.keys.sort_by{|s| s.to_s}.each do |key|
				if ![:gender,:number,:case,:person,:infinitive,:imperative,:animate].include?(key)
					parts << "#{key}=#{form[key]}"
				end
			end
			parts.join(' ')
		end

		def self.format_gender(gender)
			name = GENDER2STRING[gender]
			raise "unknown gender #{gender}" unless name
			name
		end

		def self.format_number(number)
			name = NUMBER2STRING[number]
			raise "unknown number #{number}" unless name
			name
		end

		def self.format_case(gram_case)
			name = CASE2STRING[gram_case]
			raise "unknown case #{gram_case}" unless name
			name.rjust(CASE_NAME_LEN)
		end

		def self.format_person(person)
			person
		end
	end

end
