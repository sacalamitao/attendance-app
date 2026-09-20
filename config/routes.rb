Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]

  root "dashboard#show"
  get "offline", to: "pages#offline"

  # PWA manifest + service worker (app/views/pwa/*)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :attendees do
    member do
      get :qr
      post :reactivate
    end
  end

  resources :events, except: [ :destroy ] do
    member do
      post :open
      post :close
      post :reopen
      get :dashboard
      get :scanner
      get :report
    end
  end

  namespace :api, defaults: { format: :json } do
    get "classification", to: "classifications#show"

    resources :attendees, only: [ :index, :show, :create, :update, :destroy ] do
      member do
        get :qr
        get :attendance
      end
    end

    resources :events, only: [ :index, :show, :create, :update ] do
      member do
        post :open
        post :close
      end

      get  "attendance",           to: "attendances#index"
      post "attendance/scan",      to: "attendances#scan"
      get  "attendance/dashboard", to: "attendances#dashboard"
      get  "report",               to: "reports#show"
    end
  end
end
