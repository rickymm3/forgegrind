Rails.application.routes.draw do
  root to: "home#index"

  get "/adopt", to: "adopt#index"
  get "nursery", to: "nursery#index", as: :nursery
  get "home/index"
  get "profile", to: "users#show", as: :user_profile  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :user_pets, only: [:index, :show] do
    member do
      post :preview
      post :equip
      post :interact
      post :level_up
      post :interact_preview
      post :energy_tick
    end
    collection do
      post :unequip
    end
  end

  resources :battle_sessions, only: [] do
    # POST /battle_sessions/:id/attack    → BattleSessionsController#attack
    # POST /battle_sessions/:id/complete  → BattleSessionsController#complete
    member do
      post :wave_complete
      post :attack
      post :sync
      post :complete
    end
  end

  # Battle gauntlet per world
  # Per-world battle:
  resources :worlds, only: [:index] do
    resource :battle_session, only: [:new, :create], controller: 'battle_sessions'
  end
  resource :player_stats,
           path: 'hero',
           as:   'hero',
           only: [:show] do
    post :upgrade, on: :member
  end

  get "/items", to: "items#index", as: :items


  namespace :admin do
    root to: "dashboard#index"
  
    resources :eggs do
      post :assign_pets, on: :member
    end
    resources :abilities
    resources :pets
  end
  

  resources :explorations, only: [:index] do
    member do
      post :start
      post :preview
      post :complete
    end
  end  
  
  resources :pets, only: [:index, :show]

  resources :user_explorations, only: [] do
    post :complete, on: :member
    get :ready   # new: GET /user_explorations/:id/ready

  end

  resources :user_eggs, only: [:create] do
    member do
      post :incubate
      post :mark_ready
      post :hatch      
    end
  end
  get "nursery/hatch/:id", to: "nursery#hatch", as: :nursery_hatch

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
