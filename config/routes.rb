Rails.application.routes.draw do
  devise_for :users
  ActiveAdmin.routes(self)

  # The resident journey. Deliberately short and unauthenticated: a household opens
  # its own record with the secret token from its link — no account, no password.
  # This is the URL a WhatsApp or SMS message will carry once that channel exists.
  get   "h/:token", to: "household_updates#show",   as: :household_update
  patch "h/:token", to: "household_updates#update"

  # The same pages, reached from a PIN session rather than a link.
  get   "my-household", to: "household_updates#show",   as: :household_dashboard
  patch "my-household", to: "household_updates#update"

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
  get "about",    to: "public#about"
  get "privacy",  to: "public#privacy"
  get "contact",  to: "public#contact"
  get "payments", to: "public#payments"
  get "diaspora", to: "public#diaspora"

  # Creating a payment reference. No money moves — this is what lets the office
  # match a payment that arrives to the collection it was meant for.
  post "payment-references", to: "payment_references#create", as: :payment_references
  get "services", to: "public#services"

  # Kept so older links and anything already shared still land somewhere.
  get "campaigns", to: redirect("/payments")
  get "trust",     to: redirect("/privacy")

  # The resident front door: phone number plus the PIN the village office issued.
  # There is deliberately no route here that sets or resets a PIN from a phone
  # number alone.
  get    "registry",         to: "resident/sessions#new",     as: :registry
  post   "registry",         to: "resident/sessions#create"
  delete "registry/signout", to: "resident/sessions#destroy", as: :registry_signout
  get    "registry/pin",     to: "resident/pins#edit",        as: :change_pin
  patch  "registry/pin",     to: "resident/pins#update"

  # Have your say — public feedback.
  get  "have-your-say", to: "feedbacks#new",    as: :have_your_say
  post "have-your-say", to: "feedbacks#create", as: :feedbacks

  # The only place the public can write over the web. It creates a request for a
  # registrar to action, never a registry record. Written out rather than
  # `resources` so the form lives at /register itself, which is what anyone would
  # type or be told.
  get  "register", to: "registration_requests#new",    as: :new_registration_request
  post "register", to: "registration_requests#create", as: :registration_requests

  # Inbound WhatsApp. Unauthenticated by nature — the provider's signature is the
  # control, and it is verified before the payload is read.
  post "webhooks/whatsapp", to: "webhooks/whatsapp#create"

  # Delivery status callbacks. Without these "sent" only means the provider
  # accepted the message, not that it reached anyone.
  post "webhooks/whatsapp/status", to: "webhooks/whatsapp_status#create"
end
