module Accounts
  class HomeController < ApplicationController
    before_action :require_account_access!

    def show
    end
  end
end
