require 'nokogiri'
require 'set'

module RXSCy
	VERSION = "0.1"
	def to_proc; proc(&method(:from_xml)) end

end

require_relative 'lib/notifyingarray'
require_relative 'rxscy/state'
require_relative 'rxscy/machine'
require_relative 'rxscy/transition'
require_relative 'rxscy/executable'
require_relative 'rxscy/interpreter'
require_relative 'rxscy/event'
require_relative 'rxscy/datamodel'
