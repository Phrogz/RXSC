# encoding: UTF-8
require 'rubygems'
$: << 'lib'
require 'rxsc'

Gem::Specification.new do |s|
	s.name        = "rxsc"
	s.version     = RXSC::VERSION
	s.date        = "2013-01-31"
	s.authors     = ["Gavin Kistner"]
	s.email       = "gavin@phrogz.net"
	s.homepage    = "http://github.com/Phrogz/RXSC"
	s.summary     = "Run SCXML statecharts with a Ruby data model."
	s.description = "Runtime for SCXML statecharts. All expressions are evaluated in the Ruby interpreter. Subscribe to notifications as state changes occur."
	s.files       = %w[ lib/**/* test/**/* ].inject([]){ |all,glob| all+Dir[glob] }
	s.test_file   = 'test/test_all.rb'
	s.add_dependency 'nokogiri'
	s.requirements << "Nokogiri gem for parsing HTML after creation (and manipulating)."
	#s.has_rdoc = true
end
