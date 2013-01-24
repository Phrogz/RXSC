class NotifyingArray < Array
	def on_change(&block); @on_change = block; self end
	def <<(o);        super.tap{ @on_change[o]      }; end
	def concat(a);    super.tap{ a.each(&@on_change) }; end
	def push(*a);     super.tap{ a.each(&@on_change) }; end
	def unshift(*a);  super.tap{ a.each(&@on_change) }; end
	def insert(i,*a); super.tap{ a.each(&@on_change) }; end
	def []=(*a,&b);   super.tap{   each(&@on_change) }; end
	def map!(*a,&b);  super.tap{   each(&@on_change) }; end
	def fill(*a,&b);  super.tap{   each(&@on_change) }; end
	def flatten!(*a); super.tap{   each(&@on_change) }; end
	def replace(*a);  super.tap{   each(&@on_change) }; end
end
