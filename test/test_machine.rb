require 'test/unit'
require_relative '../rxscy'

class MachineTester < Test::Unit::TestCase
	def setup
		@data = File.join(File.dirname(__FILE__),'data')
		@xml  = Dir.chdir(@data){ Hash[
			Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
		] }
	end

	def test_can_parse_xml
		simple = RXSCy.Machine(@xml['simple'])

		assert_equal(2,simple.states.length)
		s1 = simple.states.first
		assert_equal('s1',s1.id)
		assert_equal(s1,simple['s1'])
		assert_equal(s1,simple[:s1])
		s11 = s1.states.first
		assert_equal('s11',s11.id)
		assert_equal(simple,s1.parent)
		assert_equal(s1,s11.parent)
		assert(simple.transitions.empty?)
		refute(s1.transitions.empty?)
		assert_equal(simple,s1.parent)
		assert_equal(s1,s11.parent)

		assert(s1.compound?)
		refute(s11.compound?)

		s1t1 = s1.transitions.first
		assert_equal(s1,s1t1.source)
		assert_equal('e',s1t1.events.first)
		assert_equal(simple['s21'],s1t1.targets.first)
	end

	def test_can_run
		simple = RXSCy.Machine(@xml['simple'])
		config = simple.configuration
		assert(config.empty?)

		simple.start
		s1  = simple['s1']
		s11 = simple['s11']
		s2  = simple['s2']
		s21 = simple['s21']
		assert(config.member?(s1))
		assert(config.member?(s11))

		config_was = config.dup
		simple.fire_event('e')
		assert_equal(config_was,config,"No change without step")

		simple.step
		assert(config.member?(s2))
		assert(config.member?(s21))
		config_was = config.dup

		simple.step
		assert_equal(config_was,config,"No change without event")
	end

	def test_transition_name_matching
		t = RXSCy::Transition.new( nil, events:%w[a b.c c.d.e d.e.f.* f.] )
		assert(t.matches_event_name?('a'))
		assert(t.matches_event_name?('a.b'))
		assert(t.matches_event_name?('b.c'))
		assert(t.matches_event_name?('b.c.d'))
		assert(t.matches_event_name?('c.d.e'))
		assert(t.matches_event_name?('c.d.e.f'))
		assert(t.matches_event_name?('d.e.f'))
		assert(t.matches_event_name?('d.e.f.g'))
		assert(t.matches_event_name?('f'))
		assert(t.matches_event_name?('f.g'))

		refute(t.matches_event_name?('alpha'))
		refute(t.matches_event_name?('b.charlie'))
		refute(t.matches_event_name?('d.e.frank'))
		refute(t.matches_event_name?('frank'))
		refute(t.matches_event_name?('b'))
		refute(t.matches_event_name?('.*'))
		refute(t.matches_event_name?('.'))
		refute(t.matches_event_name?('z.a'))

		t = RXSCy::Transition.new( nil, events:'*' )
		assert(t.matches_event_name?('a'))
		assert(t.matches_event_name?('a.b'))
		assert(t.matches_event_name?('c.d.e.f'))
	end

	def test_transition_conditions
		d  = RXSCy::Datamodel.new
		d.run('ok = false')
		t0 = RXSCy::Transition.new( nil              )
		t1 = RXSCy::Transition.new( nil,cond:"false" )
		t2 = RXSCy::Transition.new( nil,cond:"true"  )
		t3 = RXSCy::Transition.new( nil,cond:"ok"    )
		t4 = RXSCy::Transition.new( nil,cond:"@yes"  )

		assert t0.condition_matched?(d)
		refute t1.condition_matched?(d)
		assert t2.condition_matched?(d)
		refute t3.condition_matched?(d)
		refute t4.condition_matched?(d)
		d.run('ok = true; @yes = :very')
		assert t3.condition_matched?(d)
		assert t4.condition_matched?(d)
	end

	def test_transition_targets
		simple = RXSCy.Machine(@xml['simple'])

		t0 = simple['s2'].transitions.first
		refute(t0.has_targets?)

		t0 = RXSCy::Transition.new( nil )
		refute(t0.has_targets?)

		t1 = simple['s1'].transitions.first
		assert(t1.has_targets?)

		t1 = RXSCy::Transition.new( nil,targets:"s21" )
		assert(t1.has_targets?)
		
		t1 = RXSCy::Transition.new( nil,targets:%w[s2 s21] )
		assert(t1.has_targets?)
	end

	def test_history
		h = RXSCy.Machine(@xml['history']).start
		config = h.configuration

		assert_equal(1,h['universe'].states.select(&:history?).length)
		assert(config.member?(h['action-1']))
		
		h.fire_event "action.done"
		h.step
		assert(config.member?(h['action-2']))

		h.fire_event "application.error.CPUONFIRE"
		h.step
		assert(config.member?(h['error-handler']))

		h.fire_event "error.handled"
		h.step
		assert(config.member?(h['action-2']))

		h.fire_event "action.done"
		h.step
		assert(config.member?(h['action-3']))

		h.fire_event "application.error.smoldering"
		h.fire_event "error.handled"
		h.step
		assert(config.member?(h['action-3']))

		h.fire_event "action.done"
		h.step
		assert(config.member?(h['action-4']))
		p config.map(&:id)
		h.step
		p config.map(&:id)
		refute(h.running?)
	end

	def test_datamodel		
		d = RXSCy::Datamodel.new
		d[:foo] = 17
		assert_equal(17,d[:foo])
		assert_equal(17,d.run("foo"))
		d.run("bar = 6")
		assert_equal(42,d.run("bar*7"))

		doc = RXSCy.Machine(@xml['datamodel'])
		doc.start
		d = doc.datamodel
		assert_equal( 2008,     d[:year]       )
		assert_equal( "Mr Big", d[:ceo]        )
		assert_equal( true,     d[:profitable] )
		assert_equal( 42,       d[:kidlins]    )

		doc = RXSCy.Machine(@xml['counting']).start
		10.times{ doc.fire_event('e') }
		doc.step
		assert_equal( 10, doc.datamodel['transitions'] )
	end

	def test_events
		mic = RXSCy.Machine(@xml['microwave'])
		assert_equal Set.new(%w[turn.on turn.off tick door.open door.close]), mic.events
	end

	def test_final
		final1 = RXSCy.Machine(@xml['final1']).start
		final1.fire_event('e').step
		refute(final1.running?)
	end

	def test_parallel_microwave
		# TEST IN PROGRESS
		mic = RXSCy.Machine(@xml['microwave']).start
		conf = mic.configuration
		p a:conf.map(&:id)
		mic.fire_event('turn.on').step
		p b:conf.map(&:id)
		mic.step
		p c:conf.map(&:id)
		3.times{ mic.fire_event('tick').step; p c2:conf.map(&:id) }
		mic.fire_event('door.open').step
		p d:conf.map(&:id)
		10.times{ mic.fire_event('tick') }
		mic.step
		p e:conf.map(&:id)
	end
end