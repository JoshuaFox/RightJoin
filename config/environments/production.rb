FiveYearItch::Application.configure do
# Settings specified here will take precedence over those in config/application.rb

# In development but not production environment, your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the web server when you make code changes.
  config.cache_classes = true

  # Showing full error reports in browser; caching
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = true

  # Set an Expires header with an expiry date 1 year in the future
  config.static_cache_control = "public, max-age=30758400"

  # Compressing JavaScripts and CSS
  config.assets.compress = true

  # Compile live at runtime instead of fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Raising errors if the mailer can't send
  config.action_mailer.raise_delivery_errors = true
  
  config.action_mailer.default_url_options = {
    :host => "www.rightjoin.io",
    :protocol => 'https'
  }
 
  # setting up sendgrid
  ActionMailer::Base.smtp_settings = {
    :user_name => "fyi",
    :password => ENV['SG_SMTP_PASSWORD'],
    :domain => "rightjoin.io",
    :address => "smtp.sendgrid.net",
    :port => 587,
    :authentication => :plain,
    :enable_starttls_auto => true
  }
  
  ActionMailer::Base.delivery_method = :smtp

  # config.action_mailer.smtp_settings = {
  # :address              => "smtp.gmail.com",
  # :port                 => 587,
  # :domain               => "google.com",
  # :user_name            => "marcfent@gmail.com",
  # :password             => "__PASSWORD__",
  # :authentication       => :plain,
  # :enable_starttls_auto => true
  # }
  #
  #
  # config.action_mailer.default_url_options = {
  # :host => "gmail.com"
  # }

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  #config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new
  
  # Add HTTP Request IDs to log
  # see https://devcenter.heroku.com/articles/http-request-id and https://github.com/heroku/rack-timeout
  config.log_tags = [ :uuid ]

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store
  config.cache_store = :dalli_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  #config.assets.precompile += ['*.ico']
  
  ##config.assets.precompile += ['quiz-loader.js', 'quiz.js', "quiz-sample.js", 'quiz.css', 'widget-config.css']
  ##config.assets.precompile += ['board-loader.js', 'board.js', "board-config.js", 'board.css', 'widget-config.css']  

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify
end
class ActionDispatch::Request
  def local?
    false
  end
end