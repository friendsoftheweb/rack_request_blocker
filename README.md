# RackRequestBlocker

Handle race conditions in Rails JS feature tests caused by outstanding overlapping actions in your app, with rack middleware to let you wait for pending feature test actions to finish.

For background on why this might be a problem you want to handle, see:
* http://blog.salsify.com/engineering/tearing-capybara-ajax-tests
* https://bibwild.wordpress.com/2016/02/18/struggling-towards-reliable-capybara-javascript-testing/

This gem is based on a concept and code [originally by Joel Turkel](http://blog.salsify.com/engineering/tearing-capybara-ajax-tests), but updated to use [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby) as a dependency, with signal/wait logic instead of polling.

**WARNING**: This code is somewhat experimental, concurrency is hard, it may have bugs. It currently
has no automated tests (testing concurrency is painful). But it's working for me, and you
only use it in test environment anyway, so if you're suffering from horrible race
conditions in test, it's worth a shot to see if it helps, and entails little risk.
It's also only a few dozen lines of code in one class, please do look at the source. 

## Installation/Usage

1. Add this line to your application's Gemfile:

    ```ruby
    gem 'rack_request_blocker'
    ```

    And then execute:

        $ bundle

    Or install it yourself as:

        $ gem install rack_request_blocker

2. Add this to your `./config/environments/test.rb`, to add the custom middleware in test env:

    ~~~ruby
    require 'rack_request_blocker'
    config.middleware.insert_before 0, RackRequestBlocker
    ~~~

3. Add this to your `spec_helper.rb`/`rails_helper.rb`

    Add _before_ your `DatabaseCleaner.clean` command, probably in a `before(:each)`:

    ~~~ruby
    if example.metadata[:js] || example.metadata[:driver] != :rack_test
      RackRequestBlocker.wait_for_no_active_requests(for_example: example)
    end
    ~~~

    This says for each JS test, block incoming requests to the embedded dummy Rails app,
    and then wait until any in-progress request actions are complete, before proceeding
    (to your `DatabaseCleaner.clean`, and then on to the next test. ) It relies on the
    custom middleware to be able to do so.

## Will this take care of all my unreliable test issues?

I found I **also** needed to stop using transactional testing *entirely*.
No `:transaction` strategy for DatabaseCleaner *at all*, in *addition* to this
middle-ware, to get reliable tests.

I can't explain why: Using transactional strategy for *non-JS tests*, as
DatabaseCleaner recommends *ought* to work. But it didn't, and I even got
some segfaults(!) with only the middleware but still transactional strategy
for non-JS tests.  Could be a bug in MRI or the pg or poltegeist gems (segfault, really?),
or capybara, databasecleaner, or the test_after_commit gem we were using
with transactional testing strategy. I dunno, debugging this stuff
is *hard*... but this seems to have finally worked.

If you are still having problems, I recommend consulting
[my essay on an overview of the issues](https://bibwild.wordpress.com/2016/02/18/struggling-towards-reliable-capybara-javascript-testing/) for background and more ideas.

