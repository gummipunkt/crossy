Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :posts, only: [:create, :show] do
        resources :deliveries, only: [:index]
      end
      namespace :nostr do
        post :prepare_event
        post :publish
      end
    end
  end

  # Threads OAuth
  get "/auth/threads", to: "threads_auth#new"
  get "/auth/threads/callback", to: "threads_auth#callback"

  resources :provider_accounts, only: [:index, :create, :destroy]
  # Own Posts
  get "/my", to: "timeline#index"
  # Aggregated Timeline
  get "/timeline", to: "feeds#index"
  post "/timeline/action", to: "feeds#interact"

  resources :posts, only: [:new, :create, :show]
  root to: "posts#new"

  namespace :admin do
    resources :users, only: [:index, :show, :edit, :update, :destroy] do
      member do
        post :make_admin
      end
    end
  end
end
