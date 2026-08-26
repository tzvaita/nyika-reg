Rails.application.routes.draw do
  devise_for :users
  ActiveAdmin.routes(self)

  # The resident journey. Deliberately short and unauthenticated: a household opens
  # its own record with the secret token from its link — no account, no password.
  # This is the URL a WhatsApp or SMS message will carry once that channel exists.
  get   "h/:token", to: "household_updates#show",   as: :household_update
  patch "h/:token", to: "household_updates#update"

  # The rest of the resident menu from the concept deck. Every page is scoped to
  # the household the token identifies.
  scope "h/:token", as: :resident do
    get  "support",      to: "resident/support#index",       as: :support
    post "support",      to: "resident/support#create"
    get  "applications", to: "resident/applications#index",  as: :applications
    get  "pay",          to: "resident/payments#index",      as: :payments
    post "pay",          to: "resident/payments#create"
    get  "receipts",     to: "resident/receipts#index",      as: :receipts
    get  "office",       to: "resident/office#index",        as: :office
  end

  # Assisted capture: the same mobile form, driven by a signed-in registrar during
  # a home visit.
  namespace :capture do
    resources :households, only: [ :new, :create, :edit, :update ]
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # The public website. Shows what the platform does, the trust rules and live
  # campaign totals — and no personal data whatsoever.
  root "public#home"
  get "services", to: "public#services"
  get "campaigns", to: "public#campaigns"
  get "trust",    to: "public#trust"

  # The only place the public can write over the web. It creates a request for a
  # registrar to action, never a registry record. Written out rather than
  # `resources` so the form lives at /register itself, which is what anyone would
  # type or be told.
  get  "register", to: "registration_requests#new",    as: :new_registration_request
  post "register", to: "registration_requests#create", as: :registration_requests

  # Inbound WhatsApp. Unauthenticated by nature — the provider's signature is the
  # control, and it is verified before the payload is read.
  post "webhooks/whatsapp", to: "webhooks/whatsapp#create"
end
