Rails.application.routes.draw do
  root to: "home#index"

  get "/adopt", to: "adopt#index"
  get "nursery", to: "nursery#index", as: :nursery
  get "home/index"
  get "profile", to: "users#show", as: :user_profile  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  resources :user_pets, only: [:index, :show, :destroy] do
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

  get "/items", to: redirect("/inventory")
  resource :inventory, only: [:show] do
    post :container_panel
    post :item_panel
  end

  namespace :containers do
    post :open, to: "open#create"
  end


  namespace :admin do
    root to: "dashboard#index"
    resources :dashboard, only: [:index] do
      collection do
        post :grant_items
      end
    end
  
    resources :eggs do
      post :assign_pets, on: :member
    end
    resources :abilities
    resources :special_abilities
    resources :pets
    resources :user_pets, only: [:index, :show, :edit, :update]
    resources :evolution_rules do
      collection do
        get :dry_run
      end
    end
  end
  

  resources :explorations, only: [:index, :show] do
    collection do
      post :scout
    end
    member do
      post :start
      post :preview
      post :reroll
    end
  end

  resources :pets, only: [:index, :show]

  resources :user_explorations, only: [] do
    post :complete, on: :member
    get :ready   # new: GET /user_explorations/:id/ready
    post :activate_encounter, on: :member
    post :resolve_encounter, on: :member
    post :checkpoint, on: :member
    post :continue_segment, on: :member
  end

  resources :user_eggs, only: [:create, :show] do
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
