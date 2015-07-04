require 'ruby_mint'
require 'vcr'
require 'webmock/rspec'

# Support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.before :each do

  end

  config.after :each do

  end
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    :match_requests_on => [:method,
      VCR.request_matchers.uri_without_param(:rnd)]
  }
end
