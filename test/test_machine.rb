require 'test/unit'
require_relative '../scxml'

class MachineTester < Test::Unit::TestCase
	def setup
		@data = File.join(File.dirname(__FILE__),'data')
		@xml  = Dir.chdir(@data){ Hash[
			Dir['*.scxml'].map{ |f| [f[/[^.]+/],IO.read(f,encoding:'utf-8')] }
		] }
	end
	def test_can_parse_xml
		simple = SCXML.Machine(@xml['simple'])

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

		assert(s1.compound?)
		refute(s11.compound?)

		s1t1 = s1.transitions.first
		assert_equal(s1,s1t1.source)
		assert_equal('e',s1t1.events.first)
		assert_equal(simple['s21'],s1t1.targets.first)
	end
	def test_can_run
		simple = SCXML.Machine(@xml['simple'])
		# p simple.configuration
		simple.start
		# p simple.configuration
		simple.fire_event('e')
		# p simple.configuration
		simple.step
		# p simple.configuration
		simple.step
		# p simple.configuration
	end
	def test_transition_name_matching
		t = SCXML::Transition.new( nil, events:%w[a b.c c.d.e d.e.f.* f.] )
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

		refute(t.matches_event_name?('b'))
		refute(t.matches_event_name?('.*'))
		refute(t.matches_event_name?('.'))

		t = SCXML::Transition.new( nil, events:'*' )
		assert(t.matches_event_name?('a'))
		assert(t.matches_event_name?('a.b'))
		assert(t.matches_event_name?('c.d.e.f'))
	end

	def test_transition_conditions
		d  = SCXML::Datamodel.new
		d.run('ok = false')
		t0 = SCXML::Transition.new( nil              )
		t1 = SCXML::Transition.new( nil,cond:"false" )
		t2 = SCXML::Transition.new( nil,cond:"true"  )
		t3 = SCXML::Transition.new( nil,cond:"ok"    )
		t4 = SCXML::Transition.new( nil,cond:"@yes"  )

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
		simple = SCXML.Machine(@xml['simple'])

		t0 = simple['s2'].transitions.first
		refute(t0.has_targets?)

		t0 = SCXML::Transition.new( nil )
		refute(t0.has_targets?)

		t1 = simple['s1'].transitions.first
		assert(t1.has_targets?)

		t1 = SCXML::Transition.new( nil,targets:"s21" )
		assert(t1.has_targets?)
		
		t1 = SCXML::Transition.new( nil,targets:%w[s2 s21] )
		assert(t1.has_targets?)
	end

	def test_history
		history = SCXML.Machine(@xml['history'])
		h = history['universe'].states.select(&:history?)
		assert_equal(1,h.length)

		history.start
		# p history.configuration
		
		history.fire_event "action.done"
		history.step
		# p history.configuration

		history.fire_event "application.error.CPUONFIRE"
		history.step
		# p history.configuration

		history.fire_event "error.handled"
		history.step
		# p history.configuration
	end

	def test_datamodel		
		d = SCXML::Datamodel.new
		d[:foo] = 17
		assert_equal(17,d[:foo])
		assert_equal(17,d.run("foo"))
		d.run("bar = 6")
		assert_equal(42,d.run("bar*7"))

		doc = SCXML.Machine(@xml['datamodel'])
		d = SCXML::Datamodel.new
		d.crawl(doc)
		assert_equal( 2008,     d[:year]       )
		assert_equal( "Mr Big", d[:ceo]        )
		assert_equal( true,     d[:profitable] )
		assert_equal( 42,       d[:kidlins]    )
	end
end