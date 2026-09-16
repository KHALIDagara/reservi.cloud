module Accounts
  class CatalogsController < ApplicationController
    before_action :require_account_access!

    def index
      @catalogs = current_account.catalogs.active.ordered.includes(:items)
    end

    def new
      require_admin!
      @catalog = current_account.catalogs.new
    end

    def create
      require_admin!
      @catalog = current_account.catalogs.new(catalog_params)
      if @catalog.save
        redirect_to catalogs_path(account_id: current_account), notice: "Catalog created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def items
      @catalog = current_account.catalogs.active.find(params[:id])
      @items = @catalog.items.active.ordered
      render layout: false
    end

    private

    def catalog_params
      params.require(:catalog).permit(:title, item_attributes: {})
    end

    def require_admin!
      unless Accounts::Policy.new(current_membership).admin?
        raise Reservi::Errors::AuthorizationError, "Only Account administrators can manage catalogs."
      end
    end
  end
end
