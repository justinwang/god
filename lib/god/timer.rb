module God
  
  class TimerEvent
    attr_accessor :condition, :at, :phase
    
    # Instantiate a new TimerEvent that will be triggered after the specified delay
    #   +condition+ is the Condition
    #   +delay+ is the number of seconds from now at which to trigger
    #
    # Returns TimerEvent
    def initialize(condition, delay)
      self.condition = condition
      self.phase = condition.watch.phase
      
      now = (Time.now.to_f * 4).round / 4.0
      self.at = now + delay
    end
  end
  
  class Timer
    INTERVAL = 0.25
    
    attr_reader :events, :timer
    
    @@timer = nil
    
    # Get the singleton Timer
    #
    # Returns Timer
    def self.get
      @@timer ||= Timer.new
    end
    
    # Reset the singleton Timer so the next call to Timer.get will
    # create a new one
    #
    # Returns nothing
    def self.reset
      @@timer = nil
    end
    
    # Instantiate a new Timer and start the scheduler loop to handle events
    #
    # Returns Timer
    def initialize
      @events = []
      @conditions = []
      @mutex = Monitor.new
      
      @timer = Thread.new do
        loop do
          begin
            # get the current time
            t = Time.now.to_i
            
            # iterate over each event and trigger any that are due
            @mutex.synchronize do
              triggered = []
              
              @events.each do |event|
                if t >= event.at
                  # trigger the event and mark it for removal
                  self.trigger(event)
                  triggered << event
                else
                  # events are ordered, so we can bail on first miss
                  break
                end
              end
              
              # remove all triggered events
              triggered.each do |event|
                @conditions.delete(event.condition)
                @events.delete(event)
              end
            end
          rescue Exception => e
            message = format("Unhandled exception (%s): %s\n%s",
                             e.class, e.message, e.backtrace.join("\n"))
            applog(nil, :fatal, message)
          ensure
            # sleep until next check
            sleep INTERVAL
          end
        end
      end
    end
    
    # Create and register a new TimerEvent
    #   +condition+ is the Condition
    #   +delay+ is the number of seconds to delay (default: interval defined in condition)
    #
    # Returns nothing
    def schedule(condition, delay = condition.interval)
      @mutex.synchronize do
        unless @conditions.include?(condition)
          @events << TimerEvent.new(condition, delay)
          @conditions << condition
          @events.sort! { |x, y| x.at <=> y.at }
        end
      end
    end
    
    # Remove any TimerEvents for the given condition
    #   +condition+ is the Condition
    #
    # Returns nothing
    def unschedule(condition)
      @mutex.synchronize do
        @conditions.delete(condition)
        @events.reject! { |x| x.condition == condition }
      end
    end
    
    # Trigger the event's condition to be evaluated
    #   +event+ is the TimerEvent to trigger
    #
    # Returns nothing
    def trigger(event)
      Hub.trigger(event.condition, event.phase)
    end
    
    # Join the timer thread
    #
    # Returns nothing
    def join
      @timer.join
    end
  end
  
end