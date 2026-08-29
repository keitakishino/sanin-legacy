Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "pages#home"

  get "/signin", to: "sessions#new"
  post "/signin", to: "sessions#create"
  delete "/signout", to: "sessions#destroy"

  get "/invite", to: "invitations_entries#new"
  post "/invite", to: "invitations_entries#create"

  get "/signup", to: "registrations#new"
  post "/signup", to: "registrations#create"

  get "/mypage", to: "users/profiles#show", as: :mypage
  get "/mypage/edit", to: "users/profiles#edit", as: :edit_mypage
  patch "/mypage", to: "users/profiles#update"

  match "/auth/:provider/callback", to: "omniauth_callbacks#create", via: [ :get, :post ]
  get "/auth/failure", to: "omniauth_callbacks#failure"

  # User-facing events (listing and detail view)
  resources :events, only: [ :index, :show ]

  namespace :admin do
    resources :invitations, only: [ :index, :create ]
    resources :events, only: [ :index, :new, :create, :edit, :update, :destroy ]
  end
end
