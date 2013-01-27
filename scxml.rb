require 'nokogiri'
require 'set'

module SCXML
	VERSION = "0.1"

	def self.Machine(xml)
		SCXML::Machine.from_xml( Nokogiri.XML(xml,&:xinclude).root )
	end

	def to_proc; proc(&method(:from_xml)) end

	def self.least_common_ancestor(*states)
		rest = states[1..-1]
		states.first.ancestors.select(&:compound?).each do |anc|
			return anc if rest.all?{ |s| s.descendant_of?(anc) }
		end
	end
	def self.common_parallel(*states)
		# TODO: I have no idea if this is valid
		rest = states[1..-1]
		states.first.ancestors.select(&:parallel?).each do |anc|
			return anc if rest.all?{ |s| s.descendant_of?(anc) }
		end
	end
end

require_relative 'lib/notifyingarray'
require_relative 'state'
require_relative 'machine'
require_relative 'transition'
require_relative 'executable'
require_relative 'interpreter'
require_relative 'event'
require_relative 'datamodel'
