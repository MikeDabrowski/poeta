#!/usr/bin/ruby -w

require 'sentence'

class Verse
	def initialize(dictionary,grammar,sentence_mgr,optimal_length=nil,rhyme=false)
		lines = 4
		sentences = []
		lines.times() { sentences << sentence_mgr.random_sentence }
		sentences_text = []
		sentences.each { |s| sentences_text << s.write }
		@subject = sentences[0].subject
		@text = sentences_text.join("\n")
	end

	# gets subject (noun) representing the verse
	def subject
		@subject
	end

	def to_s
		@text
	end
end

class Poem
	def initialize(dictionary,grammar,sentence_mgr,verses_number=4)
		if (verses_number == 0):
			@text = ''
			return
		end
		verses = Array.new(verses_number)
		(0..verses_number-1).each { |i| verses[i] = Verse.new(dictionary,grammar,sentence_mgr) }

		title_sentence_mgr = SentenceManager.new(dictionary)
		title_sentences_defs = <<-END
60 ${NOUN}
40 ${ADJ} ${NOUN}
 2 ${NOUN} ${ADJ}
10 ***
 		END
		title_sentence_mgr.read(title_sentences_defs)

		title_sentence = title_sentence_mgr.random_sentence
		title_sentence.subject = verses[0].subject
		title = title_sentence.write

		@title = title
		@text = "\"#{@title}\"\n\n#{verses.join("\n\n")}"
	end

	def text
		@text
	end
end