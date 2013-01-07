#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './dictionary'
require './test/test_helper'

include Grammar

class DictionaryTest < Test::Unit::TestCase
	def test_read
		input = <<-END
# some test dict
line with not speech part
N 100 słońce/EF
N 100 szatan/G NO_NOUN_NOUN
N 10.5 nietaki
N -1 nieboujemny
 N 10 niebowcięty
N 20 nieboźleodmiana/

Z line with invalid speech part

A 100 zły
A 50 "strasznie mocny"
		END
		dict = Dictionary.new
		dict.read(input)
		assert_equal('Dictionary; 2x adjective, 2x noun', dict.to_s)

		input = ""
		dict.read(input)
		assert_equal('Dictionary', dict.to_s)
	end

	def test_get_random_and_each
		srand
		# deliberately used different order of speech parts here to assure word order is not important
		input = <<-END
D 100 czasem

A 1 jedyny

V 0 nic

O 100 "some other"

N 0 nigdy
N 1 jeden
N 0 przenigdy
N 2 dwa
N 0 też nigdy
		END
		dict = Dictionary.new
		dict.read(input)
		assert_equal('Dictionary; 1x adjective, 1x adverb, 5x noun, 1x other, 1x verb', dict.to_s)

		count = 0
		dict.each { count += 1 }
		assert_equal 9, count, "Each does not iterate over all words"

		100.times() do
			noun = dict.get_random(NOUN)
			assert_not_equal('nigdy', noun.text)
			assert(%w{jeden dwa}.include?(noun.text), "unexpected noun text: '#{noun.text}'")
			adj = dict.get_random(ADJECTIVE)
			assert_equal('jedyny', adj.text)
			assert_equal('some other',dict.get_random(OTHER).text)
			assert_equal('czasem',dict.get_random(ADVERB).text)
			assert_nil(dict.get_random(VERB))
		end
	end

	def test_parse_noun
		dict = Dictionary.new

		dict.read('N 100 ty PERSON(2)')
		noun = dict.get_random(NOUN)
		assert_equal('ty', noun.text)
		assert_equal(2, noun.person)

		dict.read('N 100 "" PERSON(2)')
		noun = dict.get_random(NOUN)
		assert_equal('', noun.text)
		assert_equal(2, noun.person)
	end

	def test_parse_adjective
		dict = Dictionary.new
		dict.read "A 100 foo/b ATTR(przed,5)"
		adj = dict.get_random ADJECTIVE
		assert_equal 'foo', adj.text
		assert_equal 'przed', adj.attributes[0].preposition
		assert_equal 5, adj.attributes[0].case
	end

	def test_parse_verb
		dict = Dictionary.new

		dict_text = "V 100 foo/B"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert_equal('foo', verb.text)
		assert_equal(%w{B}, verb.gram_props)
		assert !verb.reflexive
		assert_equal 0, verb.objects.size

		dict_text = "V 100 foo OBJ(,,,)\nV 100 bar REFLEX"
		dict.read(dict_text)
		assert_equal('Dictionary; 1x verb', dict.to_s)
		verb = dict.get_random(VERB)
		assert_equal('bar', verb.text)
		assert_equal([], verb.gram_props)
		assert verb.reflexive
		assert_equal 0, verb.objects.size

		dict_text = "V 100 foo/B OBJ(4)"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert_equal(%w{B}, verb.gram_props)
		assert !verb.reflexive
		assert_nil verb.objects[0].preposition
		assert_equal(4, verb.objects[0].case)

		dict_text = "V 100 foo OBJ(4,na)"
		dict.read(dict_text)
		assert_equal('Dictionary', dict.to_s) # no words, parse error

		dict_text = "V 100 foo OBJ(8)"
		dict.read(dict_text)
		assert_equal('Dictionary', dict.to_s) # no words, wrong case

		dict_text = "V 100 foo OBJ(na)"
		dict.read(dict_text)
		assert_equal('Dictionary', dict.to_s) # no words, parse error

		dict_text = "V 100 foo/B OBJ(na,4) REFLEX"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert verb.reflexive
		assert_equal('na', verb.objects[0].preposition)
		assert_equal(4, verb.objects[0].case)

		dict_text = "V 100 foo INF"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert verb.objects[0].is_infinitive?

		dict_text = "V 100 foo ADJ"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert verb.objects[0].is_adjective?
	end

	def test_inline_comments
		dict = Dictionary.new
		dict.read("V 100 foo # REFLEX")
		verb = dict.get_random(VERB)
		assert !verb.reflexive
	end

	def test_only_obj_only_subj
		dict_text = <<-END
