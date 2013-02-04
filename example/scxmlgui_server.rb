require 'sinatra'
require 'haml'
require_relative '../lib/rxsc'
$machine = RXSC(IO.read('dashboard.scxml')).start
p $machine.active_state_ids
p $machine.active_atomic_ids
p $machine.instance_eval{ @scxml.xpath('//xmlns:transition').length  }
get '/' do
	haml :index
end

helpers do
	def nest(h,path)
		"<ul>#{h.sort_by{|k,v|k.downcase}.map{|k,v|"<li><span id='#{k}'>#{k}</span>#{nest(v)}</li>"}.join}</ul>" unless !h || h.empty?
	end
	def nested_events
		hier = Hash.new{ |h,k| h[k]=Hash.new(&h.default_proc) }
		$machine.events.each{ |evt| h=hier; evt.split('.').each{ |part| h=h[part] } }
		nest(hier)
	end
	def nested_states
		nest($machine.state_hierarchy)
	end
end

__END__
@@ layout
!!! 5
%html
	%head
		%meta(charset='utf-8')
		%title SCXML Interactor
		:css
			html, body { margin:0; padding:0; height:100%; font-family:'Calibri'; font-size:10pt }
			#events, #states, #output { position:fixed; top:0; bottom:0; left:0; right:0; overflow:scroll }
			#states { right:60% } #output { left:40%; right:20% } #events { left:80%  }
			h2 { margin:0 }
			#events span { background:#eee; padding:0 0.5em; border:3px outset #999; cursor:pointer; display:inline-block; margin:1px }
	%body= yield

@@ index
%section#events
	%h2 Events
	#{nested_events}
%section#states
	%h2 States
	#{nested_states}
%section#output
	%h2 Log