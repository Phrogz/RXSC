require 'nokogiri'
require 'set'

module SCXML
	VERSION = "0.1"

	def self.Machine(xml)
		SCXML::Machine.new( Nokogiri.XML(xml).root )
	end

	def to_proc; proc(&method(:new)) end

	def self.least_common_ancestor(*states)
		rest = states[1..-1]
		states.first.ancestors.select(&:compound?).each do |anc|
			return anc if rest.all?{ |s| s.descendant_of?(anc) }
		end
	end
end

require_relative 'state'
require_relative 'machine'
require_relative 'transition'
require_relative 'executable'
require_relative 'interpreter'
require_relative 'event'
require_relative 'datamodel'

