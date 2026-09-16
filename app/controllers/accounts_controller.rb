class AccountsController < ApplicationController
  PAGE_SIZE = 20

  def index
    @memberships = scoped_memberships.take(PAGE_SIZE)
    @next_cursor = scoped_memberships.size > PAGE_SIZE ? @memberships.last.id : nil
  end

  def new
    @operation_key = SecureRandom.uuid
  end

  def create
    account = Accounts::Create.call(
      user: Current.user,
      name: account_params[:name],
      operation_key: account_params[:operation_key].presence || SecureRandom.uuid,
      locale: account_params[:locale].presence || "en",
      timezone: account_params[:timezone].presence || "UTC"
    )

    if account&.persisted?
      redirect_to account_home_path(account), notice: "#{account.name} is ready."
    else
      @account = account || Account.new(account_params)
      @operation_key = SecureRandom.uuid
      render :new, status: :unprocessable_content
    end
  end

  private

  # Keyset (cursor) pagination over memberships; a different tab can always
  # resolve its own Account context from the URL without session retargeting.
  def scoped_memberships
    scope = Current.user.memberships.active.includes(:account).order(id: :desc)
    scope = scope.where("memberships.id < ?", params[:before].to_i) if params[:before].present?
    scope.limit(PAGE_SIZE + 1)
  end

  def account_params
    params.fetch(:account, {}).permit(:name, :operation_key, :locale, :timezone)
  end
end