N 100 Object1 ONLY_OBJ
N  10 MySubject
N   0 Object2 OBJ_FREQ(100)
		END
		dict = Dictionary.new
		dict.read(dict_text)
		20.times do
			assert_equal('MySubject', dict.get_random_subject.text)
		end

		dict_text = <<-END
N 100 Subject1 ONLY_SUBJ
N   0 MyObject OBJ_FREQ(100)
N 100 Subject2 ONLY_SUBJ
N   0 ObjectNever
		END
		dict.read(dict_text)
		20.times do
			assert_equal('MyObject', dict.get_random_object.text)
		end

		dict_text = <<-END
N 10 MySubject3 ONLY_SUBJ
N 10 MyObject3  ONLY_OBJ
		END
		dict.read(dict_text)
		20.times do
			assert_equal('MySubject3', dict.get_random_subject.text)
			assert_equal('MyObject3', dict.get_random_object.text)
		end
	end

	def test_semantic
		dictionary = Dictionary.new
		dictionary.read("N 100 angel ONLY_WITH(GOOD,HEAVEN)\nN 100 devil NOT_WITH(HEAVEN,GOOD)")
		# ONLY_WITH is 'or', NOT_WITH is 'and'
		10.times do
			assert_equal('devil', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				word_semantic('', ['BAD']))).text)
		end
		10.times do
			assert_equal('angel', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				word_semantic('', ['HEAVEN']))).text)
			assert_equal('angel', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				word_semantic('', ['GOOD']))).text)
			assert_equal('angel', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				word_semantic('', ['GOOD','HEAVEN']))).text)
		end

		dictionary.read("A 100 holy ONLY_WITH_W(angel)\nA 100 evil NOT_WITH_W(angel,saint)")
		10.times do
			assert_equal('evil', dictionary.get_random(ADJECTIVE, &dictionary.semantic_chooser(
				word_semantic('devil', []))).text)
		end
		10.times do
			assert_equal('holy', dictionary.get_random(ADJECTIVE, &dictionary.semantic_chooser(
				word_semantic('angel', []))).text)
		end
		10.times do
			assert_nil(dictionary.get_random(ADJECTIVE, &dictionary.semantic_chooser(
				word_semantic('saint', []))))
		end

		dictionary.read("N 100 evil SEMANTIC(EVIL)\nN 100 good SEMANTIC(GOOD)")
		10.times do
			assert_equal('evil', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				Word.new('purge', [], {:takes_only=>['EVIL']}))).text)
			assert_equal('evil', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				Word.new('purge', [], {:takes_only_word=>['evil']}))).text)
			assert_equal('good', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				Word.new('spread', [], {:takes_no=>['EVIL']}))).text)
			assert_equal('good', dictionary.get_random(NOUN, &dictionary.semantic_chooser(
				Word.new('spread', [], {:takes_no_word=>['evil']}))).text)
		end
	end

	def test_nonlatin_characters
		dict = Dictionary.new
		dict.read <<-END
A 100 стоющий/b ATTR(перед,5)
O 100 "разве, что"
		END
		adj = dict.get_random ADJECTIVE
		assert_equal 'стоющий', adj.text
		assert_equal 'перед', adj.attributes[0].preposition
		assert_equal 5, adj.attributes[0].case

		assert_equal 'разве, что', dict.get_random(OTHER).text
	end

	def test_non_breakable_space
		dict = Dictionary.new
		dict.read "D 100 od~razu"
		assert_equal 'od~razu', dict.get_random(ADVERB).text
	end

	def test_validate_word_from_dictionary
		dict = Dictionary.new
		dict.read "N 10 dog\nN 10 devil SEMANTIC(BAD)"
		dict.each { |w| assert_nil dict.validate_word(w), "should report valid: #{w}" }

		dict.read <<-END
