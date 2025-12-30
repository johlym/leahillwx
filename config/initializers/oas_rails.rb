# config/initializers/oas_rails.rb
OasRails.configure do |config|
  # Source OAS file for reusable components
  config.source_oas_path = "lib/assets/oas.json"

  # Basic Information about the API
  config.info.title = "leahillwx.org API documentation"
  config.info.version = "1.0.0"
  config.info.summary = "leahillwx.org API documentation"
  config.info.description = <<~HEREDOC
    The leahillwx.org API is designed to provide weather measurement input to the site. This API is largely private (except where noted), requires authentication, and is subject to change. This documentation portal is provided for reference, testing purposes, and proof of concept.
  HEREDOC
  config.info.contact.name = "Johnathan Lyman"
  config.info.contact.email = "email@johnathan.org"
  config.info.contact.url = "https://a-chacon.com"

  # Servers Information. For more details follow: https://spec.openapis.org/oas/latest.html#server-object
  config.servers = [ { url: "http://localhost:3000", description: "Local" } ]

  # Tag Information. For more details follow: https://spec.openapis.org/oas/latest.html#tag-object
  config.tags = [ { name: "Weather Measurements", description: "Manage the `weather_measurements` table." } ]

  config.include_mode = :with_tags

  # Optional Settings (Uncomment to use)

  # Extract default tags of operations from namespace or controller. Can be set to :namespace or :controller
  # config.default_tags_from = :namespace

  # Automatically detect request bodies for create/update methods
  # Default: true
  # config.autodiscover_request_body = false

  # Automatically detect responses from controller renders
  # Default: true
  # config.autodiscover_responses = false

  # API path configuration if your API is under a different namespace
  config.api_path = "/api"

  # Apply your custom layout. Should be the name of your layout file
  # Example: "application" if file named application.html.erb
  # Default: false
  # config.layout = "application"

  # Override general rapidoc settings
  # config.rapidoc_configuration
  # default: {}

  # Add a logo to rapidoc
  # config.rapidoc_logo_url
  # default: nil

  # Override specific rapidoc theme settings
  # config.rapidoc_theme_configuration
  # default: {}

  config.rapidoc_theme = "rails"
  # Excluding custom controllers or controllers#action
  # Example: ["projects", "users#new"]
  # config.ignored_actions = []

  # #######################
  # Authentication Settings
  # #######################

  # Whether to authenticate all routes by default
  # Default is true; set to false if you don't want all routes to include security schemas by default
  # config.authenticate_all_routes_by_default = true

  # Default security schema used for authentication
  # Choose a predefined security schema
  # [:api_key_cookie, :api_key_header, :api_key_query, :basic, :bearer, :bearer_jwt, :mutual_tls]
  # config.security_schema = :bearer

  # Custom security schemas
  # Please follow the documentation: https://spec.openapis.org/oas/latest.html#security-scheme-object
  config.security_schemas = {
    api_key: {
      type: "http",
      scheme: "bearer",
      description: "Bearer token for authentication"
    }
  }

  # ###########################
  # Default Responses (Errors)
  # ###########################

  # The default responses errors are set only if the action allow it.
  # Example, if you add forbidden then it will be added only if the endpoint requires authentication.
  # Example: not_found will be setted to the endpoint only if the operation is a show/update/destroy action.
  # config.set_default_responses = true
  # config.possible_default_responses = [:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_entity]
  # config.response_body_of_default = "Hash{ message: String }"
  # config.response_body_of_unprocessable_entity= "Hash{ errors: Array<String> }"
end
