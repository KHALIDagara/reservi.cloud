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
    post "conversations/:id/messages", to: "conversations#create_message", as: :account_conversation_messages
    post "conversations/:id/notes", to: "conversations#create_note", as: :account_conversation_notes
    post "conversations/:id/claim", to: "conversations#claim", as: :account_conversation_claim
    post "conversations/:id/unclaim", to: "conversations#unclaim", as: :account_conversation_unclaim
    post "conversations/:id/cancel", to: "conversations#cancel", as: :account_conversation_cancel
    get "people", to: "people#index", as: :account_people
    get "invitations/new", to: "invitations#new", as: :new_account_invitation
    post "invitations", to: "invitations#create", as: :account_invitations
    post "invitations/:id/resend", to: "invitations#resend", as: :resend_account_invitation
    post "invitations/:id/revoke", to: "invitations#revoke", as: :revoke_account_invitation
    post "memberships/:id/role", to: "memberships#update_role", as: :account_membership_role
    post "memberships/:id/remove", to: "memberships#remove", as: :account_membership_remove
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # Signed-in users land on their Account switcher; guests are redirected to
  # sign in by Authentication#request_authentication.
  root "accounts#index"
end