V 10 like OBJ(2)  TAKES_ONLY(cute)     # this is semantic cute, not word 'cute'
V 10 throw OBJ(2) TAKES_ONLY_W(stone)
V 10 hate OBJ(2)  TAKES_NO(LOVELY)
V 10 think OBJ(2) TAKES_NO_W(thought)
A 10 stoned       ONLY_WITH(DRUGGED)
V 10 shine        ONLY_WITH_W(sun)
A 10 cute         NOT_WITH(UGLY)
D 10 fast         NOT_WITH_W(snail)
		END
		dict.each { |w| assert_not_nil dict.validate_word(w), "should report invalid: #{w}" }

		dict.read <<-END
N 10 devil SEMANTIC(BAD)
N 10 angel SEMANTIC(GOOD)
N 10 children

V 10 like TAKES_ONLY(GOOD)
V 10 help TAKES_ONLY_W(children)
V 10 hate TAKES_NO(BAD)
V 10 fight TAKES_NO_W(children)

A 10 good     NOT_WITH(BAD)
A 10 devlish  NOT_WITH_W(devil)
A 10 helpful  ONLY_WITH(HELPFUL,GOOD)
A 10 guardian ONLY_WITH_W(angels,angel)
		END
		dict.each { |w| assert_nil dict.validate_word(w), "should report valid: #{w}" }
	end

	def test_validate_word_itself
		dict = Dictionary.new
		dict.read "V 10 help SEMANTIC(GOOD) TAKES_ONLY(GOOD)"
		dict.each { |w| assert_not_nil dict.validate_word(w), "should report invalid: #{w}" }
	end

	def test_validate_word_outside_dictionary
		dict = Dictionary.new
		dict.read "N 10 devil SEMANTIC(BAD)"
		assert_nil     dict.validate_word(Word.new('bad', [], {:only_with => ['BAD']}))
		assert_not_nil dict.validate_word(Word.new('good', [], {:only_with => ['GOOD']}))
		assert_not_nil dict.validate_word(Word.new('good', [], {:only_with => []}))
	end

	def test_validate_word_multiple_constraints
		dict = Dictionary.new
		# NOT_WITH is satisfied, but ONLY_WITH_W is not
		dict.read "N 10 devil SEMANTIC(BAD)\nN 10 angel SEMANTIC(GOOD)\nA 10 good NOT_WITH(BAD) ONLY_WITH_W(girl)"
		assert_not_nil dict.validate_word(dict.get_random(ADJECTIVE))

		# both NOT_WITH and ONLY_WITH are satisfied
		dict.read "N 10 devil SEMANTIC(BAD)\nN 10 angel SEMANTIC(GOOD)\nA 10 good NOT_WITH(BAD) ONLY_WITH(GOOD)"
		assert_nil dict.validate_word(dict.get_random(ADJECTIVE))
	end

	def test_validate_grammar_no_rule_is_not_error
		grammar = GenericGrammar.new
		grammar.read_rules "N A 2 a e a"
		dict = Dictionary.new
		dict.read "N 10 noga"
		assert_equal [], dict.validate_with_grammar(grammar)
	end

	def test_validate_grammar_no_such_rule
		grammar = GenericGrammar.new
		grammar.read_rules "N A 2 a e a"
		dict = Dictionary.new
		dict.read "N 10 noga/A\nN 10 toga/B"
		errors = dict.validate_with_grammar(grammar)
		assert_equal 1, errors.size
		assert_equal 'toga', errors.first[:word]
		assert_not_nil errors.first[:message]
	end

	def test_validate_grammar_word_does_not_match_rule
		grammar = GenericGrammar.new
		grammar.read_rules "N A 2 0 i .\nN B 11 a i a"
		dict = Dictionary.new
		dict.read "N 10 kolano/A\nN 10 wino/B"
		errors = dict.validate_with_grammar(grammar)
		assert_equal 1, errors.size
		assert_equal 'wino', errors.first[:word]
		assert_not_nil errors.first[:message]
	end

	def test_validate_grammar_many_errors
		grammar = GenericGrammar.new
		grammar.read_rules "N A 2 a e a"
		dict = Dictionary.new
		dict.read "N 10 kolano/A\nN 10 toga/B"
		errors = dict.validate_with_grammar(grammar)
		assert_equal 2, errors.size
		kolano_error = errors.find { |err| err[:word] == 'kolano' }
		toga_error =   errors.find { |err| err[:word] == 'toga' }
		assert_not_nil kolano_error[:message]
		assert_not_nil toga_error[:message]
	end

	def test_validate_with_grammar_wrong_speech_part
		grammar = GenericGrammar.new
		grammar.read_rules "N A 2 a e a"
		dict = Dictionary.new
		dict.read "A 10 tania/a"
		errors = dict.validate_with_grammar(grammar)
		assert_equal 1, errors.size
		assert_equal 'tania', errors.first[:word]
		assert_not_nil errors.first[:message]
	end

	private

	def word_semantic(text, semantic)
		Word.new(text, [], {:semantic => semantic})
	end
