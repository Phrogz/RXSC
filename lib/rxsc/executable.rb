class RXSC

	to_execute 'log' do |el|
		puts [el['label'],el['expr'] && @datamodel.run(el['expr'])].compact.join(': ') if $DEBUG
	end
	
	to_execute 'raise' do |el|
		fire_event(el['event'],nil,true)
	end

	to_execute 'assign' do |el|
		@datamodel[el['location']] = el['expr'] ? @datamodel.run(el['expr']) : el.text
	end

	to_execute 'send' do |el|
		warn "Delayed <send> events not supported (#{el})" if el['delay'] || el['delayexpr']

		name = el['event'] ? el['event'] : @datamodel.run(el['eventexpr'])
		data = Hash[ el['namelist'].split.map{ |n| [n,@datamodel[n]] } ] if el['namelist']
		# TODO: support type/typeexpr, just to yell about non-support of non-SCXML types
		# TODO: support target/targetexpr, mostly for targetting other RXSC machines

		if el['idlocation'] && !el['id']
			@datamodel[@datamodel.run(el['idlocation'])] = @SecureRandom.uuid
		end

		fire_event(name,data,false)
	end
end