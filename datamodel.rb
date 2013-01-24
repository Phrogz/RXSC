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
		state.data.each{ |datum| self[datum.id] = datum.value_in(self) }
	end
end

class SCXML::Datamodel::Datum
	extend SCXML
	attr_reader :id
	def initialize(el)
		@id      = el[:id]
		@expr    = el[:expr]
		@src     = el[:src]
		@content = el.text unless el.children.empty?
		raise "<data> must have an id (#{el})" unless @id
		raise "<data> must have either expr or src, but not both (#{el})" if @expr && @src
		raise "<data> cannot of children if it has either expr or src (#{el})" if @content && (@expr || @src)
	end
	def value_in(datamodel)
		raise "<data src='...'> not supported" if @src
		datamodel.run(@expr || @content)
	end
end
