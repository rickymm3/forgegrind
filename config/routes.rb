Rails.application.routes.draw do
  root to: "home#index"

  get "/adopt", to: "adopt#index"
  get "adopt/index"
  get "nursery", to: "nursery#index", as: :nursery
  get "users/show"
  get "home/index"
  get "profile", to: "users#show", as: :user_profile  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :user_pets, only: [] do
    member do
      post :preview
      post :equip
    end
    collection do
      post :unequip
    end
  end

  namespace :admin do
    root to: "dashboard#index"
  
    resources :eggs do
      post :assign_pets, on: :member
    end

    resources :pets
  end
  

  resources :explorations, only: [:index] do
     post :start, on: :member
  end  
  
  resources :pets, only: [:index, :show]

  resources :user_explorations, only: [] do
    post :complete, on: :member
  end

  resources :user_eggs, only: [:create] do
    member do
      post :incubate
      post :mark_ready
      post :hatch
    end
  end

  devise_for :users


  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  
end
