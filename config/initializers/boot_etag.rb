# Generate a unique ETag value on each application boot
# This ensures cached responses are invalidated after deployments
Rails.application.config.boot_etag = SecureRandom.uuid
