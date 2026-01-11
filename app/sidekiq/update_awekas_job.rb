class UpdateAwekasJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(*args)
    # Do something
  end
end
