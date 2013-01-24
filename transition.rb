module SCXML; end
class SCXML::Transition
	attr_reader :source, :targets, :events, :cond, :type
	def initialize(source=nil,options={})
		@source  = source
		@targets = []
		@events  = []
		@exec    = NotifyingArray.new.on_change{ |e| e.parent = self }

		@cond = options[:cond] if options.key?(:cond)
		case t=options[:targets]
			when Array  then @targets.concat t
			when String then @targets << t
		end
		case e=options[:events]
			when Array  then @events.concat e
			when String then @events << e
		end
		@events.each{ |s| s.sub! /\.\*?\z/, '' }
	end

	def read_xml(el)
		@targets.concat el[:target].split(/\s+/) if el[:target]
		@events.concat  el[:event ].split(/\s+/) if el[:event ]
		@cond   = el[:cond]
		@type   = el[:type]
		@exec.concat el.elements.map(&SCXML::Executable)
		self
	end

	def parent=(state)
		@source = state
	end

	def machine
		@source && @source.machine
	end

	def connect_references!
		@targets.map! do |target|
			if target.is_a?(String)
				unless state=machine[target]
					raise "Cannot find target state #{target.inspect}"
				end
				state
			else
				target
			end
		end
	end

	def has_targets?
		!@targets.empty?
	end

	def matches_event_name?(name)
		chunks = name.split('.')
		@events.any?{ |e| e=='*' || e==chunks[0,e.split('.').length].join('.') }
	end

	def condition_matched?(datamodel)
		if !@cond || @cond.empty?
			true
		else
			datamodel.run(@cond)
		end
	end

	def preempt_level
		@preempt_level ||= begin
			if @targets.empty? then 1
			elsif iswithinsinglechildofparallel then 2
			else 3
			end
		end
	end
	def run
		@exec.each(&:run)
	end
	def to_s
		"<#{self.class} #{source.path} -> #{targets.map{ |t| t.is_a?(SCXML::State) ? t.path : t}.join(' & ')}>"
	end
end