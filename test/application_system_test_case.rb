require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # System tests require a Chrome/Chromium browser. On hosts without one,
  # system tests use Rack::Test (non-JS). Set CHROME_BIN to the path of
  # a Chrome/Chromium binary and the test will use Selenium instead.
  # Example:
  #   CHROME_BIN=~/.cache/ms-playwright/chromium-1234/chrome-linux/chrome bin/rails test:system
  chrome_bin = ENV["CHROME_BIN"].presence

  if chrome_bin
    chromedriver = Dir["#{Dir.home}/.cache/selenium/chromedriver/linux-*/chromedriver"].first

    Capybara.register_driver :headless_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.binary = chrome_bin
      options.args << "--headless=new"
      options.args << "--no-sandbox"
      options.args << "--disable-gpu"

      driver = Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
      driver
    end

    driven_by :headless_chrome, screen_size: [375, 812]
  else
    driven_by :rack_test
  end

  # Reset fixtures-driven data before each test
  fixtures :all
end