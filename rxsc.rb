require 'nokogiri'
require 'set'

module RXSC
	VERSION = "0.1"
	def to_proc; proc(&method(:from_xml)) end

end

require_relative 'lib/notifyingarray'
require_relative 'rxsc/state'
require_relative 'rxsc/machine'
require_relative 'rxsc/transition'
require_relative 'rxsc/executable'
require_relative 'rxsc/interpreter'
require_relative 'rxsc/event'
require_relative 'rxsc/datamodel'
