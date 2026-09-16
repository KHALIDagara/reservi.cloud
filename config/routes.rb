Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "register", to: "registrations#new"
  post "register", to: "registrations#create"

  get "verify_email/:token", to: "email_verifications#show", as: :verify_email
  post "verify_email/resend", to: "email_verifications#resend", as: :resend_verification_email

  get "accounts", to: "accounts#index", as: :accounts
  get "accounts/new", to: "accounts#new", as: :new_account
  post "accounts", to: "accounts#create"

  # Invitation acceptance links are global; the token in the path is the secret
  # (it is filtered from logs by config.filter_parameters => token).
  get "invitations/accept/:token", to: "invitation_accepts#show", as: :accept_invitation
  post "invitations/accept/:token", to: "invitation_accepts#accept"

  # Per-tab Account routing: the URL carries the Account explicitly and every
  # request revalidates an active Membership (INV-130).
  scope "/a/:account_id", module: :accounts do
    get "/", to: "home#show", as: :account_home
    get "inbox", to: "inbox#index", as: :account_inbox
    get "conversations/new", to: "conversations#new", as: :new_account_conversation
    post "conversations", to: "conversations#create", as: :account_conversations
    get "conversations/:id", to: "conversations#show", as: :account_conversation
    get "conversations/:id/panel", to: "conversations#panel", as: :account_conversation_panel
    post "conversations/:id/messages", to: "conversations#create_message", as: :account_conversation_messages
    post "conversations/:id/notes", to: "conversations#create_note", as: :account_conversation_notes
    post "conversations/:id/claim", to: "conversations#claim", as: :account_conversation_claim
    post "conversations/:id/unclaim", to: "conversations#unclaim", as: :account_conversation_unclaim
    post "conversations/:id/cancel", to: "conversations#cancel", as: :account_conversation_cancel
    # Magic side panel operations
    patch "conversations/:id/field", to: "conversations#update_field", as: :account_conversation_field
    patch "conversations/:id/customer_field", to: "conversations#update_customer_field", as: :account_conversation_customer_field
    post "conversations/:id/reassign", to: "conversations#reassign", as: :account_conversation_reassign
    post "conversations/:id/appointments", to: "conversations#create_appointment", as: :account_conversation_appointments
    post "conversations/:appointment_id/confirm_appointment", to: "conversations#confirm_appointment", as: :confirm_account_conversation_appointment
    post "conversations/:appointment_id/cancel_appointment", to: "conversations#cancel_appointment", as: :cancel_account_conversation_appointment
    get "people", to: "people#index", as: :account_people
    get "invitations/new", to: "invitations#new", as: :new_account_invitation
    post "invitations", to: "invitations#create", as: :account_invitations
    post "invitations/:id/resend", to: "invitations#resend", as: :resend_account_invitation
    post "invitations/:id/revoke", to: "invitations#revoke", as: :revoke_account_invitation
    post "memberships/:id/role", to: "memberships#update_role", as: :account_membership_role
    post "memberships/:id/remove", to: "memberships#remove", as: :account_membership_remove

    # Field definitions (admin)
    get "field_definitions", to: "field_definitions#index", as: :account_field_definitions
    get "field_definitions/new", to: "field_definitions#new", as: :new_account_field_definition
    post "field_definitions", to: "field_definitions#create", as: :account_field_definitions_create
    post "field_definitions/:id/archive", to: "field_definitions#archive", as: :archive_account_field_definition

    # Customer profile fields
    get "customers/:customer_id/fields/edit", to: "customer_fields#edit", as: :edit_account_customer_fields
    post "customers/:customer_id/fields", to: "customer_fields#update", as: :account_customer_fields

    # Catalogs (admin for create)
    resources :catalogs, only: [:index, :new, :create], controller: "catalogs" do
      get :items, on: :member
    end

    # Item selections
    resources :item_selections, only: [:create, :destroy]

    # Flow management (admin)
    resources :flows, only: [:index, :new, :create, :edit, :update], controller: "flows" do
      resources :versions, only: [:new, :create, :show, :edit, :update], controller: "flow_versions", as: :flow_version do
        member do
          post :publish
          post :preview
        end
        # Stages are edited inline within the version
        resources :stages, only: [:new, :create, :edit, :update, :destroy], controller: "stages"
      end
    end
  end

  # Webhook endpoints — authenticated by inbound_token, not by session
  post "webhooks/dev/:token", to: "webhooks#dev_inbound", as: :dev_webhook_inbound
  post "webhooks/dev/:token/status", to: "webhooks#dev_status", as: :dev_webhook_status

  get "up" => "rails/health#show", as: :rails_health_check

  # Root: logged-out visitors see the landing page; signed-in users see their
  # account switcher. The landing controller allows unauthenticated access and
  # redirects authenticated users to after_authentication_url.
  root "landing#show"
end