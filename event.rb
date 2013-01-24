module SCXML; end
class SCXML::Event
	attr_reader :name, :data
	def initialize(name,data=nil)
		@name = name
		@data = data
	end
	def quit?
		name=="quit"
	end
end