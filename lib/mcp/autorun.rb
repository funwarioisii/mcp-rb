module MCP
  # This is from Sinatra to detect if the app should run at_exit
  module Autorun
    CALLERS_TO_IGNORE = [ # :nodoc:
      %r{/mcp(/(app|autorun))?\.rb$},   # all sinatra code
      /^\(.*\)$/,                                         # generated code
      /\/bundled_gems.rb$/,                               # ruby >= 3.3 with bundler >= 2.5
      %r{rubygems/(custom|core_ext/kernel)_require\.rb$}, # rubygems require hacks
      /active_support/,                                   # active_support require hacks
      %r{bundler(/(?:runtime|inline))?\.rb},              # bundler require hacks
      /<internal:/,                                       # internal in ruby >= 1.9.2
      %r{zeitwerk/(core_ext/)?kernel\.rb}                 # Zeitwerk kernel#require decorator
    ].freeze

    def callers_to_ignore
      CALLERS_TO_IGNORE
    end

    def cleaned_caller(keep = 3)
      caller(1)
        .map! { |line| line.split(/:(?=\d|in )/, 3)[0, keep] }
        .reject { |file, *_| callers_to_ignore.any? { |pattern| file =~ pattern } }
    end
  end
end
