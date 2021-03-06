class Narrative
  def data 
    @data ||= {
      state: :begin,
      previous: nil
    }
  end

  # static
  def self.stories 
    @stories ||= Hash.new
  end

  def self.create(name, &block)
    stories[name] = block
  end

  # instance
  def states
    @states ||= Hash.new
  end

  def data_listeners
    @data_listeners ||= Set.new
  end

  def initialize(name, d)
    self.instance_exec &(Narrative.stories[name])
    @story = name
    @data = d
  end

  # state.enter, state.leave, state.action.other
  def state(s, on: 'enter', &block)
    states["#{s}.#{on}"] = block
  end

  # Call event on state, log state for input but not "enter" or "leave"
  def input(input, *params)
    result = fire(data[:state], input, *params)
    go( result, *params ) if result && result.is_a?(Symbol)
  end

  def go(to, *params)
    @data[:previous] = data[:state]
    @data[:state] = to
    dirty
    fire(data[:previous], 'leave', *params)
    fire(data[:state], 'enter', *params)
    dirty
  end

  def fire(state, event, *params)
    event = states["#{state}.#{event}"]
    self.instance_exec(*params, &event) if ( event )
  end

  # listen for dirty data
  def on_data(&block)
    data_listeners << block
  end

  # There's probably a smarter way to do this
  def dirty
    data_listeners.each do | listener |
      listener.call(data)
    end
  end

  # Utility
  def reply (as, raw, options = {})
    options[:raw] = raw
    options[:topic_id] ||= data[:topic_id] if data[:topic_id]

    PostCreator.create( as, options )
  end

  def dialogue_file
    @dialogue_file ||= YAML.load_file File.expand_path("../narratives/#{ @story }/dialogue.en.erb.yml", __FILE__)
  end

  def dialogue( term, b=nil)
    (ERB.new dialogue_file[term]).result(b || binding)
  end
end

## TODO: Test properly

# Narrative.create 'gun' do |n|
#   n.state :begin do 
#     puts 'Ready!'
#   end

#   n.state :begin, on: 'fire' do 
#     puts 'BANG!'
#     :empty
#   end

#   n.state :empty do 
#     puts 'TIME TO RELOAD!'
#   end

#   n.state :empty, on: 'fire' do
#     puts "Please reload"
#   end

#   n.state :empty, on: 'reload' do
#     puts "Reloaded!"
#     :begin
#   end
# end

# gun = Narrative.new 'gun'

# gun.input 'fire'
# gun.input 'fire'
# gun.input 'fire'
# gun.input 'reload'
# gun.input 'fire'

## Fun one 

# Narrative.create 'turnstile' do |n|
#   n.state :locked, on: 'coin' do 
#     puts 'BEEP'
#     :unlocked
#   end

#   n.state :locked, on: 'push' do 
#     puts 'NOPE'
#   end

#   n.state :unlocked, on: 'push' do
#     puts 'CLICK'
#     :locked
#   end
# end

# ts = Narrative.new 'turnstile', :locked

# ts.input 'coin'
# ts.input 'push'
# ts.input 'push'
# ts.input 'push'
# ts.input 'coin'
# ts.input 'coin'
# ts.input 'push'