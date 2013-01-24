module SCXML; end
class SCXML::Transition
	extend SCXML
	attr_reader :source, :targets, :events, :cond, :type
	def initialize(source,options={})
		@source  = source
		@targets = []
		@events  = []
		if options[:element]
			@el = options[:element]
			@targets.concat @el[:target].split(/\s+/) if @el[:target]
			@events.concat  @el[:event ].split(/\s+/) if @el[:event ]
			@cond   = @el[:cond]
			@type   = @el[:type]
			@exec   = @el.elements.map(&SCXML::Executable)
			@exec   = nil if @exec.empty?
		else
			@cond = options[:cond] if options.key?(:cond)
			case t=options[:targets]
				when Array  then @targets.concat t
				when String then @targets << t
			end
			case e=options[:events]
				when Array  then @events.concat e
				when String then @events << e
			end
		end
		@events.each{ |s| s.sub! /\.\*?\z/, '' }
	end

	def connect_references!
		@targets.map! do |target|
			if target.is_a?(String)
				unless state=source.machine[target]
					raise "Cannot find target state #{target.inspect} in transition #{@el}"
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
		@exec.each(&:run) if @exec
	end
	def to_s
		"<#{self.class} #{source.path} -> #{targets.map{ |t| t.is_a?(SCXML::State) ? t.path : t}.join(' & ')}>"
	end
end