end

class SmartRandomDictionaryTest < Test::Unit::TestCase
	def test_correct
		dictionary_text = "N 1 foo\nN 1 bar"
		sum_freqs = 2
		dictionary = Dictionary.new
		smart_dictionary = SmartRandomDictionary.new(1)
		dictionary.read(dictionary_text)
		smart_dictionary.read(dictionary_text)
		srand 1
		assert_equal(1,rand(sum_freqs))
		assert_equal(1,rand(sum_freqs))
		assert_equal(0,rand(sum_freqs))
		100.times do
			srand 1
			assert_equal('bar', dictionary.get_random(NOUN).text)
			assert_equal('bar', dictionary.get_random(NOUN).text)
			srand 1
			assert_equal('bar', smart_dictionary.get_random(NOUN).text)
			assert_equal('foo', smart_dictionary.get_random(NOUN).text)
		end
	end
end

class ControlledDictionaryTest < Test::Unit::TestCase
	def setup
		srand
		dictionary_text = "N 100 first\nN 100 second\nN 0 impossible\nV 100 go\nV 100 run"
		@dictionary = ControlledDictionary.new
		@dictionary.read dictionary_text
	end

	def test_disallows_wrong_indices
		# no such speech part
		assert_raise(ArgumentError) { @dictionary.set_indices(666, [1]) }
		# wrong second arg
		assert_raise(ArgumentError) { @dictionary.set_indices(NOUN, NOUN) }
		# there are no adverbs in this dictionary
		assert_raise(ArgumentError) { @dictionary.set_indices(ADVERB, [1]) }
		# negative index
		assert_raise(ArgumentError) { @dictionary.set_indices(NOUN, [0, -1, 2]) }
		# too big index
		assert_raise(ArgumentError) { @dictionary.set_indices(VERB, [2]) }
		# now test a hash
		assert_raise(ArgumentError) { @dictionary.set_indices(NOUN => [0], VERB=>[2]) }
	end

	def test_correct
		@dictionary.set_indices NOUN, [0, 2, 2, 2]
		@dictionary.set_indices VERB, [1, 1, 1, 0]

		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'impossible', @dictionary.get_random(NOUN).text
		assert_equal 'impossible', @dictionary.get_random(NOUN).text
		assert_equal 'impossible', @dictionary.get_random(NOUN).text
		assert_not_nil @dictionary.get_random(NOUN) # some random
		assert_not_nil @dictionary.get_random(NOUN) # some random
		assert_not_nil @dictionary.get_random(NOUN) # some random

		assert_equal 'run', @dictionary.get_random(VERB).text
		assert_equal 'run', @dictionary.get_random(VERB).text
		assert_equal 'run', @dictionary.get_random(VERB).text
		assert_equal 'go', @dictionary.get_random(VERB).text
		assert_not_nil @dictionary.get_random(VERB) # some random
		assert_not_nil @dictionary.get_random(VERB) # some random
		assert_not_nil @dictionary.get_random(VERB) # some random

		assert_nil @dictionary.get_random(ADVERB)

		# supply with some more indices, should stop serving random numbers
		@dictionary.set_indices NOUN, [1, 1]

		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_not_nil @dictionary.get_random(NOUN) # some random now
	end

	def test_set_indices_hash
		@dictionary.set_indices(NOUN => [0,2,2,2], VERB => [1,1,1,0])
		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'run', @dictionary.get_random(VERB).text
		@dictionary.set_indices({NOUN => [0,2,2,2], VERB => [1,1,1,0]})
		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'run', @dictionary.get_random(VERB).text
	end

	def test_interrupt
		@dictionary.set_indices NOUN, [1, 1, 1, 1, 1]

		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_equal 'second', @dictionary.get_random(NOUN).text

		# we interrupt now!
		@dictionary.set_indices NOUN, [0, 0, 0, 0, 0]

		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'first', @dictionary.get_random(NOUN).text
	end
end
