class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :offline

  # Cached by the service worker and shown when the network is unavailable.
  def offline
    render layout: "minimal"
  end
end
