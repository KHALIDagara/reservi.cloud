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

    driven_by :headless_chrome, screen_size: [ 375, 812 ]
  else
    driven_by :rack_test
  end

  # Reset fixtures-driven data before each test
  fixtures :all

  # Helper: sign in as a user via the actual form, then navigate to an
  # account-scoped page. Works with both rack_test and headless_chrome.
  def sign_in_as(user, account: nil)
    visit new_session_url
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password123"
    click_button "Sign in"

    if account
      # Navigate explicitly so an Account name appearing elsewhere cannot make
      # this helper mistake the account switcher for the selected workspace.
      assert_current_path accounts_path, wait: 10
      visit account_home_url(account_id: account.id)
    end
  end

  # Resize helpers — no-op under rack_test, functional under headless_chrome
  def resize_phone
    return unless page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:manage)
    page.driver.browser.manage.window.resize_to(375, 812)
  end

  def resize_desktop
    return unless page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:manage)
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  def javascript_driver?
    page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:manage)
  end
end
