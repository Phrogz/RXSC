module SCXML; end
class SCXML::Datamodel
	def initialize
		@__scope = binding
	end
	def []( key )
		run(key.to_s)
	end
	def []=( key, value )
		run("#{key}=nil; ->(v){ #{key}=v }").call(value)
	end
	def run(code)
		@__scope.eval(code,'datamodel_evaluator')
	end
	def variables
		run('Hash[local_variables.map{ |s| [s.to_s,eval(s.to_s)] }]')
	end
	def crawl(machine,states_inited=Set.new)
		queue = [machine]
		while s = queue.shift
			next if states_inited.member?(s)
			states_inited << s
			queue.concat(s.states)
			populate_from(s)
		end
	end
	def populate_from(state)
		state.data.each(&:run)
	end
end

class SCXML::Datamodel::Datum
	extend SCXML
	attr_reader :id, :src, :expr
	attr_accessor :parent
	def self.from_xml(el)
		if    el[:src ] then new( el[:id],  src:el[:src]  )
		elsif	el[:expr] then new( el[:id], expr:el[:expr] )
		else                 new( el[:id], expr:el.text   )
		end
	end
	def initialize(id,data={})
		@id      = id
		@expr    = data[:expr]
		@src     = data[:src]
	end
	def machine
		@parent && @parent.machine
	end
	def run
		raise "<data src='...'> not supported" if @src
		machine.datamodel[@id] = machine.datamodel.run(@expr)
	end
end
