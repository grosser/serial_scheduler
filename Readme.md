Simple scheduler for long-running and infrequent tasks.

 - no threads, always in serial, to avoid out-of-memory issues and race-conditions
 - forks for each execution to avoid leaking memory
 - no dependencies
 - supports crons with timezones

Install
=======

```Bash
gem install serial_scheduler
```

Usage
=====

```Ruby
require 'serial_scheduler'
scheduler = SerialScheduler.new

scheduler.add :foo, interval: 10, timeout: 2 do
  puts 'Doing foo'
end
scheduler.add :bar, interval: 5, timeout: 1 do
  puts 'Doing bar'
end

require 'fugit'
scheduler.add :bar, cron: "* * * * * America/New_York", timeout: 1 do
  puts 'Doing cron'
end

scheduler.run
```

### Logging

`SerialScheduler.new logger: my_logger`

### Errors

Send to error service of your choice, or don't set it and it will raise.

`SerialScheduler.new error_handler: ->(e) { puts e }`

### Stopping

Will not start any new task, but finish the current one.

`scheduler.stop`

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/serial_scheduler.png)](https://travis-ci.org/grosser/serial_scheduler)
