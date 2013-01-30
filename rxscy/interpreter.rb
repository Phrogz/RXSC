module RXSCy;end

class RXSCy::Machine
	def self.least_common_ancestor(*states)
		rest = states[1..-1]
		states.first.ancestors.select(&:compound?).each do |anc|
			return anc if rest.all?{ |s| s.descendant_of?(anc) }
		end
	end

	def self.least_common_parallel(*states)
		# https://github.com/jroxendal/PySCXML/wiki/Transition-Preemption-in-SCXML
		rest = states[1..-1]
		states.first.ancestors.select(&:parallel?).each do |anc|
			return anc if rest.all?{ |s| s.descendant_of?(anc) }
		end
	end

	MAX_ITERATIONS = 10

	def running?
		!!@running
	end

	def is_active?(state_id)
		@configuration.any?{ |s| s.id==state_id }
	end

	def active_state_ids
		Set.new @configuration.map(&:id)
	end

	def active_atomic_ids
		Set.new @configuration.select(&:atomic?).map(&:id)
	end

	def fire_event( name, data=nil, internal=false )
		p fire_event:name, data:data, internal:internal if $DEBUG
		(internal ? @internal_queue : @external_queue) << RXSCy::Event.new(name,data)
		self
	end

	def start
		fail_with_error unless validate
		interconnect!

		@configuration.clear
		@states_to_invoke   = Set.new
		@history_value      = {} # Indexed by state
		@datamodel          = RXSCy::Datamodel.new(self)
		@datamodel['_name'] = @name
		@states_inited     = Set.new
		@internal_queue    = []
		@external_queue    = []
		@running           = true

		@datamodel.crawl(self,@states_inited) if self.binding=="early"

		@initial.transitions.first.run
		enter_states_for_transitions(@initial.transitions)

		step
	end

	def stop(msg=nil)
		puts "Stopping #{self.name} #{"because #{msg}" if msg}" if $DEBUG
		@running = false
	end

	def step
		return unless @running
		while @running
			enabled_transitions = nil
			stable = false

			# Handle eventless transitions and transitions triggered by internal events
			iterations = 0
			while @running && !stable && iterations < MAX_ITERATIONS
				enabled_transitions = eventless_transitions
				if enabled_transitions.empty?
					if @internal_queue.empty?
						stable = true
					else
						evt = @internal_queue.shift
						@datamodel["_event"] = evt
						enabled_transitions = transitions_for(evt)
					end
				end
				microstep(enabled_transitions) unless enabled_transitions.empty?
				iterations += 1
			end

			warn "WARNING: stopped unstable system after #{iterations} iterations" if iterations >= MAX_ITERATIONS

			# TODO: Enable invoke
			# @states_to_invoke.each{ |state| state.invokes.each(&:run) }
			# @states_to_invoke.clear


			# Invoking may have raised internal error events and we need to back up and handle those too        
			next unless @internal_queue.empty?


			# Normally this is an asynchronous blocking call that waits for an event; instead, we'll bail if we can't find an event
			if evt = @external_queue.shift
				change = true
				if evt.quit?
					stop("Quit event received")
					break
				end
				@datamodel["_event"] = evt

				# TODO: Enable invoke
				# @configuration.each do |state|
				# 	state.invokes.each do |inv|
				# 		applyFinalize(inv, externalEvent) if inv.invokeid==evt.invokeid
				# 		send(inv.id, externalEvent) if inv.autoforward?
				# 	end
				# end

				enabled_transitions = transitions_for(evt)
				microstep(enabled_transitions) unless enabled_transitions.empty?
				puts "    step-external: #{@configuration.map(&:path).join(' :: ')}" if $DEBUG
			else
				break
			end
		end
	
		exit_interpreter! unless @running
		puts "  post-step-config: #{@configuration.map(&:path).join(' :: ')}" if $DEBUG
		self
	end

	private

	def microstep(transitions)
		p microstep:transitions if $DEBUG
		exit_states_for_transitions(transitions)
		transitions.each(&:run)
		enter_states_for_transitions(transitions)
	end

	def enter_states_for_transitions(transitions)
		states_to_enter          = Set.new
		states_for_default_entry = Set.new

		add_states_to_enter = ->(state) do
			if state.history?
				if @history_value[state]
					@history_value[state].each do |s|
						add_states_to_enter[s]
						s.ancestors(state).each{ |anc| states_to_enter << anc }
					end
				else
					state.transitions.each{ |t| t.targets.each{ |s| add_states_to_enter[s] } }
				end
			else
				states_to_enter << state
				if state.compound?
					states_for_default_entry << state
					state.initial.transitions.first.targets.each{ |s| add_states_to_enter[s] }
				elsif state.parallel?
					state.states.select(&:real?).each{ |s| add_states_to_enter[s] }
				end
			end
		end

		transitions.select(&:has_targets?).each do |t|
			if t.type == "internal" && t.source.compound? && t.targets.all?{ |s| s.descendant_of?(t.source) }
				ancestor = t.source
			else
				ancestor = RXSCy::Machine.least_common_ancestor( t.source, *t.targets )
			end
			t.targets.each{ |s| add_states_to_enter[s] }
			t.targets.each do |s|
				s.ancestors(ancestor).each do |anc|
					states_to_enter << anc
					if anc.parallel?
						anc.states.select(&:real?).each do |child|
							add_states_to_enter[child] unless states_to_enter.any?{ |s| s.descendant_of?(child) }
						end
					end
				end
			end
		end

		enter_states(states_to_enter,states_for_default_entry)
	end

	def enter_states(states,states_for_default_entry)
		states.sort_by(&:entry_ordering).each do |s|
			@configuration    << s
			@states_to_invoke << s
			if binding=="late" && !@states_inited.member?(s)
				@datamodel.populate_from(s)
				@states_inited << s
			end
			s.onenters.each(&:run)
			s.initial.transitions.first.run if states_for_default_entry.member?(s)
			if s.final?
				parent = s.parent
				if parent.scxml?
					stop("Final state #{s.id} entered.")
				else
					fire_event( "done.state.#{parent.id}", s.donedata, true )
					grandparent = parent.parent
					if grandparent && grandparent.parallel? && grandparent.states.select(&:real?).all?{ |s| in_final_state?(s) }
						fire_event( "done.state.#{grandparent.id}", nil, true )
					end
				end
			end
		end
	end

	def exit_states_for_transitions(transitions)
		states_to_exit = Set.new
		transitions.select(&:has_targets?).each do |t|
			if t.type=="internal" && t.source.compound? && t.targets.all?{ |s| s.descendant_of?(t.source) }
				ancestor = t.source
			else
				ancestor = RXSCy::Machine.least_common_ancestor(t.source,*t.targets)
			end
			@configuration.each{ |s| states_to_exit << s if s.descendant_of?(ancestor) }
		end

		states_to_exit.each{ |s| @states_to_invoke.delete s }
		states_to_exit = states_to_exit.sort_by(&:exit_ordering)

		# Record the history before exiting
		states_to_exit.each do |s|
			s.states.select(&:history?).each do |h|
				@history_value[h] = Set.new(@configuration.select{ |s0| h.type == "deep" ? ( s0.atomic? && s0.descendant_of?(s) ) : (s0.parent == s) })
			end
		end

		# Exit the states
		states_to_exit.each do |s|
			s.onexits.each(&:run)
			# s.invokes.each(&:cancel) # TODO: Handle invokes
			@configuration.delete s
		end
	end

	def exit_interpreter!
		@configuration.sort_by(&:exit_ordering).each do |s|
			s.onexits.each(&:run)
			# s.invokes.each(&:cancel) # TODO: invokes
			# @configuration.delete(s)
			if s.final? && s.parent.scxml?
				break
				# TODO: return the done event with self.donedata to notify other machines
			end
		end
	end

	def transitions_for(event)
		enabled_transitions = Set.new
		@configuration.select(&:atomic?).sort_by(&:entry_ordering).each do |state|
			catch :found_matching do
				[state,*state.ancestors].each do |s|
					s.transitions.each do |t|
						if t.matches_event_name?(event.name) && t.condition_matched?(@datamodel)
							enabled_transitions << t
							throw :found_matching
						end
					end
				end
			end
		end
		filter_preempted(enabled_transitions)
	end

	def eventless_transitions
		enabled_transitions = Set.new
		@configuration.select(&:atomic?).sort_by(&:entry_ordering).each do |state|
			catch :found_matching_eventless do
				[state,*state.ancestors].each do |s|
					s.transitions.each do |t|
						if t.events.empty? && t.condition_matched?(@datamodel)
							enabled_transitions << t
							throw :found_matching_eventless
						end
					end
				end
			end
		end
		filter_preempted(enabled_transitions)
	end

	def filter_preempted(transitions)
		Set.new.tap{ |filtered| transitions.each{ |t1|
			filtered << t1 unless filtered.any?{ |t2| (t2.preempt_category==3) || (t2.preempt_category==2 && t1.preempt_category==3)  }
		} }
	end

	def in_final_state?( state )
		real_children = state.states.select(&:real?)
		if state.compound?
			real_children.any?{ |s| @configuration.member?(s) && s.final? }
		elsif state.parallel?
			real_children.all?{ |s| in_final_state?(s) }
		end		
	end

	def validate
		# warn "TODO: validate document fully"
		true
	end
end