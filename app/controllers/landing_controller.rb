class LandingController < ApplicationController
  allow_unauthenticated_access

  def show
    if authenticated?
      redirect_to accounts_path
    end
  end
end