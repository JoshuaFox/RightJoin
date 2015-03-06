FiveYearItch::Application.configure do
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE 
  # Settings specified here will take precedence over those in config/application.rb
 
  # In development but not production environment, your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false
  config.cache_store = :memory_store

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  config.log_level = :debug

  # Showing full error reports in browser; caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Compressing JavaScripts and CSS
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true
  
  # Raising errors if the mailer can't send
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.smtp_settings = {
    :address              => "smtp.gmail.com",
    :port                 => 587,
    :domain               => "google.com",
    :user_name            => "marcfent@gmail.com",
    :password             => "__PASSWORD__",
    :authentication       => :plain,
    :enable_starttls_auto => true
  }

  config.action_mailer.default_url_options = { :host => 'localhost:3000' }
end
